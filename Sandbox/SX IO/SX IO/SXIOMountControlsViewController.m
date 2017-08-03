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

@interface CASNilableArrayController : NSArrayController

@end

@implementation CASNilableArrayController

- (void)setNilValueForKey:(NSString *)key
{
    if ([key isEqualToString:@"selectionIndex"]){
        self.selectionIndex = NSNotFound;
    }
    else {
        [super setNilValueForKey:key];
    }
}

- (id)selectedObject
{
    return self.selectedObjects.firstObject;
}

- (void)setSelectedObject:(id)object
{
    if (object){
        self.selectedObjects = @[object];
    }
    else {
        self.selectedObjects = @[];
    }
}

+ (NSSet*)keyPathsForValuesAffectingSelectedObject
{
    return [NSSet setWithObject:@"selectedObjects"];
}

@end

@interface SXIOMountControlsNameTransformer : NSValueTransformer
@end

@implementation SXIOMountControlsNameTransformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    if ([value isKindOfClass:[NSArray class]]) {
        NSArray* array = (NSArray*)value;
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:array.count];
        for (id object in array){
            id transformed = [self transformedValue:object];
            if (transformed){
                [result addObject:transformed];
            }
        }
        return result;
    }

    CASMountController* controller = value;
    if ([controller isKindOfClass:[CASMountController class]]){
        return controller.mount.deviceName;
    }
    
    return nil;
}

@end

@interface SXIOMountControlsViewController ()
@property (strong) IBOutlet CASNilableArrayController *mountsArrayController;
@end

@implementation SXIOMountControlsViewController {
}

+ (void)initialize
{
    if (self == [SXIOMountControlsViewController class]){
        [NSValueTransformer setValueTransformer:[[SXIOMountControlsNameTransformer alloc] init] forName:@"SXIOMountControlsNameTransformer"];
    }
}

- (void)dealloc
{
    self.mountControllerHost = nil;
}

- (void)setMountControllerHost:(id<SXIOMountControllerHost>)mountControllerHost
{
    if (_mountControllerHost != mountControllerHost){
        [self.mountsArrayController unbind:@"selectedObject"];
        _mountControllerHost = mountControllerHost;
        if (_mountControllerHost){
            [self.mountsArrayController bind:@"selectedObject" toObject:_mountControllerHost withKeyPath:@"mountController" options:nil];
        }
    }
}

- (CASDeviceManager*)deviceManager
{
    return [CASDeviceManager sharedManager];
}

- (NSArray<CASMountController*>*)mountControllers
{
    return self.deviceManager.mountControllers;
}

+ (NSSet*)keyPathsForValuesAffectingMountControllers
{
    return [NSSet setWithObject:@"deviceManager.mountControllers"];
}

@end
