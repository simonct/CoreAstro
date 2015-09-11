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

@interface CASExposureInfoView ()
@property (weak) IBOutlet NSTextField *averageValueField;
@property (weak) IBOutlet NSTextField *medianValueField;
@property (weak) IBOutlet NSTextField *minimumValueField;
@property (weak) IBOutlet NSTextField *maximumValueField;
@property (weak) IBOutlet NSTextField *standardDeviationValueField;
@end

@implementation CASExposureInfoView

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

- (void)clearFields
{
    self.medianValueField.stringValue = self.averageValueField.stringValue = self.minimumValueField.stringValue = self.maximumValueField.stringValue = self.standardDeviationValueField.stringValue = @"";
}

- (void)_updateImpl
{
    CASCCDExposure* exp = nil;
    CASCCDExposure* currentExposure = self.exposure;
    const BOOL isSubframe = _exposure.isSubframe;
    if (_subframe.size.width > 0 && _subframe.size.height > 0 && !isSubframe){ // todo; subframes of subframes
        exp = [currentExposure subframeWithRect:self.subframe];
    }
    else {
        exp = currentExposure;
    }
    if (exp){
        
        [self clearFields];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        
            const float maxPixelValue = self.exposure.maxPixelValue;
            
            const float median = floor(maxPixelValue * [self.imageProcessor medianPixelValue:exp]);
            const float average = floor(maxPixelValue * [self.imageProcessor averagePixelValue:exp]);
            const float minimum = floor(maxPixelValue * [self.imageProcessor minimumPixelValue:exp]);
            const float maximum = floor(maxPixelValue * [self.imageProcessor maximumPixelValue:exp]);
            const float stddev = floor(maxPixelValue * [self.imageProcessor standardDeviationPixelValue:exp]);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (currentExposure == _exposure){

                    self.medianValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)median];
                    self.averageValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)average];
                    self.minimumValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)minimum];
                    self.maximumValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)maximum];
                    self.standardDeviationValueField.stringValue = [NSString stringWithFormat:@"%ld",(NSInteger)stddev];
                }
            });
        });
    }
    else {
        [self clearFields];
    }
}

- (void)update
{
    if (self.isHidden){
        return;
    }
    
    [self clearFields];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateImpl) object:nil];
    [self performSelector:@selector(_updateImpl) withObject:nil afterDelay:0.1];
}

- (void)setHidden:(BOOL)flag
{
    [super setHidden:flag];
    
    if (!self.isHidden){
        [self update];
    }
}

@end
