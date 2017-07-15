//
//  CASAPGTOGuidePort.h
//  guide-socket-test
//
//  Created by Simon Taylor on 27/05/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import "CASMount.h"

@protocol CASAPGTOGuidePortDelegate <NSObject>
- (void)pulseInDirection:(CASMountDirection)direction ms:(NSInteger)ms;
@end

@class CASAPGTOMount;

@interface CASAPGTOGuidePort : NSObject
- (instancetype)initWithMount:(CASAPGTOMount*)mount delegate:(id<CASAPGTOGuidePortDelegate>)delegate;
- (void)disconnect;
@end
