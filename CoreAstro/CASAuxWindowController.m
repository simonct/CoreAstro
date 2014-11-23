//
//  CASAuxWindowController.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "CASAuxWindowController.h"

@interface CASAuxWindowController ()
@property (nonatomic,weak) NSWindow* parent;
@end

@implementation CASAuxWindowController

- (void)endSheetWithCode:(NSInteger)code
{
    if ([self.parent respondsToSelector:@selector(endSheet:returnCode:)]){
        [self.parent endSheet:self.window returnCode:code];
    }
    else {
        [NSApp endSheet:self.window returnCode:code];
        [self.window orderOut:self];
    }
    
    if (self.modalHandler){
        self.modalHandler(code);
    }
}

- (void)beginSheetModalForWindow:(NSWindow*)window completionHandler:(void (^)(NSInteger))handler
{
    self.parent = window;
    self.modalHandler = handler;
    
    if ([self.parent respondsToSelector:@selector(beginSheet:completionHandler:)]){
        [self.parent beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
            self.modalHandler = nil;
            handler(returnCode);
        }];
    }
    else {
        [NSApp beginSheet:self.window modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
    }
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
