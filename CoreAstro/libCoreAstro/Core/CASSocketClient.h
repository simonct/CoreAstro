//
//  CASSocketClient.h
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASSocketClientRequest : NSObject
@property (nonatomic,strong) NSData* data;
@property (nonatomic,copy) void (^completion)(NSData*);
@property (nonatomic,assign) NSUInteger readCount;
@property (nonatomic,assign) NSUInteger writtenCount;
@property (nonatomic,strong) NSMutableData* response;
- (BOOL)appendResponseData:(NSData*)data;
@end

@interface CASSocketClient : NSObject // CASTransport ?
@property (nonatomic,retain) NSHost* host;
@property (nonatomic,assign) NSInteger port;
@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) NSError* error;
- (BOOL)connect;
- (void)disconnect;
- (void)enqueueRequest:(CASSocketClientRequest*)request;
- (void)enqueue:(NSData*)data readCount:(NSUInteger)readCount completion:(void (^)(NSData*))completion;
- (CASSocketClientRequest*)makeRequest;
@end

@class CASJSONRPCSocketClient;

@protocol CASJSONRPCSocketClientDelegate <NSObject>
- (void)client:(CASJSONRPCSocketClient*)client receivedNotification:(NSDictionary*)message;
@end

@interface CASJSONRPCSocketClient : CASSocketClient
@property (nonatomic,weak) id<CASJSONRPCSocketClientDelegate> delegate;
- (void)enqueueCommand:(NSDictionary*)command completion:(void (^)(id))completion;
@end