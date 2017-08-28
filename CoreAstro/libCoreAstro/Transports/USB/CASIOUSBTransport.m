//
//  CASIOUSBTransport.m
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

#import "CASIOUSBTransport.h"
#import "BusProberSharedFunctions.h"

@interface CASIOUSBTransport ()
@property (nonatomic,assign) IOCFPlugInInterface** plugin;
@property (nonatomic,assign) IOUSBInterfaceRef interface;
@property (nonatomic,assign) UInt8 inPipe, outPipe;
@property (nonatomic,assign) UInt16 inMaxSize, outMaxSize;
- (void)clearPipeStall;
@end

NSString* const kCASIOUSBTransportNoDataTimeoutDefaultsKey = @"CASIOUSBTransportNoDataTimeout";
NSString* const kCASIOUSBTransportCompletionTimeoutDefaultsKey = @"CASIOUSBTransportCompletionTimeout";

@implementation CASIOUSBTransport

@synthesize plugin, interface, inPipe, outPipe, inMaxSize, outMaxSize;

+ (void)initialize {
    if (self == [CASIOUSBTransport class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [NSNumber numberWithInteger:30 * 1000],kCASIOUSBTransportNoDataTimeoutDefaultsKey,
                                                                 [NSNumber numberWithInteger:30 * 1000],kCASIOUSBTransportCompletionTimeoutDefaultsKey,
                                                                 nil]];
    }
}

- (CASIOTransportType)type {
    return kCASTransportTypeUSB;
}

- (id)initWithPluginInterface:(IOCFPlugInInterface**)plugin_ {
    
    self = [super init];
    if (self){
        
        self.plugin = plugin_;
        if (self.plugin){
            (*self.plugin)->AddRef(self.plugin);
        }

        if ([self connect] != nil){
            self = nil;
        }
    }
    
    if (self && !self->interface){
        self = nil;
    }
    return self;
}

- (void)dealloc {
    [self disconnect];
    if (plugin){
        (*plugin)->Release(plugin);
        plugin = nil;
    }
}

- (NSString*) location {
    return [NSString stringWithFormat:@"USB[0x%lx:%ld]",(long)self.bus,self.address];
}

- (void)clearPipeStall:(UInt8)pipe {
    if (self->interface){
        const IOReturn result = (*self->interface)->ClearPipeStallBothEnds(self->interface,pipe);
        if (result != kIOReturnSuccess){
            NSLog(@"ClearPipeStallBothEnds %d: %08x (%s)",pipe,result,USBErrorToString(result));
        }
    }
}

- (void)clearPipeStall {
    [self clearPipeStall:self.inPipe];    
    [self clearPipeStall:self.outPipe];    
}

- (NSError*)connect {
    
    IOReturn result = kIOReturnSuccess;
    
    if (!self->interface){
        
        IOUSBInterfaceRef intf = nil;
        result = (*self.plugin)->QueryInterface(self.plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID300), (LPVOID)&intf);
        verify_noerr( result );
        if (result == kIOReturnSuccess){
            
            UInt8 numPipes;
            result = (*intf)->GetNumEndpoints(intf, &numPipes);
            verify_noerr( result );
            
            if (result == kIOReturnSuccess && numPipes > 0){
                
                result = (*intf)->USBInterfaceOpen(intf);
                verify_noerr( result );
                
                if (result == kIOReturnSuccess){
                    
                    for (UInt8 i = 1; i <= numPipes; i++) {
                        
                        UInt16 maxPacketSize;
                        UInt8 direction, number, transferType, interval;
                        IOReturn result = (*intf)->GetPipeProperties(intf, i, &direction, &number, &transferType, &maxPacketSize, &interval);
                        verify_noerr( result );
                        
                        if (result == kIOReturnSuccess){
                            
                            if (transferType == kUSBBulk){
                                
                                if ((direction == kUSBIn) && !self.inPipe){
                                    self.inPipe = i;
                                    self.inMaxSize = maxPacketSize;
                                }
                                
                                if ((direction == kUSBOut) && !self.outPipe){
                                    self.outPipe = i;
                                    self.outMaxSize = maxPacketSize;
                                }
                            }
                        }
                    }
                    if (self.inPipe && self.outPipe){
                        self->interface = intf;
                    }
                    else {
                        (*intf)->USBInterfaceClose(intf);
                    }
                }
            }
        }
    }
    
    return result ? [NSError errorWithDomain:@"CASIOUSBTransport" code:result userInfo:nil] : nil;
}

