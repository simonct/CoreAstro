//
//  CASLibraryBrowserView.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASLibraryBrowserView.h"
#import "CASCCDExposure.h"

// from ImageBrowserViewAppearance sample code
@interface CASLibraryBrowserViewCell : IKImageBrowserCell
@property (nonatomic,weak) CASCCDExposure* exposure;
@property (nonatomic,weak) CASCCDExposureLibraryProject* project;
@end

@implementation CASLibraryBrowserViewCell

- (void)dealloc
{
    [_exposure removeObserver:self forKeyPath:@"type"];
}

- (void)setExposure:(CASCCDExposure *)exposure
{
    if (exposure != _exposure){
        [_exposure removeObserver:self forKeyPath:@"type"];
        _exposure = exposure;
        [_exposure addObserver:self forKeyPath:@"type" options:0 context:(__bridge void *)(self)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        [self.imageBrowserView reloadData]; // doesn't seem to be a 'reload this cell' method
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (CALayer *) layerForType:(NSString*) type
{
    CALayer *layer = nil;
    
	const CGRect frame = [self frame];
    const CGRect imageFrame = [self imageFrame];
    const CGRect relativeImageFrame = NSMakeRect(imageFrame.origin.x - frame.origin.x, imageFrame.origin.y - frame.origin.y, imageFrame.size.width, imageFrame.size.height);

    if(type == IKImageBrowserCellForegroundLayer){
        
        NSString* label = nil;
        
        switch (self.exposure.type) {
            case kCASCCDExposureLightType:
                if (self.exposure.correctedExposure){
                    label = @"CORRECTED"; // todo; tick image not text
                }
                break;
            case kCASCCDExposureDarkType:
                label = (self.exposure == self.project.masterDark) ? @"MASTER DARK" : @"DARK";
                break;
            case kCASCCDExposureBiasType:
                label = (self.exposure == self.project.masterBias) ? @"MASTER BIAS" : @"BIAS";
                break;
            case kCASCCDExposureFlatType:
                label = (self.exposure == self.project.masterFlat) ? @"MASTER FLAT" : @"FLAT";
                break;
        }
        
        if (label){
            
            layer = [CALayer layer];
            layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
            
            CATextLayer *textLayer = [CATextLayer layer];
            CGRect textFrame = relativeImageFrame;
            textFrame.size.height = 15;
            textLayer.frame = textFrame;
            textLayer.backgroundColor = CGColorCreateGenericRGB(0, 0, 0, 0.25); // gradient layer ?
            textLayer.alignmentMode = kCAAlignmentCenter;
            textLayer.fontSize = 14;
            textLayer.font = CFSTR("Helvetica-Bold");
            textLayer.string = label;
            
            [layer addSublayer:textLayer];
        }
    }

    return layer;
}

@end

@interface CASLibraryBrowserView ()
@property (nonatomic,unsafe_unretained) NSViewController* viewController; // can't be weak pre-10.8
@end

@implementation CASLibraryBrowserView

@synthesize viewController = _viewController;

- (void)keyDown:(NSEvent *)theEvent
{
    if (theEvent.keyCode == 49){
        if (![NSResponder instancesRespondToSelector:@selector(quickLookPreviewItems:)]){
            if ([self.nextResponder respondsToSelector:@selector(quickLookPreviewItems:)]){
                [self.nextResponder quickLookPreviewItems:nil];
                return;
            }
        }
    }
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)setNextResponder:(NSResponder *)aResponder
{
    if (aResponder && self.viewController && aResponder != self.viewController){
        [self.viewController setNextResponder:aResponder];
        aResponder = self.viewController;
    }
    [super setNextResponder:aResponder];
}

- (void)setViewController:(NSViewController *)viewController
{
    if (viewController != _viewController){
        _viewController = viewController;
        self.nextResponder = self.nextResponder;
    }
}

- (IKImageBrowserCell *) newCellForRepresentedItem:(id) wrapper
{
    CASLibraryBrowserViewCell* cell = [[CASLibraryBrowserViewCell alloc] init];
    cell.exposure = [wrapper valueForKey:@"exposure"];
    cell.project = self.project;
	return cell;
}

@end
