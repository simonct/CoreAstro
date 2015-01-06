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
@property (nonatomic,assign) NSInteger filterIndex;
@end

@interface SXIOSequenceStep ()
@property (nonatomic,assign) BOOL active;
@end

@implementation SXIOSequenceStep

@synthesize active;

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.filterIndex = NSNotFound;
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
        self.filterIndex = [coder decodeIntegerForKey:@"filterIndex"]; // or name ?
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.count forKey:@"count"];
    [aCoder encodeInteger:self.duration forKey:@"duration"];
    [aCoder encodeInteger:self.binning forKey:@"binning"];
    [aCoder encodeInteger:self.filterIndex forKey:@"filterIndex"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SXIOSequenceStep* copy = [SXIOSequenceStep new];
    
    copy.count = self.count;
    copy.duration = self.duration;
    copy.binning = self.binning;
    copy.filterIndex = self.filterIndex;

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

@implementation SXIOSequenceRunner

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
    [self.target endSequence];
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

- (void)executeCurrentStep
{
    void (^nextStep)() = ^(){
        const NSInteger index = [self.sequence.steps indexOfObject:self.currentStep];
        if (index != NSNotFound && index < [self.sequence.steps count] - 1){
            self.currentStep = self.sequence.steps[index + 1];
        }
    };
    
    if (self.currentStep.count < 1 || self.currentStep.duration < 1 || self.currentStep.binning < 1){
        NSLog(@"Skipping empty step");
        nextStep();
    }
    else {
        
        SXIOSequenceStep* sequenceStep = self.currentStep;
        CASExposureSettings* settings = self.target.sequenceCameraController.settings;
        
        settings.captureCount = sequenceStep.count;
        settings.exposureUnits = 0;
        settings.exposureDuration = sequenceStep.duration;
        settings.binningIndex = sequenceStep.binningIndex;
        
        // dither
        // filter
        // temperature
        // prefix

        [self.target captureWithCompletion:^(){
            dispatch_async(dispatch_get_main_queue(), ^{
                nextStep();
            });
        }];
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
}

- (void)dealloc
{
    self.sequenceRunner = nil;
}

- (void)close
{
    // warn first...
    [self.sequenceRunner stop];
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
