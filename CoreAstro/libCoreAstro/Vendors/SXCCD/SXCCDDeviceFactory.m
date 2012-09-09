//
//  SXCCDDeviceFactory.m
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

#import "SXCCDDeviceFactory.h"
#import "SXCCDDevice.h"

@interface SXCCDDeviceFactory ()
@end

@implementation SXCCDDeviceFactory

static NSDictionary* _deviceLookup = nil;

+ (SInt32)vendorID {
    return 0x1278;
}

+ (NSDictionary*)deviceLookup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _deviceLookup = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"SXDevices" ofType:@"plist"]];
        NSAssert(_deviceLookup, @"SXCCDDeviceFactory: no lookup table !");
    });
    return _deviceLookup;
}

- (BOOL)supportedProductID:(NSNumber*)productID {
    return ([[[self class] deviceLookup] objectForKey:[productID stringValue]] != nil);
}

- (CASDevice*)createDeviceWithDeviceRef:(void*)dev path:(NSString*)path properties:(NSDictionary*)properties {
    
    SXCCDDevice* result = nil;
    
    NSNumber* vendorID = [properties objectForKey:@"idVendor"];
    if ([vendorID isEqualToNumber:[NSNumber numberWithInteger:[[self class] vendorID]]]){
    
        NSNumber* productID = [properties objectForKey:@"idProduct"];
        if (![self supportedProductID:productID]){
            NSLog(@"Unsuported SX pid: %@",productID);            
        }
        else{
            
            result = [[SXCCDDevice alloc] init]; // subclass depending on exact type ?
            result.device = dev;
            result.path = path;
            result.properties = properties;
            result.productID = [productID integerValue];
        }
    }
    
    return result;
}

@end
