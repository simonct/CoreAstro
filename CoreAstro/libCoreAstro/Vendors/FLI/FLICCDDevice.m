//
//  FLICCDDevice.m
//  CoreAstro
//
//  Copyright (c) 2016, Simon Taylor
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

#import "FLICCDDevice.h"
#import "FLISDK.h"
#import "libfli.h"

@interface FLICCDDevice ()
@property BOOL connected;
@property (copy) NSString* fli_ident;
@property (copy) NSString* fli_path;
@property (copy) NSString* fli_model;
@property (copy) NSString* fli_serial;
@property (assign) NSInteger fli_domain;
@property (assign) NSInteger fli_status;
@property (assign) NSInteger fli_hwVersion, fli_fwVersion;
@property (assign) double fli_ccdTemp, fli_coolerPower;
@property (assign) CGSize fli_pixelSize;
@property (assign) CGRect fli_area, fli_visibleArea;
// background flush mode, fan control, download speed
@end

@implementation FLICCDDevice {
    flidev_t _dev;
    CGFloat _targetTemperature;
    CASCCDProperties* _sensor;
    CASExposeParams _params;
    CASCCDExposureType _type;
    void (^_completion)(NSError*,CASCCDExposure*exposure);
    NSDate* _exposureStart;
    BOOL _continuous, _shutterOpen, _backgroundFlushing;
}

- (instancetype)initWithId:(NSString*)ident path:(NSString*)path domain:(long)domain
{
    self = [super init];
    if (self) {
        _dev = FLI_INVALID_DEVICE;
        self.fli_path = path;
        self.fli_ident = ident;
        self.fli_domain = domain;
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
}

- (BOOL) isColour
{
    return NO;
}

- (BOOL) hasCooler
{
    return YES;
}

- (BOOL) canSubframe
{
    return YES;
}

- (NSArray*)binningModes
{
    return @[@1,@2,@3,@4]; // actually all the way to 16
}

- (CGFloat) temperature // make this double
{
    return round(self.fli_ccdTemp);
}

+ (NSSet*)keyPathsForValuesAffectingTemperature
{
    return [NSSet setWithObject:@"fli_ccdTemp"];
}

- (NSInteger) temperatureFrequency
{
    return 1;
}

- (CASCCDProperties*)sensor
{
    return _sensor;
}

- (NSString*)uniqueID
{
    return self.fli_path;
}

- (NSString*)deviceName
{
    return self.fli_model;
}

- (NSString*) deviceLocation
{
    return @"USB";
}

- (NSString*) vendorName
{
    return @"FLI";
}

- (NSString*)serialNumber
{
    return self.fli_serial;
}

- (CGFloat)targetTemperature
{
    return _targetTemperature;
}

- (void)setTargetTemperature:(CGFloat)targetTemperature
{
    if (_targetTemperature != targetTemperature){
        _targetTemperature = targetTemperature;
        dispatch_sync([FLISDK q], ^{
            if (FLISetTemperature(_dev, _targetTemperature) != 0){
                NSLog(@"Failed to set target temperature");
            }
            else {
                NSLog(@"Set target temperature to %f",_targetTemperature);
            }
        });
    }
}

- (NSInteger)binnedWidth
{
    return _params.bin.width > 0 ? _params.frame.width / _params.bin.width : 0;
}

- (NSInteger)binnedHeight
{
    return _params.bin.height > 0 ? _params.frame.height / _params.bin.height : 0;
}

- (void)startContinuousExposures
{
    _continuous = YES;
    [self openShutter];
}

- (void)stopContinuousExposures
{
    _continuous = NO;
    [self closeShutter];
}

- (void)openShutter
{
    if (!_shutterOpen){
        _shutterOpen = YES;
        dispatch_async([FLISDK q], ^{
            NSLog(@"Opening shutter");
            FLIControlShutter(_dev,FLI_SHUTTER_OPEN);
        });
    }
}

- (void)closeShutter
{
    if (_shutterOpen){
        _shutterOpen = NO;
        dispatch_async([FLISDK q], ^{
            NSLog(@"Closing shutter");
            FLIControlShutter(_dev,FLI_SHUTTER_CLOSE);
        });
    }
}

- (void)exposeWithParams:(CASExposeParams)params type:(CASCCDExposureType)type block:(void (^)(NSError*,CASCCDExposure*exposure))block
{
    dispatch_sync([FLISDK q], ^{
        
        // open shutter if this isn't a dark or bias
        if (kCASCCDExposureDarkType != type && kCASCCDExposureBiasType != type){
            [self openShutter];
        }
        
        _type = type;
        _params = params;
        _completion = [block copy];
        _exposureStart = [NSDate date];
        
        self.exposureTemperatures = [NSMutableArray array];
        [self.exposureTemperatures addObject:@(self.fli_ccdTemp)];
        
        long status;
        status = FLISetCameraMode(_dev, 0);
        require_noerr(status, end);
        
        status = FLISetExposureTime(_dev, params.ms);
        require_noerr(status, end);
        
        status = FLISetBitDepth(_dev, FLI_MODE_16BIT);
//        require_noerr(status, end); // always fails ?
        
        if (!_backgroundFlushing){
            status = FLISetNFlushes(_dev, 5);
            require_noerr(status, end);
        }
        
        switch (type) {
            case kCASCCDExposureDarkType:
                status = FLISetFrameType(_dev, FLI_FRAME_TYPE_DARK);
                break;
            default:
                status = FLISetFrameType(_dev, FLI_FRAME_TYPE_NORMAL);
                break;
        }
        require_noerr(status, end);
        
        // check return values
        const NSInteger binnedWidth = [self binnedWidth];
        const NSInteger binnedHeight = [self binnedHeight];
        status = FLISetImageArea(_dev,
                                 params.origin.x /*+ self.fli_visibleArea.origin.x*/,
                                 params.origin.y /*+ self.fli_visibleArea.origin.y*/,
                                 binnedWidth,
                                 binnedHeight);
        require_noerr(status, end);
        NSLog(@"FLISetImageArea: x=%ld, y=%ld, width=%ld, height=%ld",params.origin.x,params.origin.y,binnedWidth,binnedHeight);
        
        status = FLISetHBin(_dev, params.bin.width);
        require_noerr(status, end);
        
        status = FLISetVBin(_dev, params.bin.height);
        require_noerr(status, end);
        
        status = FLIExposeFrame(_dev);
        require_noerr(status, end);
        
    end:
        if (status != 0){
            NSLog(@"Expose frame failed with code %ld",status);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block){
                    block([NSError errorWithDomain:@"FLI" code:status userInfo:nil],nil);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self checkExposureStatus];
            });
        }
    });
}

