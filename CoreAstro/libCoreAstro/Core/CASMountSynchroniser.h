//
//  CASMountSynchroniser.h
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
@optional
- (void)mountSynchroniserDidSyncMount:(CASMountSynchroniser*)mountSynchroniser;
@end

@interface CASMountSynchroniser : NSObject
@property (readonly) NSError* error;
@property (readonly) BOOL busy;
@property (readonly,nonatomic,copy) NSString* status;
@property (weak) CASMountController* mountController;
@property (weak) id<CASMountMountSynchroniserDelegate> delegate;
- (void)findLocation;
- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees;
- (void)cancel;
@end
