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

enum {
    kCASSHGPUSBDevice_RAMinusMask = (1 << 0),
    kCASSHGPUSBDevice_RAPlusMask = (1 << 1),
    kCASSHGPUSBDevice_DecMinusMask = (1 << 2),
    kCASSHGPUSBDevice_DecPlusMask = (1 << 3),
    kCASSHGPUSBDevice_LedRedMask = (1 << 4),
    kCASSHGPUSBDevice_LedOnMask = (1 << 5),
};

#pragma mark Commands

@interface CASSHGPUSBIOCommand : CASIOCommand
@end

@implementation CASSHGPUSBIOCommand
@end

@interface CASSHGPUSBIOSetStateCommand : CASSHGPUSBIOCommand
@property (nonatomic,assign) BOOL ledOn;
@property (nonatomic,assign) BOOL ledRed;
@property (nonatomic,assign) CASGuiderDirection guideDirection;
@end

@implementation CASSHGPUSBIOSetStateCommand

- (NSData*)toDataRepresentation {
    
    uint8_t buffer = 0;
    
    // set guide state
    switch (self.guideDirection) {
        case kCASGuiderDirection_RAPlus:
            buffer |= kCASSHGPUSBDevice_RAPlusMask;
            break;
        case kCASGuiderDirection_RAMinus:
            buffer |= kCASSHGPUSBDevice_RAMinusMask;
            break;
        case kCASGuiderDirection_DecPlus:
            buffer |= kCASSHGPUSBDevice_DecPlusMask;
            break;
        case kCASGuiderDirection_DecMinus:
            buffer |= kCASSHGPUSBDevice_DecMinusMask;
            break;
        default:
            break;
    }
    
    // set led state
    if (self.ledOn){
        buffer |= kCASSHGPUSBDevice_LedOnMask;
    }
    if (self.ledRed){
        buffer |= kCASSHGPUSBDevice_LedRedMask;
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

- (CASSHGPUSBIOSetStateCommand*)createStateCommand {
    
    CASSHGPUSBIOSetStateCommand* state = [[CASSHGPUSBIOSetStateCommand alloc] init];
    
    state.ledOn = self.ledOn;
    state.ledRed = self.ledRed;
    state.guideDirection = self.guideDirection;
    
    return state;
}

- (BOOL)ledOn {
    return (_state & kCASSHGPUSBDevice_LedOnMask) != 0;
}

- (void)setLedOn:(BOOL)ledOn {
    
    CASSHGPUSBIOSetStateCommand* state = [self createStateCommand];
    
    state.ledOn = ledOn;

    [self.transport submit:state block:^(NSError* error){
        
        if (error){
            NSLog(@"setLedOn: %@",error);
        }
    }];
}

- (BOOL)ledRed {
    return (_state & kCASSHGPUSBDevice_LedRedMask) != 0;
}

- (void)setLedRed:(BOOL)ledRed {
    
    CASSHGPUSBIOSetStateCommand* state = [self createStateCommand];
    
    state.ledRed = ledRed;
    
    [self.transport submit:state block:^(NSError* error){
        
        if (error){
            NSLog(@"setLedRed: %@",error);
        }
    }];
}

- (CASGuiderDirection)guideDirection {
    if (_state & kCASSHGPUSBDevice_RAPlusMask){
        return kCASGuiderDirection_RAPlus;
    }
    else if (_state & kCASSHGPUSBDevice_RAMinusMask){
        return kCASGuiderDirection_RAMinus;
    }
    else if (_state & kCASSHGPUSBDevice_DecPlusMask){
        return kCASGuiderDirection_DecPlus;
    }
    else if (_state & kCASSHGPUSBDevice_DecMinusMask){
        return kCASGuiderDirection_DecMinus;
    }
    return kCASGuiderDirection_None;
}

- (void)setGuideDirection:(CASGuiderDirection)guideDirection {
        
    CASSHGPUSBIOSetStateCommand* state = [self createStateCommand];
    
    state.guideDirection = guideDirection;
    
    [self.transport submit:state block:^(NSError* error){
        
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

- (void)pulse:(CASGuiderDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block {
    
//    NSLog(@"pulse: %d duration: %ld",direction,durationMS);

    self.guideDirection = direction;
    
    if (direction != kCASGuiderDirection_None){
        
        const double delayInSeconds = durationMS/1000.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            
            // check still connected ?
            self.guideDirection = kCASGuiderDirection_None;
        });
    }
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