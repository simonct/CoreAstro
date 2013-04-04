//
//  CASSocketClient.h
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASSocketClient : NSObject
@property (nonatomic,retain) NSHost* host;
@property (nonatomic,assign) NSInteger port;
@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) NSError* error;
- (void)connect;
- (void)disconnect;
- (void)enqueue:(NSData*)data completion:(void (^)(NSData*))completion;
@end
