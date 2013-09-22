//
//  CASFilterWheelController.m
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
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

#import "CASFilterWheelController.h"
#import "CASClassDefaults.h"

@interface CASFilterWheelController ()
@property (nonatomic,strong) CASDevice<CASFWDevice>* filterWheel;
@end

@implementation CASFilterWheelController

- (id)initWithFilterWheel:(CASDevice<CASFWDevice>*)filterWheel
{
    self = [super init];
    if (self){
        self.filterWheel = filterWheel;
        [self registerDeviceDefaults];
    }
    return self;
}

- (void)dealloc
{
    [self unregisterDeviceDefaults];
}

- (void)connect:(void(^)(NSError*))block
{
    if (block){
        block(nil);
    }
}

- (void)disconnect
{
    self.filterWheel = nil;
}

- (BOOL) moving
{
    return self.filterWheel.moving;
}

- (NSUInteger) filterCount
{
    return self.filterWheel.filterCount;
}

+ (NSSet*)keyPathsForValuesAffectingFilterCount
{
    return [NSSet setWithObject:@"filterWheel.filterCount"];
}

- (NSInteger) currentFilter
{
    if (!self.filterWheel){
        return NSNotFound;
    }
    return self.filterWheel.currentFilter;
}

+ (NSSet*)keyPathsForValuesAffectingCurrentFilter
{
    return [NSSet setWithObject:@"filterWheel.currentFilter"];
}

- (void)setCurrentFilter:(NSInteger)currentFilter
{
    NSLog(@"setCurrentFilter: %ld",currentFilter);
    self.filterWheel.currentFilter = currentFilter;
}

- (NSArray*)deviceDefaultsKeys
{
    return @[@"filterNames"];
}

- (void)registerDeviceDefaults
{
    NSString* deviceName = self.filterWheel.deviceName;
    if (deviceName){
        [[CASDeviceDefaults defaultsForClassname:deviceName] registerKeys:self.deviceDefaultsKeys ofInstance:self];
    }
}

- (void)unregisterDeviceDefaults
{
    NSString* deviceName = self.filterWheel.deviceName;
    if (deviceName){
        [[CASDeviceDefaults defaultsForClassname:deviceName] unregisterKeys:self.deviceDefaultsKeys ofInstance:self];
    }
}

@end

@implementation CASFilterWheelController (CASScripting)

- (NSString*)containerAccessor
{
	return @"filterWheelControllers";
}

- (id)scriptingDeviceName
{
    return self.filterWheel.deviceName;
}

- (id)scriptingVendorName
{
    return self.filterWheel.vendorName;
}

- (NSNumber*)scriptingFilterCount
{
    return @(self.filterWheel.filterCount);
}

- (NSNumber*)scriptingCurrentFilter
{
    return @(self.filterWheel.currentFilter);
}

- (void)setScriptingCurrentFilter:(NSNumber*)currentFilter
{
    self.filterWheel.currentFilter = [currentFilter integerValue];
}

@end
