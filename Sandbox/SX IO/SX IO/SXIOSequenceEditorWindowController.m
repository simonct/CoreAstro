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
    return (self.bookmark.count > 0);
}

@end

@interface CASSequence : NSObject<NSCoding>
@property (nonatomic,strong) NSMutableArray* steps;
@property (nonatomic,copy) NSString* prefix;
@property (nonatomic,assign) NSInteger dither;
@property (nonatomic,assign) NSInteger temperature;
@end

@implementation CASSequence

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
@property (nonatomic,weak) CASSequence* sequence; // copy ?
@property (nonatomic,weak) id<SXIOSequenceTarget> target;
@property (nonatomic,weak,readonly) CASSequenceStep* currentStep;
@property (nonatomic,copy) void(^completion)();
- (BOOL)startWithError:(NSError**)error;
- (void)stop;
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
    
    self.currentStep = [self.sequence.steps firstObject];
    
    // table cell subviews only seem to be able to bind to the container table view cell so
    // we need to set a property on its objectValue directly rather than going through the
    // File Owner proxy
    for (CASSequenceStep* step in self.sequence.steps){
        step.sequenceRunning = YES;
    }
    
    return YES;
}

- (void)stop
{
    _stopped = YES;
    
    self.currentStep = nil;
    
    for (CASSequenceStep* step in self.sequence.steps){
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
                [self stop];
                [NSApp presentError:error];
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
        
        if ([self.currentStep.type isEqualToString:@"exposure"]){
            [self executeExposureStep:(CASSequenceExposureStep*)self.currentStep];
        }
        else if ([self.currentStep.type isEqualToString:@"slew"]){
            [self executeSlewStep:(CASSequenceSlewStep*)self.currentStep];
        }
        else {
            NSLog(@"Unknown sequence step %@",self.currentStep.type);
        }
    }
}

- (void)executeExposureStep:(CASSequenceExposureStep*)sequenceStep
{
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

- (void)executeSlewStep:(CASSequenceSlewStep*)sequenceStep
{
    [self.target slewToBookmark:sequenceStep.bookmark plateSolve:sequenceStep.plateSolve completion:^(NSError* error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error){
                [self stop];
                [NSApp presentError:error];
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
            if ([self.target.sequenceFilterWheelController.currentFilterName isEqualToString:((CASSequenceExposureStep*)self.currentStep).filter]){
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
@end

@implementation SXIOSequenceEditorRowView
@end

@interface SXIOSequenceEditorExposureView : SXIOSequenceEditorRowView
@property (strong) IBOutlet NSObjectController *objectController;
@end

@implementation SXIOSequenceEditorExposureView
@end

@interface SXIOSequenceEditorSlewStepView : SXIOSequenceEditorRowView
@property (strong) IBOutlet NSObjectController *objectController;
@end

@implementation SXIOSequenceEditorSlewStepView

- (NSArray*)bookmarks
{
    return CASBookmarks.sharedInstance.bookmarks;
}

@end

@interface SXIOSequenceEditorWindowControllerStepsController : NSArrayController
@property (weak) IBOutlet SXIOSequenceEditorWindowController *windowController;
@end

@implementation SXIOSequenceEditorWindowControllerStepsController

- (void)setFilterNameOnObject:(id)object
{
    CASSequenceExposureStep* step = object;
    if ([step respondsToSelector:@selector(setFilterNames:)]){
        step.filterNames = [[[self.windowController.target.sequenceFilterWheelController.filterNames allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString* evaluatedObject, NSDictionary *_) {
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
        [step isKindOfClass:[CASSequenceSlewStep class]];
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

@interface SXIOSequenceEditorWindowController ()<NSWindowDelegate,NSTableViewDelegate>
@property (nonatomic,strong) NSURL* sequenceURL;
@property (nonatomic,strong) CASSequence* sequence;
@property (nonatomic,strong) SXIOSequenceRunner* sequenceRunner;
@property (nonatomic,weak) IBOutlet NSButton *startButton;
@property (nonatomic,strong) IBOutlet SXIOSequenceEditorWindowControllerStepsController* stepsController;
@property (weak) IBOutlet NSTableView *tableView;
@end

@implementation SXIOSequenceEditorWindowController

static void* kvoContext;

+ (instancetype)loadSequenceEditor
{
    return [[[self class] alloc] initWithWindowNibName:@"SXIOSequenceEditorWindowController"];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.sequence = [CASSequence new];
    
    self.tableView.delegate = self;
    
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"SXIOSequenceEditorExposureView" bundle:nil] forIdentifier:@"exposure"];
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"SXIOSequenceEditorSlewStepView" bundle:nil] forIdentifier:@"slew"];
    
    NSButton* closeButton = [self.window standardWindowButton:NSWindowCloseButton];
    [closeButton setTarget:self];
    [closeButton setAction:@selector(close:)];
    
    // [NSSet setWithArray:@[@"stepsController.arrangedObjects"]] doesn't seem to work so trigger manually
    [self.stepsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:&kvoContext];
    
    NSURL* sequenceUrl = CASUrlFromDefaults(kSXIOSequenceEditorWindowControllerBookmarkKey);
    if (sequenceUrl){
        [self openSequenceWithURL:sequenceUrl];
    }
    
    self.window.delegate = self;
    [self.window registerForDraggedTypes:@[(id)NSFilenamesPboardType]];
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
            CASSequenceExposureStep* exposureStep = (CASSequenceExposureStep*)step;
            if ([exposureStep.filter length]){
                CASFilterWheelController* filterWheel = self.target.sequenceFilterWheelController;
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
    if (self.sequenceRunner){
        // button is in Stop mode
        [self.sequenceRunner stop];
        self.sequenceRunner = nil;
        return;
    }
    
    NSParameterAssert(self.target);
    NSParameterAssert([self.sequence.steps count] > 0);
    
    if ([self preflightSequence]){
        
        self.sequenceRunner = [SXIOSequenceRunner new];
        self.sequenceRunner.target = self.target;
        self.sequenceRunner.sequence = self.sequence;
        
        __typeof(self) weakSelf = self;
        self.sequenceRunner.completion = ^(){
            weakSelf.sequenceRunner = nil;
            weakSelf.startButton.title = @"Start";
        };
        
        NSError* error;
        if (![self.sequenceRunner startWithError:&error]){
            self.sequenceRunner = nil;
            [NSApp presentError:error];
        }
        else {
            self.startButton.title = @"Stop";
        }
    }
}

- (void)cancelSequence
{
    [self.sequenceRunner stop];
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
    CASSequenceSlewStep* step = [CASSequenceSlewStep new];
    [self.stepsController addObject:step];
}

- (IBAction)addParkStep:(id)sender
{
    NSLog(@"addParkStep");
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
