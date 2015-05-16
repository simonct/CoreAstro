//
//  CASPHD2Client.h
//  phd-client
//
//  Created by Simon Taylor on 06/02/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

@interface CASPHD2Client : NSObject
@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) BOOL guiding;

- (void)connectWithCompletion:(void(^)())completion;

- (void)guideWithCompletion:(void(^)(BOOL))completion;
- (void)stop;

- (void)flipWithCompletion:(void(^)(BOOL))completion;

- (void)ditherByPixels:(float)pixels inRAOnly:(BOOL)raOnly completion:(void(^)(BOOL))completion;

- (void)cancel;

@end
