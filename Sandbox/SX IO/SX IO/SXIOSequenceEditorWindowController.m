//
//  SXIOSequenceEditorWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/5/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOSequenceEditorWindowController.h"
#import <CoreAstro/CoreAstro.h>

#if defined(SXIO) || defined(CCDIO)
#import "SXIOAppDelegate.h"

static NSString* const kSXIOSequenceEditorWindowControllerBookmarkKey = @"SXIOSequenceEditorWindowControllerBookmarkKey";

@class SXIOSequenceEditorWindowController;

@interface SXIOSequenceEditorWindowController ()
@property (nonatomic) CASCameraController* selectedCameraController;
@end

@protocol SequenceExecutable <NSObject>
- (void)execute:(id<SXIOSequenceTarget>)target completion:(void(^)(NSError*))completion;
@end

@interface CASSequenceStep : NSObject<NSCoding,NSCopying>
@property (nonatomic,readonly,copy) NSString* type;
@property (nonatomic,readonly,getter=isValid) BOOL valid;
@property (nonatomic,weak) SXIOSequenceEditorWindowController* windowController;
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

@interface CASSequencePreflightStep : CASSequenceStep<SequenceExecutable>
@property (nonatomic,copy) NSString* camera;
@property (nonatomic,copy) NSString* filterWheel;
@property (nonatomic,copy) NSString* mountClass;
@property (nonatomic,copy) NSString* mountName;
@property (nonatomic,copy) NSString* mountPath;
@property (nonatomic,copy) NSString* status;
@property BOOL preparePHD2;
@property (copy) void (^completion)(NSError *);
@end

enum {
    StateNone = 0,
    StateCamera,
    StateFilterWheel,
    StateMount,
    StatePHD2
};

@implementation CASSequencePreflightStep {
    NSInteger _state;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.camera = [coder decodeObjectOfClass:[NSString class] forKey:@"camera"];
        self.filterWheel = [coder decodeObjectOfClass:[NSString class] forKey:@"filterWheel"];
        self.mountClass = [coder decodeObjectOfClass:[NSString class] forKey:@"mountClass"];
        self.mountName = [coder decodeObjectOfClass:[NSString class] forKey:@"mountName"];
        self.mountPath = [coder decodeObjectOfClass:[NSString class] forKey:@"mountPath"];
        self.preparePHD2 = [coder decodeBoolForKey:@"preparePHD2"];
        [self updateStatus];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeBool:self.preparePHD2 forKey:@"preparePHD2"];
    [aCoder encodeObject:self.mountPath forKey:@"mountPath"];
    [aCoder encodeObject:self.mountClass forKey:@"mountClass"];
    [aCoder encodeObject:self.mountName forKey:@"mountName"];
    [aCoder encodeObject:self.camera forKey:@"camera"];
    [aCoder encodeObject:self.filterWheel forKey:@"filterWheel"];
}

- (id)copyWithZone:(NSZone *)zone
{
    CASSequencePreflightStep* copy = [super copyWithZone:zone];
    
    copy.camera = [self.camera copy];
    copy.filterWheel = [self.filterWheel copy];
    copy.mountClass = [self.mountClass copy];
    copy.mountName = [self.mountName copy];
    copy.mountPath = [self.mountPath copy];
    [copy updateStatus];
    
    return copy;
}

- (NSString*)type
{
    return @"preflight";
}

- (BOOL)isValid
{
    return self.camera != nil;
}

- (void)capture
{
    CASCameraController* camera = self.windowController.selectedCameraController;
    self.camera = camera.camera.deviceName;
    self.filterWheel = camera.filterWheel.filterWheel.deviceName;

    // yuk - this should be associated with the camera controller
    SXIOCameraWindowController* window = (SXIOCameraWindowController*)[[SXIOAppDelegate sharedInstance] findDeviceWindowController:camera];
    CASMountController* mount = window.sequenceMountController;
    
    self.mountName = mount.mount.deviceName;
    self.mountClass = NSStringFromClass([mount.mount class]);
    
    CASLX200Mount* lx200 = (CASLX200Mount*)mount.mount;
    if ([lx200 isKindOfClass:[CASLX200Mount class]]){
        self.mountPath = lx200.port.path;
    }
    
    [self updateStatus];
}

