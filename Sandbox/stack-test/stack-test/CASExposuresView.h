//
//  CASExposuresView.h
//  stack-test
//
//  Created by Simon Taylor on 21/11/2012.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASImageView.h"

@class CASCCDExposure;

@interface CASExposuresView : CASImageView
@property (nonatomic,strong) NSArray* exposures;
@property (nonatomic,strong) CASCCDExposure* currentExposure;
@property (nonatomic,assign) NSInteger currentExposureIndex;
@property (nonatomic,strong) NSString* statusText;
- (IBAction)nextExposure:(id)sender;
- (IBAction)previousExposure:(id)sender;
@end
