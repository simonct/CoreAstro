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

@interface CASBlockAnimation : NSAnimation
@property (nonatomic,copy) void (^block)(NSAnimationProgress progress);
@end

@implementation CASBlockAnimation

- (void)setCurrentProgress:(NSAnimationProgress)progress
{
    if (self.block){
        self.block(progress);
    }
}

@end

@interface CASJogControl : NSSlider
- (void)setStandardActionMask;
- (void)animateToFloatValue:(float)value;
@end

@implementation CASJogControl

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setStandardActionMask];
}

- (void)setStandardActionMask
{
    [self sendActionOn:NSLeftMouseUpMask|NSLeftMouseDownMask|NSPeriodicMask];
}

- (void)animateToFloatValue:(float)value
{
    [self sendActionOn:0];
    
    const float start = self.floatValue;
    CASBlockAnimation* anim = [[CASBlockAnimation alloc] initWithDuration:0.2 animationCurve:NSAnimationEaseInOut];
    [anim setAnimationBlockingMode:NSAnimationNonblocking];
    anim.block = ^(NSAnimationProgress progress){
        self.floatValue = start - start*progress;
        if (self.floatValue == 0){
            [self setStandardActionMask];
        }
    };
    [anim startAnimation];
}

@end

@interface CASAppDelegate ()
@property (nonatomic,strong) CASHIDDeviceBrowser* browser;
@property (nonatomic,strong) CASSHDeviceFactory* factory;
@property (nonatomic,strong) CASSHFCUSBDevice* fcusb;
@property (nonatomic,assign) NSInteger pulseDuration;
@property (unsafe_unretained) IBOutlet NSPanel *controlPanel;
@property (weak) IBOutlet CASJogControl *jogControl;
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
                    [self.controlPanel makeKeyAndOrderFront:nil];
                }
            }];
            //            NSLog(@"%@: %@ %@ %@",self.gpusb,dev,path,props);
        }
        
        return NO;
    }];
}

- (void)pulseInDirection:(CASFocuserDirection)direction forDuration:(NSInteger)duration {
    
    if (duration > 0) {
        
        [self.fcusb pulse:direction duration:duration block:^(NSError *error) {
            
            if (error){
                NSLog(@"pulseInDirection:forDuration: %@",error);
            }
        }];
    }
}

- (IBAction)pulseForward:(id)sender {
    
    [self pulseInDirection:CASFocuserForward forDuration:self.pulseDuration];
}

- (IBAction)pulseReverse:(id)sender {
    
    [self pulseInDirection:CASFocuserReverse forDuration:self.pulseDuration];
}

- (IBAction)reverse:(NSButton*)sender {

    self.fcusb.motorSpeed = 0.5;
    [self pulseInDirection:CASFocuserReverse forDuration:200];
}

- (IBAction)forward:(NSButton*)sender {

    self.fcusb.motorSpeed = 0.5;
    [self pulseInDirection:CASFocuserForward forDuration:200];
}

- (IBAction)jog:(CASJogControl*)sender {
    
//    NSLog(@"jog: %f, %ld",sender.floatValue,[[NSApplication sharedApplication] currentEvent].type);
    
    if ([[NSApplication sharedApplication] currentEvent].type == NSLeftMouseUp){
        [self.jogControl animateToFloatValue:0];
        return;
    }

    if (self.fcusb.pulsing){ // todo; get from focusser
//        NSLog(@"already pulsing, doing nothing");
        return;
    }
    
    const NSInteger duration = 200; // todo; relate to the control's continuous interval ?
    self.fcusb.motorSpeed = fabs(sender.floatValue);

    if (sender.floatValue < 0){
        
        [self pulseInDirection:CASFocuserReverse forDuration:duration];
    }
    else if (sender.floatValue > 0) {
        
        [self pulseInDirection:CASFocuserForward forDuration:duration];
    }
}

@end
