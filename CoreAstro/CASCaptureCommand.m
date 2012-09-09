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
#import "CASCameraController.h"

@interface CASCaptureCommand ()
@end

@implementation CASCaptureCommand

- (id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef
{
    return [super initWithCommandDescription:commandDef];
}

- (void)setDirectParameter:(id)directParameter
{
    [super setDirectParameter:directParameter];
}

- (id)performDefaultImplementationImpl
{
    CASCameraController* controller = (CASCameraController*)[self evaluatedReceivers];
    if ([controller isKindOfClass:[CASCameraController class]]){
        
        [self suspendExecution];
                                
        id bin = [[self evaluatedArguments] objectForKey:@"bin"];
        const NSInteger binningIndex = ([bin integerValue] > 0) ? [bin integerValue] - 1 : 0;
        controller.binningIndex = MAX(0,MIN(3,binningIndex));
        controller.exposure = [[[self evaluatedArguments] objectForKey:@"milliseconds"] integerValue];
        controller.exposureUnits = 1;
        
        [controller captureWithBlock:^(NSError *error, CASCCDExposure *exposure) {
            
            if (error){
                [self setErrorCode:[error code] string:[error localizedDescription]];
            }
            else{
                [self resumeExecutionWithResult:exposure];
            }
        }];
    }
	return nil;
}

@end
