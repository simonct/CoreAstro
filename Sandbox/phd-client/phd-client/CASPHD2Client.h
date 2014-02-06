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

- (void)pause;
- (void)resume;

- (void)start;
- (void)stop;

- (void)ditherByPixels:(NSInteger)pixels inRAOnly:(BOOL)raOnly;

typedef NS_ENUM(NSInteger, CASPHD2ClientState) {
    CASPHD2ClientStateNone,
    CASPHD2ClientStateSettling,
    CASPHD2ClientStateSettled
};
@property (nonatomic,readonly) CASPHD2ClientState state;

@end
