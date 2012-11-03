//
//  CASExposuresWindowController.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASExposuresWindowController : NSWindowController
@property (nonatomic,readonly) NSArrayController* exposures;
@property (nonatomic,copy) void (^modalHandler)(NSInteger result,NSArray* selectedExposures);
+ (CASExposuresWindowController*)createWindowController;
- (void)beginSheetModalForWindow:(NSWindow*)window completionHandler:(void (^)(NSInteger,NSArray*))handler;
@end
