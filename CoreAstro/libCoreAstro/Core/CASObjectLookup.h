//
//  CASObjectLookup.h
//  CoreAstro
//
//  Created by Simon Taylor on 2/7/15.
//  Copyright (c) 2015 Mako Technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASObjectLookup : NSObject

- (void)lookupObject:(NSString*)name withCompletion:(void(^)(BOOL success,double ra,double dec))completion;

@end
