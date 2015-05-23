//
//  CASMountWindowController.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMountWindowController.h"
#import "SXIOPlateSolveOptionsWindowController.h" // for +focalLengthWithCameraKey:
#if defined(SXIO)
#import "SXIOAppDelegate.h"
#endif
#import <CoreAstro/CoreAstro.h>

@interface CASPierSideTransformer : NSValueTransformer
@end

@implementation CASPierSideTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    switch ([value integerValue]) {
        case CASMountPierSideEast:
            return @"East";
        case CASMountPierSideWest:
            return @"West";
    }
    return @"";
}

@end

@interface CASMountWindowController ()<CASMountMountSynchroniserDelegate>
@property (nonatomic,strong) CASMount* mount;
@property (nonatomic,copy) NSString* searchString;
@property (nonatomic,assign) NSInteger guideDurationInMS;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSPopUpButton *cameraPopupButton;
@property (nonatomic,readonly) NSArray* cameraControllers;
@property (strong) IBOutlet NSArrayController *camerasArrayController;
@property (nonatomic) CASCameraController* selectedCameraController;
@property (nonatomic,strong) CASMountSynchroniser* mountSynchroniser;
@property (weak) IBOutlet NSTextField *pierSideLabel;
@end

// todo;
// not reflecting initial slew state
// ra/dec all zeros ?

@implementation CASMountWindowController

@synthesize cameraControllers = _cameraControllers;

static void* kvoContext;

+ (void)initialize
{
    [NSValueTransformer setValueTransformer:[CASLX200RATransformer new] forName:@"CASLX200RATransformer"];
    [NSValueTransformer setValueTransformer:[CASLX200DecTransformer new] forName:@"CASLX200DecTransformer"];
    [NSValueTransformer setValueTransformer:[CASPierSideTransformer new] forName:@"CASPierSideTransformer"];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASMountWindowControllerBinning":@(4),
                                                              @"CASMountWindowControllerDuration":@(5),
                                                              @"CASMountWindowControllerConvergence":@(0.02)}];
}

- (void)dealloc
{
    self.mountSynchroniser = nil;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
#if defined(SXIO)
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self];
#endif
    
    self.mountSynchroniser = [CASMountSynchroniser new];
    
    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(closeWindow:)];
}

- (void)closeWindow:sender
{
    if (self.mountSynchroniser.solving){
        // need a way of cancelling a solve
        NSLog(@"Currently solving...");
        return;
    }
    
    [self.mountSynchroniser cancel];
    [self.mount disconnect];
    
#if defined(SXIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromWindowMenu:self];
#endif
    
    [self close];
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
}

#pragma mark - Mount/Camera

- (NSArray*)cameraControllers
{
    return [CASDeviceManager sharedManager].cameraControllers;
}

- (CASCameraController*) selectedCameraController
{
    if (_cameraController){
        return _cameraController;
    }
    return self.camerasArrayController.selectedObjects.firstObject;
}

+ (NSSet*)keyPathsForValuesAffectingSelectedCameraController
{
    return [NSSet setWithObject:@"cameraController"];
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    if (cameraController != _cameraController){
        _cameraController = cameraController;
        if (_cameraController){
            NSString* const focalLengthKey = [SXIOPlateSolveOptionsWindowController focalLengthWithCameraKey:_cameraController];
            NSNumber* focalLength = [[NSUserDefaults standardUserDefaults] objectForKey:focalLengthKey];
            if ([focalLength isKindOfClass:[NSNumber class]]){
                self.mountSynchroniser.focalLength = [focalLength floatValue];
            }
        }
    }
}

