//
//  CASExposureInfoView.m
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

#import "CASExposureInfoView.h"

BOOL CASRectEqualToRect(CASRect a,CASRect b)
{
    return (a.size.width == b.size.width && a.size.height == b.size.height && a.origin.x == b.origin.x && a.origin.y == b.origin.y);
}

@interface CASExposureInfoView ()
@property (weak) IBOutlet NSTextField *averageValueField;
@property (weak) IBOutlet NSTextField *minimumValueField;
@property (weak) IBOutlet NSTextField *maximumValueField;
@property (weak) IBOutlet NSTextField *standardDeviationValueField;
@end

@implementation CASExposureInfoView

- (void)awakeFromNib
{
    self.wantsLayer = YES;
    self.layer.backgroundColor = CGColorCreateGenericRGB(0,0,0,0.5);
    self.layer.cornerRadius = 10;
    self.layer.borderWidth = 2.5;
    self.layer.borderColor = CGColorCreateGenericRGB(1,1,1,0.8);
}

- (void)setExposure:(CASCCDExposure *)exposure
{
    if (exposure != _exposure){
        _exposure = exposure;
        [self update];
    }
}

- (void)setSubframe:(CASRect)subframe
{
    if (!CASRectEqualToRect(subframe,_subframe)){
        _subframe = subframe;
        [self update];
    }
}

- (void)update
{
    CASCCDExposure* exp = nil;
    if (_subframe.size.width > 0 && _subframe.size.height > 0){
        exp = [self.exposure subframeWithRect:self.subframe];
    }
    else {
        exp = self.exposure;
    }
    if (exp){
        // async ?
        const float maxPixelValue = 65535;
        self.averageValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)floor(maxPixelValue * [self.imageProcessor averagePixelValue:exp])];
        self.minimumValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)floor(maxPixelValue * [self.imageProcessor minimumPixelValue:exp])];
        self.maximumValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)floor(maxPixelValue * [self.imageProcessor maximumPixelValue:exp])];
        self.standardDeviationValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)floor(maxPixelValue * [self.imageProcessor standardDeviationPixelValue:exp])];
        self.alphaValue = 1;
    }
    else {
        self.averageValueField.stringValue = self.minimumValueField.stringValue = self.maximumValueField.stringValue = self.standardDeviationValueField.stringValue = @"";
        self.alphaValue = 0;
    }
}

+ (id)loadExposureInfoView
{
    NSArray* objects = nil;
    NSNib* nib = [[NSNib alloc] initWithNibNamed:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
    [nib instantiateNibWithOwner:nil topLevelObjects:&objects];
    for (id obj in objects){
        if ([obj isKindOfClass:[self class]]){
            return obj;
        }
    }
    return nil;
}

@end
