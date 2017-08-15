//
//  CASHIDDeviceBrowser.m
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

#import "CASHIDDeviceBrowser.h"
#import "CASIOHIDTransport.h"
#import "HID_Utilities_External.h"

@interface CASHIDDeviceBrowser ()
- (void)deviceAdded:(IOHIDDeviceRef)device;
- (void)deviceRemoved:(IOHIDDeviceRef)device;
@end

@implementation CASHIDDeviceBrowser {
    CFRunLoopRef _runLoop;
    NSMutableArray* _devices;
    IOHIDManagerRef _hidManager;
}

@synthesize deviceAdded, deviceRemoved;

static void CASIOHIDDeviceRemovedCallback (void *                  context,
                                           IOReturn                result,
                                           void *                  sender,
                                           IOHIDDeviceRef          device) {
    
    CASHIDDeviceBrowser* browser = (__bridge CASHIDDeviceBrowser*)context;
    
    [browser deviceRemoved:device];
}

static void CASIOHIDDeviceMatchedCallback (void *                  context,
                                           IOReturn                result,
                                           void *                  sender,
                                           IOHIDDeviceRef          device) {
    
    CASHIDDeviceBrowser* browser = (__bridge CASHIDDeviceBrowser*)context;
    
    [browser deviceAdded:device];
}

- (void)dealloc
{
    if (_hidManager && _runLoop){
        IOHIDManagerUnscheduleFromRunLoop(_hidManager,_runLoop,kCFRunLoopCommonModes);
    }
}

- (void)invokeCallback:(CASDeviceBrowserCallback)callback withDevice:(IOHIDDeviceRef)device {
    
    NSParameterAssert(device);
    NSParameterAssert(callback);

    const long location = IOHIDDevice_GetLocationID(device);
    NSString* const transport = (__bridge NSString*)IOHIDDevice_GetTransport(device);
    if (transport){
        
        const long vendor = IOHIDDevice_GetVendorID(device);
        const long product = IOHIDDevice_GetProductID(device);
        
        NSString* path = [NSString stringWithFormat:@"hid://%@/%ld",transport,location];
        
        NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithLong:vendor],@"idVendor",
                                    [NSNumber numberWithLong:product],@"idProduct",
                                    nil];
        
//        NSLog(@"%@: %@",path,properties);
        callback(device,path,properties);
    }
}

- (void)deviceAdded:(IOHIDDeviceRef)device {
    
//    NSLog(@"HID device added: %@",device);
    
    if (!_devices){
        _devices = [[NSMutableArray alloc] initWithCapacity:10];
    }
    [_devices addObject:(__bridge id)(device)];
    
    if (self.deviceAdded){
        [self invokeCallback:self.deviceAdded withDevice:device];
    }
}

- (void)deviceRemoved:(IOHIDDeviceRef)device {
    
//    NSLog(@"HID device removed: %@",device);

    if (self.deviceRemoved){
        [self invokeCallback:self.deviceRemoved withDevice:device];
    }

    [_devices removeObject:(__bridge id)(device)];
}

- (void)scanForDevices {

	if ( !_hidManager ) {
		_hidManager = IOHIDManagerCreate( kCFAllocatorDefault, 0L );
	}
    
	if ( !_hidManager ) {
		NSLog( @"%s: Couldn’t create a IOHIDManager.", __PRETTY_FUNCTION__ );
    }
    else {

		IOReturn tIOReturn = IOHIDManagerOpen( _hidManager, 0L);
		if ( kIOReturnSuccess != tIOReturn ) {
			NSLog(@"%s: Couldn’t open IOHIDManager.", __PRETTY_FUNCTION__ );
		}
        else {
            
            // register for device added/removed notifications
            IOHIDManagerSetDeviceMatching( _hidManager, NULL );
            IOHIDManagerRegisterDeviceRemovalCallback(_hidManager,CASIOHIDDeviceRemovedCallback,(__bridge void *)(self));
            IOHIDManagerRegisterDeviceMatchingCallback(_hidManager,CASIOHIDDeviceMatchedCallback,(__bridge void *)(self));
            
            _runLoop = CFRunLoopGetMain(); // todo; set up a dedicated run loop
            IOHIDManagerScheduleWithRunLoop(_hidManager,_runLoop,kCFRunLoopCommonModes);
		}
	}
}

- (void)scan {
    [self scanForDevices];
}

- (CASIOTransport*)createTransportWithDevice:(CASDevice*)device {
    CASIOHIDTransport* transport = [[CASIOHIDTransport alloc] initWithDeviceRef:(IOHIDDeviceRef)device.device];
    if ([device conformsToProtocol:@protocol(CASIOHIDTransportDelegate)]){
        transport.delegate = (id<CASIOHIDTransportDelegate>)device;
    }
    else {
        NSLog(@"CASHIDDeviceBrowser: device doesn't conform to CASIOHIDTransportDelegate");
    }
    return transport;
}

@end
