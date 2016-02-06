//
//  CASDevice.m
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

#import "CASDevice.h"
#import "CASIOCommand.h"

@interface CASDevice ()
@end

@implementation CASDevice

@synthesize device, notification, path, properties, transport;

+ (void)initialize {
    srandomdev();
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@ (%@@%@)",[super description],self.deviceName,self.deviceLocation];
}

- (CASDeviceType)type {
    return kCASDeviceTypeNone;   
}

- (NSString*)deviceName {
    return nil;   
}

- (NSImage*)deviceImage {
    return nil; // some kind of placeholder image
}

- (NSString*)deviceLocation {
    NSString* result = nil;
    if (self.transport){
        result = self.transport.location;
    }
    if (result){
        return  result;
    }
    switch (self.transport.type) {
        case kCASTransportTypeUSB:
            return @"USB";
        case kCASTransportTypeFirewire:
            return @"Firewire";
        case kCASTransportTypeEthernet:
            return @"Ethernet";
        case kCASTransportTypeHID:
            return @"HID";
        case kCASTransportTypeSerial:
            return @"Serial";
        default:
            break;
    }
    return @"Unknown";
}

- (NSString*)vendorName {
    return nil;   
}

- (NSString*)serialNumber {
    return nil;   
}

- (NSString*)uniqueID {
    return self.serialNumber;   
}

- (BOOL) beta {
    return NO;
}

- (void)connect:(void (^)(NSError*))block {
    if (block){
        block(nil);
    }
}

- (void)disconnect {
    self.transport = nil;
}

- (NSData*)randomDataOfLength:(NSInteger)length {
    
    NSMutableData* data = [NSMutableData dataWithLength:length];
    long* p = [data mutableBytes];
    for (int i = 0; i < length/sizeof(*p); ++i) { // rounding...
        *p++ = random();
    }
    
    return data;
}

@end

