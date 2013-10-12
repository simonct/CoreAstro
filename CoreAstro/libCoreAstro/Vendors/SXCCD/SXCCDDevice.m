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
@property (nonatomic,assign) BOOL shutterOpen;
@property (nonatomic,strong) SXCCDProperties* sensor;
@property (nonatomic,strong) NSMutableArray* exposureTemperatures;
@property (nonatomic,strong) NSDate* exposureCompletionDate;
@property (nonatomic,strong) NSDate* lastCompletionDate;
@property (nonatomic,copy) void (^exposureCompletion)(NSError*,CASCCDExposure*image);
@property (nonatomic,strong) SXCCDIOFlushCommand* flushCommand;
@property (nonatomic,strong) SXCCDIOExposeCommand* exposureCommand;
- (void)fetchTemperature;
@end

@implementation SXCCDDevice

@synthesize temperature, targetTemperature, sensor, productID, exposureTemperatures;

#pragma mark - Properties

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

- (NSInteger)maximumFlushInterval {
    return 3;
}

- (NSInteger)flushCount {
    const NSInteger flushCount = [[[self deviceParams] objectForKey:@"flush-count"] integerValue];
    // incorporate time since last exposure ?
    return flushCount;
}

- (void)fetchTemperature {
    
    if (!self.connected){
        return;
    }
    
    // this is a bit rubbish but I think one of these slips in between the flush and read commands at the end of
    // an externally timed exposure and really messes things up.
    if (self.exposureCompletionDate){
        if ([self.exposureCompletionDate timeIntervalSinceReferenceDate] - [NSDate timeIntervalSinceReferenceDate] < 10){
            NSLog(@"Ignoring fetch temp command as we're close to exposure completion");
            [self performSelector:_cmd withObject:nil afterDelay:self.temperatureFrequency inModes:@[NSRunLoopCommonModes]];
            return;
        }
    }
    
    SXCCDIOCoolerCommand* cooler = [[SXCCDIOCoolerCommand alloc] init];
    
    cooler.on = self.temperature >= self.targetTemperature - 1;
    cooler.centigrade = self.targetTemperature;
    
    __weak SXCCDDevice* weakDevice = self;
    
    [self.transport submit:cooler block:^(NSError* error) {
        
        if (self.connected){
        
            SXCCDDevice* strongDevice = weakDevice;
            if (strongDevice){
                
                if (!error){
                    
                    strongDevice.temperature = cooler.centigrade;
                    
                    [strongDevice.exposureTemperatures addObject:[NSNumber numberWithFloat:strongDevice.temperature]];
                }
                
                [strongDevice performSelector:_cmd withObject:nil afterDelay:strongDevice.temperatureFrequency inModes:@[NSRunLoopCommonModes]];
            }
        }
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
        
        if (!error){
            
            if (self.isInterlaced){
                getParams.params.height = getParams.params.height * 2;
                getParams.params.pixelHeight = getParams.params.pixelHeight / 2;
            }
            
//            if (self.productID == 806){ // M26C
//                getParams.params.height *= 2;
//            }
            
            self.sensor = getParams.params;
        }
        
        if (block){
            block(error,getParams.params);
        }
    }];    
}

- (void)flushField:(SXCCDIOField)field wipe:(BOOL)wipe block:(void (^)(NSError*))block {
    
    SXCCDIOFlushCommand* flush = [[SXCCDIOFlushCommand alloc] init];
    
    flush.field = field;
    flush.noWipe = !wipe;
    
    [self.transport submit:flush block:^(NSError* error){
                
        if (block){
            block(error);
        }
    }];    
}

- (void)openShutter:(BOOL)open block:(void (^)(NSError*))block {
    
    SXCCDIOShutterCommand* shutter = [[SXCCDIOShutterCommand alloc] init];
    
    shutter.open = open;
    
    // actually, should check the return value...
    self.shutterOpen = open;

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
//        case 806:
//            expose = [[SXCCDIOExposeCommandM26C alloc] init]; // special command to handle the rotated/interleaved pixel structure
//            break;
        default:
            expose = [[SXCCDIOExposeCommand alloc] init]; // regular progressive camera
            break;
    }
    
    expose.ms = exp.ms;
    expose.params = exp;
    
    // by default, exposures over 5 seconds use external timing so that we can cancel them easily
    expose.latchPixels = (exp.ms > 5000);

    if (self.isInterlaced){
        expose.readPixels = NO; // always use an external timer for interlaced cameras
    }
    else {
        expose.readPixels = (exp.ms < self.temperatureFrequency * 1000);
    }

    return expose;
}


