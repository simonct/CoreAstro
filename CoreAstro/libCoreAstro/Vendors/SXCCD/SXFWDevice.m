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
@end

@interface SXFWIOGetFilterCountCommand : SXFWIOCommand
@property (nonatomic,assign,readonly) uint8_t count;
@end

@implementation SXFWIOGetFilterCountCommand {
    uint8_t _count;
}

- (NSData*)toDataRepresentation {
    uint8_t buffer[2] = {1, 0};
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
    uint8_t buffer[2] = {0, 0x80 | self.index };
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

@interface SXFWDeviceCallback : NSObject
@property (nonatomic,copy) id block;
- (void)invokeWithResult:(uint16_t)result error:(NSError*)error;
@end
@implementation SXFWDeviceCallback
- (void)invokeWithResult:(uint16_t)result error:(NSError*)error {}
@end

@interface SXFWDeviceCountFilterCallback : SXFWDeviceCallback
@end
@implementation SXFWDeviceCountFilterCallback
- (void)invokeWithResult:(uint16_t)result error:(NSError*)error {
    if (self.block){
        void (^callback)(NSError*,NSInteger) = self.block;
        callback(error,result >> 8);
    }
}
@end

@interface SXFWDevice ()
@property (nonatomic,assign) NSUInteger filterCount;
@end

@implementation SXFWDevice {
    BOOL _connected;
    NSUInteger _filterCount;
    NSInteger _currentFilter;
    NSMutableArray* _completionStack;
}

@synthesize filterCount = _filterCount;
@synthesize currentFilter = _currentFilter;

#pragma mark - Device

- (id)init
{
    self = [super init];
    if (self) {
        _currentFilter = NSNotFound;
        _completionStack = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (NSString*)deviceName {
    return @"Filter Wheel";
}

- (NSString*)vendorName {
    return @"Starlight Xpress";
}

- (void)_getCountUntilCalibrated {
    
    if (!self.filterCount){
        
        [self getFilterCount:^(NSError* error, NSInteger count) {
            
            if (error){
                _connected = NO;
            }
            else{
                if (count){
                    self.filterCount = count;
                }
                else {
                 //   [self _getCountUntilCalibrated];
                }
            }
        }];
    }
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

- (NSInteger)currentFilter {
    return _currentFilter;
}

- (void)setCurrentFilter:(NSInteger)currentFilter {
    if (_currentFilter != currentFilter){
        _currentFilter = currentFilter;
        [self setFilterIndex:_currentFilter block:^(NSError* error) {
            NSLog(@"Setting filter index: %@",error);
        }];
    }
}

- (NSUInteger)filterCount {
    return _filterCount;
}

#pragma mark - Commands

- (void)getFilterCount:(void (^)(NSError*,NSInteger count))block {
    
    SXFWIOGetFilterCountCommand* getCount = [[SXFWIOGetFilterCountCommand alloc] init];
    
    SXFWDeviceCountFilterCallback* callback = [[SXFWDeviceCountFilterCallback alloc] init];
    callback.block = block;
    [_completionStack addObject:callback];
    
    [self.transport submit:getCount block:^(NSError* error){
        
        if (error){
            block(error,0);
            [_completionStack removeObject:callback];
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

#pragma mark HID Transport

- (void)receivedInputReport:(NSData*)data {
    
    NSLog(@"receivedInputReport: %@",data);
    
    uint16_t result;
    if ([data length] == sizeof(result)){
        [data getBytes:&result length:sizeof(result)];
        SXFWDeviceCallback* callback = [_completionStack lastObject];
        if (callback){
            [callback invokeWithResult:result error:nil];
            [_completionStack removeLastObject];
        }
    }
    else {
        NSLog(@"Got input report of %ld bytes",[data length]);
    }
}

@end