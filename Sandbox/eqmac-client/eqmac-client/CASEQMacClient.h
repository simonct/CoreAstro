//
//  CASEQMacClient.h
//  eqmac-client
//
//  Created by Simon Taylor on 04/04/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

typedef NS_OPTIONS(NSUInteger, CASEQMacClientPrecision) {
    CASEQMacClientPrecisionUnknown = 0,
    CASEQMacClientPrecisionLow = 1, // DD*MM
    CASEQMacClientPrecisionHigh = 2 // DD*MM:SS
};

@interface CASEQMacClient : CASSocketClient
@property (nonatomic,copy,readonly) NSString* ra;
@property (nonatomic,copy,readonly) NSString* dec;
@property (nonatomic,readonly) CASEQMacClientPrecision precision;

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(BOOL))completion;
- (void)halt;

+ (NSUInteger)standardPort;

@end
