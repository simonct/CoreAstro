//
//  debayer_cifilterFilter.m
//  debayer-cifilter
//
//  Created by Simon Taylor on 11/11/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//
// From http://www.siliconimaging.com/RGB%20Bayer.htm
// and http://lists.apple.com/archives/quicktime-api/2009/Dec/msg00015.html

#import "CASDebayerFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation CASDebayerFilter

static CIKernel *_DebayerFilterKernel = nil;

- (id)init
{
    if(!_DebayerFilterKernel) {
		NSBundle    *bundle = [NSBundle bundleForClass:NSClassFromString(@"CASDebayerFilter")];
		NSStringEncoding encoding = NSUTF8StringEncoding;
		NSError     *error = nil;
		NSString    *code = [NSString stringWithContentsOfFile:[bundle pathForResource:@"CADebayerFilterKernel" ofType:@"cikernel"] encoding:encoding error:&error];
		NSArray     *kernels = [CIKernel kernelsWithString:code];

		_DebayerFilterKernel = kernels[0];
        NSAssert(_DebayerFilterKernel, @"Failed to load _DebayerFilterKernel");
    }
    return [super init];
}

- (CGRect)regionOf:(int)sampler  destRect:(CGRect)rect  userInfo:(NSNumber *)radius
{
    return CGRectInset(rect, -[radius floatValue], 0);
}

- (NSDictionary *)customAttributes
{
    return @{
        @"inputOffset":@{
            kCIAttributeDefault:[CIVector vectorWithX:0 Y:0],
            kCIAttributeType:kCIAttributeTypeOffset,
        }
    };
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    CISampler *src;
    
    src = [CISampler samplerWithImage:inputImage];
    
    return [self apply:_DebayerFilterKernel,src,inputOffset,nil];
}

@end