- (void)updateStatus
{
    self.status = @"";
    if (self.camera){
        self.status = [self.status stringByAppendingString:self.camera];
    }
    if (self.filterWheel){
        if (self.status.length > 0){
            self.status = [self.status stringByAppendingString:@", "];
        }
        self.status = [self.status stringByAppendingString:self.filterWheel];
    }
    if (self.mountName){
        if (self.status.length > 0){
            self.status = [self.status stringByAppendingString:@", "];
        }
        self.status = [self.status stringByAppendingString:self.mountName];
    }
}

- (void)execute:(id<SXIOSequenceTarget>)target completion:(void (^)(NSError *))completion
{
    completion(nil); // just advance immediately to the next step
}

- (void)preflight:(void (^)(NSError *))completion
{
    self.completion = completion;
    
    [self performNextState:StateNone error:nil];
}

- (void)performNextState:(NSInteger)state error:(NSError*)error
{
    if (error){
        self.completion(error);
        return;
    }
    
    _state = state;
    
    switch (_state) {
            
        case StateNone:{
            
            if (self.camera){
                
                NSArray* cameras = [[[CASDeviceManager sharedManager] cameraControllers] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                    CASCameraController* camera = evaluatedObject;
                    return [camera.device.deviceName isEqualToString:self.camera];
                }]];
                
                if (cameras.count == 0){
                    [self performNextState:StateCamera error:[NSError errorWithDomain:NSStringFromClass([self class])
                                                                                 code:1
                                                                             userInfo:@{
                                                                                        NSLocalizedDescriptionKey:NSLocalizedString(@"Preflight Failed", @"Preflight Failed"),
                                                                                        NSLocalizedRecoverySuggestionErrorKey:[NSString stringWithFormat:NSLocalizedString(@"No camera matching the name '%@' was found", @"No camera matching the name '%@' was found"),self.camera]
                                                                                        }]];
                    return;
                }
                
                // select the first matching camera controller
                self.windowController.selectedCameraController = cameras.firstObject;
            }
            
            
            [self performNextState:StateCamera error:nil];
        }
            break;
            
        case StateCamera: {
            
            if (self.mountClass && self.mountPath && self.mountName){
                
                NSArray* mounts = [[[CASDeviceManager sharedManager] mountControllers] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                    CASMountController* mount = evaluatedObject;
                    return [mount.device.deviceName isEqualToString:self.mountName];
                }]];
                
                void (^completeWithMount)(CASMountController*) = ^(CASMountController* mount) {
                    // yuk - this should be associated with the camera controller (not updating the menu in the camera window)
                    SXIOCameraWindowController* window = (SXIOCameraWindowController*)[[SXIOAppDelegate sharedInstance] findDeviceWindowController:self.windowController.selectedCameraController];
                    window.mountController = mount;
                    
                    [self performNextState:StateFilterWheel error:nil];
                };
                
                if (mounts.count > 0){
                    completeWithMount(mounts.firstObject);
                }
                else {
                    [[CASMountWindowController sharedMountWindowController] connectToMountAtPath:self.mountPath completion:^(NSError* error,CASMountController* mountController){
                        if (error){
                            [self performNextState:StateFilterWheel error:error];
                        }
                        else {
                            completeWithMount(mountController);
                        }
                    }];
                }
            }
            else {
                [self performNextState:StateFilterWheel error:nil];
            }

        }
            break;
            
        case StateFilterWheel: {
            
            if (!self.filterWheel){
                [self performNextState:StateMount error:nil];
            }
            else {
                
                NSArray* filterWheels = [[[CASDeviceManager sharedManager] filterWheelControllers] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                    CASFilterWheelController* filterWheel = evaluatedObject;
                    return [filterWheel.device.deviceName isEqualToString:self.filterWheel];
                }]];
                
                if (filterWheels.count == 0){
                    [self performNextState:StateCamera error:[NSError errorWithDomain:NSStringFromClass([self class])
                                                                                 code:4
                                                                             userInfo:@{
                                                                                        NSLocalizedDescriptionKey:NSLocalizedString(@"Preflight Failed", @"Preflight Failed"),
                                                                                        NSLocalizedRecoverySuggestionErrorKey:[NSString stringWithFormat:NSLocalizedString(@"No filter wheel matching the name '%@' was found", @"No filter wheel matching the name '%@' was found"),self.camera]
                                                                                        }]];
                    return;
                }

                // connect the camera to the filter wheel (not updating the menu in the camera window)
                self.windowController.selectedCameraController.filterWheel = filterWheels.firstObject;

                [self performNextState:StateMount error:nil];
            }
        }
            break;
            
        case StateMount: {
            
            // Connect PHD2
            if (self.preparePHD2){
                
                void (^completeConnect)(NSRunningApplication*) = ^(NSRunningApplication* app){
                    
                    // attempt to connect and check state ?
                    CASPHD2Client* client = [[CASPHD2Client alloc] init];
                    [client connectWithCompletion:^{
                        
                        if (!client.connected){
                            
                            // todo; retry a couple of times as the system may still be in the process of releasing the server socket
                            
                            [self performNextState:StatePHD2 error:[NSError errorWithDomain:NSStringFromClass([self class])
                                                                                       code:7
                                                                                   userInfo:@{
                                                                                              NSLocalizedDescriptionKey:NSLocalizedString(@"Preflight Failed", @"Preflight Failed"),
                                                                                              NSLocalizedRecoverySuggestionErrorKey:@"It wasn't possible to establish a connection with PHD2",
                                                                                              }]];
                        }
                        else {
                            
                            // set config
                            
                            [self performNextState:StatePHD2 error:nil];
                        }
                    }];
                };
                
                NSRunningApplication* app;
                NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"org.openphdguiding.phd2"];
                if (apps.count > 0){
                    app = apps.firstObject;
                    completeConnect(app);
                }
                else {
                    // check it's installed
                    NSURL* url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"org.openphdguiding.phd2"];
                    if (!url){
                        [self performNextState:StatePHD2 error:[NSError errorWithDomain:NSStringFromClass([self class])
                                                                                   code:5
                                                                               userInfo:@{
                                                                                          NSLocalizedDescriptionKey:NSLocalizedString(@"Preflight Failed", @"Preflight Failed"),
                                                                                          NSLocalizedRecoverySuggestionErrorKey:@"PHD2 does not appear to be installed",
                                                                                          }]];
                        return;
                    }
                    
                    // launch/get existing instance
                    NSError* error;
                    NSRunningApplication* app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:NSWorkspaceLaunchDefault configuration:@{} error:nil];
                    if (!app){
                        [self performNextState:StatePHD2 error:[NSError errorWithDomain:NSStringFromClass([self class])
                                                                                   code:6
                                                                               userInfo:@{
                                                                                          NSLocalizedDescriptionKey:NSLocalizedString(@"Preflight Failed", @"Preflight Failed"),
                                                                                          NSLocalizedRecoverySuggestionErrorKey:[NSString stringWithFormat:@"There was an error launching PHD2: %@",error],
                                                                                          }]];
                        return;
                    }
                    
                    // give it 10s to launch
                    NSInteger waitLimit = 10;
                    while (!app.finishedLaunching && waitLimit-- > 0) {
                        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
                    }
                    
                    // and another couple of seconds to open the socket
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        completeConnect(app);
                    });
                }
            }
            else {
                [self performNextState:StatePHD2 error:nil];
            }
        }
            break;
            
        case StatePHD2:
            self.completion(nil);
            break;
            
        default:
            NSLog(@"CASSequencePreflightStep: unrecognised state: %ld",_state);
            break;
    }
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

