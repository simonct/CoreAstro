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
#import "CASGuiderController.h"
#import "CASCameraController.h"
#import "CASCCDDevice.h"

@interface CASDeviceManager ()
@property (nonatomic,strong) CASPluginManager* pluginManager;
@end

@implementation CASDeviceManager {
    NSMutableArray* _devices;
    NSMutableArray* _cameraControllers;
    NSMutableArray* _guiderControllers;
}

@synthesize pluginManager;
@synthesize devices = _devices;
@synthesize cameraControllers = _cameraControllers;
@synthesize guiderControllers = _guiderControllers;

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
        _cameraControllers = [NSMutableArray arrayWithCapacity:10];
        _guiderControllers = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (NSArray*) devices {
    return [_devices copy]; // ensure we return an immutable copy to clients
}

- (NSArray*) cameraControllers {
    return [_cameraControllers copy]; // ensure we return an immutable copy to clients
}

- (NSArray*) guiderControllers {
    return [_guiderControllers copy]; // ensure we return an immutable copy to clients
}

- (id)deviceWithPath:(NSString*)path {
    for (CASDevice* device in self.devices){
        if ([device.path isEqualToString:path]){
            return device;
        }
    }
    return nil;
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
                        [self addObserver:self forKeyPath:@"devices" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionOld context:nil];
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

- (CASGuiderController*)guiderControllerForDevice:(CASDevice*)device
{
    for (CASGuiderController* guiderController in self.guiderControllers){
        if (guiderController.guider == device){
            return guiderController;
        }
    }
    return nil;
}

- (CASCameraController*)cameraControllerForDevice:(CASDevice*)device
{
    for (CASCameraController* cameraController in self.cameraControllers){
        if (cameraController.camera == device){
            return cameraController;
        }
    }
    return nil;
}

- (NSMutableArray*)mutableCameraControllers
{
    return [self mutableArrayValueForKey:@"cameraControllers"];
}

- (NSMutableArray*)mutableGuiderControllers
{
    return [self mutableArrayValueForKey:@"guiderControllers"];
}

- (void)recogniseGuider:(CASDevice*)device
{
    id<CASGuider> guider = (id<CASGuider>)device;
    if ([guider conformsToProtocol:@protocol(CASGuider)]){
        if (![self guiderControllerForDevice:guider]){
            [self.mutableGuiderControllers addObject:[[CASGuiderController alloc] initWithGuider:guider]];
        }
    }
}

- (void)recogniseCamera:(CASDevice*)device
{
    CASCCDDevice* ccd = (CASCCDDevice*)device;
    if ([ccd isKindOfClass:[CASCCDDevice class]]){ // todo; need a CASCCDDevice protocol and check for that instead of a class
        
        // todo; defer this until the device is actually clicked on in the master selection view
        [ccd connect:^(NSError* error) {
            
            if (error){
                [NSApp presentError:error]; // todo: specific error message
            }
            else {
                
                CASCameraController* cameraController = [[CASCameraController alloc] initWithCamera:ccd];
                if (cameraController){
                    cameraController.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
                    cameraController.guideAlgorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
                    [self.mutableCameraControllers addObject:cameraController];
                }
            }
            
            // re-check to see if it's now capable of being a guider
            [self recogniseGuider:device];
        }];
    }
}

// todo; most of this should probably be in the device manager
- (void)processDevices:(NSArray*)devices
{
    for (CASDevice* device in devices){
        [self recogniseCamera:device];
        [self recogniseGuider:device];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == nil) {
        
        switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                
            case NSKeyValueChangeSetting:
            case NSKeyValueChangeInsertion: {
                NSArray* devices = nil;
                NSIndexSet* indexes = [change objectForKey:NSKeyValueChangeIndexesKey];
                if (indexes){
                    devices = [[CASDeviceManager sharedManager].devices objectsAtIndexes:indexes];
                }
                else {
                    devices = [CASDeviceManager sharedManager].devices;
                }
                [self processDevices:devices];
            }
                break;
                
            case NSKeyValueChangeRemoval: {
                NSArray* old = [change objectForKey:NSKeyValueChangeOldKey];
                if (old){
                    
                    if (![old isKindOfClass:[NSArray class]]){
                        old = [NSArray arrayWithObject:old];
                    }
                    for (CASDevice* device in old){
                        
                        CASCameraController* cameraController = [self cameraControllerForDevice:device];
                        if (cameraController){
                            [self.mutableCameraControllers removeObject:cameraController];
                        }
                        CASGuiderController* guiderController = [self guiderControllerForDevice:device];
                        if (guiderController){
                            [self.mutableGuiderControllers removeObject:guiderController];
                        }
                    }
                }
            }
                break;
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
