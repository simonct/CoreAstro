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

@interface SXCCDDevice ()
@property (nonatomic,strong) SXCCDParams* params;
@property (nonatomic,strong) NSMutableArray* exposureTemperatures;
- (void)fetchTemperature;
@end

@implementation SXCCDDevice

@synthesize temperature, targetTemperature, params, productID, exposureTemperatures;

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

- (void)disconnect
{
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
    
    [self reset:^(NSError* error) {
       
        if (error){
            if (block){
                block(error);
            }
        }
        else {
            
            [self getParams:^(NSError* error, SXCCDParams* params) {
                
                // ignore the read params as they may have been incorrectly set by a firmware upload
                if (!error){
                    
                    NSDictionary* storedParams = [[self deviceParams] objectForKey:@"params"];
                    if (storedParams){
                        
                        self.params.width = [[storedParams objectForKey:@"width"] integerValue];
                        self.params.height = [[storedParams objectForKey:@"height"] integerValue];
                        self.params.bitsPerPixel = [[storedParams objectForKey:@"bits-per-pixel"] integerValue];
                        self.params.pixelWidth = [[storedParams objectForKey:@"pix-width"] floatValue];
                        self.params.pixelHeight = [[storedParams objectForKey:@"pix-height"] floatValue];
                        self.params.horizFrontPorch = [[storedParams objectForKey:@"h-front-porch"] integerValue];
                        self.params.horizBackPorch = [[storedParams objectForKey:@"h-back-porch"] integerValue];
                        self.params.vertFrontPorch = [[storedParams objectForKey:@"v-front-porch"] integerValue];
                        self.params.vertBackPorch = [[storedParams objectForKey:@"v-back-porch"] integerValue];
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
    return (self.params.capabilities & (1 << 0)) != 0;
}

- (BOOL)hasCompressedPixels {
    return (self.params.capabilities & (1 << 1)) != 0;   
}

- (BOOL)hasEEPROM {
    return (self.params.capabilities & (1 << 2)) != 0;
}

- (BOOL)hasIntegratedGuider {
    return (self.params.capabilities & (1 << 3)) != 0;
}

- (BOOL)isColour {
    return self.params.colourMatrix != 0;   
}

- (BOOL)hasCooler {
    return [[[self deviceParams] objectForKey:@"has-cooler"] boolValue];
}

- (NSInteger)temperatureFrequency {
    return 5;
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
        
        [self performSelector:_cmd withObject:nil afterDelay:self.temperatureFrequency];
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

- (void)getParams:(void (^)(NSError*,SXCCDParams* params))block {
    
    SXCCDIOGetParamsCommand* getParams = [[SXCCDIOGetParamsCommand alloc] init];
    
    [self.transport submit:getParams block:^(NSError* error){
                
        self.params = getParams.params;
        
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

- (void)exposeWithParams:(CASExposeParams)exp block:(void (^)(NSError*,CASCCDExposure*image))block {
    
    SXCCDIOExposeCommand* expose = [[SXCCDIOExposeCommand alloc] init];
    
    expose.ms = exp.ms;
    expose.params = exp;
    expose.readPixels = (exp.ms < self.temperatureFrequency * 1000);
    
    NSDate* time = [NSDate date];

    void (^complete)(NSError*,NSData*) = ^(NSError* error,NSData* pixels) {
        
        CASCCDExposure* exposure = nil;
        if (!error){
            exposure = [CASCCDExposure exposureWithPixels:pixels camera:self params:exp time:time];
        }
        
        if (block){
            block(error,exposure);
        }
    };
    
    self.exposureTemperatures = [NSMutableArray arrayWithCapacity:100];
    
    [self.transport submit:expose block:^(NSError* error){
        
        if (error) {
            if (block){
                block(error,nil);
            }
        }
        else {
            
            if (expose.readPixels){
                complete(error,expose.pixels);
            }
            else {
                
                SXCCDIOReadCommand* read = [[SXCCDIOReadCommand alloc] init];
                read.params = exp;
                [self.transport submit:read when:[NSDate dateWithTimeIntervalSinceNow:exp.ms/1000.0] block:^(NSError* error){
                    complete(error,read.pixels);
                }];
            }
        }
    }];    
}

@end
