//
//  CASPHDControlsViewController.m
//  CoreAstro
//
//  Created by Simon Taylor on 21/7/13.
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

#import "CASPHDControlsViewController.h"
#import <CoreAstro/CoreAstro.h>

@interface CASPHDControlsViewController ()
@end

@implementation CASPHDControlsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self){
    }
    return self;
}

- (IBAction)connectToPHD:(id)sender {
    
    NSString* const kPHDAppID = @"com.StarkLabs.PHD";
    
    // check it's installed
    NSURL* url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:kPHDAppID];
    if (!url){
        // alert
        return;
    }
    
    // launch/get existing instance
    NSRunningApplication* app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:0 configuration:nil error:nil];
    if (!app){
        // alert
        return;
    }
    
    NSLog(@"%@",app);
    
    // create phd client
}

@end
