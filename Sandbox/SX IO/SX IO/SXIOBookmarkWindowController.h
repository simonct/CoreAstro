//
//  SXIOBookmarkWindowController.h
//  SX IO
//
//  Created by Simon Taylor on 09/09/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>
#import "CASAuxWindowController.h"

@interface SXIOBookmarkWindowController : CASAuxWindowController
- (void)addSolutionBookmark:(CASPlateSolveSolution*)solution;
+ (SXIOBookmarkWindowController*)sharedController;
@end
