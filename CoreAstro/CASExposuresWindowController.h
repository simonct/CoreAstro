//
//  CASExposuresWindowController.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASAuxWindowController.h"

@interface CASExposuresWindowController : CASAuxWindowController
@property (nonatomic,readonly) NSArrayController* exposures;
- (void)beginSheetModalForWindow:(NSWindow*)window exposuresCompletionHandler:(void (^)(NSInteger,NSArray*))handler;
@end