- (void)callCompletion:(NSError*)error exposure:(CASCCDExposure*)exposure
{
    if (_completion){
        typeof (_completion) _completionCopy = [_completion copy];
        _completion = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            _completionCopy(error,exposure);
        });
    }
    [self startBackgroundFlush];
}

- (void)checkExposureStatus
{
    // todo; this is a slow operation and could block other calls/devices if they make sync calls on the main thread
    // todo; make queue per-device - what's the details of the sdk ? serialise only open/close ?
    dispatch_async([FLISDK q], ^{

        long status = FLI_CAMERA_STATUS_UNKNOWN;
        long timeleft = 1;
        
        FLIGetDeviceStatus(_dev, &status);
        FLIGetExposureStatus(_dev, &timeleft);
        
        const BOOL readyForDownload = ((status == FLI_CAMERA_STATUS_UNKNOWN) && (timeleft == 0)) || ((status != FLI_CAMERA_STATUS_UNKNOWN) && ((status & FLI_CAMERA_DATA_READY) != 0));
        if (!readyForDownload) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSelector:_cmd withObject:nil afterDelay:self.temperatureFrequency];
            });
            return;
        }

        // close shutter
        if (!_continuous){
            [self closeShutter];
        }
        
        // read the pixels from the camera
        const NSInteger binnedWidth = [self binnedWidth];
        const NSInteger binnedHeight = [self binnedHeight];
        NSMutableData* buffer = [NSMutableData dataWithLength:binnedWidth * binnedHeight * 2];
        UInt16* p = (UInt16*)[buffer bytes];
        if (!p){
            [self callCompletion:[NSError errorWithDomain:@"FLICCDDevice" code:memFullErr userInfo:@{@"Out of memory":NSLocalizedDescriptionKey}] exposure:nil];
        }
        else {
            
            // grab all the rows
            const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
            for (int i = 0; i < binnedHeight; i++, p += binnedWidth) {
                FLIGrabRow(_dev, p, binnedWidth);
            }
            NSLog(@"Downloaded %ld rows in %.2f seconds",binnedHeight,[NSDate timeIntervalSinceReferenceDate] - start);
            
            // wrap it in an exposure object
            CASCCDExposure* exposure = [CASCCDExposure exposureWithPixels:buffer camera:self params:_params time:_exposureStart];
            
            // call the completion block
            [self callCompletion:nil exposure:exposure];
        }
    });
}

- (void)cancelExposure
{
    dispatch_sync([FLISDK q], ^{
        FLICancelExposure(_dev);
    });
    [self closeShutter];
    self.exposureTemperatures = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkExposureStatus) object:nil];
    if (_completion){
        typeof (_completion) _completionCopy = [_completion copy];
        _completion = nil;
        _completionCopy(nil,nil);
    }
}

