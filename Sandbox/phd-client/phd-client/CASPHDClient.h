//
//  CASPHDClient.h
//  phd-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASPHDClient : NSObject
@property (nonatomic,readonly) BOOL connected;
- (void)pause;
- (void)resume;
@end
