//
//  CASMountController.m
//  CoreAstro
//
//  Created by Simon Taylor on 1/9/16.
//  Copyright © 2016 Simon Taylor. All rights reserved.
//

#import "CASMountController.h"
#import "CASCameraController.h"
#import "CASLX200Commands.h"
#import "CASObjectLookup.h"
#import "CASMountSynchroniser.h"
#import <CoreAstro/CoreAstro-Swift.h>

NSString* kCASMountControllerCapturedSyncExposureNotification = @"kCASMountControllerCapturedSyncExposureNotification";
NSString* kCASMountControllerSolvedSyncExposureNotification = @"kCASMountControllerSolvedSyncExposureNotification";
NSString* kCASMountControllerCompletedSyncNotification = @"kCASMountControllerCompletedSyncNotification";

@interface CASMountController ()<CASMountMountSynchroniserDelegate>
@property (nonatomic,strong) CASMount* mount;
@property (strong) NSScriptCommand* slewCommand;
@property (strong) CASMountSynchroniser* mountSynchroniser;
@property (copy) void(^slewCompletion)(NSError*);
@property (strong) CASMountSlewObserver* slewObserver;
@property (strong) NSScriptCommand* findCommand;
@end

@implementation CASMountController

- (id)initWithMount:(CASMount*)mount
{
    self = [super init];
    if (self){
        self.mount = mount;
        self.mountSynchroniser = [[CASMountSynchroniser alloc] init];
        self.mountSynchroniser.delegate = self;
        [self bind:@"status" toObject:self.mountSynchroniser withKeyPath:@"status" options:nil];
        // unbind ?
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"[CASMountController dealloc]");
}

- (CASDevice*) device
{
    return self.mount;
}

- (BOOL) busy
{
    return self.mount.slewing || self.synchronising;
}

- (BOOL) synchronising
{
    return self.mountSynchroniser.busy;
}

#pragma mark - Mount Synchroniser delegate

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCaptureExposure:(CASCCDExposure*)exposure
{
    NSDictionary* userInfo = exposure ? @{@"exposure":exposure} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASMountControllerCapturedSyncExposureNotification object:self userInfo:userInfo];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didSolveExposure:(CASPlateSolveSolution*)solution
{
    NSDictionary* userInfo = solution ? @{@"solution":solution} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASMountControllerSolvedSyncExposureNotification object:self userInfo:userInfo];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCompleteWithError:(NSError*)error
{
    if (self.slewCommand){
        if (error){
            self.slewCommand.scriptErrorNumber = error.code;
            self.slewCommand.scriptErrorString = error.localizedDescription;
        }
        [self.slewCommand resumeExecutionWithResult:nil];
        self.slewCommand = nil;
    }

    if (self.findCommand){
        if (error){
            self.findCommand.scriptErrorNumber = error.code;
            self.findCommand.scriptErrorString = error.localizedDescription;
        }
        [self.findCommand resumeExecutionWithResult:nil];
        self.findCommand = nil;
    }

    [self callSlewCompletion:error];

    NSDictionary* userInfo = error ? @{@"error":error} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASMountControllerCompletedSyncNotification object:self userInfo:userInfo];
}

#pragma mark - Slewing

- (void)callSlewCompletion:(NSError*)error
{
    if (self.slewCompletion){
        self.slewCompletion(error);
    }
    self.slewCompletion = nil;
}

- (void)setTargetRA:(double)raDegs dec:(double)decDegs completion:(void(^)(NSError*))completion
{
    if (!self.mount.connected){
        completion([NSError errorWithDomain:NSStringFromClass([self class]) code:13 userInfo:@{NSLocalizedDescriptionKey:@"Mount not connected"}]);
        return;
    }
    if (self.mount.slewing || self.mountSynchroniser.busy){
        completion([NSError errorWithDomain:NSStringFromClass([self class]) code:14 userInfo:@{NSLocalizedDescriptionKey:@"Mount is busy"}]);
        return;
    }

    [self.mount setTargetRA:raDegs dec:decDegs completion:^(CASMountSlewError slewError) {
        NSError* error;
        if (error != CASMountSlewErrorNone){
            error = [NSError errorWithDomain:NSStringFromClass([self class]) code:12 userInfo:@{NSLocalizedDescriptionKey:@"Set target failed"}];
        }
        if (completion){
            completion(error);
        }
    }];
}

- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees
{
    NSParameterAssert(self.mount.connected);
    
    if (!self.usePlateSolving){
        
        NSLog(@"Slewing without plate solving");
        
        // not doing anything clever, just ask the mount to slew and return when it confirms that it's on its way (todo; this should wait until it's completed the slew...)
        __weak __typeof(self) weakSelf = self;
        [self.mount startSlewToRA:raInDegrees dec:decInDegrees completion:^(CASMountSlewError slewError,CASMountSlewObserver* observer) {
            if (slewError != CASMountSlewErrorNone){
                if (slewError == CASMountSlewErrorInvalidState){
                    [self callSlewCompletion:[NSError errorWithDomain:NSStringFromClass([self class]) code:16 userInfo:@{NSLocalizedDescriptionKey:@"Start slew failed. The mount has not yet been synced to the sky."}]];
                }
                else {
                    [self callSlewCompletion:[NSError errorWithDomain:NSStringFromClass([self class]) code:10 userInfo:@{NSLocalizedDescriptionKey:@"Start slew failed. The object may be below the local horizon"}]];
                }
            }
            else {
                self.slewObserver = observer;
                self.slewObserver.completion = ^(NSError* error){
                    [weakSelf callSlewCompletion:error];
                    weakSelf.slewObserver = nil;
                };
            }
        }];
    }
    else {
        
        if (!self.cameraController){
            [self callSlewCompletion:[NSError errorWithDomain:NSStringFromClass([self class]) code:11 userInfo:@{NSLocalizedDescriptionKey:@"Cannot slew with plate solving enabled as no camera has been selected"}]];
        }
        else {
            
            NSLog(@"Slewing with plate solving");

            // ok, looks like we're plate solving so we need to set up the mount synchroniser
            [self.cameraController cancelCapture]; // todo; belongs in mountSynchroniser ?
            
            self.mountSynchroniser.mount = self.mount; // redundant ?
            self.mountSynchroniser.cameraController = self.cameraController;
            
            [self.mountSynchroniser startSlewToRA:raInDegrees dec:decInDegrees]; // this calls its delegate on completion which calls the slew completion block
        }
    }
}

- (void)slewToTargetWithCompletion:(void(^)(NSError*))completion
{
    if (!self.mount.targetRa || !self.mount.targetDec){
        if (completion){
            completion([NSError errorWithDomain:NSStringFromClass([self class]) code:3 userInfo:@{NSLocalizedDescriptionKey:@"No slew target is set"}]);
        }
        return;
    }
    if (!self.mount.connected || self.mount.slewing || self.mountSynchroniser.busy || self.slewCompletion){
        if (completion){
            completion([NSError errorWithDomain:NSStringFromClass([self class]) code:4 userInfo:@{NSLocalizedDescriptionKey:@"Mount is busy"}]);
        }
        return;
    }
    
    // this might involve a flip if the mount decides that it wants to
    // set the slew completion block; this is the bottleneck called from interactive slew and sequence (note: scripting *does not* currently go via this)
    self.slewCompletion = completion;
    
    return [self startSlewToRA:self.mount.targetRa.doubleValue dec:self.mount.targetDec.doubleValue];
}

- (NSDictionary*)bookmarkWithName:(NSString*)name
{
    NSDictionary* bookmark;
    NSArray* bookmarks = CASBookmarks.sharedInstance.bookmarks;
    
    for (NSDictionary* bm in bookmarks){
        if ([bm[CASBookmarks.nameKey] isEqualToString:name]){
            bookmark = bm;
            break;
        }
    }
    
    return bookmark;
}

- (void)getCoordinatesRA:(double*)ra dec:(double*)dec fromBookmark:(NSDictionary*)bookmark
{
    CASPlateSolveSolution* solution = [CASPlateSolveSolution solutionWithDictionary:bookmark[CASBookmarks.solutionDictionaryKey]];
    if (solution){
        *ra = solution.centreRA;
        *dec = solution.centreDec;
    }
    else {
        *ra = [bookmark[CASBookmarks.centreRaKey] doubleValue];
        *dec = [bookmark[CASBookmarks.centreDecKey] doubleValue];
    }
}

- (void)setTargetFromBookmark:(NSDictionary*)bookmark completion:(void(^)(NSError*))completion
{
    double ra = 0, dec = 0;
    [self getCoordinatesRA:&ra dec:&dec fromBookmark:bookmark];
    [self setTargetRA:ra dec:dec completion:completion];
}

