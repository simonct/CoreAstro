//
//  CASLibraryBrowserViewController.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASCCDExposure;
@class CASLibraryBrowserView;
@class CASExposuresController;

@protocol CASLibraryBrowserViewControllerDelegate <NSObject>
@optional
- (void)focusOnExposure:(CASCCDExposure*)exposure;
@end

@interface CASLibraryBrowserViewController : NSViewController
@property (nonatomic,unsafe_unretained) id<CASLibraryBrowserViewControllerDelegate> exposureDelegate; // delegate is a window controller
@property (nonatomic,strong) CASExposuresController* exposuresController;
@property (nonatomic,weak) IBOutlet CASLibraryBrowserView* browserView;
@end
