//
//  CASObjectLookup.h
//  CoreAstro
//
//  Created by Simon Taylor on 2/7/15.
//  Copyright (c) 2015 Mako Technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASObjectLookupResult : NSObject
@property BOOL foundIt;
@property (copy) NSString* object;
@property double ra, dec;
@end

@interface CASObjectLookup : NSObject

- (void)cachedLookupObject:(NSString*)name withCompletion:(void(^)(CASObjectLookupResult* result))completion;
- (void)lookupObject:(NSString*)name withCompletion:(void(^)(CASObjectLookupResult* result))completion;

@end
