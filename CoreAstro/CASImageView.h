//
//  CASImageView.h
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface CASImageView : IKImageView
@property (nonatomic,assign) BOOL firstShowEditPanel;
@end

@interface IKImageView (Private)
- (CGRect)selectionRect; // great, a private method to get the selection...
@end

