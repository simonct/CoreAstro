//
//  FLICCDDevice.m
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
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
#import "libfli.h"

@interface FLICCDDevice ()
@property (copy) NSString* fli_ident;
@property (copy) NSString* fli_path;
@property (copy) NSString* fli_model;
@property (copy) NSString* fli_serial;
@property (assign) NSInteger fli_domain;
@property (assign) NSInteger fli_status;
@property (assign) NSInteger fli_hwVersion, fli_fwVersion;
@property (assign) double fli_ccdTemp, fli_baseTemp, fli_coolerPower;
@property (assign) CGSize fli_pixelSize;
@property (assign) CGRect fli_area;
//@property (readonly) NSString* fli_pixelSizeString;
//@property (readonly) NSString* fli_areaString;
@end

@implementation FLICCDDevice {
    flidev_t _dev;
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

- (void)connect
{
    long status = FLIOpen(&_dev, (char*)[self.fli_ident UTF8String], FLIDOMAIN_USB | FLIDEVICE_CAMERA);
    if (status != 0){
        NSLog(@"FLIOpen: %ld",status);
    }
    else {
        
        const int BUFSZ = 1024;
        char buff[BUFSZ];
        
        if (FLIGetModel(_dev, buff, BUFSZ) == 0){
            self.fli_model = [NSString stringWithUTF8String:buff];
        }
        
        if (FLIGetSerialString(_dev, buff, BUFSZ) == 0){
            self.fli_serial = [NSString stringWithUTF8String:buff];
        }
        
        long hwRev;
        if (FLIGetHWRevision(_dev, &hwRev) == 0){
            self.fli_hwVersion = hwRev;
        }
        
        long fwRev;
        if (FLIGetFWRevision(_dev, &fwRev) == 0){
            self.fli_fwVersion = fwRev;
        }
        
        double w,h;
        if (FLIGetPixelSize(_dev, &w, &h) == 0){
            self.fli_pixelSize = CGSizeMake(w, h);
        }
        
        long ul_x, ul_y, lr_x, lr_y;
        if (FLIGetArrayArea(_dev, &ul_x, &ul_y, &lr_x, &lr_y) == 0){
            self.fli_area = CGRectMake(ul_x, ul_y, lr_x, lr_y);
        }
        
        [self fetchCameraStatus];
    }
}

- (void)fetchCameraStatus
{
    long status;
    if (FLIGetDeviceStatus(_dev, &status) == 0){
        self.fli_status = status;
    }
    
    double temp;
    if (FLIReadTemperature(_dev, FLI_TEMPERATURE_CCD, &temp) == 0){
        self.fli_ccdTemp = temp;
    }
    
    if (FLIReadTemperature(_dev, FLI_TEMPERATURE_BASE, &temp) == 0){
        self.fli_baseTemp = temp;
    }
    
    double power;
    if (FLIGetCoolerPower(_dev, &power) == 0){
        self.fli_coolerPower = power;
    }
    
    //    const int BUFSZ = 1024;
    //    char buff[BUFSZ];
    //    if (FLIGetCameraModeString(<#flidev_t dev#>, <#flimode_t mode_index#>, <#char *mode_string#>, <#size_t siz#>)(_dev, &power) == 0){
    //    }
    
    [self performSelector:_cmd withObject:nil afterDelay:1];
}

- (void)disconnect
{
    if (_dev != FLI_INVALID_DEVICE){
        FLIClose(_dev);
        _dev = FLI_INVALID_DEVICE;
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (NSString*)pixelSizeString
{
    return NSStringFromSize(self.fli_pixelSize);
}

- (NSString*)areaString
{
    return NSStringFromRect(self.fli_area);
}

// ccd device property accessors

@end
