//
//  CASLibraryBrowserView.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "CASCCDExposureLibrary.h"

@interface CASLibraryBrowserView : IKImageBrowserView // NSCollectionView may be a more flexible choice in the future
@property (nonatomic,weak) CASCCDExposureLibraryProject* project;
@end
