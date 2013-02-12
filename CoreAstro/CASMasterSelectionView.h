//
//  CASMasterView.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreAstro/CoreAstro.h>
#import "CASExposuresController.h"

@protocol CASMasterSelectionViewDelegate <NSObject>
@optional
- (void)cameraWasSelected:(id)camera;
- (void)libraryWasSelected:(id)library;
@end

@interface CASMasterSelectionView : NSOutlineView
- (void)completeSetup;
@property (nonatomic,strong) id camerasContainer;
@property (nonatomic,unsafe_unretained) id<CASMasterSelectionViewDelegate> masterViewDelegate; // can't use weak as NSWindowController on Lion can't be weak-linked to
@end

@interface CASCCDExposureLibraryProject (CASMasterSelectionView)
@property (nonatomic,strong) CASExposuresController* exposuresController;
@end