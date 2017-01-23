//
//  SXIOSequenceEditorWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/5/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOSequenceEditorWindowController.h"
#import <CoreAstro/CoreAstro.h>

#import "CASMountWindowController.h" // tmp until this is refactored into a mount controller
#import "SXIOAppDelegate.h"

static NSString* const kSXIOSequenceEditorWindowControllerBookmarkKey = @"SXIOSequenceEditorWindowControllerBookmarkKey";

@interface CASSequenceStep : NSObject<NSCoding,NSCopying>
@property (nonatomic,readonly,copy) NSString* type;
@property (nonatomic,readonly,getter=isValid) BOOL valid;
@end

@interface CASSequenceStep ()
@property (nonatomic,assign) BOOL active; // per-step flag
@property (nonatomic,assign) BOOL sequenceRunning; // whole sequence flag
@property (nonatomic,copy) NSString* type;
@end

@implementation CASSequenceStep

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
    CASSequenceStep* copy = [[self class] new];
    copy.type = self.type;
    return copy;
}

- (void)cancel {}

@end

@interface CASSequenceExposureStep : CASSequenceStep
@property (nonatomic,assign) NSInteger count;
@property (nonatomic,assign) NSInteger duration;
@property (nonatomic,assign) NSInteger binning;
@property (nonatomic,assign) NSInteger binningIndex;
@property (nonatomic,copy) NSString* filter;
@end

@interface CASSequenceExposureStep ()
@property (nonatomic,strong) NSArray* filterNames;
@end

@implementation CASSequenceExposureStep

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
    CASSequenceExposureStep* copy = [super copyWithZone:zone];
    
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
    return self.filter;
}

- (void)setSelectedFilter:(NSString *)filter
{
    if (filter){
        NSArray* filterNames = [self filterNames];
        if (![filterNames containsObject:filter]){
            NSLog(@"Attempt to set unknown filter %@",filter);
            filter = nil;
        }
    }
    self.filter = filter;
}

@end

@interface CASSequenceSlewStep : CASSequenceStep
@property (nonatomic,copy) NSDictionary* bookmark;
@property BOOL plateSolve;
@end

@implementation CASSequenceSlewStep

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.plateSolve = YES;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.bookmark = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"bookmarkName"];
        self.plateSolve = [coder decodeBoolForKey:@"plateSolve"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.bookmark forKey:@"bookmarkName"];
    [aCoder encodeBool:self.plateSolve forKey:@"plateSolve"];
}

- (id)copyWithZone:(NSZone *)zone
{
    CASSequenceSlewStep* copy = [super copyWithZone:zone];
    copy.bookmark = self.bookmark;
    copy.plateSolve = self.plateSolve;
    return copy;
}

- (NSString*)type
{
    return @"slew";
}

- (BOOL)isValid
{
    return (self.bookmark.count > 0); // and mount connected
}

@end

@interface CASSequenceParkStep : CASSequenceStep
@end

@implementation CASSequenceParkStep

- (NSString*)type
{
    return @"park";
}

@end

@interface CASSequence ()
@property (nonatomic,strong) NSMutableArray* steps;
@property (nonatomic,copy) NSString* prefix;
@property (nonatomic,assign) NSInteger dither;
@property (nonatomic,assign) NSInteger temperature;
@property BOOL hasStartTime;
@property (nonatomic,strong) NSDate* startTime;
@property BOOL repeat;
@property NSInteger repeatHoursInterval;
@end

@implementation CASSequence

- (id)init
{
    self = [super init];
    if (self) {
        self.steps = [NSMutableArray arrayWithCapacity:10];
        self.repeatHoursInterval = 24;
        self.startTime = [NSDate date];
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
        self.hasStartTime = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"hasStartTime"] boolValue];
        self.startTime = [coder decodeObjectOfClass:[NSDate class] forKey:@"startTime"];
        self.repeat = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"repeat"] boolValue];
        self.repeatHoursInterval = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"repeatHoursInterval"] integerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.steps forKey:@"steps"];
    
    [aCoder encodeObject:@(self.dither) forKey:@"dither"];
    [aCoder encodeObject:@(self.temperature) forKey:@"temperature"];
    
    [aCoder encodeObject:@(self.hasStartTime) forKey:@"hasStartTime"];
    [aCoder encodeObject:self.startTime forKey:@"startTime"];

    [aCoder encodeObject:@(self.repeat) forKey:@"repeat"];
    [aCoder encodeObject:@(self.repeatHoursInterval) forKey:@"repeatHoursInterval"];
}

