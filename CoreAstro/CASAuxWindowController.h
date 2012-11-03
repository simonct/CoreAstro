//
//  CASAuxWindowController.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASAuxWindowController : NSWindowController

@property (nonatomic,copy) void (^modalHandler)(NSInteger result);

- (void)beginSheetModalForWindow:(NSWindow*)window completionHandler:(void (^)(NSInteger))handler;
- (void)endSheetWithCode:(NSInteger)code;

+ (id)createWindowController;

@end