- (NSArray*)filterNames
{
    CASFilterWheelController* filterWheel = self.windowController.selectedCameraController.filterWheel;
    if (!filterWheel){
        return nil;
    }
    
    NSDictionary* filterNames = filterWheel.filterNames;
    if (filterNames.count > 0){
        return [[[filterWheel.filterNames allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString* evaluatedObject, NSDictionary *_) {
            return [evaluatedObject length] > 0;
        }]] sortedArrayUsingSelector:@selector(compare:)];
    }
    
    const NSInteger filterCount = filterWheel.filterCount;
    NSMutableArray* filterNamesArray = [NSMutableArray arrayWithCapacity:filterCount];
    for (NSUInteger i = 0; i < filterCount; ++i){
        NSString* filterName = filterWheel.filterNames[[@(i) description]] ?: [NSString stringWithFormat:@"Filter %ld",i+1];
        [filterNamesArray addObject:filterName];
    }
    
    return [filterNamesArray copy];
}

+ (NSSet*)keyPathsForValuesAffectingFilterNames
{
    return [NSSet setWithObjects:@"windowController.selectedCameraController.filterWheel",nil];
}

- (NSString*)selectedFilter
{
    CASFilterWheelController* filterWheel = self.windowController.selectedCameraController.filterWheel;
    if (!filterWheel){
        return nil;
    }

    if (!self.filter){
        self.filter = self.filterNames.firstObject;
    }
    return self.filter;
}

