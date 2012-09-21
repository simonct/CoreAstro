//
//  MKOAppDelegate.m
//  gpusb-test
//
//  Created by Simon Taylor on 9/18/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "MKOAppDelegate.h"
#import "CASHIDDeviceBrowser.h"
#import "CASSHDeviceFactory.h"
#import "CASSHGPUSBDevice.h"

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASHIDDeviceBrowser* browser;
@property (nonatomic,strong) CASSHDeviceFactory* factory;
@property (nonatomic,strong) CASSHGPUSBDevice* gpusb;
@property (nonatomic,assign) CASGuiderDirection pulseDirection;
@property (nonatomic,copy) NSString* pulseDuration;
@end

@implementation MKOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.browser = [[CASHIDDeviceBrowser alloc] init];
    self.factory = [[CASSHDeviceFactory alloc] init];

    [self.browser scan:^CASDevice *(void *dev, NSString *path, NSDictionary *props) {
        
        CASDevice* gp =[self.factory createDeviceWithDeviceRef:dev path:path properties:props];
        if ([gp isKindOfClass:[CASSHGPUSBDevice class]]){
            self.gpusb = (CASSHGPUSBDevice*)gp;
            self.gpusb.transport = [self.browser createTransportWithDevice:self.gpusb];
            [self.gpusb connect:^(NSError* error) {
                if (error){
                    NSLog(@"connect: %@",error);
                }
            }];
//            NSLog(@"%@: %@ %@ %@",self.gpusb,dev,path,props);
        }
        
        return NO;
    }];
}

- (IBAction)pulse:(id)sender {
    
    const NSInteger pulseDuration = [self.pulseDuration integerValue];
    
    NSLog(@"pulse: %d duration: %ld",self.pulseDirection,pulseDuration);
    
    if (pulseDuration > 0){
        
        [self.gpusb pulse:self.pulseDirection duration:pulseDuration block:^(NSError *error) {
            if (error){
                NSLog(@"pulse: %@",error);
            }
        }];
    }
}

@end