- (void)connect:(void (^)(NSError*))block
{
    if (self.connected){
        if (block){
            block(nil);
        }
        return;
    }
    
    dispatch_async([FLISDK q], ^{
        
        const int BUFSZ = 128;
        char buff[BUFSZ];
        long hwRev;
        long fwRev;
        double w,h;
        long left, top, right, bottom;
        CASCCDProperties* sensor = [CASCCDProperties new];
        
        long status;
        status = FLIOpen(&_dev, (char*)[self.fli_path UTF8String], FLIDOMAIN_USB | FLIDEVICE_CAMERA);
        require_noerr(status, end);
        
        status = FLIGetModel(_dev, buff, BUFSZ);
        require_noerr(status, end);
        self.fli_model = [NSString stringWithUTF8String:buff];
        
        status = FLIGetSerialString(_dev, buff, BUFSZ);
        require_noerr(status, end);
        self.fli_serial = [NSString stringWithUTF8String:buff];
        
        status = FLIGetHWRevision(_dev, &hwRev);
        require_noerr(status, end);
        self.fli_hwVersion = hwRev;
        
        status = FLIGetFWRevision(_dev, &fwRev);
        require_noerr(status, end);
        self.fli_fwVersion = fwRev;
        
        status = FLIGetPixelSize(_dev, &w, &h);
        require_noerr(status, end);
        self.fli_pixelSize = CGSizeMake(w, h);
        NSLog(@"FLIGetPixelSize: %@",NSStringFromSize(self.fli_pixelSize));
        
        status = FLIGetVisibleArea(_dev, &left, &top, &right, &bottom);
        require_noerr(status, end);
        self.fli_visibleArea = CGRectMake(left, top, right- left, bottom - top);
        NSLog(@"FLIGetVisibleArea: %@",NSStringFromRect(self.fli_visibleArea));
        
        status = FLIGetArrayArea(_dev, &left, &top, &right, &bottom);
        require_noerr(status, end);
        self.fli_area = CGRectMake(left, top, right- left, bottom - top);
        NSLog(@"FLIGetArrayArea: %@",NSStringFromRect(self.fli_area));
        
        sensor.width = self.fli_visibleArea.size.width;
        sensor.height = self.fli_visibleArea.size.height;
        sensor.pixelSize = CGSizeMake(w*1e6, h*1e6); // w,h are in microns
        sensor.sensorSize = CGSizeMake((sensor.width * sensor.pixelSize.width)/1e3, (sensor.height * sensor.pixelSize.height)/1e3);
        sensor.bitsPerPixel = 16;
        _sensor = sensor;
        
        [self startBackgroundFlush];
        [self fetchCameraStatus];
        
        self.connected = YES;
        
    end:
        if (status != 0){
            NSLog(@"Connect failed with code %ld",status);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block){
                    block([NSError errorWithDomain:@"FLI" code:status userInfo:nil]);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block){
                    block(nil);
                }
            });
        }
    });
}

- (void)startBackgroundFlush
{
    dispatch_async([FLISDK q], ^{
        
        if (FLIControlBackgroundFlush(_dev, FLI_BGFLUSH_START) == 0){
            _backgroundFlushing = YES;
            NSLog(@"Started background flushing");
        }
        else {
            _backgroundFlushing = NO;
            NSLog(@"Camera doesn't support background flushing");
        }
    });
}

- (void)fetchCameraStatus
{
    dispatch_async([FLISDK q], ^{
        
        long status;
        if (FLIGetDeviceStatus(_dev, &status) == 0){
            self.fli_status = status;
        }
        
        double temp;
        if (FLIGetTemperature(_dev, &temp) == 0){
            self.fli_ccdTemp = temp;
            if (self.exposureTemperatures){
                [self.exposureTemperatures addObject:@(self.fli_ccdTemp)];
            }
        }
        
        double power;
        if (FLIGetCoolerPower(_dev, &power) == 0){
            self.fli_coolerPower = power;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSelector:_cmd withObject:nil afterDelay:1];
        });
    });
}

- (void)disconnect
{
    if (_dev != FLI_INVALID_DEVICE){
        dispatch_sync([FLISDK q], ^{
            FLIClose(_dev);
        });
        _dev = FLI_INVALID_DEVICE;
    }
    self.connected = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (NSString*)fli_pixelSizeString
{
    return NSStringFromSize(self.fli_pixelSize);
}

+ (NSSet*)keyPathsForValuesAffectingFli_pixelSizeString
{
    return [NSSet setWithObject:@"fli_pixelSize"];
}

- (NSString*)fli_areaString
{
    return NSStringFromRect(self.fli_area);
}

+ (NSSet*)keyPathsForValuesAffectingFli_areaString
{
    return [NSSet setWithObject:@"fli_area"];
}

@end
