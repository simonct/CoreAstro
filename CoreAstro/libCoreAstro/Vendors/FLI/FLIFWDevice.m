//
//  FLIFWDevice.m
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

#import "FLIFWDevice.h"
#import "FLISDK.h"
#import "libfli.h"

@interface FLIFWDevice ()
@property (copy) NSString* fli_ident;
@property (copy) NSString* fli_path;
@property (copy) NSString* fli_model;
@property (copy) NSString* fli_serial;
@end

@implementation FLIFWDevice {
    flidev_t _dev;
    BOOL _connected;
    BOOL _moving;
    NSUInteger _filterCount;
}

- (instancetype)initWithId:(NSString*)ident path:(NSString*)path
{
    self = [super init];
    if (self) {
        _dev = FLI_INVALID_DEVICE;
        self.fli_path = path;
        self.fli_ident = ident;
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
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

- (void)connect:(void (^)(NSError*))block
{
    if (_connected){
        if (block){
            block(nil);
        }
    }
    else {
        
        dispatch_async([FLISDK q], ^{
            
            const long status = FLIOpen(&_dev, (char*)[self.fli_path UTF8String], FLIDOMAIN_USB | FLIDEVICE_FILTERWHEEL);
            if (status != 0){
                NSLog(@"FLIFWDevice, FLIOpen: %ld",status);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block){
                        block([NSError errorWithDomain:@"FLI" code:status userInfo:nil]);
                    }
                });
            }
            else {
                
                _connected = YES;
                
                const int BUFSZ = 1024;
                char buff[BUFSZ];
                
                if (FLIGetModel(_dev, buff, BUFSZ) == 0){
                    self.fli_model = [NSString stringWithUTF8String:buff];
                }
                
                if (FLIGetSerialString(_dev, buff, BUFSZ) == 0){
                    self.fli_serial = [NSString stringWithUTF8String:buff];
                }
                
                long count;
                if (FLIGetFilterCount(_dev,&count) == 0) {
                    [self willChangeValueForKey:@"filterCount"];
                    _filterCount = count;
                    [self didChangeValueForKey:@"filterCount"];
                }
                
                // FLISetFilterPos(_dev,0);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block){
                        block(nil);
                    }
                });
            }
        });
    }
}

- (void)disconnect
{
    if (_dev){
        dispatch_sync([FLISDK q], ^{
            FLIClose(_dev);
        });
        _dev = FLI_INVALID_DEVICE;
    }
}

- (BOOL)moving
{
    return _moving;
}

- (NSUInteger)filterCount
{
    return _filterCount;
}

- (NSInteger)currentFilter
{
    __block long filter = NSNotFound;
    dispatch_sync([FLISDK q], ^{
        FLIGetFilterPos(_dev,&filter);
    });
    return filter;
}

- (void)setCurrentFilter:(NSInteger)currentFilter
{
    _moving = YES;
    dispatch_sync([FLISDK q], ^{
        FLISetFilterPos(_dev,currentFilter); // this blocks
    });
    _moving = NO;
}

@end