+ (NSSet*)keyPathsForValuesAffectingSelectedFilter
{
    return [NSSet setWithObjects:@"filterNames",nil];
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

@interface CASSequenceSlewStep : CASSequenceStep<NSSpeechSynthesizerDelegate,SequenceExecutable>
@property (nonatomic,copy) NSDictionary* bookmark;
@property (nonatomic) BOOL plateSolve;
@property (weak) id<SXIOSequenceTarget> target;
@property (copy) void(^completion)(NSError*);
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

- (NSString*)warning
{
    return @"Mount will start slewing to target";
}

- (BOOL)isValid
{
    return (self.bookmark.count > 0); // and mount connected
}

- (void)execute:(id<SXIOSequenceTarget>)target completion:(void(^)(NSError*))completion
{
    self.target = target;
    self.completion = completion;
    
    NSString* warning = [self warning];
    if (![warning length]){
        [self warningCompleted];
    }
    else {
        NSSpeechSynthesizer* speech = [[NSSpeechSynthesizer alloc] init];
        speech.delegate = self;
        [speech startSpeakingString:warning];
    }
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking
{
    [self warningCompleted]; // todo; want an additional countdown timer
}

- (void)warningCompleted
{
    [self.target slewToBookmark:self.bookmark plateSolve:self.plateSolve completion:^(NSError* error){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completion(error);
        });
    }];
}

@end

@interface CASSequenceParkStep : CASSequenceSlewStep
@end

@implementation CASSequenceParkStep

- (BOOL) plateSolve
{
    return NO;
}

- (NSString*)type
{
    return @"park";
}

- (NSString*)warning
{
    return @"Mount will start slewing to park position";
}

- (BOOL)isValid
{
    return YES; // override bookmark check
}

- (void)warningCompleted
{
    [self.target parkMountWithCompletion:^(NSError* error){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completion(error);
        });
    }];
}

@end

@interface CASSequenceSynchroniseStep : CASSequenceSlewStep<CASMountMountSynchroniserDelegate>
@property (strong) CASMountSynchroniser* synchroniser;
@end

@implementation CASSequenceSynchroniseStep

- (NSString*)type
{
    return @"synchronise";
}

- (NSString*)warning
{
    return @"Mount will start synchronising with the sky";
}

- (BOOL)isValid
{
    return YES; // override bookmark check
}

- (void)warningCompleted
{
    // identical to mount controller
    self.synchroniser = [[CASMountSynchroniser alloc] init];
    self.synchroniser.mount = [self.target sequenceMountController].mount;
    self.synchroniser.delegate = self;
    self.synchroniser.cameraController = [self.target sequenceCameraController];
    [self.synchroniser findLocation];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCaptureExposure:(CASCCDExposure*)exposure
{
    // identical to mount controller - do we need this callback at all ?
    NSDictionary* userInfo = exposure ? @{@"exposure":exposure} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASMountControllerCapturedSyncExposureNotification object:[self.target sequenceMountController] userInfo:userInfo];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didSolveExposure:(CASPlateSolveSolution*)solution
{
    // identical to mount controller - do we need this callback at all ?
    NSDictionary* userInfo = solution ? @{@"solution":solution} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASMountControllerSolvedSyncExposureNotification object:[self.target sequenceMountController] userInfo:userInfo];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCompleteWithError:(NSError*)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.completion(error);
    });
}

@end

@interface CASSequence ()
@property (nonatomic,strong) NSMutableArray<CASSequenceStep*>* steps;
@property (nonatomic,copy) NSString* prefix;
@property (nonatomic,assign) NSInteger dither;
@property (nonatomic,assign) NSInteger temperature;
@property BOOL hasStartTime;
@property (nonatomic,strong) NSDate* startTime;
@property BOOL repeat;
@property NSInteger repeatHoursInterval;
@property BOOL autoStart;
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
        self.autoStart = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"autoStart"] boolValue];
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
    
    [aCoder encodeObject:@(self.autoStart) forKey:@"autoStart"];
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
@property (nonatomic,weak) SXIOSequenceEditorWindowController* windowController;
@property (nonatomic,weak,readonly) CASSequenceStep* currentStep;
@property (nonatomic,copy) void(^completion)(NSError*);
- (void)start:(void (^)(NSError *))completion;
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

