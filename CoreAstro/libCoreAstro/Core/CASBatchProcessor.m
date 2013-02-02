//
//  CASBatchProcessor.m
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

#import "CASBatchProcessor.h"
#import "CASImageProcessor.h"
#import "CASCCDExposureLibrary.h"
#import "CASCCDExposureIO.h"
#import <Accelerate/Accelerate.h>

@interface CASBatchProcessor ()
@property (nonatomic,strong) NSMutableArray* history;
- (void)start;
- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info;
- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block;
- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure;
@end

@interface CASCombineProcessor ()
@property (nonatomic,assign) NSInteger count;
@property (nonatomic,strong) CASCCDExposure* first;
@end

@implementation CASCombineProcessor { // todo; bench this against -averageSum, upgrage -averageSum to vDSP, combine the two models
    vImage_Buffer _final;
}

- (void)start
{
    [super start];
    
    bzero(&_final,sizeof(_final));
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    const CASSize size = exposure.actualSize;
    
    if (!self.first){
        self.first = exposure;
    }
    
    if (!_final.data){
        _final.data = calloc(size.width*size.height*sizeof(float),1);
        if (!_final.data){
            NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
            return;
        }
        _final.width = size.width;
        _final.height = size.height;
        _final.rowBytes = size.width*sizeof(float);
    }
    else {
        if (_final.width != size.width || _final.height != size.height){
            NSLog(@"%@: Ignoring exposure as it's the wrong size",NSStringFromSelector(_cmd));
            return;
        }
    }
    
    float* fbuf = (float*)[exposure.floatPixels bytes];
    if (!fbuf){
        NSLog(@"%@: No pixels for exposure",NSStringFromSelector(_cmd));
        return;
    }

    ++self.count;

    vDSP_vadd(fbuf,1,_final.data,1,_final.data,1,_final.width*_final.height);
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    if (self.mode == kCASCombineProcessorAverage){
        
        float fcount = self.count;
        vDSP_vsdiv(_final.data,1,(float*)&fcount,_final.data,1,_final.width*_final.height);
    }

    CASCCDExposure* result = [CASCCDExposure exposureWithFloatPixels:[NSData dataWithBytesNoCopy:_final.data length:_final.height*_final.rowBytes freeWhenDone:YES]
                                                              camera:nil
                                                              params:CASExposeParamsMake(_final.width,_final.height,0,0,_final.width,_final.height,1,1,self.first.params.bps,0)
                                                                time:[NSDate date]];
    
    result.type = self.first.type;

    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:result.meta];
    NSString* modeStr = (self.mode == kCASCombineProcessorAverage) ? @"average" : @"sum";
    [mutableMeta setObject:@{@"stack":@{@"images":self.history,@"mode":modeStr}} forKey:@"history"];
    if (self.mode == kCASCombineProcessorAverage){
        [mutableMeta setObject:[NSString stringWithFormat:@"Average of %@",self.first.displayName] forKey:@"displayName"];
    }else{
        [mutableMeta setObject:[NSString stringWithFormat:@"Sum of %@",self.first.displayName] forKey:@"displayName"];
    }
    result.meta = [mutableMeta copy];
    
    // this really should be associated with the parent device folder and live in there - perhaps with a special name indicating that it's a combined frame ?
    
    [[CASCCDExposureLibrary sharedLibrary] addExposure:result toProject:self.project save:YES block:^(NSError *error, NSURL *url) {
        
        NSLog(@"Added exposure at %@",url);
        
        block(error,result);
    }];
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    return @{@"uuid":exposure.uuid};
}

@end

@interface CASFlatDividerProcessor ()
@property (nonatomic,readonly) BOOL save;
@property (nonatomic,strong) CASCCDExposure* first;
@property (nonatomic,strong) CASCCDExposure* result;
@end

@implementation CASFlatDividerProcessor {
    CASCCDExposure* _normalisedFlat;
}

- (BOOL)save
{
    return YES;
}

