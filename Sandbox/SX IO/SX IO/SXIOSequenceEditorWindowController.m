//
//  SXIOSequenceEditorWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/5/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOSequenceEditorWindowController.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOSequenceStep : NSObject<NSCoding,NSCopying>
@property (nonatomic,readonly,copy) NSString* type;
@property (nonatomic,readonly,getter=isValid) BOOL valid;
@end

@interface SXIOSequenceStep ()
@property (nonatomic,assign) BOOL active; // per-step flag
@property (nonatomic,assign) BOOL sequenceRunning; // whole sequence flag
@property (nonatomic,copy) NSString* type;
@end

@implementation SXIOSequenceStep

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        self.type = [coder decodeObjectOfClass:[NSString class] forKey:@"type"];
    }
    return self;
}

- (BOOL)isValid
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.type forKey:@"type"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SXIOSequenceStep* copy = [[self class] new];
    copy.type = self.type;
    return copy;
}

@end

@interface SXIOSequenceExposureStep : SXIOSequenceStep
@property (nonatomic,assign) NSInteger count;
@property (nonatomic,assign) NSInteger duration;
@property (nonatomic,assign) NSInteger binning;
@property (nonatomic,assign) NSInteger binningIndex;
@property (nonatomic,copy) NSString* filter;
@end

@interface SXIOSequenceExposureStep ()
@property (nonatomic,strong) NSArray* filterNames;
@end

@implementation SXIOSequenceExposureStep

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.count = 1;
        self.duration = 300; // use a default, last value entered ?
        self.binning = 1;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.count = [coder decodeIntegerForKey:@"count"];
        self.duration = [coder decodeIntegerForKey:@"duration"]; // always seconds
        self.binning = [coder decodeIntegerForKey:@"binning"];
        self.filter = [coder decodeObjectOfClass:[NSString class] forKey:@"filter"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeInteger:self.count forKey:@"count"];
    [aCoder encodeInteger:self.duration forKey:@"duration"];
    [aCoder encodeInteger:self.binning forKey:@"binning"];
    [aCoder encodeObject:self.filter forKey:@"filter"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SXIOSequenceExposureStep* copy = [super copyWithZone:zone];
    
    copy.count = self.count;
    copy.duration = self.duration;
    copy.binning = self.binning;
    copy.filter = self.filter;

    return copy;
}

- (NSString*)type
{
    return @"exposure";
}

- (BOOL)isValid
{
    return (self.count > 0 && self.duration > 0 && self.binning > 0);
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"count" isEqualToString:key]){
        self.count = 0;
    }
    else if ([@"duration" isEqualToString:key]){
        self.duration = 0;
    }
    else {
        [super setNilValueForKey:key];
    }
}

- (NSInteger)binningIndex
{
    return self.binning - 1;
}

- (void)setBinningIndex:(NSInteger)binningIndex
{
    self.binning = binningIndex + 1;
}

- (void)setBinning:(NSInteger)binning
{
    _binning = MIN(4,MAX(1,binning));
}

+ (NSSet*)keyPathsForValuesAffectingBinningIndex
{
    return [NSSet setWithObject:@"binning"];
}

- (NSString*)selectedFilter
{
    NSArray* filterNames = [self filterNames];
    return [filterNames containsObject:self.filter] ? self.filter : [filterNames firstObject];
}

- (void)setSelectedFilter:(NSString *)filter
{
    NSArray* filterNames = [self filterNames];
    if ([filter isEqualToString:[filterNames firstObject]] || ![filterNames containsObject:filter]){
        filter = nil;
    }
    self.filter = filter;
}

@end

@interface SXIOSequence : NSObject<NSCoding>
@property (nonatomic,strong) NSMutableArray* steps;
@property (nonatomic,copy) NSString* prefix;
@property (nonatomic,assign) NSInteger dither;
@property (nonatomic,assign) NSInteger temperature;
@end

@implementation SXIOSequence

- (id)init
{
    self = [super init];
    if (self) {
        self.steps = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        self.steps = [[coder decodeObjectOfClass:[NSArray class] forKey:@"steps"] mutableCopy];
        self.dither = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"dither"] integerValue];
        self.temperature = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"temperature"] integerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.steps forKey:@"steps"];
    [aCoder encodeInteger:self.dither forKey:@"dither"];
    [aCoder encodeInteger:self.temperature forKey:@"temperature"];
}

- (void)setNilValueForKey:(NSString *)key
{
    [super setNilValueForKey:key];
}

@end

@interface SXIOSequenceRunner : NSObject // use an operation queue?
@property (nonatomic,weak) SXIOSequence* sequence; // copy ?
@property (nonatomic,weak) id<SXIOSequenceTarget> target;
@property (nonatomic,weak,readonly) SXIOSequenceStep* currentStep;
@property (nonatomic,copy) void(^completion)();
- (BOOL)startWithError:(NSError**)error;
- (void)stop;
@end

@interface SXIOSequenceRunner ()
@property (nonatomic,weak) SXIOSequenceStep* currentStep;
@end

@implementation SXIOSequenceRunner {
    BOOL _stopped:1;
    BOOL _observing:1;
}

