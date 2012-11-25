//
//  CASLibraryBrowserViewController.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASLibraryBrowserView;

@interface CASLibraryBrowserViewController : NSViewController
@property (nonatomic,weak) IBOutlet CASLibraryBrowserView* browserView;
@end