- (void)slewToBookmark:(NSDictionary*)bookmark plateSolve:(BOOL)plateSolve completion:(void(^)(NSError*))completion;
{
    if (!bookmark.count){
        if (completion){
            completion([NSError errorWithDomain:NSStringFromClass([self class]) code:2 userInfo:@{NSLocalizedDescriptionKey:@"Invalid bookmark"}]);
        }
        return;
    }
    if (!self.mount.connected || self.mount.slewing || self.mountSynchroniser.busy){
        if (completion){
            completion([NSError errorWithDomain:NSStringFromClass([self class]) code:1 userInfo:@{NSLocalizedDescriptionKey:@"Mount is busy"}]);
        }
        return;
    }
    
    self.usePlateSolving = plateSolve; // push and pop this value ?
    
    __weak __typeof(self) weakSelf = self;
    [self setTargetFromBookmark:bookmark completion:^(NSError* error) {
        if (error){
            completion(error);
        }
        else {
            [weakSelf slewToTargetWithCompletion:completion];
        }
    }];
}

- (void)parkMountWithCompletion:(void(^)(NSError*))completion
{
    __weak __typeof(self) weakSelf = self;
    void (^parkCompletion)(CASMountSlewError,CASMountSlewObserver*) = ^(CASMountSlewError error, CASMountSlewObserver* observer){
        if (error != CASMountSlewErrorNone){
            completion([NSError errorWithDomain:NSStringFromClass([self class]) code:15 userInfo:@{NSLocalizedDescriptionKey:@"Mount failed to park"}]);
        }
        else {
            self.slewObserver = observer;
            self.slewObserver.completion = ^(NSError* error){
                weakSelf.slewObserver = nil;
                completion(error);
            };
        }
    };

    [self.mount park:^(CASMountSlewError error, CASMountSlewObserver* observer) {
        parkCompletion(error,observer);
    }];
}

- (void)stop
{
    if (self.mountSynchroniser.mount){
        [self.mountSynchroniser cancel];
    }
    else {
        [self.mount halt];
    }
}

@end

#pragma mark - Scripting

@implementation CASMountController (CASScripting)

- (NSString*)containerAccessor
{
    return @"mountControllers";
}

- (NSString*)scriptingRightAscension
{
    return [CASLX200Commands highPrecisionRA:self.mount.ra.doubleValue];
}

- (NSString*)scriptingDeclination
{
    return [CASLX200Commands highPrecisionDec:self.mount.dec.doubleValue];
}

- (NSString*)scriptingAltitude
{
    return [CASLX200Commands highPrecisionDec:self.mount.alt.doubleValue];
}

- (NSString*)scriptingAzimuth
{
    return [CASLX200Commands highPrecisionDec:self.mount.az.doubleValue];
}

- (NSNumber*)scriptingSlewing
{
    return @(self.mount.slewing || self.mountSynchroniser.busy);
}

- (CASCameraController*)scriptingCamera
{
    return self.cameraController;
}

- (void)setScriptingCamera:(CASCameraController*)cameraController
{
    self.cameraController = cameraController;
}

