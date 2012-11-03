//
//  CASAuxWindowController.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASAuxWindowController.h"

@interface CASAuxWindowController ()

@end

@implementation CASAuxWindowController

- (void)endSheetWithCode:(NSInteger)code
{
    [NSApp endSheet:self.window returnCode:code];
    [self.window orderOut:self];
    
    if (self.modalHandler){
        self.modalHandler(code);
    }
}

- (void)beginSheetModalForWindow:(NSWindow*)window completionHandler:(void (^)(NSInteger))handler
{
    self.modalHandler = handler;
    
    [NSApp beginSheet:self.window modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

+ (id)createWindowController
{
    id result = nil;
    Class klass = [self class];
    do {
        result = [[[self class] alloc] initWithWindowNibName:NSStringFromClass(klass)];
        klass = [klass superclass];
    } while (klass && !result);
    return result;
}

@end
