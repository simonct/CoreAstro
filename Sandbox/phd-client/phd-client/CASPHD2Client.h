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

- (void)start;
- (void)stop;

- (void)ditherByPixels:(NSInteger)pixels inRAOnly:(BOOL)raOnly;

@end
