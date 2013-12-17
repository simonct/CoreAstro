//
//  CASFilterPipeline.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/30/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASFilterPipeline.h"
#import <QuartzCore/QuartzCore.h>

@implementation CASFilterPipeline {
    CASImageDebayer* _imageDebayer;
    CASImageProcessor* _imageProcessor;
    NSMutableDictionary* _filterCache;
}

- (CASCCDExposure*)preprocessedExposureWithExposure:(CASCCDExposure*)exposure
{
    // debayer
    if (self.debayerMode != kCASImageDebayerNone){
        if (!_imageDebayer){
            _imageDebayer = [CASImageDebayer imageDebayerWithIdentifier:nil];
        }
        _imageDebayer.mode = self.debayerMode;
        CASCCDExposure* debayeredExposure = [_imageDebayer debayer:exposure adjustRed:1 green:1 blue:1 all:1];
        if (debayeredExposure){
            exposure = debayeredExposure;
        }
    }
    
    // equalise
    if (self.equalise){
        if (!_imageProcessor){
            _imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
        }
        exposure = [_imageProcessor equalise:exposure];
    }

    return nil;
}

- (CIFilter*)filterWithName:(NSString*)name
{
    CIFilter* result; // arc nils it
    @synchronized(self){
        if (!_filterCache){
            _filterCache = [NSMutableDictionary dictionaryWithCapacity:5];
        }
        result = _filterCache[name];
        if (!result){
            result = [CIFilter filterWithName:name];
            if (result){
                _filterCache[name] = result;
            }
        }
    }
    return result;
}

- (CIImage*)filteredImageWithExposure:(CASCCDExposure*)exposure
{
    CASCCDImage* ccdImage = [exposure newImage];
    CIImage* image = [CIImage imageWithCGImage:ccdImage.CGImage options:@{kCIImageColorSpace:[NSNull null]}];
    if (image){

        
        //    if (!CGRectIsNull(_extent)){
        //        // set roi on filters - does this mean I have to sublcass all the filters ?
        //        // or at least have a wrapper than composites with the underlying filter ?
        //    }
        
        // todo; allow filter order to be set externally ?
        // todo; set roi to the area of the subframe using CIFilterShape
        
        if (self.flipVertical || self.flipHorizontal){
            
            CIFilter* flip = [self filterWithName:@"CIAffineTransform"];
            [flip setDefaults];
            [flip setValue:image forKey:@"inputImage"];
            
            NSAffineTransform* transform = [NSAffineTransform transform];
            if (self.flipVertical){
                [transform scaleXBy:1.0 yBy:-1.0];
                [transform translateXBy:0 yBy:-image.extent.size.height];
            }
            if (self.flipHorizontal){
                [transform scaleXBy:-1.0 yBy:1.0];
                [transform translateXBy:-image.extent.size.width yBy:0];
            }
            [flip setValue:transform forKey:@"inputTransform"];
            
            image = [flip valueForKey:@"outputImage"];
        }
        
        if (self.medianFilter){
            CIFilter* median = [self filterWithName:@"CIMedianFilter"];
            [median setDefaults];
            [median setValue:image forKey:@"inputImage"];
            image = [median valueForKey:@"outputImage"];
        }
        
        if (self.contrastStretch){
            CIFilter* stretch = [self filterWithName:@"CASContrastStretchFilter"];
            if (stretch){
                [stretch setDefaults];
                [stretch setValue:image forKey:@"inputImage"];
                [stretch setValue:@(self.stretchMin) forKey:@"inputMin"];
                [stretch setValue:@(self.stretchMax) forKey:@"inputMax"];
                [stretch setValue:@(self.stretchGamma) forKey:@"inputGamma"];
                image = [stretch valueForKey:@"outputImage"];
            }
        }
        
        if (self.invert){
            CIFilter* invert = [self filterWithName:@"CIColorInvert"];
            [invert setDefaults];
            [invert setValue:image forKey:@"inputImage"];
            image = [invert valueForKey:@"outputImage"];
        }
    }
    
    return [image imageByCroppingToRect:image.extent]; // this seems to be required to prevent the filtered image from having infinite extent
}

- (CVPixelBufferRef)pixelBufferWithExposure:(CASCCDExposure*)exposure
{
    return nil;
}

@end
