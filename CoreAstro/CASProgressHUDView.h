//
//  CASProgressHUDView.h
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHUDView.h"

@interface CASProgressHUDView : CASHUDView
@property (nonatomic,weak) NSTextField* label;
@property (nonatomic,assign) CGFloat progress;
@end
