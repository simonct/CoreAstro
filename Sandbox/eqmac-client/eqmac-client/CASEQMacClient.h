//
//  CASEQMacClient.h
//  eqmac-client
//
//  Created by Simon Taylor on 04/04/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASLX200IPClient.h"

@interface CASEQMacClient : CASLX200IPClient

+ (NSUInteger)standardPort;
+ (CASEQMacClient*)standardClient;

@end