- (void)exposeWithParams:(CASExposeParams)exp type:(CASCCDExposureType)type block:(void (^)(NSError*,CASCCDExposure*image))block {
    
    // can only have one exposure active at a time
    if (self.exposureCommand){
        if (block){
            block([NSError errorWithDomain:NSStringFromClass([self class]) code:1 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Exposure already in progress"}],nil);
        }
        return;
    }
    
    // grab the completion block
    self.exposureCompletion = block;
    
    // create an exposure command object
    self.exposureCommand = [self createExposureCommandWithParams:exp];
    
    // prep the exposure temp array
    self.exposureTemperatures = [NSMutableArray arrayWithCapacity:100];

    // if we've got a cooler, record the start temp rather than waiting for the cooler command to return
    if (self.hasCooler){
        [self.exposureTemperatures addObject:[NSNumber numberWithFloat:self.temperature]];
    }
    
    // helper block to optionally flush any accumulated charge before starting the exposure
    // if we're externally timing then set the flushCount to at least one to clear the ccd first
    NSInteger initialFlushCount = MAX(self.flushCount, self.exposureCommand.latchPixels ? 1 : 0);
    
    // always flush the camera if the last exposure was more than 3 seconds ago
    if (!initialFlushCount && [[NSDate date] timeIntervalSinceDate:self.lastCompletionDate] > self.maximumFlushInterval){
        initialFlushCount = 1;
    }
    initialFlushCount = 1;
    
    // record the exposure start time
    NSDate* time = [NSDate date];
    
    // helper block to create the exposure object from the exposure's pixels and then call the completion block
    void (^exposureCompleted)(NSError*,NSData*) = ^(NSError* error,NSData* pixels) {
        
        // record the approximate end time of the last exposure
        self.lastCompletionDate = [NSDate date];
        
        // allow fetch temperature commands to run again
        self.exposureCompletionDate = nil;
        
        // close the shutter
        if (self.shutterOpen){
            [self openShutter:NO block:nil];
        }
        
        CASCCDExposure* exposure = nil;
        if (!error){
            exposure = [CASCCDExposure exposureWithPixels:pixels camera:self params:self.exposureCommand.params time:time];
        }
        
        if (self.exposureCompletion){
            self.exposureCompletion(error,exposure);
            self.exposureCompletion = nil;
        }
        
        self.flushCommand = nil;
        self.exposureCommand = nil;
    }; // end exposureCompleted
    
    // helper block to issue the expose/latch and read pixels commands
    void (^exposePixelsAndCompleteExposure)(SXCCDIOField,NSDate*,SXCCDIOExposeCommand*,void (^)(NSError*,NSData*)) = ^(SXCCDIOField field,NSDate* when,SXCCDIOExposeCommand* exposureCommand,void (^completion)(NSError*,NSData*)){
        
        // record the completion time - we use this in -fetchTemperature to prevent any
        // temp commands with interfering with the flush-read sequence (not 100%, need something better)
        self.exposureCompletionDate = when;
        
        void (^completeExposure)() = ^(){
            
            // set the field
            exposureCommand.field = field;

            // kick things off by submitting the exposure command
            [self.transport submit:exposureCommand when:when block:^(NSError* error){
                
                if (error) {
                    completion(error,nil);
                }
                else {
                    
                    if (exposureCommand.readPixels){
                        // expose command also read the pixels so jump straight to completion
                        completion(error,exposureCommand.pixels);
                    }
                    else {
                        
                        // schedule the read for the exposure end time unless we're in latch mode in which case we're
                        // being externally timed and need to execute the command immediately
                        NSDate* when = nil;
                        if (!exposureCommand.latchPixels){
                            when = [time dateByAddingTimeInterval:exposureCommand.params.ms/1000.0];
                        }
                        else {
                            NSLog(@"Elapsed time %f",[[NSDate date] timeIntervalSinceDate:time]);
                        }
                        
                        // todo; record the actual exposure time to account for inaccuracies in external timing
                        
                        // build and submit a command to read pixels from the ccd
                        if (!self.isInterlaced){
                            
                            // with progressive cameras just read all the pixels in a single block from the pipe
                            SXCCDIOReadCommand* read = [[SXCCDIOReadCommand alloc] init];
                            read.params = exposureCommand.params;
                            [self.transport submit:read when:when block:^(NSError* error){
                                completion(error,[exposureCommand postProcessPixels:read.pixels]);
                            }];
                        }
                        else {
                            
                            // for interlaced cameras in binning mode read both fields together with no de-interlacing necessary...
                            if (exp.bin.width != 1 || exp.bin.height != 1){
                                
                                SXCCDIOReadFieldCommand* readField = [[SXCCDIOReadFieldCommand alloc] init];
                                readField.params = exposureCommand.params;
                                readField.field = kSXCCDIOFieldBoth;
                                [self.transport submit:readField when:when block:^(NSError* error){
                                    completion(error,[exposureCommand postProcessPixels:readField.pixels]);
                                }];
                            }
                            else {
                                
                                // ...and in hi-res mode read both fields and then de-interlace in -postProcessPixels:
                                SXCCDIOReadFieldCommand* readField = [[SXCCDIOReadFieldCommand alloc] init];
                                readField.params = exposureCommand.params;
                                readField.field = field;
                                [self.transport submit:readField when:when block:^(NSError* error){
                                    completion(error,nil);
                                }];
                            }
                        }
                    }
                }
            }]; // end submit
            
        }; // end completeExposure
        
        // if we're internally timed, issue the exposure command now
        // also if it's an interlaced exposure as this has it's own mechanism todo; express this more clearly
        if (!when /*|| [self.exposureCommand isKindOfClass:[SXCCDIOExposeCommandInterlaced class]]*/){
            completeExposure();
        }
        else {
            
            // if we're externally timed schedule a flush command for shortly before the exposure
            // completes to clear the vertical registers before reading the pixels (currently at T-2)
            self.flushCommand = [[SXCCDIOFlushCommand alloc] init];
            
            self.flushCommand.noWipe = YES; // clear the vertical registers in preparation for reading the pixels
            
            [self.transport submit:self.flushCommand when:[NSDate dateWithTimeInterval:-2 sinceDate:when] block:^(NSError* error){
                
                if (error) {
                    completion(error,nil);
                }
                else {
                    completeExposure();
                }
            }]; // end submit
        }
        
    }; // end exposePixelsAndCompleteExposure
    
    void (^__block clearChargeAndExpose)(SXCCDIOExposeCommand*,SXCCDIOField,NSInteger,NSInteger,void (^completion)(NSError*,NSData*));
    void (^__block clearChargeAndExpose2)(SXCCDIOExposeCommand*,SXCCDIOField,NSInteger,NSInteger,void (^completion)(NSError*,NSData*));
    clearChargeAndExpose = ^(SXCCDIOExposeCommand* exposureCommand,SXCCDIOField field,NSInteger ms,NSInteger flushCount,void (^completion)(NSError*,NSData*)){
                
        if (flushCount-- > 0) {
            [self flushField:field wipe:YES block:^(NSError *error) {
                clearChargeAndExpose2(exposureCommand,field,ms,flushCount,completion);
            }];
        }
        else {
            
            // if we're externally timing then the exposure time starts with the flush and 
            // we set a timer to fire at the appropriate time to latch and read the pixels
            if (exposureCommand.latchPixels && ms > 1){
                exposePixelsAndCompleteExposure(field,[NSDate dateWithTimeIntervalSinceNow:(ms / 1000.0)],exposureCommand,completion);
            }
            else {
                // we're using internal timing so start exposing now
                exposePixelsAndCompleteExposure(field,nil,exposureCommand,completion);
            }
//            clearChargeAndExpose2 = nil; // crashing on second call but probably leaking now
        }
    }; // end clearChargeAndExpose
    clearChargeAndExpose2 = clearChargeAndExpose;
    
    // entry point to actually running an exposure
    void (^startExposureSequence)(SXCCDIOExposeCommand*) = ^(SXCCDIOExposeCommand* exposureCommand) {
        
        // unbinned interlaced cameras require special handling
        if (self.isInterlaced && exp.bin.width == 1 && exp.bin.height == 1){
            
            const NSInteger flushOnce = 1;
            const NSInteger exposureTime = exp.ms;
            const NSInteger exposureStrategyCutoff = 1000; // or 5000 for M26C
            
            // clear both fields first ??
            
            void (^combineAndComplete)(NSError*,NSData*,NSData*) = ^(NSError* error, NSData* evenField, NSData* oddField){
                NSMutableData* combined = [NSMutableData dataWithLength:[evenField length] + [oddField length]];
                if (!combined){
                    // error
                }
                else {
                    memcpy([combined mutableBytes], [evenField bytes], [evenField length]);
                    memcpy([combined mutableBytes] + [evenField length], [oddField bytes], [oddField length]);
                }
                exposureCompleted(error,[exposureCommand postProcessPixels:combined]);
            };
            
            if (exposureTime < exposureStrategyCutoff){
                
                exposureCommand.latchPixels = NO;
                exposureCommand.readPixels = YES;
                
                // clear and expose EVEN
                clearChargeAndExpose(exposureCommand,kSXCCDIOFieldEven,exposureTime,flushOnce,^(NSError* error,NSData* evenField){
                    
                    // clear and expose ODD
                    clearChargeAndExpose(exposureCommand,kSXCCDIOFieldOdd,exposureTime,flushOnce,^(NSError* error,NSData* oddField){
                        
                        // combine the fields, post process and complete
                        combineAndComplete(error,evenField,oddField);
                    });
                });
            }
            else {
                
                __block CASExposeParams params = exposureCommand.params;
                params.ms = 0;
                exposureCommand.params = params;
                exposureCommand.latchPixels = YES;
                exposureCommand.readPixels = YES;
                
                // do a zero second clear, latch, read EVEN and discard the pixels
                clearChargeAndExpose(exposureCommand,kSXCCDIOFieldEven,0,flushOnce,^(NSError* error,NSData* ignored){
                    
                    // reset the EVEN field
                    [self flushField:kSXCCDIOFieldEven wipe:YES block:^(NSError *error) {

                        // start a latched ODD exposure for the required exposure time
                        params.ms = exposureTime;
                        exposureCommand.params = params;
                        exposePixelsAndCompleteExposure(kSXCCDIOFieldOdd,[NSDate dateWithTimeIntervalSinceNow:(exposureTime / 1000.0)],exposureCommand,^(NSError* error,NSData* oddField){
                            
                            // finally, do an immediate EVEN latch and read
                            params.ms = 0;
                            exposureCommand.params = params;
                            exposePixelsAndCompleteExposure(kSXCCDIOFieldEven,nil,exposureCommand,^(NSError* error,NSData* evenField){
                                
                                // combine the fields, post process and complete
                                combineAndComplete(error,evenField,oddField);
                            });
                        });
                    }];
                });
            }
        }
        else {
            
            // the entirety of progressive camera handling is here; flush, expose and read whole frame - that's it
            clearChargeAndExpose(exposureCommand,kSXCCDIOFieldBoth,exp.ms,initialFlushCount,exposureCompleted);
        }
    }; // startExposureSequence
    
    // start off by opening the shutter if required...
    if (self.hasShutter && (type == kCASCCDExposureLightType || type == kCASCCDExposureFlatType)){

        [self openShutter:YES block:^(NSError *error) {
            
            if (error){
                exposureCompleted(error,nil);
            }
            else {
                startExposureSequence(self.exposureCommand);
            }
        }];
    }
    else {
        
        startExposureSequence(self.exposureCommand);
    }
}

- (void)cancelExposure {
    
    // remove expose command from the ioq if we're using external timing
    if (self.exposureCommand.latchPixels){
        
        [self.transport remove:self.flushCommand];
        self.flushCommand = nil;
        
        [self.transport remove:self.exposureCommand];
        self.exposureCommand = nil;

        // call the completion block
        if (self.exposureCompletion){
            self.exposureCompletion(nil,nil); // need to indicate cancelled somehow to block ? nil, nil enough ?
            self.exposureCompletion = nil;
        }
    }
    
    // re-enable cooler commands
    self.exposureCompletionDate = nil;
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
