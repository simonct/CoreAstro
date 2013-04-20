//
//  CASEQMacClient.h
//  eqmac-client
//
//  Created by Simon Taylor on 04/04/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, CASEQMacClientPrecision) {
    CASEQMacClientPrecisionUnknown = 0,
    CASEQMacClientPrecisionLow = 1, // DD*MM
    CASEQMacClientPrecisionHigh = 2 // DD*MM:SS
};

@interface CASEQMacClient : NSObject
@property (nonatomic,copy,readonly) NSString* ra;
@property (nonatomic,copy,readonly) NSString* dec;
@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) NSError* error;
@property (nonatomic,readonly) CASEQMacClientPrecision precision;

- (void)connectWithCompletion:(void(^)())completion;
- (void)disconnect;

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(BOOL))completion;
- (void)halt;

+ (NSUInteger)standardPort;
+ (CASEQMacClient*)standardClient;
+ (CASEQMacClient*)clientWithHost:(NSHost*)host port:(NSUInteger)port;

@end