- (void)start:(void (^)(NSError *))completion
{
    // locate any preflight step and run that first
    NSArray* preflight = [self.sequence.steps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject isKindOfClass:[CASSequencePreflightStep class]];
    }]];
    
    void (^start)() = ^(){
        NSError* error;
        
        if (![self preflightSequence:&error]){
            completion(error);
            return;
        }
        
        _stopped = NO;
        
        if (![self.target prepareToStartSequenceWithError:&error]){
            completion(error);
            return;
        }
        
        // todo; alternatively we could create all steps at once as dependent nsoperations, which would allow some to run in parallel
        self.currentStep = [self.sequence.steps firstObject];
        
        // table cell subviews only seem to be able to bind to the container table view cell so
        // we need to set a property on its objectValue directly rather than going through the
        // File Owner proxy
        for (CASSequenceStep* step in self.sequence.steps){
            step.sequenceRunning = YES;
        }
    };
    
    if (preflight.count == 0){
        start();
    }
    else {
        CASSequencePreflightStep* step = preflight.firstObject; // just run the first, ignore any others
        step.windowController = self.windowController;
        [step preflight:^(NSError * error) {
            if (error){
                completion(error);
            }
            else {
                self.target = self.windowController.target;
                start();
            }
        }];
    }
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
    
    void (^complete)(NSError*) = ^(NSError* error) {
        if (self.completion){
            self.completion(error);
            self.completion = nil;
        }
        
        if (error){
            [NSApp presentError:error];
        }
    };
    
    if (!error) {
        complete(nil);
    }
    else{
        
        // on error, park the mount if we've got one (todo; make this optional)
        CASMountController* mount = [self.target sequenceMountController];
        if (!mount){
            complete(error);
        }
        else {
            CASSequenceParkStep* parkStep = [[CASSequenceParkStep alloc] init];
            [parkStep execute:self.target completion:^(NSError *parkError) {
                complete(error);
                if (parkError){
                    [NSApp presentError:parkError];
                }
            }];
        }
    }
}

- (BOOL)preflightSequence:(NSError**)error
{
    NSString* preflightFailed = NSLocalizedString(@"Preflight Failed", @"Preflight Failed");
    
    for (CASSequenceStep* step in self.sequence.steps){
        
        if ([step isKindOfClass:[CASSequenceExposureStep class]]){
            
            if (!self.target.sequenceCameraController){
                *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                             code:1
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey:preflightFailed,
                                                    NSLocalizedRecoverySuggestionErrorKey:NSLocalizedString(@"Please select a camera from the pop-up menu before running this sequence", @"Please select a camera from the pop-up menu before running this sequence")
                                                    }];
                return NO;
            }
            CASSequenceExposureStep* exposureStep = (CASSequenceExposureStep*)step;
            if ([exposureStep.filter length]){
                CASFilterWheelController* filterWheel = self.target.sequenceCameraController.filterWheel;
                if (!filterWheel){
                    *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                                 code:1
                                             userInfo:@{
                                                        NSLocalizedDescriptionKey:preflightFailed,
                                                        NSLocalizedRecoverySuggestionErrorKey:NSLocalizedString(@"Please select a filter wheel in the camera window before running this sequence", @"Please select a filter wheel in the camera window before running this sequence")
                                                        }];
                    return NO;
                }
                if (![filterWheel.filterNames.allValues containsObject:exposureStep.filter]){
                    *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                                 code:1
                                             userInfo:@{
                                                        NSLocalizedDescriptionKey:preflightFailed,
                                                        NSLocalizedRecoverySuggestionErrorKey:[NSString stringWithFormat:NSLocalizedString(@"The filter '%@' isn't recognised by '%@'", @"The filter '%@' isn't recognised by '%@'"),exposureStep.filter,filterWheel.filterWheel.deviceName]
                                                        }];
                    return NO;
                }
            }
        }
        else if ([step isKindOfClass:[CASSequenceSlewStep class]]){
            
            CASSequenceSlewStep* slewStep = (CASSequenceSlewStep*)step;
            if (!self.target.sequenceMountController){
                *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                             code:1
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey:preflightFailed,
                                                    NSLocalizedRecoverySuggestionErrorKey:NSLocalizedString(@"Please connect to a mount before before running this sequence", @"Please connect to a mount before before running this sequence")
                                                    }];
                return NO;
            }
            if (slewStep.plateSolve){
                CASPlateSolver* solver = [CASPlateSolver plateSolverWithIdentifier:nil];
                if (![solver canSolveExposure:nil error:nil]){
                    *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                                 code:1
                                             userInfo:@{
                                                        NSLocalizedDescriptionKey:preflightFailed,
                                                        NSLocalizedRecoverySuggestionErrorKey:NSLocalizedString(@"The astrometry.net installer tools and indexes need to be installed for plate solved slew steps", @"The astrometry.net installer tools and indexes need to be installed for plate solved slew steps")
                                                        }];
                    return NO;
                }
            }
        }
    }
    
    return YES;
}

