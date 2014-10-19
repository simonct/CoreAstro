//
//  SXIOAppDelegate.m
//  fli-test
//
//  Created by Simon Taylor on 29/11/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOAppDelegate.h"
#import "libfli.h"
#import "stdio.h"

@interface SXIOAppDelegate ()
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSArrayController *devicesArrayController;
@end

@interface FLIDevice : NSObject
@property (copy) NSString* name;
@property (copy) NSString* model;
@property (copy) NSString* serial;
@property (assign) NSInteger domain;
@property (assign) NSInteger status;
@property (assign) NSInteger hwVersion, fwVersion;
@property (assign) double ccdTemp, baseTemp, coolerPower;
@property (assign) CGSize pixelSize;
@property (assign) CGRect area;
@property (readonly) NSString* pixelSizeString;
@property (readonly) NSString* areaString;
@end

@implementation FLIDevice {
    flidev_t _dev;
}

- (id)init
{
    self = [super init];
    if (self) {
        _dev = FLI_INVALID_DEVICE;
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
}

- (void)connect
{
    long status = FLIOpen(&_dev, (char*)[self.name UTF8String], FLIDOMAIN_USB | FLIDEVICE_CAMERA);
    if (status != 0){
        NSLog(@"FLIOpen: %ld",status);
    }
    else {
        
        const int BUFSZ = 1024;
        char buff[BUFSZ];
        
        if (FLIGetModel(_dev, buff, BUFSZ) == 0){
            self.model = [NSString stringWithUTF8String:buff];
        }
        
        if (FLIGetSerialString(_dev, buff, BUFSZ) == 0){
            self.serial = [NSString stringWithUTF8String:buff];
        }
        
        long hwRev;
        if (FLIGetHWRevision(_dev, &hwRev) == 0){
            self.hwVersion = hwRev;
        }
        
        long fwRev;
        if (FLIGetFWRevision(_dev, &fwRev) == 0){
            self.fwVersion = fwRev;
        }
        
        double w,h;
        if (FLIGetPixelSize(_dev, &w, &h) == 0){
            self.pixelSize = CGSizeMake(w, h);
        }
        
        long ul_x, ul_y, lr_x, lr_y;
        if (FLIGetArrayArea(_dev, &ul_x, &ul_y, &lr_x, &lr_y) == 0){
            self.area = CGRectMake(ul_x, ul_y, lr_x, lr_y);
        }
        
        [self fetchCameraStatus];
    }
}

- (void)fetchCameraStatus
{
    long status;
    if (FLIGetDeviceStatus(_dev, &status) == 0){
        self.status = status;
    }

    double temp;
    if (FLIReadTemperature(_dev, FLI_TEMPERATURE_CCD, &temp) == 0){
        self.ccdTemp = temp;
    }
    
    if (FLIReadTemperature(_dev, FLI_TEMPERATURE_BASE, &temp) == 0){
        self.baseTemp = temp;
    }
    
    double power;
    if (FLIGetCoolerPower(_dev, &power) == 0){
        self.coolerPower = power;
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
    return NSStringFromSize(self.pixelSize);
}

- (NSString*)areaString
{
    return NSStringFromRect(self.area);
}

@end

@implementation SXIOAppDelegate

- (void)enumerateDevices
{
    #define MAX_PATH 1024
	char file[MAX_PATH], name[MAX_PATH];
	long domain;
    
	FLICreateList(FLIDOMAIN_USB | FLIDEVICE_CAMERA);
    
	if(FLIListFirst(&domain, file, MAX_PATH, name, MAX_PATH) == 0)
	{
		do
		{
            NSString* name = [NSString stringWithUTF8String:file];
            FLIDevice* device = [FLIDevice new];
            device.name = name;
            device.domain = domain;
            [self.devicesArrayController addObject:device];
            [device connect];
		}
		while((FLIListNext(&domain, file, MAX_PATH, name, MAX_PATH) == 0));
	}
    
	FLIDeleteList();
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    #define LIBVERSIZE 1024
    char libver[LIBVERSIZE];

	if(FLIGetLibVersion(libver, LIBVERSIZE) != 0) {
		printf("Unable to retrieve library version!\n");
	}
    else {
        printf("Library version is %s\n",libver);
        
        [self enumerateDevices];
        
//        FLIDevice* device = [FLIDevice new];
//        device.name = @"Name";
//        device.fwVersion = 10.11;
//
//        [self.devicesArrayController addObject:device];
//        [device connect];
        
        NSLog(@"Found %lu devices",(unsigned long)[self.devicesArrayController.arrangedObjects count]);
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self.devicesArrayController.arrangedObjects makeObjectsPerformSelector:@selector(disconnect)];
}

@end