- (void)setStartTime:(NSDate *)startTime
{
    if (startTime != _startTime){
        _startTime = [[NSCalendar currentCalendar] dateBySettingUnit:NSCalendarUnitSecond value:0 ofDate:startTime options:0];;
    }
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"repeatHoursInterval" isEqualToString:key]){
        self.repeatHoursInterval = 0;
    }
    else {
        [super setNilValueForKey:key];
    }
}

@end

@interface SXIOSequenceRunner : NSObject // use an operation queue?
@property (nonatomic,weak) CASSequence* sequence; // copy ?
@property (nonatomic,weak) id<SXIOSequenceTarget> target;
@property (nonatomic,weak) CASCameraController* cameraController;
@property (nonatomic,weak,readonly) CASSequenceStep* currentStep;
@property (nonatomic,copy) void(^completion)(NSError*);
- (BOOL)startWithError:(NSError**)error;
- (void)stopWithError:(NSError*)error; // todo; cancelled flag/error ?
@end

@interface SXIOSequenceRunner ()
@property (nonatomic,weak) CASSequenceStep* currentStep;
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
    
    // todo; alternatively we could create all steps at once as dependent nsoperations, which would allow some to run in parallel
    self.currentStep = [self.sequence.steps firstObject];
    
    // table cell subviews only seem to be able to bind to the container table view cell so
    // we need to set a property on its objectValue directly rather than going through the
    // File Owner proxy
    for (CASSequenceStep* step in self.sequence.steps){
        step.sequenceRunning = YES;
    }
    
    return YES;
}

- (void)stopWithError:(NSError*)error
{
    _stopped = YES;
    
    self.currentStep = nil;
    
    for (CASSequenceStep* step in self.sequence.steps){
        [step cancel];
        step.sequenceRunning = NO;
    }

    [self unobserveFilterWheel];
    [self.target endSequence];
    
    if (self.completion){
        self.completion(error);
        self.completion = nil;
    }
    
    if (error){
        [NSApp presentError:error];
    }
}

- (void)observeFilterWheel
{
    if (!_observing){
        [self.cameraController.filterWheel.filterWheel addObserver:self forKeyPath:@"moving" options:0 context:&kvoContext];
        _observing = YES;
    }
}

- (void)unobserveFilterWheel
{
    if (_observing){
        [self.cameraController.filterWheel.filterWheel removeObserver:self forKeyPath:@"moving" context:&kvoContext];
        _observing = NO;
    }
}

- (void)setCurrentStep:(CASSequenceStep *)currentStep
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
    [self.target captureWithCompletion:^(NSError* error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error){
                [self stopWithError:error];
            }
            else {
                if (!_stopped){
                    [self advanceToNextStep];
                }
            }
        });
    }];
}

- (void)advanceToNextStep
{
    const NSInteger index = [self.sequence.steps indexOfObject:self.currentStep]; // get from array controller instead ?
    if (index != NSNotFound && index < [self.sequence.steps count] - 1){
        self.currentStep = self.sequence.steps[index + 1];
    }
    else {
        [self stopWithError:nil];
    }
}

- (void)executeCurrentStep
{
    if (![self.currentStep isValid]){
        NSLog(@"Skipping invalid step: %@",self.currentStep);
        [self advanceToNextStep];
    }
    else {
        
        if ([self.currentStep.type isEqualToString:@"exposure"]){
            [self executeExposureStep:(CASSequenceExposureStep*)self.currentStep];
        }
        else if ([self.currentStep.type isEqualToString:@"slew"]){
            [self executeSlewStep:(CASSequenceSlewStep*)self.currentStep];
        }
        else if ([self.currentStep.type isEqualToString:@"park"]){
            [self executeParkStep:(CASSequenceParkStep*)self.currentStep];
        }
        else {
            NSLog(@"Unknown sequence step %@",self.currentStep.type);
        }
    }
}

