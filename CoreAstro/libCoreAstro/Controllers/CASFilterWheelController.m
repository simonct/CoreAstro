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

- (CASDevice*) device
{
    return self.filterWheel;
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
    self.filterWheel.currentFilter = currentFilter;
}

- (NSString*) currentFilterName
{
    return [self.filterNames[[@(self.currentFilter) description]] copy];
}

+ (NSSet*)keyPathsForValuesAffectingCurrentFilterName
{
    return [NSSet setWithObject:@"currentFilter"];
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

+ (NSString*)sanitizeFilterName:(NSString*)string
{
    NSData* ascii = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString* asciiString = [[NSString alloc] initWithData:ascii encoding:NSASCIIStringEncoding];
    return asciiString;
}

@end

@implementation CASFilterWheelController (CASScripting)

- (NSString*)containerAccessor
{
	return @"filterWheelControllers";
}

- (NSNumber*)scriptingFilterCount
{
    return @(self.filterWheel.filterCount);
}

- (NSNumber*)scriptingCurrentFilter
{
    return @(self.filterWheel.currentFilter + 1);
}

- (void)setScriptingCurrentFilter:(NSNumber*)currentFilter
{
    NSInteger index = [currentFilter integerValue] - 1;
    if (index < 0) {index = 0;}
    if (index >= self.filterWheel.filterCount) {index = self.filterWheel.filterCount-1;}
    self.filterWheel.currentFilter = index;
}

- (NSArray*)scriptingFilterNames
{
    NSDictionary* filterNames = self.filterNames;
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:[filterNames count]];
    NSArray* sortedKeys = [[filterNames allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (id key in sortedKeys){
        [result addObject:filterNames[key]];
    }
    return result;
}

- (NSString*)scriptingCurrentFilterName
{
    return self.currentFilterName;
}

- (void)setScriptingCurrentFilterName:(NSString*)name
{
    NSArray* indexes = [self.filterNames allKeysForObject:name];
    if ([indexes count]){
        self.filterWheel.currentFilter = [indexes[0] integerValue];
    }
    else {
        NSLog(@"*** Unknown filter name: %@",name);
    }
}

- (BOOL)scriptingIsMoving
{
    return self.filterWheel.moving;
}

@end
