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

- (CALayer *) layerForType:(NSString*) type
{
	const CGRect frame = [self frame];
    const CGRect imageFrame = [self imageFrame];
    const CGRect relativeImageFrame = NSMakeRect(imageFrame.origin.x - frame.origin.x, imageFrame.origin.y - frame.origin.y, imageFrame.size.width, imageFrame.size.height);

    if (self.exposure.type != kCASCCDExposureLightType){
        
        if(type == IKImageBrowserCellForegroundLayer){
            
            CALayer *layer = [CALayer layer];
            layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
            
            CATextLayer *textLayer = [CATextLayer layer];
            CGRect textFrame = relativeImageFrame;
            textFrame.size.height = 15;
            textLayer.frame = textFrame;
            textLayer.backgroundColor = CGColorCreateGenericRGB(0, 0, 0, 0.25); // gradient layer ?
            textLayer.alignmentMode = kCAAlignmentCenter;
            textLayer.fontSize = 14;
            textLayer.font = CFSTR("Helvetica-Bold");

            // masterDark, etc
            
            switch (self.exposure.type) {
                case kCASCCDExposureDarkType:
                    textLayer.string = (self.exposure == self.project.masterDark) ? @"MASTER DARK" : @"DARK";
                    break;
                case kCASCCDExposureBiasType:
                    textLayer.string = (self.exposure == self.project.masterBias) ? @"MASTER BIAS" : @"BIAS";
                    break;
                case kCASCCDExposureFlatType:
                    textLayer.string = (self.exposure == self.project.masterFlat) ? @"MASTER FLAT" : @"FLAT";
                    break;
                default:
                    break;
            }

            [layer addSublayer:textLayer];
            
            return layer;
        }
    }

    return nil;
}

@end

@interface CASLibraryBrowserView ()
@property (nonatomic,unsafe_unretained) NSViewController* viewController;
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
