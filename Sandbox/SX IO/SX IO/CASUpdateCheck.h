//
//  CASUpdateCheck.h
//  SX IO
//
//  Created by Simon Taylor on 8/3/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASUpdateCheck : NSObject

+ (instancetype)sharedUpdateCheck;

- (void)checkForUpdate;

@end