- (void)start
{
    [super start];
    
    // create a normalised flat
    _normalisedFlat = [self.imageProcessor normalise:self.flat];
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    if (!self.first){
        self.first = exposure;
    }
    
    const CASSize size1 = self.flat.actualSize;
    const CASSize size2 = exposure.actualSize;
    if (size1.width != size2.width || size1.height != size2.height){
        NSLog(@"%@: Image sizes don't match",NSStringFromSelector(_cmd));
        return;
    }
    
    float* fbuf = (float*)[exposure.floatPixels bytes];
    float* fnorm = (float*)[_normalisedFlat.floatPixels bytes];
    if (!fbuf || !fnorm){
        NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
        return;
    }

    NSMutableData* corrected = [NSMutableData dataWithLength:[self.flat.floatPixels length]];
    if (!corrected){
        NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
        return;
    }

    vDSP_vdiv(fnorm,1,fbuf,1,(float*)[corrected mutableBytes],1,[corrected length]/sizeof(float));
    
    self.result = [CASCCDExposure exposureWithFloatPixels:corrected
                                                   camera:nil // exposure.camera
                                                   params:exposure.params
                                                     time:[NSDate date]];
    
    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:self.result.meta];
    [mutableMeta setObject:@{@"flat-correction":@{@"flat":self.flat.uuid,@"light":exposure.uuid}} forKey:@"history"];
    [mutableMeta setObject:@"Flat Corrected" forKey:@"displayName"];
    [mutableMeta setObject:[self.first.meta objectForKey:@"device"] forKey:@"device"];
    self.result.meta = [mutableMeta copy];
    
    if (self.save){
        
        [[CASCCDExposureLibrary sharedLibrary] addExposure:self.result toProject:self.project save:YES block:^(NSError *error, NSURL *url) {
            
            NSLog(@"Added flat corrected exposure at %@",url);
        }];
    }
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    block(nil,self.result);
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    return nil;
}

@end

@interface CASSubtractProcessor ()
@property (nonatomic,strong) CASCCDExposure* first;
@end

@implementation CASSubtractProcessor

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    if (!self.first){
        self.first = exposure;
    }
    
    const CASSize size1 = self.base.actualSize;
    const CASSize size2 = exposure.actualSize;
    if (size1.width != size2.width || size1.height != size2.height){
        NSLog(@"%@: Image sizes don't match",NSStringFromSelector(_cmd));
        return;
    }
    
    float* fbuf = (float*)[exposure.floatPixels bytes];
    float* fbase = (float*)[self.base.floatPixels bytes];
    if (!fbuf || !fbase){
        NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
        return;
    }
    
    NSMutableData* corrected = [NSMutableData dataWithLength:[self.base.floatPixels length]];
    if (!corrected){
        NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
        return;
    }
    
    vDSP_vsub(fbase,1,fbuf,1,(float*)[corrected mutableBytes],1,[corrected length]/sizeof(float));
    
    CASCCDExposure* result = [CASCCDExposure exposureWithFloatPixels:corrected
                                                              camera:nil // exposure.camera
                                                              params:exposure.params
                                                                time:[NSDate date]];
    
    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:result.meta];
    if (self.mode == kCASSubtractProcessorDark){
        [mutableMeta setObject:@{@"dark-correction":@{@"dark":self.base.uuid,@"light":exposure.uuid}} forKey:@"history"];
        [mutableMeta setObject:@"Dark Corrected" forKey:@"displayName"];
    }
    else {
        [mutableMeta setObject:@{@"bias-correction":@{@"bias":self.base.uuid,@"light":exposure.uuid}} forKey:@"history"];
        [mutableMeta setObject:@"Bias Corrected" forKey:@"displayName"];
    }
    result.meta = [mutableMeta copy];
    
    [[CASCCDExposureLibrary sharedLibrary] addExposure:result toProject:self.project save:YES block:^(NSError *error, NSURL *url) {
        
        NSLog(@"Added dark/bias corrected exposure at %@",url);
    }];
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    block(nil,nil);
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    return nil;
}

@end

@implementation CASCCDCorrectionProcessor

- (BOOL)save
{
    return NO;
}

- (void)_subtractExposure:(CASCCDExposure*)base from:(CASCCDExposure*)exposure
{
    // todo; move to -subtract on image processor
    
    float* fbuf = (float*)[exposure.floatPixels bytes];
    float* fbase = (float*)[base.floatPixels bytes];
    if (!fbuf || !fbase){
        NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
        return;
    }
    if ([exposure.floatPixels length] != [base.floatPixels length]){
        NSLog(@"%@: Exposure sizes don't match",NSStringFromSelector(_cmd));
        return;
    }
    
    vDSP_vsub(fbase,1,fbuf,1,fbuf,1,[exposure.floatPixels length]/sizeof(float));
}