static void* kvoContext;

- (void)dealloc
{
    [self unobserveFilterWheel];
}

- (BOOL)startWithError:(NSError**)error
{
    NSParameterAssert(self.target);
    
    _stopped = NO;
    
    if (![self.target prepareToStartSequenceWithError:error]){
        return NO;
    }
    
    self.currentStep = [self.sequence.steps firstObject];
    
    // table cell subviews only seem to be able to bind to the container table view cell so
    // we need to set a property on its objectValue directly rather than going through the
    // File Owner proxy
    for (SXIOSequenceStep* step in self.sequence.steps){
        step.sequenceRunning = YES;
    }
    
    return YES;
}

- (void)stop
{
    _stopped = YES;
    
    self.currentStep = nil;
    
    for (SXIOSequenceStep* step in self.sequence.steps){
        step.sequenceRunning = NO;
    }

    [self unobserveFilterWheel];
    [self.target endSequence];
    if (self.completion){
        self.completion();
    }
}

- (void)observeFilterWheel
{
    if (!_observing){
        [self.target.sequenceFilterWheelController.filterWheel addObserver:self forKeyPath:@"moving" options:0 context:&kvoContext];
        _observing = YES;
    }
}

- (void)unobserveFilterWheel
{
    if (_observing){
        [self.target.sequenceFilterWheelController.filterWheel removeObserver:self forKeyPath:@"moving" context:&kvoContext];
        _observing = NO;
    }
}

- (void)setCurrentStep:(SXIOSequenceStep *)currentStep
{
    if (_currentStep != currentStep){
        _currentStep.active = NO;
        _currentStep = currentStep;
        if (_currentStep){
            [self executeCurrentStep];
            _currentStep.active = YES;
        }
    }
}

- (void)capture
{
    [self.target captureWithCompletion:^(){
        if (!_stopped){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self advanceToNextStep];
            });
        }
    }];
}

- (void)advanceToNextStep
{
    const NSInteger index = [self.sequence.steps indexOfObject:self.currentStep];
    if (index != NSNotFound && index < [self.sequence.steps count] - 1){
        self.currentStep = self.sequence.steps[index + 1];
    }
    else {
        [self stop];
    }
}

