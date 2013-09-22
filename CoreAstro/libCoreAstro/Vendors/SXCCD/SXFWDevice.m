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
@end

@implementation SXFWIOGetFilterCountCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer[2] = {1, 0};
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

@end

@interface SXFWIOGetFilterIndexCommand : SXFWIOCommand
@property (nonatomic,assign,readonly) uint8_t index, count;
@end

@implementation SXFWIOGetFilterIndexCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer[2] = {0, 0};
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

@end

@interface SXFWIOSetFilterIndexCommand : SXFWIOCommand
@property (nonatomic,assign) uint8_t index;
@end

@implementation SXFWIOSetFilterIndexCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer[2] = { 0x80 | self.index + 1 , 0 }; // our index is 0-based but the filter wheel is 1-based
    NSData* msg = [NSData dataWithBytes:buffer length:sizeof(buffer)];
//    NSLog(@"SXFWIOSetFilterIndexCommand: %@",msg);
    return msg;
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
        void (^callback)(NSError*,NSInteger,NSInteger) = self.block;
        callback(error,result >> 8,result & 0x00ff);
    }
}
@end

@interface SXFWDevice ()
@property (nonatomic,assign) BOOL moving;
@property (nonatomic,assign) NSUInteger filterCount;
@property (nonatomic,copy) void (^completionBlock)(NSError*);
@end

@implementation SXFWDevice {
    BOOL _connected;
    BOOL _settingFilter;
    BOOL _moving;
    NSUInteger _filterCount;
    NSInteger _currentFilter;
    NSMutableArray* _completionStack;
}

@synthesize moving = _moving;
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

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (NSString*)deviceName {
    return @"SX Filter Wheel";
}

- (NSString*)vendorName {
    return @"Starlight Xpress";
}

- (void)_updateCurrentFilterIndex:(NSInteger)index {
    
    [self willChangeValueForKey:@"currentFilter"];
    if (index > 0){
        _currentFilter = index - 1;
    }
    else {
        _currentFilter = NSNotFound;
    }
    [self didChangeValueForKey:@"currentFilter"];
}

- (void)_pollCurrentFilter {
    
    if (!_connected){
        return;
    }

    [self getFilterIndex:^(NSError *error, NSInteger count, NSInteger index) {
        
        if (error){
            _connected = NO;
        }
        else {
            
            [self _updateCurrentFilterIndex:index];
            
            [self performSelector:_cmd withObject:nil afterDelay:1]; // only while index == 0 ?
        }
    }];
}

- (void)_getCountUntilCalibrated {
    
    if (!_connected){
        return;
    }
    
    // need to give up after a certain amount of time - 10s ?
    
    [self getFilterCount:^(NSError* error, NSInteger count, NSInteger index) {
        
        if (error){
            _connected = NO;
            if (self.completionBlock){
                self.completionBlock(error);
            }
        }
        else{
            
            if (count){
                
                [self _pollCurrentFilter];
                
                if (self.completionBlock){
                    self.completionBlock(nil);
                }
            }
            else{
                [self performSelector:_cmd withObject:nil afterDelay:0.5];
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
        self.completionBlock = block;
        _connected = YES;
        [self _getCountUntilCalibrated];
    }
}

- (void)disconnect {
    [super disconnect];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - Properties

- (NSInteger)currentFilter {
    return _settingFilter ? NSNotFound : _currentFilter;
}

- (void)setCurrentFilter:(NSInteger)currentFilter {
    
//    NSLog(@"setCurrentFilter: %ld",currentFilter);
    
    if (_currentFilter != currentFilter){

        self.moving = YES;
        
        if (_settingFilter){
            NSLog(@"Attempt to set filter index to while already setting it");
        }
        else {
            
            _settingFilter = YES;
            
            __weak SXFWDevice* weakDev = self;
            [self setFilterIndex:currentFilter block:^(NSError* error) {

                SXFWDevice* strongDev = weakDev;
                if (error){
                    NSLog(@"Setting filter index: error=%@",error);
                }
                else {
                    if (strongDev){
                        strongDev->_currentFilter = currentFilter;
                    }
                }
                if (strongDev){
                    strongDev->_settingFilter = NO;
                }
            }];
        }
    }
}

- (NSUInteger)filterCount {
    return _filterCount;
}

#pragma mark - Commands

- (void)getFilterCount:(void (^)(NSError*,NSInteger count,NSInteger index))block {
    
    SXFWIOGetFilterCountCommand* getCount = [[SXFWIOGetFilterCountCommand alloc] init];
    
    SXFWDeviceCountFilterCallback* callback = [[SXFWDeviceCountFilterCallback alloc] init];
    callback.block = block;
    [_completionStack addObject:callback];
    
    [self.transport submit:getCount block:^(NSError* error){
        
        if (error){
            block(error,0,0);
        }
        else {
            block(nil,self.filterCount,self.currentFilter);
        }
    }];
}

- (void)getFilterIndex:(void (^)(NSError*,NSInteger count,NSInteger index))block {
    
    SXFWIOGetFilterIndexCommand* getIndex = [[SXFWIOGetFilterIndexCommand alloc] init];
    
    SXFWDeviceCountFilterCallback* callback = [[SXFWDeviceCountFilterCallback alloc] init];
    callback.block = block;
    [_completionStack addObject:callback];

    [self.transport submit:getIndex block:^(NSError* error){
        
        if (error){
            block(error,0,0);
        }
    }];
}

- (void)setFilterIndex:(NSInteger)index block:(void (^)(NSError*))block {
    
//    NSLog(@"setFilterIndex: %ld",(long)index);
    
    SXFWIOSetFilterIndexCommand* setIndex = [[SXFWIOSetFilterIndexCommand alloc] init];

    setIndex.index = index;
    
    [self.transport submit:setIndex block:^(NSError* error){

        if (block){
            block(error);
        }
    }];
}

#pragma mark HID Transport

- (void)updateStateFromReport:(uint16_t)report {
    
    [self willChangeValueForKey:@"filterCount"];
    [self willChangeValueForKey:@"currentFilter"];
    [self willChangeValueForKey:@"moving"];
    _filterCount = report >> 8;
    const NSInteger index = report & 0x00ff;
    [self _updateCurrentFilterIndex:index];
    _moving = (index == 0);
    [self didChangeValueForKey:@"filterCount"];
    [self didChangeValueForKey:@"currentFilter"];
    [self didChangeValueForKey:@"moving"];
}

- (void)receivedInputReport:(NSData*)data {
    
//    NSLog(@"-[SXFWDevice receivedInputReport]: %@",data);
    
    uint16_t result;
    if ([data length] == sizeof(result)){
        
        [data getBytes:&result length:sizeof(result)];
        [self updateStateFromReport:result];
        
        SXFWDeviceCallback* callback = [_completionStack count] ?  [_completionStack objectAtIndex:0] : nil;
        if (callback){
            [callback invokeWithResult:result error:nil];
            [_completionStack removeObject:callback];
        }
    }
    else {
        NSLog(@"Got input report of %ld bytes",[data length]);
    }
}

@end