- (void)executeExposureStep:(CASSequenceExposureStep*)sequenceStep
{
    CASExposureSettings* settings = self.cameraController.settings;
    
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
        CASFilterWheelController* filterWheel = self.cameraController.filterWheel;
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

- (void)executeSlewStep:(CASSequenceSlewStep*)sequenceStep
{
//    // speak/beep warning for a few seconds ?
//    NSSpeechSynthesizer* speech = [[NSSpeechSynthesizer alloc] init];
//    [speech startSpeakingString:@"Mount will start slewing"];
    // - (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking
    [self.target slewToBookmark:sequenceStep.bookmark plateSolve:sequenceStep.plateSolve completion:^(NSError* error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error){
                [self stopWithError:error];
            }
            else {
                if (!_stopped){
                    [self advanceToNextStep];
                }
            }
        });
    }];
}

- (void)executeParkStep:(CASSequenceParkStep*)parkStep
{
//    // speak/beep warning for a few seconds ?
//    NSSpeechSynthesizer* speech = [[NSSpeechSynthesizer alloc] init];
//    [speech startSpeakingString:@"Mount will start parking"];
    [self.target parkMountWithCompletion:^(NSError* error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error){
                [self stopWithError:error];
            }
            else {
                if (!_stopped){
                    [self advanceToNextStep];
                }
            }
        });
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if ([@"moving" isEqualToString:keyPath]){
            if (!self.cameraController.filterWheel.filterWheel.moving && [self.cameraController.filterWheel.currentFilterName isEqualToString:((CASSequenceExposureStep*)self.currentStep).filter]){
                [self unobserveFilterWheel];
                [self capture];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

@interface SXIOSequenceEditorRowView : NSTableRowView
@property (strong) CASSequenceStep* step;
@property (strong) IBOutlet NSObjectController *objectController;
@end

@implementation SXIOSequenceEditorRowView

- (void)setSelectionHighlightStyle:(NSTableViewSelectionHighlightStyle)selectionHighlightStyle
{
    // suppressing this with the table view selection style set to none, seems (a) enable highlighting and (b) fix editing of text fields. I have no idea why.
}

@end

@interface SXIOSequenceEditorExposureStepView : SXIOSequenceEditorRowView
@end

@implementation SXIOSequenceEditorExposureStepView
@end

@interface SXIOSequenceEditorSlewStepView : SXIOSequenceEditorRowView
@end

@implementation SXIOSequenceEditorSlewStepView

- (NSArray*)bookmarks
{
    return CASBookmarks.sharedInstance.bookmarks;
}

@end

@interface SXIOSequenceEditorParkStepView : SXIOSequenceEditorRowView
@end

@implementation SXIOSequenceEditorParkStepView
@end

@interface SXIOSequenceEditorWindowControllerStepsController : NSArrayController
@property (weak) IBOutlet SXIOSequenceEditorWindowController *windowController;
@end

@interface SXIOSequenceEditorWindowController () // need to forward declare this for -setFilterNameOnObject:
@property (nonatomic,readonly) CASCameraController* selectedCameraController;
@end

@implementation SXIOSequenceEditorWindowControllerStepsController

- (void)setFilterNameOnObject:(id)object
{
    CASSequenceExposureStep* step = object;
    if ([step respondsToSelector:@selector(setFilterNames:)]){
        step.filterNames = [[[self.windowController.selectedCameraController.filterWheel.filterNames allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString* evaluatedObject, NSDictionary *_) {
            return [evaluatedObject length] > 0;
        }]] sortedArrayUsingSelector:@selector(compare:)];
        if (!step.selectedFilter){
            step.selectedFilter = step.filterNames.firstObject;
        }
    }
}

- (void)setContent:(id)content
{
    [super setContent:content];
    
    // only supporting exposure types for now but in the future could have focus, slew, etc
    self.filterPredicate = [NSPredicate predicateWithBlock:^BOOL(CASSequenceStep* step, NSDictionary *bindings) {
        return [step isKindOfClass:[CASSequenceExposureStep class]] ||
        [step isKindOfClass:[CASSequenceSlewStep class]] ||
        [step isKindOfClass:[CASSequenceParkStep class]];
    }];
    
    for (id object in self.content){
        [self setFilterNameOnObject:object];
    }
}

- (id)newObject
{
    return [CASSequenceExposureStep new];
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

// from https://developer.apple.com/library/mac/samplecode/ButtonMadness/Introduction/Intro.html
//
@interface SXIOSequenceEditorAddButton : NSButton
@end

@implementation SXIOSequenceEditorAddButton {
    NSPopUpButtonCell* popUpCell;
}

- (void)awakeFromNib
{
    popUpCell = [[NSPopUpButtonCell alloc] initTextCell:@""];
    [popUpCell setPullsDown:YES];
    [popUpCell setPreferredEdge:NSMaxYEdge];
}

- (void)mouseDown:(NSEvent*)theEvent
{
    // create the menu the popup will use
    NSMenu *popUpMenu = [[self menu] copy];
    [popUpMenu insertItemWithTitle:@"" action:NULL keyEquivalent:@"" atIndex:0];	// blank item at top
    [popUpCell setMenu:popUpMenu];
    
    // and show it
    [popUpCell performClickWithFrame:[self bounds] inView:self];
    
    [self setNeedsDisplay: YES];
}

@end

@interface SXIOSequenceEditorWindowController ()<NSWindowDelegate,NSTableViewDelegate,NSTableViewDataSource>
@property (nonatomic,strong) NSURL* sequenceURL;
@property (nonatomic,strong) SXIOSequenceRunner* sequenceRunner;
@property (nonatomic,weak) IBOutlet NSButton *startButton;
@property (nonatomic,strong) IBOutlet SXIOSequenceEditorWindowControllerStepsController* stepsController;
@property (weak) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSArrayController *camerasController;

@property (copy) void(^startTimeCompletion)();
@property (strong) NSDate* nextRunTime;

@end

@implementation SXIOSequenceEditorWindowController {
    BOOL _stopped;
}

static void* kvoContext;

@synthesize sequence = _sequence;

+ (instancetype)sharedWindowController
{
    static SXIOSequenceEditorWindowController* _sharedWindowController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedWindowController = [SXIOSequenceEditorWindowController createWindowController];
    });
    return _sharedWindowController;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self; // for dragging
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone; // see comment about with SXIOSequenceEditorExposureStepView
    [self.tableView registerForDraggedTypes:@[@"sxio.sequencestep.index"]];
    
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"SXIOSequenceEditorExposureStepView" bundle:nil] forIdentifier:@"exposure"];
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"SXIOSequenceEditorSlewStepView" bundle:nil] forIdentifier:@"slew"];
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"SXIOSequenceEditorParkStepView" bundle:nil] forIdentifier:@"park"];

    NSButton* closeButton = [self.window standardWindowButton:NSWindowCloseButton];
    [closeButton setTarget:self];
    [closeButton setAction:@selector(closeWindow:)];

    if (self.sequence){
        self.stepsController.content = self.sequence.steps;
    }
    // [NSSet setWithArray:@[@"stepsController.arrangedObjects"]] doesn't seem to work so trigger manually
    [self.stepsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:&kvoContext];
        
    self.window.delegate = self;
    [self.window registerForDraggedTypes:@[(id)NSFilenamesPboardType]];
}

