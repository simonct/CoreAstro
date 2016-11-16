//
//  CASLX200Mount.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMount.h"
#import "ORSSerialPort.h"

@interface CASLX200Mount : CASMount

@property (nonatomic,copy) NSString* name;
@property (nonatomic,copy) void(^connectCompletion)(NSError*);

@property (nonatomic,assign) BOOL connected;
@property (nonatomic,assign) BOOL slewing;
@property (nonatomic,assign) BOOL tracking;
@property (nonatomic,strong) NSNumber* ra;
@property (nonatomic,strong) NSNumber* dec;
@property (nonatomic,strong) NSNumber* alt;
@property (nonatomic,strong) NSNumber* az;
@property (nonatomic,assign) CASMountPierSide pierSide;

@property BOOL logCommands;

@property (nonatomic,strong,readonly) ORSSerialPort* port;

- (id)initWithSerialPort:(ORSSerialPort*)port;

- (void)connect:(void (^)(NSError*))block;
- (void)disconnect;

// for subclasses
- (void)sendCommand:(NSString*)command readCount:(NSInteger)readCount completion:(void (^)(NSString*))completion;
- (void)sendCommand:(NSString*)command completion:(void (^)(NSString*))completion;
- (void)sendCommand:(NSString*)command;

@end

