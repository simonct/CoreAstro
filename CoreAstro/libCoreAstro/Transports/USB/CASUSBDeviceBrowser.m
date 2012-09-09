//
//  CASUSBDeviceBrowser.m
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

#import "CASUSBDeviceBrowser.h"
#import "CASIOUSBTransport.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/IOMessage.h>
#import <IOKit/usb/IOUSBLib.h>
#import <mach/mach.h>
#import "BusProberSharedFunctions.h"

@interface CASUSBDeviceBrowser ()
@property (nonatomic,assign) BOOL scanned;
@property (nonatomic,assign) IONotificationPortRef notifyPort;
@property (nonatomic,assign) IONotificationPortRef terminatePort;
@property (nonatomic,copy) CASDeviceBrowserCallback callback;
- (io_iterator_t)registerForNotifications;
@end

@implementation CASUSBDeviceBrowser

@synthesize notifyPort, terminatePort, callback, deviceRemoved, scanned;

static void DeviceAdded(void *refCon, io_iterator_t iterator) {
        
//    NSLog(@"DeviceAdded");
    
    CASUSBDeviceBrowser* self = (__bridge CASUSBDeviceBrowser*)refCon;
    
    io_service_t usbDeviceRef = 0;
    while ( (usbDeviceRef = IOIteratorNext(iterator)) ){
        
        SInt32 score;
        IOCFPlugInInterface **ioPlugin;
        kern_return_t err = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &ioPlugin, &score);
        if (err == kIOReturnSuccess) {
            
            CASDevice* device = nil;
            IOUSBDeviceRef deviceIntf = NULL;
            err = (*ioPlugin)->QueryInterface(ioPlugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID320), (LPVOID *)&deviceIntf);
            IODestroyPlugInInterface(ioPlugin);
            if (err == kIOReturnSuccess) {
                
                io_string_t path;
                err = IORegistryEntryGetPath(usbDeviceRef,kIOServicePlane,path); // why does kIODeviceTreePlane not work ?
                if (err == kIOReturnSuccess) {
                    
                    CFMutableDictionaryRef props = (__bridge CFMutableDictionaryRef)[NSMutableDictionary dictionaryWithCapacity:100];
                    err = IORegistryEntryCreateCFProperties(usbDeviceRef,&props,NULL,0);
                    if (err == kIOReturnSuccess) {
                        
                        device = self.callback(deviceIntf,[NSString stringWithCString:path encoding:NSUTF8StringEncoding],(__bridge NSDictionary*)props);
                        if (props){
                            CFRelease(props);
                        }
                    }
                }
            }
            if (!device){
                IOObjectRelease((io_registry_entry_t)deviceIntf);
            }
        }
		IOObjectRelease(usbDeviceRef);
    }
    
    IOObjectRelease(iterator); // release this ?
    
    [self registerForNotifications];
}

static void DeviceRemoved(void *refCon, io_iterator_t iterator) {
    
//    NSLog(@"DeviceRemoved");
    
    CASUSBDeviceBrowser* self = (__bridge CASUSBDeviceBrowser*)refCon;
    
    io_service_t usbDeviceRef = 0;
    while ( (usbDeviceRef = IOIteratorNext(iterator)) ){

        if (self.deviceRemoved){
            io_string_t path;
            IORegistryEntryGetPath(usbDeviceRef,kIOServicePlane,path); // why does kIODeviceTreePlane not work ?
            self.deviceRemoved(nil,[NSString stringWithCString:path encoding:NSUTF8StringEncoding],/*(__bridge NSDictionary*)props*/nil);
        }
        
        IOObjectRelease(usbDeviceRef);
    }
}

