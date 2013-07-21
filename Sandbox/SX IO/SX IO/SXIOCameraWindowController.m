//
//  SXIOCameraWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 7/21/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOCameraWindowController.h"

#import "CASExposureView.h"
#import "CASCameraControlsViewController.h"

@interface CASControlsContainerView : NSView
@end
@implementation CASControlsContainerView
@end

@interface SXIOCameraWindowController ()
@property (weak) IBOutlet CASControlsContainerView *controlsContainerView;
@property (weak) IBOutlet CASExposureView *exposureView;
@property (weak) IBOutlet NSTextField *statusText;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (strong) CASCameraControlsViewController *cameraControlsViewController;
@end

@implementation SXIOCameraWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
//    CGColorRef gray = CGColorCreateGenericRGB(128/255.0, 128/255.0, 128/255.0, 1); // match to self.imageView.backgroundColor ?
//    self.exposureView.layer.backgroundColor = gray;
//    CGColorRelease(gray);
    
    // slot the camera controls into the controls container view todo; make this layout code part of the container view or its controller
    self.cameraControlsViewController = [[CASCameraControlsViewController alloc] initWithNibName:@"CASCameraControlsViewController" bundle:nil];
    self.cameraControlsViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsContainerView addSubview:self.cameraControlsViewController.view];
    
    // layout camera controls
    id cameraControlsViewController1 = self.cameraControlsViewController.view;
    NSDictionary* viewNames = NSDictionaryOfVariableBindings(cameraControlsViewController1);
    [self.controlsContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[cameraControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [self.controlsContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[cameraControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.cameraControlsViewController.view.frame.size.height)} views:viewNames]];
    
    [self.cameraControlsViewController bind:@"cameraController" toObject:self withKeyPath:@"cameraController" options:nil];
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    if (cameraController != _cameraController){
        _cameraController = cameraController;
        self.window.title = _cameraController.camera.deviceName;
    }
}

- (IBAction)capture:(id)sender
{
    NSLog(@"capture");
}

@end
