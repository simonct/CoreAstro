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

@interface CASAPGTOGuidePort : NSObject
@property (weak) id<CASAPGTOGuidePortDelegate> delegate;
- (instancetype)initWithDelegate:(id<CASAPGTOGuidePortDelegate>)delegate;
@end
