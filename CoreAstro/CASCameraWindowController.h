//
//  CASCameraWindowController.h
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
// 
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to deal 
//  in the Software without restriction, including without limitation the rights 
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
//  copies of the Software, and to permit persons to whom the Software is furnished 
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import <Cocoa/Cocoa.h>

@class CASExposureView;
@class CASCameraWindowController;
@class CASCameraController;
@class CASMasterSelectionView;
@class CASImageBannerView;

@protocol CASCameraWindowControllerDelegate <NSObject>
@optional
- (void)cameraWindowWillClose:(CASCameraWindowController*)window;
@end

@interface CASCameraWindowController : NSWindowController
@property (nonatomic,strong) CASCameraController* cameraController;
@property (nonatomic,weak) IBOutlet NSView *detailContainerView;
@property (nonatomic,weak) id<CASCameraWindowControllerDelegate> delegate;
@property (nonatomic,weak) IBOutlet NSToolbar *toolbar;
@property (nonatomic,weak) IBOutlet CASImageBannerView *imageBannerView;
@property (nonatomic,weak) IBOutlet CASExposureView *imageView;
@property (nonatomic,weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic,weak) IBOutlet NSTextField *progressStatusText;
@property (nonatomic,weak) IBOutlet NSButton *captureButton;
@property (nonatomic,weak) IBOutlet NSTextField *exposureField;
@property (weak) IBOutlet NSPopUpButton *exposureScalePopup;
@property (weak) IBOutlet NSMatrix *binningRadioButtons;
@property (nonatomic,strong) IBOutlet NSSegmentedControl *zoomControl;
@property (nonatomic,strong) IBOutlet NSSegmentedControl *zoomFitControl;
@property (nonatomic,strong) IBOutlet NSSegmentedControl *selectionControl;
@property (nonatomic,weak) IBOutlet NSSegmentedControl *devicesToggleControl;
@property (nonatomic,weak) IBOutlet NSTextField *sensorSizeField;
@property (nonatomic,weak) IBOutlet NSTextField *sensorPixelsField;
@property (nonatomic,weak) IBOutlet NSTextField *subframeDisplay;
@property (nonatomic,weak) IBOutlet CASMasterSelectionView *devicesTableView;
@end