- (void)observeFilterWheel // todo; put into exposure step
{
    if (!_observing){
        [self.target.sequenceCameraController.filterWheel.filterWheel addObserver:self forKeyPath:@"moving" options:0 context:&kvoContext];
        _observing = YES;
    }
}

- (void)unobserveFilterWheel // todo; put into exposure step
{
    if (_observing){
        [self.target.sequenceCameraController.filterWheel.filterWheel removeObserver:self forKeyPath:@"moving" context:&kvoContext];
        _observing = NO;
    }
}

- (void)setCurrentStep:(CASSequenceStep *)currentStep
{
    if (_currentStep != currentStep){
        _currentStep.active = NO;
        _currentStep = currentStep;
        if (_currentStep && !_stopped){
            [self executeCurrentStep];
            _currentStep.active = YES;
        }
    }
}

- (void)capture
{
    [self.target captureWithCompletion:^(NSError* error){ // todo; put into exposure step
        [self stepCompletedWithError:error];
    }];
}

- (void)advanceToNextStep
{
    const NSInteger index = [self.sequence.steps indexOfObject:self.currentStep]; // get from array controller instead ?
    if (index != NSNotFound && index < [self.sequence.steps count] - 1){
        const NSInteger delay = 0.5;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.currentStep = self.sequence.steps[index + 1];
        });
    }
    else {
        [self stopWithError:nil];
    }
}

- (void)executeCurrentStep
{
    // start step log, each step logs pertinant info (e.g mount position), we log time of execution and success/error
    
    if ([self.currentStep isKindOfClass:[CASSequencePreflightStep class]]){
        [self stepCompletedWithError:nil];
        return;
    }
    
    if (![self.currentStep isValid]){
        [self stopWithError:[NSError errorWithDomain:NSStringFromClass([self class])
                                                code:2
                                            userInfo:@{NSLocalizedFailureReasonErrorKey:NSLocalizedString(@"Encountered an invalid step", @"Encountered an invalid step")}]];
    }
    else {
        
        if ([self.currentStep conformsToProtocol:@protocol(SequenceExecutable)]){
            id<SequenceExecutable> executable = (id<SequenceExecutable>)self.currentStep;
            [executable execute:self.target completion:^(NSError* error) {
                [self stepCompletedWithError:error];
            }];
        }
        else if ([self.currentStep.type isEqualToString:@"exposure"]){
            [self executeExposureStep:(CASSequenceExposureStep*)self.currentStep];
        }
        else {
            [self stopWithError:[NSError errorWithDomain:NSStringFromClass([self class])
                                                    code:3
                                                userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:NSLocalizedString(@"Unknown sequence step %@", @"Unknown sequence step %@"),self.currentStep.type]}]];
        }
    }
}

- (void)executeExposureStep:(CASSequenceExposureStep*)sequenceStep // todo; put into exposure step
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
        CASFilterWheelController* filterWheel = self.target.sequenceCameraController.filterWheel;
        if (!filterWheel){
            [self stopWithError:[NSError errorWithDomain:NSStringFromClass([self class])
                                                    code:1
                                                userInfo:@{NSLocalizedFailureReasonErrorKey:NSLocalizedString(@"An exposure step has a filter setting but no filter wheel has been selected", @"An exposure step has a filter setting but no filter wheel has been selected")}]];
            return;
        }
        else {
            if (![filterWheel.filterNames.allValues containsObject:filter]){
                [self stopWithError:[NSError errorWithDomain:NSStringFromClass([self class])
                                                        code:2
                                                    userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:NSLocalizedString(@"Unrecognised filter '%@'", @"Unrecognised filter '%@'"),filter]}]];
                return;
            }
            filterWheel.currentFilterName = filter;
            if (filterWheel.filterWheel.moving){
                [self observeFilterWheel];
                return;
            }
        }
    }
    
    [self capture];
}