- (void)disconnect {
    if (self->interface){
        (*self->interface)->USBInterfaceClose(self->interface);
        (*self->interface)->Release(self->interface);
        self->interface = nil;
    }
}

- (NSError*)send:(NSData*)data {
    
    NSError* error = nil;
    
    if ([data length]){
        
        const IOReturn result = (*self->interface)->WritePipeTO(self->interface,self.outPipe,(void*)[data bytes],(UInt32)[data length],
                                                                (UInt32)[[NSUserDefaults standardUserDefaults] integerForKey:kCASIOUSBTransportNoDataTimeoutDefaultsKey],
                                                                (UInt32)[[NSUserDefaults standardUserDefaults] integerForKey:kCASIOUSBTransportCompletionTimeoutDefaultsKey]);
        if (result != kIOReturnSuccess){
            NSLog(@"WritePipeTO: %08x (%s)",result,USBErrorToString(result));
            switch (result) {
                case kIOReturnNotOpen:
                    NSLog(@"kIOReturnNotOpen");
                    break;
            }
            [self clearPipeStall]; // todo; retry after stall
            error = [NSError errorWithDomain:@"CASIOUSBTransport" code:result userInfo:nil];
        }
    }
    
    return error;    
}

- (NSError*)receive:(NSMutableData*)data {
    
    NSError* error = nil;
    
    NSMutableData* packetBuffer = [NSMutableData dataWithLength:MAX(self.inMaxSize,[data length])]; // cache this buffer ? also lots of copying going on
    uint8_t* packetBufferPtr = (uint8_t*)[packetBuffer mutableBytes];
    
    // const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

    UInt32 totalSize = 0;
    UInt32 size = (UInt32)[data length];
    while (size > 0){
        
        UInt32 readSize = (UInt32)[packetBuffer length]; // always request the full buffer size otherwise can get kIOReturnOverrun
        const IOReturn result = (*self->interface)->ReadPipeTO(self->interface,self.inPipe,(void*)packetBufferPtr,&readSize,
                                                               (UInt32)[[NSUserDefaults standardUserDefaults] integerForKey:kCASIOUSBTransportNoDataTimeoutDefaultsKey],
                                                               (UInt32)[[NSUserDefaults standardUserDefaults] integerForKey:kCASIOUSBTransportCompletionTimeoutDefaultsKey]);
        
        if (result != kIOReturnSuccess){ // get kIOReturnAborted here on first launch, retry ?
            NSLog(@"ReadPipeTO: %08x (%s)",result,USBErrorToString(result));
            if (result == kIOReturnOverrun){
                break;
            }
            else {
                [self clearPipeStall]; // todo; retry after stall
                error = [NSError errorWithDomain:@"CASIOUSBTransport" code:result userInfo:nil];
                break;
            }
        }
        else {
            if (readSize > 0){
                if (totalSize + readSize > [data length]){
                    [data setLength:[data length] + readSize];
                }
                memcpy(((uint8_t*)[data mutableBytes]) + totalSize, packetBufferPtr, readSize);
            }
            totalSize += readSize;
            size -= readSize;
            if (readSize < [packetBuffer length]){
                break;
            }
        }
    }
    
    // const NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];

    // NSLog(@"Read %d bytes out of %lu from pipe %d in %f seconds using packet size of %hu",totalSize,[data length],self.inPipe,end - start,self.inMaxSize);

    if (!error){
        if (totalSize < [data length]) {
            [data setLength:totalSize];
        };
    }

    return error;    
}

@end
