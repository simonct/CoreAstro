//
//  CASINDICamera.h
//  indi-client
//
//  Created by Simon Taylor on 03/09/17.
//  Copyright (c) 2017 Simon Taylor. All rights reserved.
//

#import "CASINDIContainer.h"
#import "CASCCDDevice.h"

@interface CASINDICamera : CASCCDDevice<CASINDICamera>
- (instancetype)initWithDevice:(CASINDIDevice<CASINDICamera>*)device;
@end
