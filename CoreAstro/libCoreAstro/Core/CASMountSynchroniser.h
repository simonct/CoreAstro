//
//  CASMountSlewController.h
//  astrometry-test
//
//  Created by Simon Taylor on 24/03/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@class CASMountSynchroniser;

@protocol CASMountMountSynchroniserDelegate <NSObject>
- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCaptureExposure:(CASCCDExposure*)exposure;
- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didSolveExposure:(CASPlateSolveSolution*)solution;
- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCompleteWithError:(NSError*)error;
@end

@interface CASMountSynchroniser : NSObject
@property (readonly) NSError* error;
@property (readonly) BOOL solving;
@property float focalLength;
@property (readonly,nonatomic,copy) NSString* status;
@property (strong) CASMount* mount;
@property (strong) CASCameraController* cameraController;
@property (weak) id<CASMountMountSynchroniserDelegate> delegate;
- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees;
- (void)cancel;
@end