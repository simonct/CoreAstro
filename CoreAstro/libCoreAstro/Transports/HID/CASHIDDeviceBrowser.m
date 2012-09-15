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
@property (nonatomic,assign) BOOL scanned;
@property (nonatomic,copy) CASDeviceBrowserCallback callback;
@end

@implementation CASHIDDeviceBrowser {
    NSArray* _devices;
    IOHIDManagerRef _hidManager;
}

@synthesize deviceRemoved;

// ---------------------------------
// used to sort the CFDevice array after copying it from the (unordered) (CF)set.
// we compare based on the location ID's since they're consistant (across boots & launches).
//
static CFComparisonResult CFDeviceArrayComparatorFunction(const void *val1, const void *val2, void *context) {
#pragma unused( context )
	CFComparisonResult result = kCFCompareEqualTo;
	
	long loc1 = IOHIDDevice_GetLocationID( (IOHIDDeviceRef) val1 );
	long loc2 = IOHIDDevice_GetLocationID( (IOHIDDeviceRef) val2 );
	if ( loc1 < loc2 ) {
		result = kCFCompareLessThan;
	} else if ( loc1 > loc2 ) {
		result = kCFCompareGreaterThan;
	}
	
	return (result);
}   // CFDeviceArrayComparatorFunction

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
            
			IOHIDManagerSetDeviceMatching( _hidManager, NULL );
			NSSet* deviceSet = (__bridge NSSet*)IOHIDManagerCopyDevices( _hidManager );
			if ( deviceSet ) {
                
                _devices = [[deviceSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    return CFDeviceArrayComparatorFunction((__bridge const void *)(obj1),(__bridge const void *)(obj2),nil);
                }];
			}
		}
        
        if (self.callback){
            
            for (id device in _devices){
                
                IOHIDDeviceRef deviceRef = (__bridge IOHIDDeviceRef)device;

                const long location = IOHIDDevice_GetLocationID(deviceRef);
                NSString* const transport = (__bridge NSString*)IOHIDDevice_GetTransport(deviceRef);
                if (transport){
                    
                    const long vendor = IOHIDDevice_GetVendorID(deviceRef);
                    const long product = IOHIDDevice_GetProductID(deviceRef);

                    NSString* path = [NSString stringWithFormat:@"hid://%@/%ld",transport,location];
                    
                    NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithLong:vendor],@"idVendor",
                                                [NSNumber numberWithLong:product],@"idProduct",
                                                nil];
                    
                    self.callback((__bridge void *)(device),path,properties);
                }
            }
        }
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
    
    // register for HID notifications
}

- (CASIOTransport*)createTransportWithDevice:(CASDevice*)device {
    return [[CASIOHIDTransport alloc] initWithDeviceRef:(IOHIDDeviceRef)device.device];
}

@end
