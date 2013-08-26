//
//  ContrastStretchFilter.m
//  ContrastStretch
//
//  Created by Simon Taylor on 8/6/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASContrastStretchFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation CASContrastStretchFilter

static CIKernel *_ContrastStretchFilterKernel = nil;

- (id)init
{
    if(!_ContrastStretchFilterKernel) {
		NSBundle    *bundle = [NSBundle bundleForClass:NSClassFromString(@"CASContrastStretchFilter")];
		NSStringEncoding encoding = NSUTF8StringEncoding;
		NSError     *error = nil;
		NSString    *code = [NSString stringWithContentsOfFile:[bundle pathForResource:@"ContrastStretchFilterKernel" ofType:@"cikernel"] encoding:encoding error:&error];
		NSArray     *kernels = [CIKernel kernelsWithString:code];

		_ContrastStretchFilterKernel = kernels[0];
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
             @"inputMin":@{
                     kCIAttributeMin:@0,
                     kCIAttributeMax:@1,
                     kCIAttributeSliderMin:@0,
                     kCIAttributeSliderMax:@1,
                     kCIAttributeDefault:@0,
                     kCIAttributeIdentity:@0,
                     kCIAttributeType:kCIAttributeTypeScalar,
                     },
             @"inputMax":@{
                     kCIAttributeMin:@0,
                     kCIAttributeMax:@1,
                     kCIAttributeSliderMin:@0,
                     kCIAttributeSliderMax:@1,
                     kCIAttributeDefault:@1,
                     kCIAttributeIdentity:@1,
                     kCIAttributeType:kCIAttributeTypeScalar,
                     },
             @"inputGamma":@{
                     kCIAttributeMin:@0,
                     kCIAttributeMax:@10,
                     kCIAttributeSliderMin:@0,
                     kCIAttributeSliderMax:@10,
                     kCIAttributeDefault:@1,
                     kCIAttributeIdentity:@1,
                     kCIAttributeType:kCIAttributeTypeScalar,
                     },
             };
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
//    NSLog(@"inputImage: %@",inputImage);
//    NSLog(@"inputMin: %@",inputMin);
//    NSLog(@"inputMax: %@",inputMax);
//    NSLog(@"inputGamma: %@",inputGamma);

    CISampler* src = [CISampler samplerWithImage:inputImage];
        
    return [self apply:_ContrastStretchFilterKernel,src,inputMin,inputMax,inputGamma,nil];
}

@end
