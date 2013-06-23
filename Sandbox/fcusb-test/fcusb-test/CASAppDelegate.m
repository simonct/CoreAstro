//
//  MKOAppDelegate.m
//  gpusb-test
//
//  Created by Simon Taylor on 9/18/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASAppDelegate.h"
#import "CASHIDDeviceBrowser.h"
#import "CASSHDeviceFactory.h"
#import "CASSHFCUSBDevice.h"

@interface CASAppDelegate ()
@property (nonatomic,strong) CASHIDDeviceBrowser* browser;
@property (nonatomic,strong) CASSHDeviceFactory* factory;
@property (nonatomic,strong) CASSHFCUSBDevice* fcusb;
@property (nonatomic,assign) NSInteger pulseDuration;
@end

@implementation CASAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.browser = [[CASHIDDeviceBrowser alloc] init];
    self.factory = [[CASSHDeviceFactory alloc] init];
    
    [self.browser scan:^CASDevice *(void *dev, NSString *path, NSDictionary *props) {
        
        CASDevice* fc =[self.factory createDeviceWithDeviceRef:dev path:path properties:props];
        if ([fc isKindOfClass:[CASSHFCUSBDevice class]]){
            self.fcusb = (CASSHFCUSBDevice*)fc;
            self.fcusb.transport = [self.browser createTransportWithDevice:self.fcusb];
            [self.fcusb connect:^(NSError* error) {
                if (error){
                    NSLog(@"connect: %@",error);
                }
                else {
                    NSLog(@"connected");
                }
            }];
            //            NSLog(@"%@: %@ %@ %@",self.gpusb,dev,path,props);
        }
        
        return NO;
    }];
}

- (IBAction)pulseForward:(id)sender {
    
    if (self.pulseDuration > 0){
        
        [self.fcusb pulse:CASFocuserForward duration:self.pulseDuration block:^(NSError *error) {
            if (error){
                NSLog(@"pulseForward: %@",error);
            }
        }];
    }
}

- (IBAction)pulseReverse:(id)sender {
    
    if (self.pulseDuration > 0){
        
        [self.fcusb pulse:CASFocuserReverse duration:self.pulseDuration block:^(NSError *error) {
            if (error){
                NSLog(@"pulseReverse: %@",error);
            }
        }];
    }
}

@end
