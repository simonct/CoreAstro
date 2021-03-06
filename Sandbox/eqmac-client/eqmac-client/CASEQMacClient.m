//
//  CASEQMacClient.m
//  eqmac-client
//
//  Created by Simon Taylor on 04/04/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASEQMacClient.h"
#import "CASLX200Commands.h"
#import <CoreAstro/CoreAstro.h>

@interface CASEQMacClient ()
@end

@implementation CASEQMacClient

+ (NSUInteger)standardPort
{
    return 4030;
}

+ (CASEQMacClient*)standardClient
{
    return (CASEQMacClient*)[[self class] clientWithHost:[NSHost hostWithName:@"localhost"] port:[CASEQMacClient standardPort]];
}

@end
