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

#pragma mark Commands

@interface CASSHGPUSBIOCommand : CASIOCommand
@end

@implementation CASSHGPUSBIOCommand

- (NSInteger) readSize {
    return 1;
}

@end

@interface CASSHGPUSBIOPulseMountCommand : CASSHGPUSBIOCommand
@property (nonatomic,assign) CASSHGPUSBDeviceDirection direction;
@end

@implementation CASSHGPUSBIOPulseMountCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer = 0;
    switch (self.direction) {
        case kCASSHGPUSB_RAPlus:
            buffer |= (1 << 1);
            break;
        case kCASSHGPUSB_RAMinus:
            buffer |= (1 << 0);
            break;
        case kCASSHGPUSB_DecPlus:
            buffer |= (1 << 4);
            break;
        case kCASSHGPUSB_DecMinus:
            buffer |= (1 << 3);
            break;
        default:
            break;
    }
    return [NSData dataWithBytes:&buffer length:sizeof(buffer)];
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    uint8_t buffer = 0;
    if ([data length] == sizeof(buffer)){
        [data getBytes:&buffer length:sizeof(buffer)];
        if (buffer & (1 << 1)){
            self.direction = kCASSHGPUSB_RAPlus;
        }
        else if (buffer & (1 << 0)){
            self.direction = kCASSHGPUSB_RAMinus;
        }
        else if (buffer & (1 << 4)){
            self.direction = kCASSHGPUSB_DecPlus;
        }
        else if (buffer & (1 << 3)){
            self.direction = kCASSHGPUSB_DecMinus;
        }
    }
    return nil;
}

@end

#pragma mark - Device

@interface CASSHGPUSBDevice ()
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
        [self pulse:kCASSHGPUSB_None block:^(NSError *error, CASSHGPUSBDeviceDirection direction) {
            if (error){
                _connected = NO;
            }
            if (block){
                block(error);
            }
        }];
    }
}

#pragma mark - Commands

- (void)pulse:(CASSHGPUSBDeviceDirection)direction block:(void (^)(NSError*,CASSHGPUSBDeviceDirection))block {
    
    CASSHGPUSBIOPulseMountCommand* pulse = [[CASSHGPUSBIOPulseMountCommand alloc] init];
    
    pulse.direction = direction;
    
    [self.transport submit:pulse block:^(NSError* error){
        
        if (block){
            block(error,pulse.direction);
        }
    }];
}

@end