- (void)scriptingSlewTo:(NSScriptCommand*)command
{
    if (self.mount.slewing || self.mountSynchroniser.busy){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"The mount is currently slewing", nil);
        return;
    }
    
    NSString* object = command.arguments[@"object"];
    NSString* bookmark = command.arguments[@"bookmark"];
    NSDictionary* coordinates = command.arguments[@"coordinates"];
    if (!object.length && !coordinates.count && !bookmark.length){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"You must specify the name, coordinates or a bookmark for the object to slew to", nil);
        return;
    }
    
    const BOOL plateSolving = [command.arguments[@"plateSolving"] boolValue];
    if (plateSolving && !self.cameraController){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"Plate solving requires that the mount's camera be set", nil);
        return;
    }
    
    void (^slew)(double,double) = ^(double ra, double dec){
        
        if (plateSolving){
            
            // save the command so that we can resume when the synchroniser completes
            self.slewCommand = command;
            
            self.mountSynchroniser.mount = self.mount;
            self.mountSynchroniser.cameraController = self.cameraController;
            
            [self.mountSynchroniser startSlewToRA:ra dec:dec]; // this calls its delegate on completion which (todo;) needs to call the completion block
        }
        else {
            
            __weak __typeof(self) weakSelf = self;
            [self.mount startSlewToRA:ra dec:dec completion:^(CASMountSlewError error,CASMountSlewObserver* observer) {
                if (error != CASMountSlewErrorNone){
                    command.scriptErrorNumber = paramErr;
                    if (error == CASMountSlewErrorInvalidState){
                        command.scriptErrorString = NSLocalizedString(@"Failed to start slewing to that object. The mount has not yet been synced to the sky.", nil);
                    }
                    else {
                        command.scriptErrorString = NSLocalizedString(@"Failed to start slewing to that object. It may be below the local horizon.", nil);
                    }
                    [command resumeExecutionWithResult:nil];
                }
                else {
                    // wait until it stops slewing and then resume the command
                    self.slewObserver = observer;
                    self.slewObserver.completion = ^(NSError* error){
                        [command resumeExecutionWithResult:nil];
                        weakSelf.slewObserver = nil;
                    };
                }
            }];
        }
    };
    
    [command suspendExecution];
    
    if (coordinates.count){
        slew([coordinates[@"ra"] doubleValue],[coordinates[@"dec"] doubleValue]);
    }
    else if (bookmark.length) {
        NSDictionary* bookmarkDict = [self bookmarkWithName:bookmark];
        if (!bookmarkDict.count){
            command.scriptErrorNumber = paramErr;
            command.scriptErrorString = [NSString stringWithFormat:NSLocalizedString(@"Couldn't locate the bookmark '%@'", nil),bookmark];
            [command resumeExecutionWithResult:nil];
        }
        else {
            double ra = 0, dec = 0;
            [self getCoordinatesRA:&ra dec:&dec fromBookmark:bookmarkDict];
            slew(ra,dec);
        }
    }
    else {
        [[CASObjectLookup new] lookupObject:object withCompletion:^(BOOL success, NSString *objectName, double ra, double dec) {
            if (!success){
                command.scriptErrorNumber = paramErr;
                command.scriptErrorString = [NSString stringWithFormat:NSLocalizedString(@"Couldn't locate the object '%@'", nil),object];
                [command resumeExecutionWithResult:nil];
            }
            else {
                slew(ra,dec);
            }
        }];
    }
}

- (void)scriptingStop:(NSScriptCommand*)command
{
    [self.mount halt];
    [self.mountSynchroniser cancel];
}

- (void)scriptingPark:(NSScriptCommand*)command
{
    [self scriptingStop:nil];
    
    [command suspendExecution];

    NSNumber* position = command.evaluatedArguments[@"position"];
    
    // non-blocking so the client will have to poll the slewing state
    __weak __typeof(self) weakSelf = self;
    
    void (^parkCompletion)(CASMountSlewError,CASMountSlewObserver*) = ^(CASMountSlewError error, CASMountSlewObserver* observer){
        if (error != CASMountSlewErrorNone){
            command.scriptErrorNumber = paramErr;
            command.scriptErrorString = [NSString stringWithFormat:NSLocalizedString(@"Failed to park", nil)];
            [command resumeExecutionWithResult:nil];
        }
        else {
            self.slewObserver = observer;
            self.slewObserver.completion = ^(NSError* error){
                if (error){
                    command.scriptErrorNumber = paramErr;
                    command.scriptErrorString = error.localizedDescription;
                }
                [command resumeExecutionWithResult:nil];
                weakSelf.slewObserver = nil;
            };
        }
    };
    
    if (position && [self.mount respondsToSelector:@selector(parkToPosition:completion:)]){
        if (![self.mount parkToPosition:[position integerValue] completion:^(CASMountSlewError error, CASMountSlewObserver* observer) {
            parkCompletion(error,observer);
        }]){
            command.scriptErrorNumber = paramErr;
            command.scriptErrorString = [NSString stringWithFormat:NSLocalizedString(@"Unrecognised park position %ld", nil),position];
            [command resumeExecutionWithResult:nil];
        }
    }
    else {
        [self.mount park:^(CASMountSlewError error, CASMountSlewObserver* observer) {
            parkCompletion(error,observer);
        }];
    }
}

- (void)scriptingFindLocation:(NSScriptCommand*)command
{
    if (self.mount.slewing || self.mountSynchroniser.busy){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"The mount is currently slewing", nil);
        return;
    }
    
    self.findCommand = command;
    
    [self.findCommand suspendExecution];

    self.mountSynchroniser.mount = self.mount;
    self.mountSynchroniser.cameraController = self.cameraController;
    [self.mountSynchroniser findLocation];
}

@end