- (io_iterator_t)registerForNotifications {
    
    NSMutableDictionary* matchingDictionary = (__bridge NSMutableDictionary*)IOServiceMatching(kIOUSBDeviceClassName);
        
    kern_return_t err = kIOReturnSuccess;
    io_iterator_t iterator = 0;
    
    if (err == kIOReturnSuccess){
        
        // should install a signal handler to remove the observer
        if (!self.notifyPort){
            self.notifyPort = IONotificationPortCreate(kIOMasterPortDefault);
            CFRunLoopAddSource(CFRunLoopGetCurrent(),
                               IONotificationPortGetRunLoopSource(self.notifyPort), 
                               kCFRunLoopDefaultMode);
        }
        
        err = IOServiceAddMatchingNotification(self.notifyPort,			// notifyPort
                                               kIOFirstMatchNotification,	// notificationType
                                               (__bridge CFDictionaryRef)matchingDictionary,			// matching
                                               DeviceAdded,			// callback
                                               (__bridge void*)self,				// refCon
                                               &iterator			// notification
                                               );		
        verify_noerr(err);
        
        while (IOIteratorNext(iterator)) {}; // leaks ?
        
        matchingDictionary = (__bridge NSMutableDictionary*)IOServiceMatching(kIOUSBDeviceClassName);
    }
    
    // Also register for removal notifications
    if (!self.terminatePort){
        self.terminatePort = IONotificationPortCreate(kIOMasterPortDefault);
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           IONotificationPortGetRunLoopSource(self.terminatePort),
                           kCFRunLoopDefaultMode);
    }
    
    err = IOServiceAddMatchingNotification(self.terminatePort,
                                              kIOTerminatedNotification,
                                              (__bridge CFDictionaryRef)matchingDictionary,
                                              DeviceRemoved,
                                              (__bridge void*)self,         // refCon/contextInfo
                                              &iterator);
    verify_noerr(err);

    while (IOIteratorNext(iterator)) {}; // leaks ?
    
    return iterator;
}

- (void)scanForDevices {
    
    NSMutableDictionary* matchingDictionary = (__bridge NSMutableDictionary*)IOServiceMatching(kIOUSBDeviceClassName);
    
    io_iterator_t iterator = 0;
    verify_noerr(IOServiceGetMatchingServices(kIOMasterPortDefault, (__bridge CFDictionaryRef)matchingDictionary, &iterator));
    matchingDictionary = nil; // this was consumed by the IOServiceGetMatchingServices call so make sure we don't use it again (even if there's an error ?)
    
    if (iterator){
        DeviceAdded((__bridge void*)self,iterator);
    }
}

- (void)scan:(CASDeviceBrowserCallback)block {
    
    if (!block){
        return;
    }
    
    self.callback = block;
    
    if (!self.scanned){
        self.scanned = YES;
        [self scanForDevices];   
    }
    
    io_iterator_t iterator = [self registerForNotifications];
    if (iterator){
        DeviceAdded((__bridge void*)self,iterator);
    }
}

- (CASIOTransport*)createTransportWithDevice:(CASDevice*)device {
    
    CASIOUSBTransport* result = nil;
    
    IOUSBDeviceRef deviceRef = (IOUSBDeviceRef)device.device;
    
    io_iterator_t iterator;
    IOUSBFindInterfaceRequest interfaceRequest;
    interfaceRequest.bInterfaceClass = kIOUSBFindInterfaceDontCare;		// requested class
    interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;	// requested subclass
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;	// requested protocol
    interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;	// requested alt setting
    
    verify_noerr( (*deviceRef)->CreateInterfaceIterator(deviceRef, &interfaceRequest, &iterator) );
    if (iterator){
        
        io_service_t usbInterfaceRef;
        while ( (usbInterfaceRef = IOIteratorNext(iterator)) ) {
            
            // create a transport object
            SInt32 score;
            IOCFPlugInInterface **iodev = nil;
            IOCreatePlugInInterfaceForService(usbInterfaceRef, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
            IOObjectRelease(usbInterfaceRef);
            if (iodev){
                result = [[CASIOUSBTransport alloc] initWithPluginInterface:iodev];
                (*iodev)->Release(iodev);
            }
        }
        
        IOObjectRelease(iterator);
    }

    return result;
}

@end
