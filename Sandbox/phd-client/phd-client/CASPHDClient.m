//
//  CASPHDClient.m
//  phd-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASPHDClient.h"

enum {
	MSG_PAUSE = 1,
	MSG_RESUME,
	MSG_MOVE1,
	MSG_MOVE2,
	MSG_MOVE3,
	MSG_IMAGE,
	MSG_GUIDE,
	MSG_CAMCONNECT,
	MSG_CAMDISCONNECT,
	MSG_REQDIST,
	MSG_REQFRAME,
	MSG_MOVE4,
	MSG_MOVE5,
	MSG_AUTOFINDSTAR,
    MSG_SETLOCKPOSITION,	//15
	MSG_FLIPRACAL,			//16
	MSG_GETSTATUS,			//17
	MSG_STOP,				//18
	MSG_LOOP,				//19
	MSG_STARTGUIDING,    	//20
	MSG_LOOPFRAMECOUNT,		//21
	MSG_CLEARCAL            //22
};

@interface CASPHDClientRequest : NSObject
@property (nonatomic,strong) NSData* data;
@property (nonatomic,copy) void (^completion)(NSData*);
@end

@implementation CASPHDClientRequest
@end

@interface CASPHDClient ()<NSStreamDelegate>
@property (nonatomic,assign) NSInteger openCount;
@property (nonatomic,strong) NSInputStream* inputStream;
@property (nonatomic,strong) NSOutputStream* outputStream;
@end

@implementation CASPHDClient {
    NSMutableArray* _queue;
}

- (id)init
{
    self = [super init];
    if (self) {
        
        const NSInteger port = 4300;
        NSHost* host = [NSHost hostWithName:@"localhost"];
        
        NSInputStream* is;
        NSOutputStream* os;
        [NSStream getStreamsToHost:host port:port inputStream:&is outputStream:&os];
        
        if (!is || !os){
            NSLog(@"Can't open connection to %@",host.name);
            self = nil;
        }
        else {
            
            self.inputStream = is;
            self.outputStream = os;
            
            [self.inputStream setDelegate:self];
            [self.outputStream setDelegate:self];
            
            [self.inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            [self.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            
            [self.inputStream open];
            [self.outputStream open];
        }
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanup
{
    [self.inputStream close];
    [self.inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    self.inputStream = nil;
    
    [self.outputStream close];
    [self.outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    self.outputStream = nil;
    
    self.openCount = 0;
    
    // call completion blocks ?
}

- (BOOL)connected
{
    return (self.openCount == 2);
}

+ (NSSet*)keyPathsForValuesAffectingConnected
{
    return [NSSet setWithObject:@"openCount"];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    NSLog(@"stream: %@ handleEvent: %ld",aStream,eventCode);
    
    NSString* name;
    switch (eventCode) {
        case NSStreamEventNone:
            name = @"NSStreamEventNone";
            break;
        case NSStreamEventOpenCompleted:
            name = @"NSStreamEventOpenCompleted";
            self.openCount++;
            break;
        case NSStreamEventHasBytesAvailable:
            name = @"NSStreamEventHasBytesAvailable";
            [self read];
            break;
        case NSStreamEventHasSpaceAvailable:
            name = @"NSStreamEventHasSpaceAvailable";
            [self process];
            break;
        case NSStreamEventErrorOccurred:
            name = [NSString stringWithFormat:@"NSStreamEventErrorOccurred: %@",[aStream streamError]];
            [self cleanup];
            break;
        case NSStreamEventEndEncountered:
            name = @"NSStreamEventEndEncountered";
            [self cleanup];
            break;
        default:
            name = [NSString stringWithFormat:@"%ld",eventCode];
            break;
    }
    NSLog(@"%@: %@",aStream,name);
}

- (void)enqueue:(NSData*)data completion:(void (^)(NSData*))completion
{
    CASPHDClientRequest* request = [[CASPHDClientRequest alloc] init];
    
    request.data = data;
    request.completion = completion;
    
    if (!_queue){
        _queue = [[NSMutableArray alloc] initWithCapacity:5];
    }
    [_queue addObject:request];
    
    [self process];
}

- (void)process
{
    if ([_queue count]){
        
        if ([self.outputStream hasSpaceAvailable]){
            
            CASPHDClientRequest* request = [_queue lastObject];
            const NSInteger count = [self.outputStream write:[request.data bytes] maxLength:[request.data length]];
            if (count < 0){
                NSLog(@"Failed to write the whole packet");
            }
            else {
                NSLog(@"wrote %ld bytes",count);
            }
        }
    }
}

- (void)read
{
    CASPHDClientRequest* request = [_queue lastObject];
    NSMutableData* data = [NSMutableData dataWithCapacity:1024];
    while ([self.inputStream hasBytesAvailable]){
        uint8_t byte[1024];
        const NSInteger count = [self.inputStream read:byte maxLength:sizeof(byte)];
        if (count > 0){
            [data appendBytes:byte length:count];
        }
    }
    
    NSLog(@"read %ld bytes",[data length]);

    if (request.completion){
        request.completion(data);
    }
    [_queue removeLastObject];
}

- (void)enqueueCommand:(uint8_t)cmd completion:(void (^)(NSData*))completion
{
    [self enqueue:[NSData dataWithBytes:&cmd length:sizeof(cmd)] completion:completion];
}

- (void)pause
{
    [self enqueueCommand:MSG_PAUSE completion:nil];
}

- (void)resume
{
    [self enqueueCommand:MSG_RESUME completion:nil];
}

@end