- (void)_subtractDarkBiasFromExposure:(CASCCDExposure*)exposure
{
    if ([self.dark floatPixels]){
        [self _subtractExposure:self.dark from:exposure];
    }
    
    if ([self.bias floatPixels]){
        [self _subtractExposure:self.bias from:exposure];
    }
}

- (void)start
{
    self.flat = self.project.masterFlat;
    self.dark = self.project.masterDark;
    self.bias = self.project.masterBias;

    // subtract dark/bias from flat
    [self _subtractDarkBiasFromExposure:self.flat];
    
    // normalise
    [super start];
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    // subtract dark/bias from exposure
    [self _subtractDarkBiasFromExposure:exposure];
    
    // divide light by normalized flat
    [super processExposure:exposure withInfo:info];
    
    if (self.result){
        
        // cache the corrected exposure in the derived data folder of the original exposure
        NSString* path = [[[exposure.io derivedDataURLForName:kCASCCDExposureCorrectedKey] path] stringByAppendingPathExtension:@"caExposure"];
        CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
        if (io){
            
            self.result.io = io;
            
            NSError* error = nil;
            if ([io writeExposure:self.result writePixels:YES error:&error]){
                NSLog(@"Wrote corrected exposure to %@",path);
            }
            else {
                NSLog(@"Error %@ writing corrected exposure to %@",error,path);
            }
            
            self.result.io = nil;
        }
    }
}

@end

@interface CASCCDStackingProcessor ()
@property (nonatomic,strong) CASCCDExposure* first;
@property (nonatomic,strong) NSMutableData* working;
@property (nonatomic,strong) NSMutableData* accumulate;
@property (nonatomic,strong) NSMutableArray* history;
@end

@implementation CASCCDStackingProcessor {
    NSInteger _count;
    CGRect _searchFrame;
    CASRect _initialSearchFrame;
    CASSize _actualSize;
    NSPoint _referenceStar;
    CGFloat _searchInsetFraction;
    CGFloat _xThresh, _yThresh;
}

- (id)init
{
    self = [super init];
    if (self) {
        _xThresh = 20;
        _yThresh = 20;
        _searchInsetFraction = 0.2;
    }
    return self;
}

- (BOOL)save
{
    return NO;
}

