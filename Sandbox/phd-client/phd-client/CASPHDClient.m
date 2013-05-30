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

@interface CASPHDClient ()
@property (nonatomic,strong) CASSocketClient* client;
@end

@implementation CASPHDClient 

- (id)init
{
    self = [super init];
    if (self) {
        self.client = [[CASSocketClient alloc] init];
        self.client.host = [NSHost hostWithAddress:@"127.0.0.1"];
        self.client.port = 4300;
        [self.client connect];
    }
    return self;
}

- (void)enqueueCommand:(uint8_t)cmd completion:(void (^)(NSData*))completion
{
    [self.client enqueue:[NSData dataWithBytes:&cmd length:sizeof(cmd)] readCount:1 completion:completion];
}

- (void)pause
{
    [self enqueueCommand:MSG_PAUSE completion:^(NSData* response){
        NSLog(@"pause: %@",response);
    }];
}

- (void)resume
{
    [self enqueueCommand:MSG_RESUME completion:^(NSData* response){
        NSLog(@"resume: %@",response);
    }];
}

- (void)move1
{
    [self enqueueCommand:MSG_MOVE1 completion:^(NSData* response){
        NSLog(@"move1: %@",response);
    }];
}

- (void)move2
{
    [self enqueueCommand:MSG_MOVE2 completion:^(NSData* response){
        NSLog(@"move2: %@",response);
    }];
}

- (void)move3
{
    [self enqueueCommand:MSG_MOVE3 completion:^(NSData* response){
        NSLog(@"move3: %@",response);
    }];
}

- (void)move4
{
    [self enqueueCommand:MSG_MOVE4 completion:^(NSData* response){
        NSLog(@"move4: %@",response);
    }];
}


- (void)move5
{
    [self enqueueCommand:MSG_MOVE5 completion:^(NSData* response){
        NSLog(@"move5: %@",response);
    }];
}

- (void)requestDistance
{
    [self enqueueCommand:MSG_REQDIST completion:^(NSData* response){
        NSLog(@"requestDistance: %@",response);
    }];
}

- (void)autoFindStar
{
    [self enqueueCommand:MSG_AUTOFINDSTAR completion:^(NSData* response){
        NSLog(@"autoFindStar: %@",response);
    }];
}

- (void)setLockPositionToX:(int16_t)x y:(int16_t)y
{
    NSMutableData* cmdData = [NSMutableData dataWithCapacity:1 + 2*sizeof(int16_t)];
    
    const uint8_t cmd = MSG_SETLOCKPOSITION;
    [cmdData appendBytes:&cmd length:sizeof(cmd)];
    
    // assuming endianess is the same as this process (phd doesn't define a netwoek byte order)
    [cmdData appendBytes:&x length:sizeof(x)];
    [cmdData appendBytes:&y length:sizeof(y)];

    [self.client enqueue:cmdData readCount:1 completion:^(NSData* response){
        NSLog(@"setLockPositionToX:y: %@",response);
    }];
}

- (void)flipRACalibration
{
    [self enqueueCommand:MSG_FLIPRACAL completion:^(NSData* response){
        NSLog(@"flipRACalibration: %@",response);
    }];
}

- (void)getStatus
{
    [self enqueueCommand:MSG_GETSTATUS completion:^(NSData* response){
        NSLog(@"getStatus: %@",response);
    }];
}

- (void)stop
{
    [self enqueueCommand:MSG_STOP completion:^(NSData* response){
        NSLog(@"stop: %@",response);
    }];
}

- (void)loop
{
    [self enqueueCommand:MSG_LOOP completion:^(NSData* response){
        NSLog(@"loop: %@",response);
    }];
}

- (void)startGuiding
{
    [self enqueueCommand:MSG_STARTGUIDING completion:^(NSData* response){
        NSLog(@"startGuiding: %@",response);
    }];
}

- (void)loopFrameCount
{
    [self enqueueCommand:MSG_LOOPFRAMECOUNT completion:^(NSData* response){
        NSLog(@"loopFrameCount: %@",response);
    }];    
}

- (void)clearCalibration
{
    [self enqueueCommand:MSG_CLEARCAL completion:^(NSData* response){
        NSLog(@"clearCalibration: %@",response);
    }];
}

@end
