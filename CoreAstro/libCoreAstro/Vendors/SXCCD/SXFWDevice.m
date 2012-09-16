//
//  SXFWDevice.m
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

#import "SXFWDevice.h"
#import "CASIOTransport.h"
#import "CASIOCommand.h"

#pragma mark Commands

@interface SXFWIOCommand : CASIOCommand
@end

@implementation SXFWIOCommand

- (NSInteger) readSize {
    return 2;
}

@end

@interface SXFWIOGetFilterCountCommand : SXFWIOCommand
@property (nonatomic,assign,readonly) uint8_t count;
@end

@implementation SXFWIOGetFilterCountCommand {
    uint8_t _count;
}

- (NSData*)toDataRepresentation {
    uint8_t buffer[2] = {0, 1};
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    uint8_t buffer[2];
    if ([data length] == sizeof(buffer)){
        [data getBytes:buffer length:sizeof(buffer)];
        _count = buffer[0];
    }
    return nil;
}

@end

@interface SXFWIOGetFilterIndexCommand : SXFWIOCommand
@property (nonatomic,assign,readonly) uint8_t index, count;
@end

@implementation SXFWIOGetFilterIndexCommand {
    uint8_t _index, _count;
}

- (NSData*)toDataRepresentation {
    uint8_t buffer[2] = {0, 0};
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    uint8_t buffer[2];
    if ([data length] == sizeof(buffer)){
        [data getBytes:buffer length:sizeof(buffer)];
        _index = buffer[0];
        _count = buffer[1];
    }
    return nil;
}

@end

@interface SXFWIOSetFilterIndexCommand : SXFWIOCommand
@property (nonatomic,assign) uint8_t index;
@end

@implementation SXFWIOSetFilterIndexCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer[2] = {0x80 | self.index, 0 };
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    uint8_t buffer[2];
    if ([data length] == sizeof(buffer)){
        [data getBytes:buffer length:sizeof(buffer)];
        _index = buffer[0];
    }
    return nil;
}

@end

@interface SXFWDevice ()
@end

@implementation SXFWDevice {
    BOOL _connected;
    NSInteger _filterCount;
    NSInteger _currentFilter;
}

#pragma mark - Device

- (id)init
{
    self = [super init];
    if (self) {
        _currentFilter = NSNotFound;
    }
    return self;
}

- (CASDeviceType)type {
    return kCASDeviceTypeFilterWheel;
}

- (NSString*)deviceName {
    return @"Filter Wheel";
}

- (NSString*)vendorName {
    return @"Starlight Xpress";
}

- (void)_getCountUntilCalibrated {
    
    [self getFilterCount:^(NSError* error, NSInteger count) {
        
        if (error){
            _connected = NO;
        }
        else{
            if (count){
                _filterCount = count;
            }
            else {
                [self _getCountUntilCalibrated];
            }
        }
    }];
}

- (void)connect:(void (^)(NSError*))block {
    
    if (_connected){
        if (block){
            block(nil);
        }
    }
    else {
        _connected = YES;
        [self _getCountUntilCalibrated];
    }
}

#pragma mark - Properties

- (NSInteger) filterCount {
    return _filterCount;
}

- (void)setCurrentFilter:(NSInteger)currentFilter {
    if (_currentFilter != currentFilter){
        _currentFilter = currentFilter;
        [self setFilterIndex:_currentFilter block:^(NSError* error) {
            NSLog(@"Setting filter index: %@",error);
        }];
    }
}

#pragma mark - Commands

- (void)getFilterCount:(void (^)(NSError*,NSInteger count))block {
    
    SXFWIOGetFilterCountCommand* getCount = [[SXFWIOGetFilterCountCommand alloc] init];
    
    [self.transport submit:getCount block:^(NSError* error){
        
        if (block){
            block(error,getCount.count);
        }
    }];
}

- (void)getFilterIndex:(void (^)(NSError*,NSInteger index,NSInteger count))block {
    
    SXFWIOGetFilterIndexCommand* getIndex = [[SXFWIOGetFilterIndexCommand alloc] init];
    
    [self.transport submit:getIndex block:^(NSError* error){
        
        if (block){
            block(error,getIndex.index,getIndex.count);
        }
    }];
}

- (void)setFilterIndex:(NSInteger)index block:(void (^)(NSError*))block {
    
    SXFWIOSetFilterIndexCommand* setIndex = [[SXFWIOSetFilterIndexCommand alloc] init];

    setIndex.index = index;
    
    [self.transport submit:setIndex block:^(NSError* error){

        if (block){
            block(error);
        }
    }];
}

@end