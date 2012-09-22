//
//  CASExposureTableView.h
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CASExposuresController.h"

@interface CASExposureTableView : NSTableView
@property (nonatomic,weak) IBOutlet CASExposuresController* exposuresController;
@end
