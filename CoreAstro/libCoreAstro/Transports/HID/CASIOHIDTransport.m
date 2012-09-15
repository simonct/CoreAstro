//
//  CASIOHIDTransport.m
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

#import "CASIOHIDTransport.h"
#import "HID_Utilities_External.h"

@interface CASIOHIDTransport ()
@end

@implementation CASIOHIDTransport {
    BOOL _open;
    IOHIDDeviceRef _device;
}

- (id)initWithDeviceRef:(IOHIDDeviceRef)device {
    self = [super init];
    if (self){
        _device = device;
    }
    return self;
}

- (IOReturn)_openDevice {
    
    IOReturn result = kIOReturnSuccess;
    
    if (!_open && _device){
        
        result = IOHIDDeviceOpen(_device, kIOHIDOptionsTypeNone);
        if (result != kIOReturnSuccess){
            NSLog(@"IOHIDDeviceOpen: %d",result);
        }
        else {
            _open = YES;
        }
    }
    
    return result;
}

- (NSError*)send:(NSData*)data {

    NSError* error = nil;
        
    if ([data length]){
        
        IOReturn result = [self _openDevice];
        if (result == kIOReturnSuccess){
            
            result = IOHIDDeviceSetReport(_device,
                                          kIOHIDReportTypeOutput,
                                          0,
                                          [data bytes],
                                          [data length]);
        }
        
        if (result != kIOReturnSuccess){
            error = [NSError errorWithDomain:@"CASIOHIDTransport" code:result userInfo:nil];
        }
    }
    
    return error;
}

- (NSError*)receive:(NSMutableData*)data {
    
    NSError* error = nil;
    
    if ([data length]){
        
        IOReturn result = [self _openDevice];
        if (result == kIOReturnSuccess){
            
            // hopefully sufficient for the devices we're dealing with but if not might have to use a local run loop and IOHIDDeviceGetReportWithCallback
            CFIndex length = [data length];
            result = IOHIDDeviceGetReport(_device,
                                          kIOHIDReportTypeInput,
                                          0,
                                          [data mutableBytes],
                                          &length);
        }
        
        if (result != kIOReturnSuccess){
            error = [NSError errorWithDomain:@"CASIOHIDTransport" code:result userInfo:nil];
        }
    }
    
    return error;
}

@end
