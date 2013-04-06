//
//  CASEQMacClient.h
//  eqmac-client
//
//  Created by Simon Taylor on 04/04/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

@interface CASEQMacClient : CASSocketClient
@property (nonatomic,copy,readonly) NSString* ra;
@property (nonatomic,copy,readonly) NSString* dec;
+ (NSUInteger)standardPort;
@end
