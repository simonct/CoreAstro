//
//  CASGuideCommand.m
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

#import "CASGuideCommand.h"
#import <CoreAstro/CoreAstro.h>

@interface CASGuideCommand ()
@end

@implementation CASGuideCommand

- (id)performDefaultImplementationImpl
{
    CASGuiderController* controller = (CASGuiderController*)[self evaluatedReceivers];
    if ([controller isKindOfClass:[CASGuiderController class]]){
                                        
        const NSInteger duration = [[[self evaluatedArguments] objectForKey:@"duration"] integerValue];
        const OSType directionCode = (OSType)[[[self evaluatedArguments] objectForKey:@"direction"] integerValue];

        CASGuiderDirection direction = kCASGuiderDirection_None;
        switch (directionCode) {
            case 'RAP ':
                direction = kCASGuiderDirection_RAPlus;
                break;
            case 'RAM ':
                direction = kCASGuiderDirection_RAMinus;
                break;
            case 'DecP':
                direction = kCASGuiderDirection_DecPlus;
                break;
            case 'DecM':
                direction = kCASGuiderDirection_DecMinus;
                break;
            default:
                NSLog(@"*** Unrecognised guide direction code: %x",directionCode);
                break;
        }
        
        [controller pulse:direction duration:duration block:^(NSError *error) {
            
            if (error){
                [self setErrorCode:[error code] string:[error localizedDescription]];
            }
        }];
    }
	return nil;
}

@end
