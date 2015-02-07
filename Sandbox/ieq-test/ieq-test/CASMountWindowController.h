//
//  iEQWindowController.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMount.h"

@interface CASMountWindowController : NSWindowController
- (void)connectToMount:(CASMount*)mount;
@end
