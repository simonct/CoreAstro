//
//  SXIOPlateSolveController.h
//  SX IO
//
//  Created by Simon Taylor on 01/06/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@class SXIOPlateSolveController;

@protocol SXIOPlateSolveControllerDelegate <NSObject>
- (void)plateSolver:(SXIOPlateSolveController*)plateSolver didStartSolvingExposure:(CASCCDExposure*)exposure;
- (void)plateSolver:(SXIOPlateSolveController*)plateSolver completedWithSolution:(CASPlateSolveSolution*)solution error:(NSError*)error;
@end

@interface SXIOPlateSolveController : NSObject

@property (weak) NSWindow* window;
@property (weak) CASCameraController* cameraController;
@property (weak) id<SXIOPlateSolveControllerDelegate> delegate;

@property (nonatomic) BOOL busy;

- (void)plateSolveExposure:(CASCCDExposure*)exposure;
- (void)plateSolveExposureWithOptions:(CASCCDExposure*)exposure;

@end
