//
//  debayer_cifilterFilter.m
//  debayer-cifilter
//
//  Created by Simon Taylor on 11/11/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//
// From http://www.siliconimaging.com/RGB%20Bayer.htm
// and http://lists.apple.com/archives/quicktime-api/2009/Dec/msg00015.html

#import "debayer_cifilterFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation debayer_cifilterFilter

static CIKernel *_debayer_cifilterFilterKernel = nil;

- (id)init
{
    if(!_debayer_cifilterFilterKernel) {
		NSBundle    *bundle = [NSBundle bundleForClass:NSClassFromString(@"debayer_cifilterFilter")];
		NSStringEncoding encoding = NSUTF8StringEncoding;
		NSError     *error = nil;
		NSString    *code = [NSString stringWithContentsOfFile:[bundle pathForResource:@"debayer_cifilterFilterKernel" ofType:@"cikernel"] encoding:encoding error:&error];
		NSArray     *kernels = [CIKernel kernelsWithString:code];

		_debayer_cifilterFilterKernel = kernels[0];
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
    
    return [self apply:_debayer_cifilterFilterKernel,src,inputOffset,nil];
}

@end