- (void)executeCurrentStep
{
    if (![self.currentStep isValid]){
        NSLog(@"Skipping empty step");
        [self advanceToNextStep];
    }
    else {
        
        SXIOSequenceExposureStep* sequenceStep = (SXIOSequenceExposureStep*)self.currentStep;
        CASExposureSettings* settings = self.target.sequenceCameraController.settings;

        settings.captureCount = sequenceStep.count;
        settings.exposureUnits = 0;
        settings.exposureDuration = sequenceStep.duration;
        settings.binningIndex = sequenceStep.binningIndex;
        
        // dither
        // temperature
        // prefix

        NSString* filter = sequenceStep.filter;
        if ([filter length]){
            // need to check it's a known filter name
            CASFilterWheelController* filterWheel = self.target.sequenceFilterWheelController;
            if (!filterWheel){
                NSLog(@"*** Filter wheel hasn't been selected in capture window");
                [self advanceToNextStep];
                return;
            }
            else {
                filterWheel.currentFilterName = filter;
                if (filterWheel.filterWheel.moving){
                    [self observeFilterWheel];
                    return;
                }
            }
        }
        
        [self capture];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if ([@"moving" isEqualToString:keyPath]){
            if ([self.target.sequenceFilterWheelController.currentFilterName isEqualToString:((SXIOSequenceExposureStep*)self.currentStep).filter]){
                [self unobserveFilterWheel];
                [self capture];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

@interface SXIOSequenceEditorWindowControllerStepsController : NSArrayController
@property (weak) IBOutlet SXIOSequenceEditorWindowController *windowController;
@end

@implementation SXIOSequenceEditorWindowControllerStepsController

- (void)setFilterNameOnObject:(id)object
{
    SXIOSequenceExposureStep* step = object;
    if ([step respondsToSelector:@selector(setFilterNames:)]){
        step.filterNames = [[[self.windowController.target.sequenceFilterWheelController.filterNames allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString* evaluatedObject, NSDictionary *_) {
            return [evaluatedObject length] > 0;
        }]] sortedArrayUsingSelector:@selector(compare:)];
    }
}

- (void)setContent:(id)content
{
    [super setContent:content];
    
    // only supporting exposure types for now but in the future could have focus, slew, etc
    self.filterPredicate = [NSPredicate predicateWithBlock:^BOOL(SXIOSequenceStep* step, NSDictionary *bindings) {
        return [step isKindOfClass:[SXIOSequenceExposureStep class]];
    }];
    
    for (id object in self.content){
        [self setFilterNameOnObject:object];
    }
}

- (id)newObject
{
    return [SXIOSequenceExposureStep new];
}

- (void)addObject:(id)object
{
    [super addObject:object];
    
    [self setFilterNameOnObject:object];
}

- (void)addObjects:(NSArray*)objects
{
    [super addObjects:objects];
    
    for (id object in objects){
        [self setFilterNameOnObject:object];
    }
}

@end

@interface SXIOSequenceEditorWindowController ()
@property (nonatomic,strong) SXIOSequence* sequence;
@property (nonatomic,strong) SXIOSequenceRunner* sequenceRunner;
@property (nonatomic,strong) IBOutlet SXIOSequenceEditorWindowControllerStepsController* stepsController;
@end

@implementation SXIOSequenceEditorWindowController

static void* kvoContext;

+ (instancetype)loadSequenceEditor
{
    return [[[self class] alloc] initWithWindowNibName:@"SXIOSequenceEditorWindowController"];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.sequence = [SXIOSequence new];
    
    NSButton* closeButton = [self.window standardWindowButton:NSWindowCloseButton];
    [closeButton setTarget:self];
    [closeButton setAction:@selector(close:)];
    
    // restore last sequence
    
    // [NSSet setWithArray:@[@"stepsController.arrangedObjects"]] doesn't seem to work so trigger manually
    [self.stepsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:&kvoContext];
}

- (void)dealloc
{
    self.sequenceRunner = nil;
    [self.stepsController removeObserver:self forKeyPath:@"arrangedObjects" context:&kvoContext];
}

- (void)close
{
    // warn first...
    [self.sequenceRunner stop];
    
    // save current sequence
    
    [super close];
}

- (void)setSequence:(SXIOSequence *)sequence
{
    if (_sequence != sequence){
        _sequence = sequence;
        self.stepsController.content = _sequence.steps;
    }
}

- (IBAction)start:(id)sender
{
    NSParameterAssert(self.target);
    NSParameterAssert([self.sequence.steps count] > 0);
    
    self.sequenceRunner = [SXIOSequenceRunner new];
    self.sequenceRunner.target = self.target;
    self.sequenceRunner.sequence = self.sequence;
    
    __typeof(self) weakSelf = self;
    self.sequenceRunner.completion = ^(){
        weakSelf.sequenceRunner = nil;
    };
    
    NSError* error;
    if (![self.sequenceRunner startWithError:&error]){
        self.sequenceRunner = nil;
        [NSApp presentError:error];
    }
    else {
        // change start to stop
    }
}

- (IBAction)cancel:(id)sender
{
    // warn first...
    [self.sequenceRunner stop];
    self.sequenceRunner = nil;
    
    // save current sequence

    if (self.parent){
        [self endSheetWithCode:NSModalResponseCancel];
    }
}

- (BOOL)canStart
{
    return self.target != nil && [self.sequence.steps count] > 0;
}

+ (NSSet*)keyPathsForValuesAffectingCanStart
{
    return [NSSet setWithArray:@[@"target",@"stepsController.arrangedObjects"]];
}

- (void)updateWindowRepresentedURL:(NSURL*)url
{
    self.window.representedURL = url; // need scoped bookmark data ?
    NSString* name = [url isFileURL] ? [[NSFileManager defaultManager] displayNameAtPath:url.path] : [url lastPathComponent];
    [self.window setTitleWithRepresentedFilename:name];
}

- (IBAction)save:(id)sender
{
    void (^archiveToURL)(NSURL*) = ^(NSURL* url){
        if ([[NSKeyedArchiver archivedDataWithRootObject:self.sequence] writeToURL:url options:NSDataWritingAtomic error:nil]){
            [self updateWindowRepresentedURL:url];
        }
    };
    
    if (self.window.representedURL){
        archiveToURL(self.window.representedURL);
    }
    else {
        NSSavePanel* save = [NSSavePanel savePanel];
        
        save.allowedFileTypes = @[@"caSequence"];
        save.canCreateDirectories = YES;
        
        [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton){
                archiveToURL(save.URL);
            }
        }];
    }
}

- (BOOL)canSave
{
    return [self.sequence.steps count] > 0;
}

+ (NSSet*)keyPathsForValuesAffectingCanSave
{
    return [NSSet setWithArray:@[@"stepsController.arrangedObjects"]];
}

- (IBAction)open:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = @[@"caSequence"];
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton){
            SXIOSequence* sequence = nil;
            @try {
                sequence = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfURL:open.URL]];
            }
            @catch (NSException *exception) {
                NSLog(@"Exception opening sequence archive: %@",exception);
            }
            if ([sequence isKindOfClass:[SXIOSequence class]]){
                self.sequence = sequence;
                [self updateWindowRepresentedURL:open.URL];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert* alert = [NSAlert alertWithMessageText:@"Can't open Sequence"
                                                     defaultButton:@"OK"
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:@"There was an problem reading the sequence file. It may be corrupt or contain sequence steps not supported by this version of %@.",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
                    [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
                });
            }
        }
    }];
}

- (BOOL)canOpen
{
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        [self willChangeValueForKey:@"canStart"];
        [self didChangeValueForKey:@"canStart"];
        [self willChangeValueForKey:@"canSave"];
        [self didChangeValueForKey:@"canSave"];
        [self willChangeValueForKey:@"canOpen"];
        [self didChangeValueForKey:@"canOpen"];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
