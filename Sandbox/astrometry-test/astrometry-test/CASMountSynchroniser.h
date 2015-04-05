//
//  CASMountSlewController.h
//  astrometry-test
//
//  Created by Simon Taylor on 24/03/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@class CASMountSynchroniser;

@protocol CASMountSlewControllerDelegate <NSObject>
- (void)slewController:(CASMountSynchroniser*)slewController didCaptureExposure:(CASCCDExposure*)exposure;
- (void)slewController:(CASMountSynchroniser*)slewController didSolveExposure:(CASPlateSolveSolution*)solution;
- (void)slewController:(CASMountSynchroniser*)slewController didCompleteWithError:(NSError*)error;
- (void)slewController:(NSError*)error;
@end

@interface CASMountSynchroniser : NSObject
@property (readonly) NSError* error;
@property (readonly) BOOL solving;
@property float focalLength;
@property (readonly,nonatomic,copy) NSString* status;
@property (strong) CASMount* mount;
@property (strong) CASCameraController* cameraController;
@property (weak) id<CASMountSlewControllerDelegate> delegate;
- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees;
- (void)cancel;
@end
