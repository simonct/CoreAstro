//
//  SXIOMountControlsViewController.m
//  CoreAstro
//
//  Created by Simon Taylor on 17/02/17.
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

#import "SXIOMountControlsViewController.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOMountControlsNameTransformer : NSValueTransformer
@end

@implementation SXIOMountControlsNameTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    CASMountController* controller = value;
    if ([controller isKindOfClass:[CASMountController class]]){
        return controller.mount.deviceName;
    }
    return nil;
}

@end

@interface SXIOMountControlsViewController ()
@end

@implementation SXIOMountControlsViewController {
}

+ (void)initialize
{
    if (self == [SXIOMountControlsViewController class]){
        [NSValueTransformer setValueTransformer:[[SXIOMountControlsNameTransformer alloc] init] forName:@"SXIOMountControlsNameTransformer"];
    }
}

- (CASDeviceManager*)deviceManager
{
    return [CASDeviceManager sharedManager];
}

- (NSArray<CASMountController*>*)mountControllers
{
    // todo; need a None item
    return self.deviceManager.mountControllers;
}

+ (NSSet*)keyPathsForValuesAffectingMountControllers
{
    return [NSSet setWithObject:@"deviceManager.mountControllers"];
}

- (CASMountController*)mountController
{
    return self.mountControllerHost.mountController;
}

- (void)setMountController:(CASMountController *)mountController
{
    self.mountControllerHost.mountController = mountController;
}

+ (NSSet*)keyPathsForValuesAffectingMountController
{
    return [NSSet setWithObjects:@"mountControllerHost",@"mountControllerHost.mountController",@"mountControllers",nil];
}

@end
