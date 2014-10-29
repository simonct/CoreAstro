//
//  CASCameraServer.h
//  SX IO
//
//  Created by Simon Taylor on 26/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASCameraServer : NSObject

+ (instancetype)sharedServer;

- (void)start;
- (void)stop;

@end
