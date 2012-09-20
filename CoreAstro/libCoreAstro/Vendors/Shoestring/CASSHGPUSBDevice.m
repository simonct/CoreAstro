//
//  CASSHGPUSBDevice.m
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

#import "CASSHGPUSBDevice.h"
#import "CASIOTransport.h"
#import "CASIOCommand.h"
#import "CASIOHIDTransport.h"

#pragma mark Commands

@interface CASSHGPUSBIOCommand : CASIOCommand
@end

@implementation CASSHGPUSBIOCommand
@end

@interface CASSHGPUSBIOPulseMountCommand : CASSHGPUSBIOCommand
@property (nonatomic,assign) CASGuiderDirection direction;
@end

@implementation CASSHGPUSBIOPulseMountCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer = 0;
    switch (self.direction) {
        case kCASGuiderDirection_RAPlus:
            buffer |= (1 << 1);
            break;
        case kCASGuiderDirection_RAMinus:
            buffer |= (1 << 0);
            break;
        case kCASGuiderDirection_DecPlus:
            buffer |= (1 << 4);
            break;
        case kCASGuiderDirection_DecMinus:
            buffer |= (1 << 3);
            break;
        default:
            break;
    }
    return [NSData dataWithBytes:&buffer length:sizeof(buffer)];
}

@end

@interface CASSHGPUSBIOLEDCommandCommand : CASSHGPUSBIOCommand
@property (nonatomic,assign) BOOL on;
@property (nonatomic,assign) BOOL red;
@end

@implementation CASSHGPUSBIOLEDCommandCommand

- (NSData*)toDataRepresentation {
    
    uint8_t buffer = 0;

    if (self.on){
        buffer |= (1 << 5);
    }
    
    if (self.red){
        buffer |= (1 << 4);
    }

    return [NSData dataWithBytes:&buffer length:sizeof(buffer)];
}

@end

#pragma mark - Device

@interface CASSHGPUSBDevice ()<CASIOHIDTransportDelegate>
@property (nonatomic,assign) uint8_t state;
@end

@implementation CASSHGPUSBDevice {
    BOOL _connected;
}

- (CASDeviceType)type {
    return kCASDeviceTypeMount;
}

- (NSString*)deviceName {
    return @"GPUSB";
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
        self.guideDirection = kCASGuiderDirection_None;
        if (block){
            block(nil);
        }
    }
}

- (BOOL)ledOn {
    return (_state & (1 << 5)) != 0;
}

- (void)setLedOn:(BOOL)ledOn {
    
    CASSHGPUSBIOLEDCommandCommand* led = [[CASSHGPUSBIOLEDCommandCommand alloc] init];
    
    led.on = ledOn;
    
    [self.transport submit:led block:^(NSError* error){
        
        if (error){
            NSLog(@"setLedOn: %@",error);
        }
    }];
}

- (BOOL)ledRed {
    return (_state & (1 << 4)) != 0;
}

- (void)setLedRed:(BOOL)ledRed {
    
    CASSHGPUSBIOLEDCommandCommand* led = [[CASSHGPUSBIOLEDCommandCommand alloc] init];
    
    led.on = self.ledOn;
    led.red = ledRed;
    
    [self.transport submit:led block:^(NSError* error){
        
        if (error){
            NSLog(@"setLedRed: %@",error);
        }
    }];
}

- (CASGuiderDirection)guideDirection {
    if (_state & (1 << 1)){
        return kCASGuiderDirection_RAPlus;
    }
    else if (_state & (1 << 0)){
        return kCASGuiderDirection_RAMinus;
    }
    else if (_state & (1 << 4)){
        return kCASGuiderDirection_DecPlus;
    }
    else if (_state & (1 << 3)){
        return kCASGuiderDirection_DecMinus;
    }
    return kCASGuiderDirection_None;
}

- (void)setGuideDirection:(CASGuiderDirection)guideDirection {
    
    CASSHGPUSBIOPulseMountCommand* pulse = [[CASSHGPUSBIOPulseMountCommand alloc] init];
    
    pulse.direction = guideDirection;
    
    [self.transport submit:pulse block:^(NSError* error){
        
        if (error){
            NSLog(@"setGuideDirection: %@",error);
        }
    }];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"ledOn"] || [key isEqualToString:@"ledRed"] || [key isEqualToString:@"guideDirection"]){
        return [NSSet setWithObject:@"state"];
    }
    return nil;
}

#pragma mark Guider

- (void)pulse:(CASGuiderDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*,CASGuiderDirection))block {
    NSLog(@"pulse: %d duration: %ld",direction,durationMS);
}

#pragma mark HID Transport

- (void)receivedInputReport:(NSData*)data {
    
    uint8_t state;
    if ([data length] == sizeof(state)){
        [data getBytes:&state length:sizeof(state)];
        if (state != _state){
            self.state = state;
        }
    }
}

@end