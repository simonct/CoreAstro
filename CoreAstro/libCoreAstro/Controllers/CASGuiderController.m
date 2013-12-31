//
//  CASGuideController.m
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

#import "CASGuiderController.h"
#import "CASAutoGuider.h"

@interface CASGuiderController ()
@property (nonatomic,strong) CASDevice<CASGuider>* guider;
@end

@implementation CASGuiderController

- (id)initWithGuider:(CASDevice<CASGuider>*)guider
{
    self = [super init];
    if (self){
        self.guider = guider;
    }
    return self;
}

- (CASDevice*) device
{
    return self.guider;
}

- (void)connect:(void(^)(NSError*))block
{
    if (block){
        block(nil);
    }
}

- (void)disconnect
{
    self.guider = nil;
}

- (void)pulse:(CASGuiderDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block
{
    [self.guider pulse:direction duration:durationMS block:block];
}

@end

@implementation CASGuiderController (CASScripting)

- (NSString*)containerAccessor
{
	return @"guiderControllers";
}

- (void)scriptingGuide:(NSScriptCommand*)command
{
    [command performDefaultImplementation];
}

@end
