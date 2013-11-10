//
//  CASPowerMonitor.h
//  power-observer2
//
//  Created by Simon Taylor on 22/08/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASPowerMonitor : NSObject
@property (readonly) BOOL onWallPower;
@property (nonatomic,assign) BOOL disableSleep;
@end
