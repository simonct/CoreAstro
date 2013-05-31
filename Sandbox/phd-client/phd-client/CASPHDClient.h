//
//  CASPHDClient.h
//  phd-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

@interface CASPHDClient : NSObject
@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,strong,readonly) CASSocketClient* client;

- (void)pause;
- (void)resume;

- (void)move:(NSInteger)amount;

- (void)requestDistance;

- (void)autoFindStar;

- (void)setLockPositionToX:(int16_t)x y:(int16_t)y;

- (void)flipRACalibration;

- (void)getStatus;

- (void)stop;
- (void)loop;

- (void)startGuiding;

- (void)loopFrameCount;

- (void)clearCalibration;

@end
