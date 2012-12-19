//
//  SXCCDDevice.m
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

#import "SXCCDDevice.h"
#import "CASIOTransport.h"
#import "SXCCDIOCommand.h"
#import "SXCCDDeviceFactory.h"
#import "CASCCDExposure.h"
#import "CASAutoGuider.h"

@interface SXCCDDevice ()
@property (nonatomic,assign) BOOL connected;
@property (nonatomic,strong) SXCCDProperties* sensor;
@property (nonatomic,strong) NSMutableArray* exposureTemperatures;
- (void)fetchTemperature;
@end

@implementation SXCCDDevice

@synthesize temperature, targetTemperature, sensor, productID, exposureTemperatures;

#pragma mark - Properties

- (id)init
{
    self = [super init];
    if (self) {
        self.targetTemperature = -10;
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    if (aProtocol == @protocol(CASGuider)){
        return self.hasStar2KPort;
    }
    return [super conformsToProtocol:aProtocol];
}

- (void)disconnect
{
    [super disconnect];

    self.connected = NO; // todo: base class
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (CASDeviceType)type {
    return kCASDeviceTypeCamera;   
}

- (NSString*)deviceName {
    return [[self deviceParams] objectForKey:@"name"];   
}

- (NSImage*)deviceImage {
    NSString* image = [[self deviceParams] objectForKey:@"image"];
    return image ? [[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:image]] : nil;
}

- (NSDictionary*)deviceParams {
    return [[SXCCDDeviceFactory deviceLookup] objectForKey:[NSString stringWithFormat:@"%ld",self.productID]];   
}

- (NSString*)vendorName {
    return @"Starlight Xpress";   
}

- (NSString*)serialNumber {
    return [self.properties objectForKey:@"SX Serial Number"];   
}

- (NSString*)uniqueID {
    return self.deviceName; // temp, until I figure out how to get the serial number   
}

- (void)connect:(void (^)(NSError*))block {
    
    if (self.connected){
        if (block){
            block(nil);
        }
        return;
    }
    
    self.connected = YES; // take this to mean connecting as well
    
    [self reset:^(NSError* error) {
       
        if (error){
            self.connected = NO;
            if (block){
                block(error);
            }
        }
        else {
            
            [self getParams:^(NSError* error, SXCCDProperties* params) {
                
                if (error){
                    self.connected = NO;
                }
                else{
                    
                    NSDictionary* storedParams = [[self deviceParams] objectForKey:@"params"];
                    if (storedParams){
                        
                        self.sensor.width = [[storedParams objectForKey:@"width"] integerValue];
                        self.sensor.height = [[storedParams objectForKey:@"height"] integerValue];
                        self.sensor.bitsPerPixel = [[storedParams objectForKey:@"bits-per-pixel"] integerValue];
                        self.sensor.pixelWidth = [[storedParams objectForKey:@"pix-width"] floatValue];
                        self.sensor.pixelHeight = [[storedParams objectForKey:@"pix-height"] floatValue];
                        self.sensor.horizFrontPorch = [[storedParams objectForKey:@"h-front-porch"] integerValue];
                        self.sensor.horizBackPorch = [[storedParams objectForKey:@"h-back-porch"] integerValue];
                        self.sensor.vertFrontPorch = [[storedParams objectForKey:@"v-front-porch"] integerValue];
                        self.sensor.vertBackPorch = [[storedParams objectForKey:@"v-back-porch"] integerValue];
                        // todo; and the rest
                    }
                    
                    if (self.hasCooler){
                        
                        // start temperature fetch cycle
                        [self fetchTemperature];
                    }
                }
                
                if (block){
                    block(error);
                }
            }];
        }
    }];
}

- (BOOL)hasStar2KPort {
    return (self.sensor.capabilities & (1 << 0)) != 0;
}

- (BOOL)hasCompressedPixels {
    return (self.sensor.capabilities & (1 << 1)) != 0;   
}

- (BOOL)hasEEPROM {
    return (self.sensor.capabilities & (1 << 2)) != 0;
}

- (BOOL)hasIntegratedGuider {
    return (self.sensor.capabilities & (1 << 3)) != 0;
}

- (BOOL)isInterlaced {
    // todo; get from capabilities
    return [[[self deviceParams] objectForKey:@"interlaced"] boolValue];
}

- (BOOL)isColour {
    return self.sensor.colourMatrix != 0;   // unreliable e.g. M25C reports 0x0fff
}

- (BOOL)hasCooler {
    return (self.sensor.capabilities & (1 << 4)) != 0;
}

- (BOOL)hasShutter {
    return (self.sensor.capabilities & (1 << 5)) != 0;
}

- (NSInteger)temperatureFrequency {
    return 5;
}

- (NSInteger)flushCount {
    const NSInteger flushCount = [[[self deviceParams] objectForKey:@"flush-count"] integerValue];
    // incorporate time since last exposure ?
    return flushCount;
}

- (void)fetchTemperature {
        
    SXCCDIOCoolerCommand* cooler = [[SXCCDIOCoolerCommand alloc] init];
    
    cooler.on = self.temperature > self.targetTemperature;
    cooler.centigrade = self.targetTemperature;
    
    [self.transport submit:cooler block:^(NSError* error) {
        
        if (!error){
            
            self.temperature = cooler.centigrade;
            
            [self.exposureTemperatures addObject:[NSNumber numberWithFloat:self.temperature]];
        }
        
        [self performSelector:_cmd withObject:nil afterDelay:self.temperatureFrequency inModes:@[NSRunLoopCommonModes]];
    }];
}

#pragma mark - Commands

- (void)reset:(void (^)(NSError*))block {
    
    SXCCDIOResetCommand* reset = [[SXCCDIOResetCommand alloc] init];
    
    [self.transport submit:reset block:^(NSError* error){
                
        if (block){
            block(error);
        }
    }];
}

- (void)echoData:(NSData*)data block:(void (^)(NSError*,NSData*))block {

    SXCCDIOEchoCommand* echo = [[SXCCDIOEchoCommand alloc] initWithData:data];
    
    [self.transport submit:echo block:^(NSError* error){
                
        if (block){
            block(error,echo.response);
        }
    }];    
}

- (void)getParams:(void (^)(NSError*,SXCCDProperties* params))block {
    
    SXCCDIOGetParamsCommand* getParams = [[SXCCDIOGetParamsCommand alloc] init];
    
    [self.transport submit:getParams block:^(NSError* error){
        
        if (self.isInterlaced){
            getParams.params.height = getParams.params.height * 2;
            getParams.params.pixelHeight = getParams.params.pixelHeight / 2;
        }

        self.sensor = getParams.params;
        
        if (block){
            block(error,getParams.params);
        }
    }];    
}

- (void)flush:(void (^)(NSError*))block {
    
    SXCCDIOFlushCommand* flush = [[SXCCDIOFlushCommand alloc] init];
    
    [self.transport submit:flush block:^(NSError* error){
                
        if (block){
            block(error);
        }
    }];    
}

- (void)openShutter:(BOOL)open block:(void (^)(NSError*))block {
    
    SXCCDIOShutterCommand* shutter = [[SXCCDIOShutterCommand alloc] init];
    
    shutter.open = open;
    
    [self.transport submit:shutter block:^(NSError* error){
        
        if (block){
            block(error);
        }
    }];
}

- (SXCCDIOExposeCommand*)createExposureCommandWithParams:(CASExposeParams)exp {
    
    SXCCDIOExposeCommand* expose = nil;
    
    if (self.isInterlaced){
        expose = [[SXCCDIOExposeCommandInterlaced alloc] init]; // actually just a clear e.g. start exposure command
    }
    else switch (self.productID) {
        case 805:
            expose = [[SXCCDIOExposeCommandM25C alloc] init]; // special command to handle the dual output registers
            break;
                        
        default:
            expose = [[SXCCDIOExposeCommand alloc] init]; // regular progressive camera
            break;
    }
    
    expose.ms = exp.ms;
    expose.params = exp;
    
    if (self.isInterlaced){
        expose.readPixels = NO; // always use an external timer for interlaced cameras
    }
    else {
        expose.readPixels = (exp.ms < self.temperatureFrequency * 1000);
    }

    return expose;
}

- (void)exposeWithParams:(CASExposeParams)exp type:(CASCCDExposureType)type block:(void (^)(NSError*,CASCCDExposure*image))block {
    
    // create an exposure command object
    SXCCDIOExposeCommand* expose = [self createExposureCommandWithParams:exp];
    
    // record the exposure time
    NSDate* time = [NSDate date];

    // prep the exposure temp array
    self.exposureTemperatures = [NSMutableArray arrayWithCapacity:100];

    // if we've got a cooler, record the start temp rather than waiting for the cooler command to return
    if (self.hasCooler){
        [self.exposureTemperatures addObject:[NSNumber numberWithFloat:self.temperature]];
    }
    
    // block to create the exposure object from the read pixels and call the completion block
    void (^exposureCompleted)(NSError*,NSData*) = ^(NSError* error,NSData* pixels) {
        
        // close the shutter
        if (self.hasShutter){
            [self openShutter:NO block:nil];
        }
        
        CASCCDExposure* exposure = nil;
        if (!error){
            exposure = [CASCCDExposure exposureWithPixels:pixels camera:self params:expose.params time:time];
        }
        
        if (block){
            block(error,exposure);
        }
    };
    
    // block to issue the expose and read pixels commands
    void (^exposePixels)() = ^{
        
        // kick things off by submitting the exposure command
        [self.transport submit:expose block:^(NSError* error){
            
            if (error) {
                exposureCompleted(error,nil);
            }
            else {
                
                if (expose.readPixels){
                    // expose command also read the pixels so jump straight to completion
                    exposureCompleted(error,expose.pixels);
                }
                else {
                    
                    // build and submit a command to read pixels from the ccd
                    if (!self.isInterlaced){
                        
                        // with progressive cameras just read all the pixels in a single block from the pipe
                        SXCCDIOReadCommand* read = [[SXCCDIOReadCommand alloc] init];
                        read.params = expose.params;
                        [self.transport submit:read when:[NSDate dateWithTimeIntervalSinceNow:expose.params.ms/1000.0] block:^(NSError* error){
                            exposureCompleted(error,[expose postProcessPixels:read.pixels]);
                        }];
                    }
                    else {
                        
                        // schedule the read for the exposure end time
                        NSDate* when = [time dateByAddingTimeInterval:expose.params.ms/1000.0];
                        
                        // for interlaced cameras in binning mode read both fields together with no de-interlacing necessary...
                        if (exp.bin.width != 1 || exp.bin.height != 1){
                            
                            SXCCDIOReadFieldCommand* readField = [[SXCCDIOReadFieldCommand alloc] init];
                            readField.params = expose.params;
                            readField.field = kSXCCDIOReadFieldCommandBoth;
                            [self.transport submit:readField when:when block:^(NSError* error){
                                exposureCompleted(error,[expose postProcessPixels:readField.pixels]);
                            }];
                        }
                        else {
                            
                            // ...and in hi-res mode read both fields and then de-interlace in -postProcessPixels:
                            SXCCDIOReadFieldCommand* readField = [[SXCCDIOReadFieldCommand alloc] init];
                            readField.params = expose.params;
                            readField.field = kSXCCDIOReadFieldCommandEven;
                            [self.transport submit:readField when:when block:^(NSError* error){
                                
                                if (error) {
                                    exposureCompleted(error,nil);
                                }
                                else {
                                    
                                    readField.field = kSXCCDIOReadFieldCommandOdd;
                                    [self.transport submit:readField block:^(NSError* error){
                                        exposureCompleted(error,[expose postProcessPixels:readField.pixels]);
                                    }];
                                }
                            }];
                        }
                    }
                }
            }
        }];    
    };
    
    // block to flush any accumulated charge before exposing if required then run the exposure
    __block NSInteger flushCount = self.flushCount;
    void (^__block flushComplete)(NSError*) = ^(NSError* error){
        
        if (error){
            exposureCompleted(error,nil);
        }
        else if (flushCount-- > 0) {
            [self flush:flushComplete];
        }
        else {
            exposePixels();
        }
        flushComplete = nil;
    };
    
    void (^ openShutter)() = ^(){
      
        [self openShutter:YES block:^(NSError *error) {
            
            if (error){
                exposureCompleted(error,nil);
            }
            else {
                flushComplete(nil);
            }
        }];
    };
    
    // open the shutter if required...
    if (self.hasShutter){
        openShutter();
    }
    else {
        // ...otherwise start the exposure process by optionally flushing the charge from the ccd
        flushComplete(nil);
    }
}

#pragma mark - Guider protocol

- (void)pulse:(CASGuiderDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block
{
    if (!self.hasStar2KPort){
        NSLog(@"-pulse:duration:block: %@ doesn't have a STAR2K port",self);
        return;
    }
        
    SXCCDIOGuideCommand* guide = [[SXCCDIOGuideCommand alloc] init];
    
    switch (direction) {
        case kCASGuiderDirection_RAPlus:
            guide.direction = kSXCCDIOGuideCommandWest;
            break;
        case kCASGuiderDirection_RAMinus:
            guide.direction = kSXCCDIOGuideCommandEast;
            break;
        case kCASGuiderDirection_DecPlus:
            guide.direction = kSXCCDIOGuideCommandNorth;
            break;
        case kCASGuiderDirection_DecMinus:
            guide.direction = kSXCCDIOGuideCommandSouth;
            break;
        default:
            if (block){
                block(nil);
            }
            return;
    }

    [self.transport submit:guide block:^(NSError* error){
        
        if (error){
            if (block){
                block(error);
            }
        }
        else {
            
            const double delayInSeconds = durationMS/1000.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                
                guide.direction = kSXCCDIOGuideCommandNone;
                
                [self.transport submit:guide block:^(NSError* error){
                
                    if (block){
                        block(error);
                    }
                }];
            });
        }
    }];
}

@end
