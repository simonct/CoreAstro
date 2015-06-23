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
    NSMutableData* _inputBuffer;
    CFRunLoopRef _runLoop;
}

static void CASIOHIDReportCallback (void *                  context,
                                    IOReturn                result,
                                    void *                  sender,
                                    IOHIDReportType         type,
                                    uint32_t                reportID,
                                    uint8_t *               report,
                                    CFIndex                 reportLength) {
    
//    NSLog(@"CASIOHIDReportCallback: %d %d (%x)",reportID,type,*report);
    
    CASIOHIDTransport* transport = (__bridge CASIOHIDTransport*)context;
    
    if (type == kIOHIDReportTypeInput && transport && transport->_open){
        
        [transport.delegate receivedInputReport:[NSData dataWithBytesNoCopy:report length:reportLength freeWhenDone:NO]];
    }
}

- (id)initWithDeviceRef:(IOHIDDeviceRef)device {
    self = [super init];
    if (self){
        _device = device;
    }
    return self;
}

- (CASIOTransportType)type {
    return kCASTransportTypeHID;
}

- (NSError*)connect {
    
    IOReturn result = kIOReturnSuccess;
    
    if (!_open && _device){
        
        result = IOHIDDeviceOpen(_device, kIOHIDOptionsTypeNone);
        if (result != kIOReturnSuccess){
            NSLog(@"IOHIDDeviceOpen: %d",result);
        }
        else {
            
            CFRetain(_device);
            
            const long size = IOHIDDevice_GetMaxInputReportSize(_device);
            if (size < 1){
                NSLog(@"IOHIDDevice_GetMaxInputReportSize: %ld",size);
            }
            else {
                
                _inputBuffer = [NSMutableData dataWithLength:size];
                _runLoop = CFRunLoopGetMain(); // todo; really need a dedicated run loop for these
                
                IOHIDDeviceScheduleWithRunLoop(_device,
                                               _runLoop,
                                               kCFRunLoopCommonModes);
                
                IOHIDDeviceRegisterInputReportCallback(_device,
                                                       [_inputBuffer mutableBytes],
                                                       [_inputBuffer length],
                                                       CASIOHIDReportCallback,
                                                       (__bridge void *)(self));
                
                _open = YES;
            }
        }
    }
    
    return result ? [NSError errorWithDomain:@"CASIOUSBTransport" code:result userInfo:nil] : nil;
}

- (void)disconnect {
    
    if (!_device){
        return;
    }
    
    NSLog(@"[CASIOHIDTransport disconnect]");
    
    _open = NO;
    IOHIDDeviceRegisterInputReportCallback(_device,
                                           [_inputBuffer mutableBytes],
                                           [_inputBuffer length],
                                           nil,
                                           (__bridge void *)(self));
    
    IOHIDDeviceUnscheduleFromRunLoop(_device,
                                     _runLoop,
                                     kCFRunLoopCommonModes);
    
    IOHIDDeviceClose(_device, kIOHIDOptionsTypeNone);
    
    CFRelease(_device);
    
    _device = nil;
}

- (NSError*)send:(NSData*)data { // todo; needs a completion block

    __block NSError* error = nil;
        
    if ([data length]){
        
        // make sure HID calls are made on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            error = [self connect];
            if (!error){
                
                if (_device){
                    
                    IOReturn result = IOHIDDeviceSetReport(_device,
                                                           kIOHIDReportTypeOutput,
                                                           0,
                                                           [data bytes],
                                                           [data length]);
                    if (result != kIOReturnSuccess){
                        NSLog(@"IOHIDDeviceSetReport: %x",result);
                        error = [NSError errorWithDomain:@"CASIOHIDTransport" code:result userInfo:nil]; // immediately discarded, -send: really needs a completion block
                    }
                }
            }
        });
    }
    
    return error;
}

- (NSError*)receive:(NSMutableData*)data {
    
    // todo
    return nil;
}

@end
