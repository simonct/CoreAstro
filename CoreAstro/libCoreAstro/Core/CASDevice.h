//
//  CASDevice.h
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
//  This is the base class of all CoreAstro devices. Make this a protocol ?

#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>

typedef enum {
    kCASDeviceTypeNone = 0,
    kCASDeviceTypeCamera,
    kCASDeviceTypeVideo,
    kCASDeviceTypeMount,
    kCASDeviceTypeFocusser,
    kCASDeviceTypeSkySensor,
    kCASDeviceTypeFilterWheel
} CASDeviceType;

@class CASIOTransport;

@interface CASDevice : NSObject

@property (nonatomic,readonly) CASDeviceType type;

@property (nonatomic,assign) void* device;
@property (nonatomic,assign) natural_t notification;

@property (nonatomic,copy) NSString* path;
@property (nonatomic,strong) NSDictionary* properties;

@property (nonatomic,strong) CASIOTransport* transport;

@property (nonatomic,readonly) NSString* deviceName;
@property (nonatomic,readonly) NSImage* deviceImage;
@property (nonatomic,readonly) NSString* deviceLocation; // e.g. 'USB'
@property (nonatomic,readonly) NSString* vendorName;
@property (nonatomic,readonly) NSString* serialNumber;
@property (nonatomic,readonly) NSString* uniqueID;

@property (nonatomic,readonly) BOOL beta;

- (void)connect:(void (^)(NSError*))block;
- (void)disconnect;

- (NSData*)randomDataOfLength:(NSInteger)length;

- (NSViewController*)configurationViewController;

@end

