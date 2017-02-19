//
//  CASCaptureCommand.m
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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

#import "CASCaptureCommand.h"
#import <CoreAstro/CoreAstro.h>

@interface CASCaptureCommand ()
@property (nonatomic,strong) NSMutableArray* result;
@end

@implementation CASCaptureCommand

- (id)performDefaultImplementationImpl
{
    CASCameraController* controller = (CASCameraController*)[self evaluatedReceivers];
    if ([controller isKindOfClass:[CASCameraController class]]){
        
        if (controller.capturing){
            [self setErrorCode:paramErr string:NSLocalizedString(@"The camera is busy capturing a sequence", @"Scripting error message")];
        }
        else {
            
            controller.scriptCommand = [NSScriptCommand currentCommand];
            
            [CASPowerMonitor sharedInstance].disableSleep = YES;
            [self suspendExecution];
            
            self.result = [NSMutableArray arrayWithCapacity:controller.settings.captureCount];
            
            [controller resetCapture];
            
            [controller captureWithBlock:^(NSError *error, CASCCDExposure *exposure) {
                
                if (error){
                    [self setErrorCode:[error code] string:[error localizedDescription]];
                }
                if (exposure){
                    [self.result addObject:exposure];
                }
                if (!controller.capturing){
                    [CASPowerMonitor sharedInstance].disableSleep = NO;
                    [self resumeExecutionWithResult:self.result];
                }
            }];
        }
    }
	return nil;
}

- (void)resumeExecutionWithResult:(id)result
{
    CASCameraController* controller = (CASCameraController*)[self evaluatedReceivers];

    controller.scriptCommand = nil;
    
    [super resumeExecutionWithResult:result];
}

@end
