//
//  CASINDICamera.m
//  indi-client
//
//  Created by Simon Taylor on 03/09/17.
//  Copyright (c) 2017 Simon Taylor. All rights reserved.
//

#import "CASINDICamera.h"

@interface CASINDICamera ()
@property BOOL capturing;
@property (strong) NSDate* exposureStartDate;
@end

@implementation CASINDICamera {
    NSInteger _binning;
    NSInteger _exposureTime;
    CASINDIDevice<CASINDICamera>* _device;
}

@synthesize binning = _binning;
@synthesize exposureTime = _exposureTime;

- (instancetype)initWithDevice:(CASINDIDevice<CASINDICamera>*)device {
    self = [super init];
    _device = device;
    return self;
}

#pragma - INDI

- (NSString*) name {
    return _device.name;
}

- (NSMutableDictionary*) vectors {
    return _device.vectors;
}

- (CASINDIContainer*) container {
    return _device.container;
}

- (NSInteger) binning {
    return _device.binning;
}

- (void)setBinning:(NSInteger)binning {
    _device.binning = binning;
}

- (NSInteger)exposureTime {
    return _device.exposureTime;
}

- (void)setExposureTime:(NSInteger)exposureTime {
    _device.exposureTime = exposureTime;
}

- (void)connect {
    [_device connect];
}

- (void)captureWithCompletion:(void(^)(NSData* exposureData))completion {
    [_device captureWithCompletion:completion];
}

#pragma - Device

- (CASDeviceType) type {
    return kCASDeviceTypeCamera;
}

- (NSString*) deviceName {
    return self.name;
}

- (NSString*) deviceLocation {
    return _device.container.service.hostName;
}

- (NSString*) vendorName {
    return @"INDI";
}

- (void)connect:(void (^)(NSError*))block {
    [self connect];
    block(nil);
}

- (void)disconnect {
    NSLog(@"[CASINDICamera disconnect]: not implemented");
}

#pragma - Camera

- (CASCCDProperties*) sensor {
    CASCCDProperties* properties = [[CASCCDProperties alloc] init];
    
    const CGSize size = _device.size;
    properties.width = size.width;
    properties.height = size.height;
    
    properties.bitsPerPixel = _device.bpp;
    properties.sensorSize = _device.sensorSize;
    properties.pixelSize = _device.pixelSize;

    return properties;
}

- (BOOL) isColour {
    return NO;
}

- (BOOL) hasCooler {
    return NO;
}

- (BOOL) canSubframe {
    return NO;
}

- (NSArray*) binningModes {
    return @[@1,@2,@4];
}

- (CGFloat) temperature {
    return 0;
}

- (CGFloat) targetTemperature {
    return 0;
}

- (void)exposeWithParams:(CASExposeParams)params type:(CASCCDExposureType)type block:(void (^)(NSError*,CASCCDExposure*exposure))block {
    
    if (self.capturing){
        if (block){
            block([NSError errorWithDomain:NSStringFromClass([self class]) code:1 userInfo:@{NSLocalizedDescriptionKey:@"Exposure already in progress"}],nil);
        }
        return;
    }
    
    self.capturing = YES;
    self.exposureStartDate = [NSDate date];
    
    // todo; set exposure type, handle shutter, etc
    
    self.binning = params.bin.width;
    self.exposureTime = params.ms / 1000;
    
    [self captureWithCompletion:^(NSData *exposureData) {
        if (exposureData.length > 0){
            CASCCDExposure* exposure = [CASCCDExposure exposureWithPixels:exposureData camera:self params:params time:self.exposureStartDate];
            block(nil,exposure);
        }
        else {
            block([NSError errorWithDomain:NSStringFromClass([self class]) code:2 userInfo:@{NSLocalizedDescriptionKey:@"Exposure failed"}],nil);
        }
        self.capturing = NO;
    }];
}

- (void)cancelExposure {
    NSLog(@"[CASINDICamera cancelExposure]: not implemented");
}

@end
