//
//  CASProgressWindowController.m
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

#import "CASProgressWindowController.h"

@interface CASProgressWindowController ()
@end

@implementation CASProgressWindowController {
    BOOL _cancelled;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.label.stringValue = @"";
    self.progressBar.indeterminate = YES;
    self.progressBar.usesThreadedAnimation = YES;
    [self.progressBar startAnimation:nil];
    self.canCancel = NO;
}

- (void)beginSheetModalForWindow:(NSWindow*)window
{
    [super beginSheetModalForWindow:window completionHandler:^(NSInteger code) {
        [self.progressBar stopAnimation:nil];
    }];
}

- (void)configureWithRange:(NSRange)range label:(NSString*)label
{
    NSAssert(self.label, @"-configureWithRange:label: called before the window's loaded");
    self.label.stringValue = label;
    self.progressBar.doubleValue = 0;
    self.progressBar.minValue = range.location;
    self.progressBar.maxValue = range.length;
    self.progressBar.indeterminate = NO;
}

- (IBAction)cancel:(id)sender {
    _cancelled = YES;
    if (self.cancelBlock){
        self.cancelBlock();
    }
}

- (BOOL)canCancel
{
    return self.cancelButton.isEnabled;
}

- (void)setCanCancel:(BOOL)canCancel
{
    NSAssert(self.cancelButton, @"-setCanCancel: called before the window's loaded");
    [self.cancelButton setEnabled:canCancel];
}

@end
