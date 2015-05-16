//
//  CASMountWindowController.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMountWindowController.h"
#import "CASMountSynchroniser.h"
#import <CoreAstro/CoreAstro.h>

@interface CASMountWindowController ()<CASMountMountSynchroniserDelegate>
@property (nonatomic,strong) CASMount* mount;
@property (nonatomic,copy) NSString* searchString;
@property (nonatomic,assign) NSInteger guideDurationInMS;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSPopUpButton *cameraPopupButton;
@property (nonatomic,readonly) NSArray* cameraControllers;
@property BOOL usePlateSolvng;
@property (strong) IBOutlet NSArrayController *camerasArrayController;
@property (nonatomic,readonly) CASCameraController* selectedCameraController;
@property (strong) CASMountSynchroniser* mountSynchroniser;
@end

@implementation CASMountWindowController

@synthesize cameraControllers = _cameraControllers;

+ (void)initialize
{
    [NSValueTransformer setValueTransformer:[CASLX200RATransformer new] forName:@"CASLX200RATransformer"];
    [NSValueTransformer setValueTransformer:[CASLX200DecTransformer new] forName:@"CASLX200DecTransformer"];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASMountWindowControllerBinning":@(4),
                                                              @"CASMountWindowControllerDuration":@(5),
                                                              @"CASMountWindowControllerConvergence":@(0.02)}];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
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
    
    [self close];
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
}

#pragma mark - Mount/Camera

- (double)separation
{
    return self.mountSynchroniser.separation;
}

- (NSArray*)cameraControllers
{
    return [CASDeviceManager sharedManager].cameraControllers;
}

- (CASCameraController*) selectedCameraController
{
    return self.camerasArrayController.selectedObjects.firstObject;
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
        
        if (!self.mountSynchroniser){
            self.mountSynchroniser = [CASMountSynchroniser new];
        }
        
        self.mountSynchroniser.mount = self.mount;
        self.mountSynchroniser.focalLength = [[NSUserDefaults standardUserDefaults] floatForKey:@"CASFocalLengthMillemeter"];
        self.mountSynchroniser.cameraController = self.selectedCameraController;
        self.mountSynchroniser.delegate = self;

        [self.mountSynchroniser startSlewToRA:raInDegrees dec:decInDegrees];
    }
}

- (void)startMoving:(CASMountDirection)direction
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving:) object:nil];
    [self performSelector:@selector(stopMoving:) withObject:nil afterDelay:0.25];
    [self.mount startMoving:direction];
}

#pragma mark - Actions

- (IBAction)north:(id)sender
{
    [self startMoving:CASMountDirectionNorth];
}

- (IBAction)soutgh:(id)sender
{
    [self startMoving:CASMountDirectionSouth];
}

- (IBAction)west:(id)sender
{
    [self startMoving:CASMountDirectionWest];
}

- (IBAction)east:(id)sender
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