- (CASGuideAlgorithm*)guideAlgorithm
{
    if (!_guideAlgorithm){
        _guideAlgorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
    }
    return _guideAlgorithm;
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    if (!exposure){
        return;
    }
     
    // use a corrected exposure for stacking if one is available (similarly for debayered)
    CASCCDExposure* corrected = exposure.correctedExposure;
    if (corrected){
        exposure = corrected;
    }
    
    if (!self.first){
        
        self.first = exposure;
        self.history = [NSMutableArray arrayWithCapacity:10];
        
        self.working = [NSMutableData dataWithLength:[self.first.floatPixels length]];
        self.accumulate = [NSMutableData dataWithLength:[self.first.floatPixels length]];
        
        if (![self.working mutableBytes] || ![self.accumulate mutableBytes]){
            NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
        }
        else {
            
            // start the accumulation buffer off with the first set of pixels
            memcpy([self.accumulate mutableBytes], [self.first.floatPixels bytes], [self.first.floatPixels length]);
            
            // get some basic stats
            _actualSize = self.first.actualSize;
            
            // figure out the subframe we'll do the initial star search in
            _initialSearchFrame = CASRectMake(CASPointMake(_actualSize.width * _searchInsetFraction,_actualSize.height * _searchInsetFraction),
                                       CASSizeMake(_actualSize.width - (2 * _actualSize.width * _searchInsetFraction),_actualSize.height - (2 * _actualSize.height * _searchInsetFraction)));
            NSLog(@"Using search frame of %@",NSStringFromCASRect(_initialSearchFrame));

            if (!self.guideAlgorithm){
                self.guideAlgorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
            }
            if (!self.imageProcessor){
                self.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
            }
            
            // locate the reference star
            CASCCDExposure* subframe = [self.first subframeWithRect:_initialSearchFrame];
            NSArray* stars = [self.guideAlgorithm locateStars:subframe];
            if (![stars count]){
                NSLog(@"%@: Found no stars in reference frame",NSStringFromSelector(_cmd));
            }
            else {
                
                // got an initial hit, now use a more precise algorithm to get a better fix
                _referenceStar = [[stars lastObject] pointValue];
                _searchFrame = CGRectMake(_referenceStar.x - _xThresh/2, _referenceStar.y - _xThresh/2, _xThresh, _yThresh);
                _referenceStar = [self.guideAlgorithm locateStar:subframe inArea:_searchFrame];
                if (_referenceStar.x == -1){
                    NSLog(@"%@: Found no stars in reference frame",NSStringFromSelector(_cmd));
                    return;
                }
                NSLog(@"Located reference star at %f,%f",_referenceStar.x,_referenceStar.y);
            }
        }
        
        return;
    }
    
    if (_referenceStar.x == -1){
        return;
    }
    
    // check the exposures match the reference
    const CASSize size2 = exposure.actualSize;
    if (_actualSize.width != size2.width || _actualSize.height != size2.height){
        NSLog(@"%@: Image sizes don't match",NSStringFromSelector(_cmd));
        return;
    }
        
    // search within the same area that we found the reference star for the corresponding one
    const NSPoint star = [self.guideAlgorithm locateStar:[exposure subframeWithRect:_initialSearchFrame] inArea:_searchFrame];
    if (star.x == -1){
        NSLog(@"%@: Found no stars in exposure frame",NSStringFromSelector(_cmd));
        return;
    }
    NSLog(@"Located star at %f,%f",star.x,star.y);

    // work out offsets
    const CGFloat xOffset = _referenceStar.x - star.x;
    const CGFloat yOffset = star.y - _referenceStar.y;
    NSLog(@"x-offset=%f, y-offset=%f",xOffset,yOffset);

    // check against threshold
    if (fabs(xOffset) > _xThresh){
        NSLog(@"xdiff %f exceeds threshold of %f, ignoring this exposure",xOffset,_xThresh);
        return;
    }
    if (fabs(yOffset) > _yThresh){
        NSLog(@"ydiff %f exceeds threshold of %f, ignoring this exposure",yOffset,_yThresh);
        return;
    }

    // apply correction to working pixels
    vImage_Buffer input = {
        .data = (void*)[[exposure floatPixels] bytes],
        .width = _actualSize.width,
        .height = _actualSize.height,
        .rowBytes = _actualSize.width * sizeof(float)
    };
    
    vImage_Buffer output = {
        .data = [self.working mutableBytes],
        .width = _actualSize.width,
        .height = _actualSize.height,
        .rowBytes = _actualSize.width * sizeof(float)
    };

    CGAffineTransform xform = CGAffineTransformIdentity;
    
    // create the appropriate affine transform
    NSDictionary* translateInfo = @{};
    if (xOffset != 0 || yOffset != 0){
        xform = CGAffineTransformConcat(xform,CGAffineTransformMakeTranslation(xOffset,yOffset));
        translateInfo = @{@"x":[NSNumber numberWithDouble:xOffset],@"y":[NSNumber numberWithDouble:yOffset]};
    }
        
    // add and entry to the history
    [self.history addObject:@{
        @"uuid":exposure.uuid,@"translate":translateInfo
     }];
    
    // translate the exposure relative to the reference star
    if (CGAffineTransformIsIdentity(xform)){
        memcpy([self.working mutableBytes],[[exposure floatPixels] bytes],_actualSize.width*_actualSize.height*sizeof(float));
    }
    else {
        const vImage_AffineTransform vxform = {
            .a = xform.a, .b = xform.b, .c = xform.c, .d = xform.d,
            .tx = xform.tx, .ty = xform.ty
        };
        vImageAffineWarp_PlanarF(&input, &output, nil, &vxform, 0, kvImageHighQualityResampling);
    }
    
    // add the translated pixels to accumulation buffer
    vDSP_vadd([self.accumulate mutableBytes],1,output.data,1,[self.accumulate mutableBytes],1,_actualSize.width*_actualSize.height);
    
    // bump the count
    ++_count;
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    // divide by number of images in the stack
    if ([self.accumulate mutableBytes]){
        if (_count > 1){
            float fcount = _count + 1;
            vDSP_vsdiv([self.accumulate mutableBytes],1,(float*)&fcount,[self.accumulate mutableBytes],1,_actualSize.width*_actualSize.height);
        }
    }
    
    CASCCDExposure* result = [CASCCDExposure exposureWithFloatPixels:self.accumulate
                                                              camera:nil
                                                              params:CASExposeParamsMake(_actualSize.width,_actualSize.height,0,0,_actualSize.width,_actualSize.height,1,1,self.first.params.bps,0)
                                                                time:[NSDate date]];
    
    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:self.first.meta];
    [mutableMeta setObject:[result.meta objectForKey:@"time"] forKey:@"time"];
    [mutableMeta setObject:@{@"stack":@{@"images":self.history,@"mode":@"average"}} forKey:@"history"];
    [mutableMeta setObject:[NSString stringWithFormat:@"Stack of %ld",_count + 1] forKey:@"displayName"];
    result.meta = [mutableMeta copy];
    
    result.format = kCASCCDExposureFormatFloat;

    [[CASCCDExposureLibrary sharedLibrary] addExposure:result toProject:self.project save:YES block:^(NSError *error, NSURL *url) {
        
        NSLog(@"Added stacked exposure at %@",url);
        
        block(error,result);
    }];
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    return nil;
}

