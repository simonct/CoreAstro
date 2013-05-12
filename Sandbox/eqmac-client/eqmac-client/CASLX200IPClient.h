//
//  CASLX200IPClient.h
//  
//
//  Created by Simon Taylor on 08/05/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CASSocketClient.h"

typedef NS_OPTIONS(NSUInteger, CASLX200ClientPrecision) {
    CASLX200ClientPrecisionUnknown = 0,
    CASLX200ClientPrecisionLow = 1, // DD*MM
    CASLX200ClientPrecisionHigh = 2 // DD*MM:SS
};

@interface CASLX200IPClient : NSObject

@property (nonatomic,copy,readonly) NSString* ra;
@property (nonatomic,copy,readonly) NSString* dec;
@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) NSError* error;
@property (nonatomic,readonly) CASLX200ClientPrecision precision;
@property (nonatomic,strong,readonly) CASSocketClient* client;

- (void)connectWithCompletion:(void(^)())completion;
- (void)disconnect;

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(BOOL))completion;
- (void)halt;

+ (CASLX200IPClient*)clientWithHost:(NSHost*)host port:(NSUInteger)port;

@end