- (void)dealloc
{
    self.sequenceRunner = nil;
    [self.stepsController removeObserver:self forKeyPath:@"arrangedObjects" context:&kvoContext];
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self]; // todo; check already in it ?
#endif
}

- (void)closeWindow:sender
{
    // check we're not running a sequence
    if (!_stopped){
        NSBeep();
        NSLog(@"Currently running a sequence...");
        return;
    }

#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromWindowMenu:self];
#endif
    
    [self close];
}

- (NSArray*)cameraControllers
{
    return [CASDeviceManager sharedManager].cameraControllers;
}

- (CASCameraController*)selectedCameraController
{
    return self.camerasController.selectedObjects.firstObject;
}

- (void)close
{
    // warn first...
    [self.sequenceRunner stopWithError:nil];
    
    // save current sequence
    
    // [super close];
    
    [self.window orderOut:nil];
}

- (CASSequence*)sequence
{
    if (!_sequence){
        _sequence = [CASSequence new];
    }
    return _sequence;
}

- (void)setSequence:(CASSequence *)sequence
{
    if (_sequence != sequence){
        _sequence = sequence;
        self.stepsController.content = _sequence.steps;
    }
}

- (BOOL)preflightSequence
{
    for (CASSequenceStep* step in self.sequence.steps){
        if ([step isKindOfClass:[CASSequenceExposureStep class]]){
            if (!self.selectedCameraController){
                NSAlert* alert = [NSAlert alertWithMessageText:@"Select Camera"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"Please select a camera from the pop-up menu before running this sequence"];
                [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
                return NO;
            }
            CASSequenceExposureStep* exposureStep = (CASSequenceExposureStep*)step;
            if ([exposureStep.filter length]){
                CASFilterWheelController* filterWheel = self.selectedCameraController.filterWheel;
                if (!filterWheel){
                    NSAlert* alert = [NSAlert alertWithMessageText:@"Select Filter Wheel"
                                                     defaultButton:@"OK"
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:@"Please select a filter wheel in the camera window before running this sequence"];
                    [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
                    return NO;
                }
            }
        }
        else if ([step isKindOfClass:[CASSequenceSlewStep class]]){
            CASSequenceSlewStep* slewStep = (CASSequenceSlewStep*)step;
            if (!self.target.sequenceMountController){
                NSAlert* alert = [NSAlert alertWithMessageText:@"Select Mount"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"Please connect to a mount before before running this sequence"];
                [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
                return NO;
            }
            if (slewStep.plateSolve){
                CASPlateSolver* solver = [CASPlateSolver plateSolverWithIdentifier:nil];
                if (![solver canSolveExposure:nil error:nil]){
                    NSAlert* alert = [NSAlert alertWithMessageText:@"Plate Solve"
                                                     defaultButton:@"OK"
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:@"The astrometry.net installer tools and indexes need to be installed for plate solved slew steps"];
                    [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
                    return NO;
                }
            }
        }
    }
    
    return YES;
}

- (IBAction)start:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartTimerFired) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(completeWaitForStartTime) object:nil];

    if (self.sequenceRunner || self.nextRunTime){
        _stopped = YES;
        // button is in Stop mode
        [self.sequenceRunner stopWithError:nil];
        self.sequenceRunner = nil;
        self.nextRunTime = nil;
        NSLog(@"Stopped");
        return;
    }
    
    NSParameterAssert(self.target);
    NSParameterAssert([self.sequence.steps count] > 0);

    _stopped = NO;
    self.startButton.title = @"Stop";

    [self waitForStartTimeWithCompletion:^{
        
        if (![self preflightSequence]){
        
            self.nextRunTime = nil;
            self.startButton.title = @"Start";
        }
        else{
        
            self.sequenceRunner = [SXIOSequenceRunner new];
            self.sequenceRunner.target = self.target;
            self.sequenceRunner.cameraController = self.selectedCameraController;
            self.sequenceRunner.sequence = self.sequence;
            
            __typeof(self) weakSelf = self;
            self.sequenceRunner.completion = ^(NSError* error){
                
                weakSelf.sequenceRunner = nil;

                // todo; have an option to continue or stop if the sequence ended with an error
                
                // check for the repeat sequence option
                if (!_stopped && self.sequence.repeat && self.sequence.repeatHoursInterval > 0){
                    
                    // figure out the date to repeat from
                    NSDate* date;
                    if (self.sequence.hasStartTime && self.sequence.startTime){
                        date = self.sequence.startTime;
                    }
                    else {
                        date = [NSDate date];
                    }
                    
                    // increment it by the interval
                    NSCalendarUnit unit = NSCalendarUnitMinute; // NSCalendarUnitHour;
                    date = [[NSCalendar currentCalendar] dateByAddingUnit:unit value:weakSelf.sequence.repeatHoursInterval toDate:date options:0];
                    
                    // update the start date if we're using that
                    if (self.sequence.hasStartTime && self.sequence.startTime){
                        weakSelf.sequence.startTime = date;
                    }
                    
                    // set the next run date text label...
                    
                    // set a timer
                    NSLog(@"Restarting at %@",date);
                    const NSTimeInterval delay = date.timeIntervalSinceReferenceDate - [NSDate timeIntervalSinceReferenceDate];
                    weakSelf.nextRunTime = [NSDate dateWithTimeIntervalSinceNow:delay];
                    [weakSelf performSelector:@selector(restartTimerFired) withObject:nil afterDelay:delay];
                }
                else {
                    weakSelf.nextRunTime = nil;
                    weakSelf.startButton.title = @"Start";
                }
            };
            
            NSError* error;
            if (![self.sequenceRunner startWithError:&error]){
                self.sequenceRunner = nil;
                [NSApp presentError:error];
            }
        }
    }];
}

- (void)restartTimerFired
{
    self.nextRunTime = nil;
    [self start:nil];
}

- (void)waitForStartTimeWithCompletion:(void(^)())completion
{
    self.startTimeCompletion = completion;

    if (!self.sequence.hasStartTime || !self.sequence.startTime){
        [self completeWaitForStartTime];
        return;
    }

    const NSTimeInterval delay = self.sequence.startTime.timeIntervalSinceReferenceDate - [NSDate timeIntervalSinceReferenceDate];
    if (delay <= 0){
        [self completeWaitForStartTime];
    }
    else {
        NSLog(@"Waiting for %@",self.sequence.startTime);
        self.nextRunTime = [NSDate dateWithTimeIntervalSinceNow:delay];
        [self performSelector:@selector(completeWaitForStartTime) withObject:nil afterDelay:delay];
    }
}

- (void)completeWaitForStartTime
{
    self.nextRunTime = nil;
    if (self.startTimeCompletion){
        self.startTimeCompletion();
        self.startTimeCompletion = nil;
    }
}

- (void)cancelSequence
{
    self.startTimeCompletion = nil;

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartTimerFired) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(completeWaitForStartTime) object:nil];

    [self.sequenceRunner stopWithError:nil];
    self.sequenceRunner = nil;
    
    if (self.parent){
        [self endSheetWithCode:NSModalResponseCancel];
    }
}