- (void)stepCompletedWithError:(NSError*)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error){
            [self stopWithError:error];
        }
        else {
            [self advanceToNextStep];
        }
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context // todo; put into exposure step
{
    if (context == &kvoContext) {
        if ([@"moving" isEqualToString:keyPath]){
            if (!self.target.sequenceCameraController.filterWheel.filterWheel.moving && [self.target.sequenceCameraController.filterWheel.currentFilterName isEqualToString:((CASSequenceExposureStep*)self.currentStep).filter]){
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
    return self.sharedBookmarks.bookmarks;
}

- (CASBookmarks*)sharedBookmarks // this only exists so that we can reference it in the method below
{
    return CASBookmarks.sharedInstance;
}

+ (NSSet*)keyPathsForValuesAffectingBookmarks
{
    return [NSSet setWithArray:@[@"sharedBookmarks.bookmarks"]];
}

@end

@interface SXIOSequenceEditorParkStepView : SXIOSequenceEditorRowView
@end

@implementation SXIOSequenceEditorParkStepView
@end

@interface SXIOSequenceEditorSynchroniseStepView : SXIOSequenceEditorRowView
@end

@implementation SXIOSequenceEditorSynchroniseStepView
@end

@interface SXIOSequenceEditorPreflightStepView : SXIOSequenceEditorRowView
@property (weak) IBOutlet NSTextField *statusLabel;
@end

@implementation SXIOSequenceEditorPreflightStepView

- (IBAction)capture:(id)sender
{
    [(CASSequencePreflightStep*)self.step capture];
}

@end

@interface SXIOSequenceEditorWindowControllerStepsController : NSArrayController
@property (weak) IBOutlet SXIOSequenceEditorWindowController *windowController;
@end

@implementation SXIOSequenceEditorWindowControllerStepsController

- (void)setContent:(id)content
{
    [super setContent:content];
    
    // only supporting exposure types for now but in the future could have focus, slew, etc
    self.filterPredicate = [NSPredicate predicateWithBlock:^BOOL(CASSequenceStep* step, NSDictionary *bindings) {
        return
        [step isKindOfClass:[CASSequenceExposureStep class]] ||
        [step isKindOfClass:[CASSequenceSlewStep class]] || // inc. synchronise and park steps
        [step isKindOfClass:[CASSequencePreflightStep class]];
    }];
    
    for (CASSequenceStep* step in self.content){
        step.windowController = self.windowController;
    }
}

- (id)newObject
{
    return [CASSequenceExposureStep new];
}

- (void)addObject:(id)object
{
    [super addObject:object];
    
    CASSequenceStep* step = object;
    step.windowController = self.windowController;
}

- (void)addObjects:(NSArray*)objects
{
    [super addObjects:objects];
    
    for (CASSequenceStep* step in self.content){
        step.windowController = self.windowController;
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

@property (nonatomic) BOOL stopped;

@end

@implementation SXIOSequenceEditorWindowController {
    BOOL _stopped;
}

static void* kvoContext;

@synthesize sequence = _sequence;
@synthesize stopped = _stopped;

+ (instancetype)sharedWindowController
{
    static SXIOSequenceEditorWindowController* _sharedWindowController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedWindowController = [SXIOSequenceEditorWindowController createWindowController];
    });
    return _sharedWindowController;
}

- (instancetype)initWithWindow:(nullable NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        _stopped = YES;
    }
    return self;
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
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"SXIOSequenceEditorSynchroniseStepView" bundle:nil] forIdentifier:@"synchronise"];
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"SXIOSequenceEditorPreflightStepView" bundle:nil] forIdentifier:@"preflight"];

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

- (CASDeviceManager*)deviceManager
{
    return [CASDeviceManager sharedManager];
}

- (NSArray*)cameraControllers
{
    return self.deviceManager.cameraControllers;
}

- (CASCameraController*)selectedCameraController
{
    return self.camerasController.selectedObjects.firstObject;
}

- (void)setSelectedCameraController:(CASCameraController *)selectedCameraController
{
    self.camerasController.selectedObjects = selectedCameraController ? @[selectedCameraController] : nil;
    self.target = (SXIOCameraWindowController*)[[SXIOAppDelegate sharedInstance] findDeviceWindowController:selectedCameraController];
}

