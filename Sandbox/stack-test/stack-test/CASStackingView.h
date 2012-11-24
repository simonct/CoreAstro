//
//  CASStackingView.h
//  stack-test
//
//  Created by Simon Taylor on 11/23/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASExposuresView.h"

@interface CASStackingView : CASExposuresView
@property (nonatomic,strong,readonly) NSMutableDictionary* points;
- (IBAction)stack:(id)sender;
@end