@end

@implementation CASBatchProcessor

- (void)start
{
    self.history = [NSMutableArray arrayWithCapacity:100];
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    return @{@"uuid":exposure.uuid};
}

- (CASImageProcessor*)imageProcessor
{
    if (!_imageProcessor){
        _imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
    }
    return _imageProcessor;
}

- (void)processWithProvider:(void(^)(CASCCDExposure** exposure,NSDictionary** info))provider completion:(void(^)(NSError* error,CASCCDExposure*))completion
{
    NSParameterAssert(provider);
    NSParameterAssert(completion);
        
    [self start];

    for (;;){
        
        NSDictionary* info = nil;
        CASCCDExposure* exposure = nil;
        provider(&exposure,&info);
        if (!exposure){
            break;
        }
        
        id entry = [self historyWithExposure:exposure];
        if (entry){
            [self.history addObject:entry];
        }

        [exposure reset];

        @try {
            @autoreleasepool {
                [self processExposure:exposure withInfo:info];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"*** Exception processing exposure: %@",exposure);
        }

        [exposure reset];
    }
    
    [self completeWithBlock:completion];
}

- (void)processWithExposures:(NSArray*)exposures completion:(void(^)(NSError* error,CASCCDExposure*))completion
{
    NSEnumerator* exposureEnum = [exposures objectEnumerator];
    
    [self processWithProvider:^(CASCCDExposure **exposure, NSDictionary **info) {
        
        *exposure = [exposureEnum nextObject];
        
    } completion:completion];
}

+ (NSArray*)batchProcessorsForExposures:(NSArray*)exposures
{
    // todo; categories
    return [exposures count] ? @[
        @{@"id":@"correct",@"name":@"Correct"},
        @{@"id":@"stack.average",@"name":@"Quick Stack"},
        @{@"id":@"combine.sum",@"name":@"Combine Sum"},
        @{@"id":@"combine.average",@"name":@"Combine Average"}
    ] : nil;
}

+ (CASBatchProcessor*)batchProcessorsWithIdentifier:(id)identifier
{
    if ([@"combine.sum" isEqualToString:identifier]){
        CASCombineProcessor* combine = [[CASCombineProcessor alloc] init];
        combine.mode = kCASCombineProcessorSum;
        return combine;
    }
    
    if ([@"combine.average" isEqualToString:identifier]){
        CASCombineProcessor* combine = [[CASCombineProcessor alloc] init];
        combine.mode = kCASCombineProcessorAverage;
        return combine;
    }
    
    if ([@"stack.average" isEqualToString:identifier]){
        CASCCDStackingProcessor* stack = [[CASCCDStackingProcessor alloc] init];
        return stack;
    }

    if ([@"correct" isEqualToString:identifier]){
        CASCCDCorrectionProcessor* stack = [[CASCCDCorrectionProcessor alloc] init];
        return stack;
    }

    NSLog(@"*** No batch processor with identifier: %@",identifier);
    
    return nil;
}

@end