+ (NSSet*)keyPathsForValuesAffectingCameraControllers
{
    return [NSSet setWithObject:@"deviceManager.cameraControllers"];
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

- (IBAction)start:(id)sender
{
#if defined(SXIO) || defined(CCDIO)
    // ensure the target is set to the current camera controller
    SXIOCameraWindowController* cameraWindow = (SXIOCameraWindowController*)[[SXIOAppDelegate sharedInstance] findDeviceWindowController:self.selectedCameraController];
    if (cameraWindow){
        self.target = cameraWindow;
    }
#endif

    if (![self canStart]){
        NSBeep();
        return;
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartTimerFired) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(completeWaitForStartTime) object:nil];

    if (self.sequenceRunner || self.nextRunTime){
        [self cancel:sender];
        return;
    }
    
    NSParameterAssert([self.sequence.steps count] > 0);

    _stopped = NO;
    self.startButton.title = NSLocalizedString(@"Stop", @"Stop");

    [self waitForStartTimeWithCompletion:^{
        
        self.sequenceRunner = [SXIOSequenceRunner new];
        self.sequenceRunner.windowController = self;
        self.sequenceRunner.target = self.target; // might be nil
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
                _stopped = YES;
                weakSelf.nextRunTime = nil;
                weakSelf.startButton.title = NSLocalizedString(@"Start", @"Start");
            }
        };
        
        [self.sequenceRunner start:^(NSError *error) {
            if (error){
                _stopped = YES;
                self.sequenceRunner = nil;
                self.nextRunTime = nil;
                self.startButton.title = NSLocalizedString(@"Start", @"Start");
                [NSApp presentError:error];
            }
        }];
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
        NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Cancel Sequence", @"Cancel Sequence")
                                         defaultButton:NSLocalizedString(@"OK", @"OK")
                                       alternateButton:NSLocalizedString(@"Cancel", @"Cancel")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to cancel the currently running sequence ?", @"Are you sure you want to cancel the currently running sequence ?")];
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
    return [self.sequence.steps count] > 0;
}

+ (NSSet*)keyPathsForValuesAffectingCanStart
{
    return [NSSet setWithArray:@[@"target",@"stepsController.arrangedObjects"]];
}

- (void)updateWindowRepresentedURL:(NSURL*)url
{
    self.sequenceURL = url; // this isn't being shown while it's a sheet
    
    if (url.isFileURL){
        [self.window setTitleWithRepresentedFilename:url.path];
    }
    else {
        self.window.representedURL = url;
    }
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] updateWindowInWindowMenu:self];
#endif
}

- (void)archiveToURL:(NSURL*)url
{
    NSError* error;
    if ([[NSKeyedArchiver archivedDataWithRootObject:self.sequence] writeToURL:url options:NSDataWritingAtomic error:&error]){
        [self updateWindowRepresentedURL:url];
    }
    else if (error) {
        [NSApp presentError:error];
    }
}

- (IBAction)saveAs:(id)sender
{
    NSSavePanel* save = [NSSavePanel savePanel];
    
    save.allowedFileTypes = @[@"sxioSequence"];
    save.canCreateDirectories = YES;
    
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton){
            [self archiveToURL:save.URL];
        }
    }];
}

- (IBAction)save:(id)sender
{
    if (self.sequenceURL && ([NSEvent modifierFlags] & NSEventModifierFlagOption) == 0){
        [self archiveToURL:self.sequenceURL];
    }
    else {
        [self saveAs:sender];
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

- (BOOL)openURL:(NSURL*)url doubleClicked:(BOOL)doubleClicked
{
    if ([self openSequenceWithURL:url]){
        CASSaveUrlToDefaults(url,kSXIOSequenceEditorWindowControllerBookmarkKey);
        [self.window makeKeyAndOrderFront:nil];
        if (doubleClicked && self.sequence.autoStart && ([NSEvent modifierFlags] & NSEventModifierFlagOption) == 0){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self start:nil];
            });
        }
        return YES;
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Can't open Sequence", @"Can't open Sequence")
                                             defaultButton:NSLocalizedString(@"OK", @"OK")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"There was an problem reading the sequence file. It may be corrupt or contain sequence steps not supported by this version of %@.", @"There was an problem reading the sequence file. It may be corrupt or contain sequence steps not supported by this version of %@."),[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
            [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        });
        return NO;
    }
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
        if ([sequence isKindOfClass:[CASSequence class]]){
            if (self.sequenceURL){
                [self.sequenceURL stopAccessingSecurityScopedResource];
            }
            self.sequence = sequence;
            [self updateWindowRepresentedURL:url];
            success = YES;
        }
    }
    return success;
}

- (IBAction)openDocument:(id)sender
{
    [self open:sender];
}

- (IBAction)open:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = @[@"sxioSequence"];
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton){
            [self openURL:open.URL doubleClicked:NO];
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

- (IBAction)addSynchroniseStep:(id)sender
{
    [self.stepsController addObject:[CASSequenceSynchroniseStep new]];
}

- (IBAction)addPreflightStep:(id)sender
{
    // force to the start of the array ? prevent duplicates ?
    [self.stepsController addObject:[CASSequencePreflightStep new]];
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

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 28;
}

@end