- (IBAction)cancel:(id)sender
{
    if (self.sequenceRunner){
        NSAlert* alert = [NSAlert alertWithMessageText:@"Cancel Sequence"
                                         defaultButton:@"OK"
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@"Are you sure you want to cancel the currently running sequence ?"];
        [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(cancelSequenceAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    }
    else {
        [self cancelSequence];
    }
}

- (void) cancelSequenceAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSOKButton){
        [self cancelSequence];
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
    self.sequenceURL = url; // this isn't being shown while it's a sheet
    self.window.representedURL = url; // need scoped bookmark data ?
    NSString* name = [url isFileURL] ? [[NSFileManager defaultManager] displayNameAtPath:url.path] : [url lastPathComponent];
    [self.window setTitleWithRepresentedFilename:name];
}

- (IBAction)save:(id)sender
{
    void (^archiveToURL)(NSURL*) = ^(NSURL* url){
        NSError* error;
        if ([[NSKeyedArchiver archivedDataWithRootObject:self.sequence] writeToURL:url options:NSDataWritingAtomic error:&error]){
            [self updateWindowRepresentedURL:url];
        }
        else if (error) {
            [NSApp presentError:error];
        }
    };
    
    if (/*self.sequenceURL*/0){ // tmp, getting permissions erros when saving
        archiveToURL(self.sequenceURL);
    }
    else {
        NSSavePanel* save = [NSSavePanel savePanel];
        
        save.allowedFileTypes = @[@"sxioSequence"];
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

- (BOOL)openSequenceWithURL:(NSURL*)url
{
    BOOL success = NO;
    if (url){
        CASSequence* sequence = nil;
        @try {
            [url startAccessingSecurityScopedResource];
            NSData* data = [NSData dataWithContentsOfURL:url];
            if (data){
                sequence = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"Exception opening sequence archive: %@",exception);
        }
        @finally{
            [url stopAccessingSecurityScopedResource];
        }
        if ([sequence isKindOfClass:[CASSequence class]]){
            self.sequence = sequence;
            [self updateWindowRepresentedURL:url];
            success = YES;
        }
    }
    return success;
}

- (IBAction)open:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = @[@"sxioSequence"];
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton){
            if ([self openSequenceWithURL:open.URL]){
                CASSaveUrlToDefaults(open.URL,kSXIOSequenceEditorWindowControllerBookmarkKey);
            }
            else{
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

- (IBAction)addExposureStep:(id)sender
{
    [self.stepsController add:nil];
}

- (IBAction)addSlewStep:(id)sender
{
    [self.stepsController addObject:[CASSequenceSlewStep new]];
}

- (IBAction)addParkStep:(id)sender
{
    [self.stepsController addObject:[CASSequenceParkStep new]];
}

#pragma mark - Drag & Drop

- (NSString*)sequencePathFromDraggingInfo:(id <NSDraggingInfo>)sender
{
    NSPasteboard* pb = sender.draggingPasteboard;
    if (!self.sequenceRunner){
        NSArray* files = [pb propertyListForType:NSFilenamesPboardType];
        if ([files isKindOfClass:[NSArray class]]){
            NSString* path = files.firstObject;
            if ([path.pathExtension isEqualToString:@"sxioSequence"]){
                return path;
            }
        }
    }
    return nil;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ([self sequencePathFromDraggingInfo:sender]){
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSString* path = [self sequencePathFromDraggingInfo:sender];
    if (path.length){
        NSURL* url = [NSURL fileURLWithPath:path];
        if ([self openSequenceWithURL:url]){
            CASSaveUrlToDefaults(url,kSXIOSequenceEditorWindowControllerBookmarkKey);
            return YES;
        }
    }
    return NO;
}

#pragma mark - Table view

- (nullable id <NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row
{
    NSPasteboardItem* item = [[NSPasteboardItem alloc] init];
    [item setString:[NSString stringWithFormat:@"%ld",row] forType:@"sxio.sequencestep.index"];
    return item;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    if (dropOperation == NSTableViewDropAbove){
        return NSDragOperationMove;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
    [info enumerateDraggingItemsWithOptions:0 forView:tableView classes:@[[NSPasteboardItem class]] searchOptions:[NSDictionary dictionary] usingBlock:^(NSDraggingItem * _Nonnull draggingItem, NSInteger idx, BOOL * _Nonnull stop) {

        NSInteger targetRow = row;
        const NSInteger sourceRow = [[draggingItem.item stringForType:@"sxio.sequencestep.index"] integerValue];

//        NSLog(@"draggingItem: %ld -> %ld",sourceRow,targetRow);

        NSArray* arrangedSteps = self.stepsController.arrangedObjects;
        if (sourceRow >= 0 && sourceRow < arrangedSteps.count){
            CASSequenceStep* step = arrangedSteps[sourceRow];
            [self.stepsController removeObjectAtArrangedObjectIndex:sourceRow];
            if (sourceRow < targetRow){
                targetRow--;
            }
            [self.stepsController insertObject:step atArrangedObjectIndex:targetRow];
        }
        
    }];
    
    return YES;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    SXIOSequenceEditorRowView* result;
    NSArray<CASSequenceStep*>* steps = self.stepsController.arrangedObjects;
    if (row < steps.count){
        CASSequenceStep* step = steps[row];
        result = [tableView makeViewWithIdentifier:step.type owner:nil];
        result.step = step;
    }
    return result;
}

@end