- (void)setMountSynchroniser:(CASMountSynchroniser *)mountSynchroniser
{
    if (mountSynchroniser != _mountSynchroniser){
        [_mountSynchroniser removeObserver:self forKeyPath:@"focalLength" context:&kvoContext];
        _mountSynchroniser = mountSynchroniser;
        [_mountSynchroniser addObserver:self forKeyPath:@"focalLength" options:0 context:&kvoContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if (_cameraController && [keyPath isEqualToString:@"focalLength"]){
            NSString* const focalLengthKey = [SXIOPlateSolveOptionsWindowController focalLengthWithCameraKey:_cameraController];
            [[NSUserDefaults standardUserDefaults] setObject:@(self.mountSynchroniser.focalLength) forKey:focalLengthKey];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)connectToMount:(CASMount*)mount completion:(void(^)(NSError*))completion
{
    self.mount = mount;
    
#if CAS_SLEW_AND_SYNC_TEST
    _testError = 1;
#endif

    [self.mount connectWithCompletion:^(NSError* error){
        if (self.mount.connected){
            [self.window makeKeyAndOrderFront:nil];
            self.guideDurationInMS = 1000;
        }
        if (completion){
            completion(error);
        }
    }];
}

- (void)setTargetRA:(double)raDegs dec:(double)decDegs
{
    NSParameterAssert(self.mount.connected);
    
    __weak __typeof (self) weakSelf = self;
    [self.mount setTargetRA:raDegs dec:decDegs completion:^(CASMountSlewError error) {
        if (error != CASMountSlewErrorNone){
            [weakSelf presentAlertWithMessage:[NSString stringWithFormat:@"Set target failed with error %ld",error]];
        }
    }];
}

- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees
{
    NSParameterAssert(self.mount.connected);

    if (!self.usePlateSolvng){
        [self.mount startSlewToRA:raInDegrees dec:decInDegrees completion:^(CASMountSlewError error) {
            if (error != CASMountSlewErrorNone){
                NSLog(@"*** start slew failed: %ld",(long)error);
            }
        }];
    }
    else {
        
        if (!self.selectedCameraController){
            NSLog(@"*** No camera selected");
            return;
        }
        
        [self.selectedCameraController cancelCapture]; // todo; belongs in mountSynchroniser ?
        
        self.mountSynchroniser.mount = self.mount;
        self.mountSynchroniser.cameraController = self.selectedCameraController;
        self.mountSynchroniser.delegate = self;

        [self.mountSynchroniser startSlewToRA:raInDegrees dec:decInDegrees];
    }
}

- (void)startMoving:(CASMountDirection)direction
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving) object:nil];
    [self performSelector:@selector(stopMoving) withObject:nil afterDelay:0.25];
    [self.mount startMoving:direction];
}

- (void)stopMoving
{
    [self.mount stopMoving];
}

#pragma mark - Actions

- (IBAction)north:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionNorth];
}

- (IBAction)soutgh:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionSouth];
}

- (IBAction)west:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionWest];
}

- (IBAction)east:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionEast];
}

- (IBAction)slew:(id)sender
{
    if (!self.mount.targetRa || !self.mount.targetDec){
        return;
    }
    
    [self startSlewToRA:[self.mount.targetRa doubleValue] dec:[self.mount.targetDec doubleValue]];
}

- (IBAction)stop:(id)sender
{
    [self.mount halt];
}

- (IBAction)home:(id)sender
{
    [self.mount gotoHomePosition];
}

- (IBAction)park:(id)sender
{
    [self.mount park];
}

- (IBAction)lookup:(id)sender
{
    if (![self.searchString length]){
        NSBeep();
        return;
    }
    
    __weak __typeof (self) weakSelf = self;
    
    CASObjectLookup* lookup = [CASObjectLookup new];
    [lookup lookupObject:self.searchString withCompletion:^(BOOL success,NSString*objectName,double ra, double dec) {
        if (!success){
            [[NSAlert alertWithMessageText:@"Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Target couldn't be found"] runModal];
        }
        else{
            [weakSelf setTargetRA:ra dec:dec]; // probably not - do this when slew commanded as the mount may be busy ?
        }
    }];
}

#pragma mark - Mount Synchroniser delegate

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCaptureExposure:(CASCCDExposure*)exposure
{
    [self.mountWindowDelegate mountWindowController:self didCaptureExposure:exposure];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didSolveExposure:(CASPlateSolveSolution*)solution
{
    [self.mountWindowDelegate mountWindowController:self didSolveExposure:solution];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCompleteWithError:(NSError*)error
{
    [self.mountWindowDelegate mountWindowController:self didCompleteWithError:error];
}

@end
