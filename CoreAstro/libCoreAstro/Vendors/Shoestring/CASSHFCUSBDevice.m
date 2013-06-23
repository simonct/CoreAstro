//
//  CASSHFCUSBDevice.m
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

#import "CASSHFCUSBDevice.h"
#import "CASIOTransport.h"
#import "CASIOCommand.h"
#import "CASIOHIDTransport.h"

enum {
    kCASSHFCUSBDevice_Motor1Mask = (1 << 0),
    kCASSHFCUSBDevice_Motor2Mask = (1 << 1),
    kCASSHFCUSBDevice_LedRedMask = (1 << 4),
    kCASSHFCUSBDevice_LedOnMask = (1 << 5),
    kCASSHFCUSBDevice_PMW1Mask = (1 << 6),
    kCASSHFCUSBDevice_PMW2Mask = (1 << 7)
};

#pragma mark Commands

@interface CASSHFCUSBIOCommand : CASIOCommand
@end

@implementation CASSHFCUSBIOCommand
@end

@interface CASSHFCUSBIOSetStateCommand : CASSHFCUSBIOCommand
@property (nonatomic,assign) uint16_t state;
@end

@implementation CASSHFCUSBIOSetStateCommand

- (NSData*)toDataRepresentation {
    return [NSData dataWithBytes:&_state length:sizeof(_state)];
}

@end

#pragma mark - Device

@interface CASSHFCUSBDevice ()<CASIOHIDTransportDelegate>
@property (nonatomic,assign) uint16_t state;
@end

@implementation CASSHFCUSBDevice {
    NSUInteger _pid;
    BOOL _connected;
}

@synthesize motorSpeed = _motorSpeed;

- (id)initWithPID:(NSUInteger)pid {
    self = [super init];
    _pid = pid;
    return self;
}

- (CASDeviceType)type {
    return kCASDeviceTypeFocusser;
}

- (NSString*)deviceName {
    switch (_pid) {
        case 0x9023:
            return @"FCUSB";
            break;
        case 0x9024:
            return @"FCUSB(2)";
    }
    return [NSString stringWithFormat:@"FCUSB(%lx)",(unsigned long)_pid];
}

- (NSString*)vendorName {
    return @"Shoestring Astronomy";
}

- (void)connect:(void (^)(NSError*))block {
    
    if (_connected){
        if (block){
            block(nil);
        }
    }
    else {
        _connected = YES;
        self.ledOn = YES;
        self.ledRed = NO;
        if (block){
            block(nil);
        }
    }
}

- (CASSHFCUSBIOSetStateCommand*)createStateCommand {
    
    CASSHFCUSBIOSetStateCommand* state = [[CASSHFCUSBIOSetStateCommand alloc] init];
    
    state.state = self.state;
    
    return state;
}

- (BOOL)ledOn {
    return (_state & kCASSHFCUSBDevice_LedOnMask) != 0;
}

- (void)setLedOn:(BOOL)ledOn {
    
    if (ledOn){
        _state |= kCASSHFCUSBDevice_LedOnMask;
    }
    else {
        _state &= ~kCASSHFCUSBDevice_LedOnMask;
    }

    [self.transport submit:[self createStateCommand] block:^(NSError* error){
        
        if (error){
            NSLog(@"setLedOn: %@",error);
        }
    }];
}

- (BOOL)ledRed {
    return (_state & kCASSHFCUSBDevice_LedRedMask) != 0;
}

- (void)setLedRed:(BOOL)ledRed {
    
    if (ledRed){
        _state |= kCASSHFCUSBDevice_LedRedMask;
    }
    else {
        _state &= ~kCASSHFCUSBDevice_LedRedMask;
    }
    
    [self.transport submit:[self createStateCommand] block:^(NSError* error){
        
        if (error){
            NSLog(@"setLedRed: %@",error);
        }
    }];
}

- (CASFocuserPMWFreq)pmwFreq
{
    if (_state & kCASSHFCUSBDevice_PMW2Mask){
        return CASFocuserPMWFreq16x;
    }

    if (_state & kCASSHFCUSBDevice_PMW1Mask){
        return CASFocuserPMWFreq4x;
    }

    return CASFocuserPMWFreq1x;
}

- (void)setPmwFreq:(CASFocuserPMWFreq)pmwFreq
{
    switch (pmwFreq) {
        case CASFocuserPMWFreq1x:{
            _state &= ~kCASSHFCUSBDevice_PMW1Mask;
            _state &= ~kCASSHFCUSBDevice_PMW2Mask;
        }
            break;
        case CASFocuserPMWFreq4x:{
            _state |= kCASSHFCUSBDevice_PMW1Mask;
            _state &= ~kCASSHFCUSBDevice_PMW2Mask;
        }
            break;
        case CASFocuserPMWFreq16x:{
            _state |= kCASSHFCUSBDevice_PMW1Mask;
            _state |= kCASSHFCUSBDevice_PMW2Mask;
        }
            break;
        default:
            NSLog(@"Unknown PMW Freq: %ld",pmwFreq);
            return;
    }
    
    [self.transport submit:[self createStateCommand] block:^(NSError* error){
        
        if (error){
            NSLog(@"setPmwFreq: %@",error);
        }
    }];
}

- (void)setMotorSpeed:(CGFloat)motorSpeed
{
    if (motorSpeed < 0){
        motorSpeed = 0;
    }
    if (motorSpeed > 1){
        motorSpeed = 1;
    }
    _motorSpeed = motorSpeed;
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"ledOn"] || [key isEqualToString:@"ledRed"] || [key isEqualToString:@"pmwFreq"] || [key isEqualToString:@"motorSpeed"]){
        return [NSSet setWithObject:@"state"];
    }
    return nil;
}

- (void)pulse:(CASFocuserDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block
{
//    NSLog(@"pulse: %d duration: %ld",direction,durationMS);
    
    // set motor direction
    switch (direction) {
        case CASFocuserForward:
            _state |= kCASSHFCUSBDevice_Motor2Mask;
            break;
        case CASFocuserReverse:
            _state |= kCASSHFCUSBDevice_Motor1Mask;
            _state &= ~kCASSHFCUSBDevice_Motor2Mask;
            break;
        default:
            if (block){
                block(nil); // error
            }
            return;
    }

    // set motor speed
    const uint16_t speed = self.motorSpeed * 255;
    _state = (speed << 8) | (_state & 0x00ff);
    
    NSLog(@"%x",_state);

    [self.transport submit:[self createStateCommand] block:^(NSError* error){
        
        if (error){
            NSLog(@"pulse 1: %@",error);
        }
        else {

            const double delayInSeconds = durationMS/1000.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                
                // check still connected ?
                _state &= ~kCASSHFCUSBDevice_Motor1Mask;
                _state &= ~kCASSHFCUSBDevice_Motor2Mask;
                
                [self.transport submit:[self createStateCommand] block:^(NSError* error){
                    
                    if (error){
                        NSLog(@"pulse 2: %@",error);
                    }
                }];
            });
        }
    }];
}

#pragma mark HID Transport

- (void)receivedInputReport:(NSData*)data {
    
//    NSLog(@"receivedInputReport: %@",data);
    
    uint16_t state;
    if ([data length] == sizeof(state)){
        [data getBytes:&state length:sizeof(state)];
        if (state != _state){
            self.state = state;
        }
    }
}

@end