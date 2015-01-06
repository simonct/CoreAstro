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
@property (nonatomic,assign) NSInteger count;
@property (nonatomic,assign) NSInteger duration;
@property (nonatomic,assign) NSInteger binning;
@property (nonatomic,assign) NSInteger binningIndex;
@property (nonatomic,copy) NSString* filter;
@end

@interface SXIOSequenceStep ()
@property (nonatomic,assign) BOOL active;
@property (nonatomic,strong) NSArray* filterNames;
@end

@implementation SXIOSequenceStep

@synthesize active;

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
    self = [super init];
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
    [aCoder encodeInteger:self.count forKey:@"count"];
    [aCoder encodeInteger:self.duration forKey:@"duration"];
    [aCoder encodeInteger:self.binning forKey:@"binning"];
    [aCoder encodeObject:self.filter forKey:@"filter"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SXIOSequenceStep* copy = [SXIOSequenceStep new];
    
    copy.count = self.count;
    copy.duration = self.duration;
    copy.binning = self.binning;
    copy.filter = self.filter;

    return copy;
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

- (NSArray*)filterNames
{
    if (!_filterNames){
        // hack... no - get from targets filter wheel controller
        CASClassDefaults* defaults = [CASDeviceDefaults defaultsForClassname:@"SX Filter Wheel"];
        NSArray* names = [[[defaults.domain[@"filterNames"] allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString* evaluatedObject, NSDictionary *_) {
            return [evaluatedObject length] > 0;
        }]] sortedArrayUsingSelector:@selector(compare:)];
        _filterNames = [@[@"None"] arrayByAddingObjectsFromArray:names];
    }
    return _filterNames;
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

@interface SXIOSequenceRunner : NSObject
@property (nonatomic,weak) SXIOSequence* sequence; // copy ?
@property (nonatomic,weak) id<SXIOSequenceTarget> target;
@property (nonatomic,weak,readonly) SXIOSequenceStep* currentStep;
- (BOOL)startWithError:(NSError**)error;
- (void)stop;
@end

@interface SXIOSequenceRunner ()
@property (nonatomic,weak) SXIOSequenceStep* currentStep;
@end

@implementation SXIOSequenceRunner {
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
    
    if (![self.target prepareToStartSequenceWithError:error]){
        return NO;
    }
    
    self.currentStep = [self.sequence.steps firstObject];
    
    return YES;
}

- (void)stop
{
    [self unobserveFilterWheel];
    [self.target endSequence];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [self advanceToNextStep];
        });
    }];
}

- (void)advanceToNextStep
{
    const NSInteger index = [self.sequence.steps indexOfObject:self.currentStep];
    if (index != NSNotFound && index < [self.sequence.steps count] - 1){
        self.currentStep = self.sequence.steps[index + 1];
    }
}

- (void)executeCurrentStep
{
    if (self.currentStep.count < 1 || self.currentStep.duration < 1 || self.currentStep.binning < 1){
        NSLog(@"Skipping empty step");
        [self advanceToNextStep];
    }
    else {
        
        SXIOSequenceStep* sequenceStep = self.currentStep;
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
            if ([self.target.sequenceFilterWheelController.currentFilterName isEqualToString:self.currentStep.filter]){
                [self unobserveFilterWheel];
                [self capture];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

@interface SXIOSequenceEditorWindowController ()
@property (nonatomic,strong) SXIOSequence* sequence;
@property (nonatomic,strong) SXIOSequenceRunner* sequenceRunner;
@property (nonatomic,strong) IBOutlet NSArrayController* stepsController;
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
}

- (void)dealloc
{
    self.sequenceRunner = nil;
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
    
    NSError* error;
    if (![self.sequenceRunner startWithError:&error]){
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
    
    // save current sequence

    if (self.parent){
        [self endSheetWithCode:NSModalResponseCancel];
    }
}

- (void)setSequenceRunner:(SXIOSequenceRunner *)sequenceRunner
{
    if (_sequenceRunner != sequenceRunner){
        [_sequenceRunner removeObserver:self forKeyPath:@"currentStep" context:&kvoContext];
        _sequenceRunner = sequenceRunner;
        [_sequenceRunner addObserver:self forKeyPath:@"currentStep" options:0 context:&kvoContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if ([@"currentStep" isEqualToString:keyPath]){
            // show spinner on current row
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (BOOL)canStart
{
    return YES;
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
    return YES;
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
            SXIOSequence* sequence = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfURL:open.URL]];
            if ([sequence isKindOfClass:[SXIOSequence class]]){
                self.sequence = sequence;
                [self updateWindowRepresentedURL:open.URL];
            }
        }
    }];
}

- (BOOL)canOpen
{
    return YES;
}

@end
