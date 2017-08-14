//
//  CASExposureView.h
//  CoreAstro
//
//  Created by Simon Taylor on 02/12/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASImageView.h"

@class CASCCDExposure;
@class CASImageProcessor;
@class CASExposureView;
@class CASGuideAlgorithm;
@class CASPlateSolveSolution;

@protocol CASExposureViewDelegate <NSObject>
- (CGRect)validateSelectionRect:(CGRect)selection exposureView:(CASExposureView*)view;
- (void)selectionRectChanged:(CASExposureView*)view;
@end

@interface CASExposureView : CASImageView
@property (nonatomic,assign) BOOL showReticle;
@property (nonatomic,assign) BOOL showSelection;
@property (nonatomic,assign) BOOL showStarProfile;
typedef enum {
    kCASStarProfileModeAuto,
    kCASStarProfileModeCentre
} CASShowStarProfileMode;
@property (nonatomic,assign) CASShowStarProfileMode showStarProfileMode;
@property (nonatomic,assign) BOOL showImageStats;
@property (nonatomic,assign) CGPoint starLocation;
@property (nonatomic,assign) CGPoint lockLocation;
@property (nonatomic,assign) CGFloat searchRadius;
@property (nonatomic,strong) CASCCDExposure* currentExposure;
@property (nonatomic,assign) BOOL showHistogram;
@property (nonatomic,assign) BOOL scaleSubframe;
@property (nonatomic,assign) BOOL displayingScaledSubframe;
@property (nonatomic,assign) BOOL showProgress;
@property (nonatomic,assign) BOOL showSolving;
@property (nonatomic,assign) BOOL autoContrastStretch;
@property (nonatomic,assign) NSInteger progressInterval;
@property (nonatomic,assign) CGFloat progress;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASGuideAlgorithm* guideAlgorithm;
@property (nonatomic,weak) id<CASExposureViewDelegate> exposureViewDelegate;
@property (nonatomic,assign) CGRect selectionRect;
@property (nonatomic,strong) CASPlateSolveSolution* plateSolveSolution;
@property (nonatomic,strong) CASPlateSolveSolution* lockedPlateSolveSolution;
- (BOOL)shouldResetDisplayForExposure:(CASCCDExposure*)exposure;
- (void)setCurrentExposure:(CASCCDExposure *)exposure resetDisplay:(BOOL)resetDisplay;
@end

extern const CGPoint kCASImageViewInvalidStarLocation;

