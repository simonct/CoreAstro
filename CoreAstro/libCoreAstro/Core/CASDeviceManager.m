//
//  CASDeviceManager.m
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

#import "CASDeviceManager.h"
#import "CASDeviceBrowser.h"
#import "CASDeviceFactory.h"
#import "CASPluginManager.h"

@interface CASDeviceManager ()
@property (nonatomic,strong) CASPluginManager* pluginManager;
@end

@implementation CASDeviceManager {
    NSMutableArray* _devices;
}

@synthesize pluginManager;
@synthesize devices = _devices;

+ (CASDeviceManager*)sharedManager {
    static CASDeviceManager* manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[CASDeviceManager alloc] init];
    });
    return manager;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.pluginManager = [[CASPluginManager alloc] init];
    }
    return self;
}

- (NSArray*) devices {
    return [_devices copy]; // ensure we return an immutable copy to clients
}

- (id)deviceWithPath:(NSString*)path {
    __block CASDevice* result = nil;
    [self.devices enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CASDevice* device = (CASDevice*)obj;
        if ([device.path isEqualToString:path]){
            *stop = YES;
            result = device;
        }
    }];
    return result;
}

- (void)scan {
    
    for (id<CASDeviceBrowser> browser in self.pluginManager.browsers){

        @try {
            
            browser.deviceRemoved = ^(void* dev,NSString* path,NSDictionary* props) {

                CASDevice* device = [self deviceWithPath:path];
                if (device){
                    NSLog(@"Removed device %@",device);
                    [[self mutableArrayValueForKey:@"devices"] removeObject:device];
                }
                
                return (CASDevice*)nil;
            };
            
            [browser scan:^(void* dev,NSString* path,NSDictionary* props) {
                                
                CASDevice* device = nil;
                if (![self deviceWithPath:path]){
                    
                    if (!_devices){
                        _devices = [[NSMutableArray alloc] initWithCapacity:10];
                    }
                    for (id<CASDeviceFactory> factory in self.pluginManager.factories){
                        device = [factory createDeviceWithDeviceRef:dev path:path properties:props];
                        if (device){
                            
                            device.transport = [browser createTransportWithDevice:device];
                            if (!device.transport){
                                NSLog(@"No transport for %@",device);
                            }
                            else {
                                NSLog(@"Added device %@",device);
                                [[self mutableArrayValueForKey:@"devices"] addObject:device];
                            }
                            break;
                        }
                    }
                }
                return device;
            }];
        }
        @catch (NSException *exception) {
            NSLog(@"*** Exception scanning for devices: %@",exception);
        }
    }
}

@end
