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
#import "CASImageDebayer.h"
#import <Accelerate/Accelerate.h>

@interface CASBatchProcessor ()
@property (nonatomic,strong) CASCCDExposure* first;
@property (nonatomic,strong) CASCCDExposure* result;
@property (nonatomic,strong) NSMutableArray* history;
- (void)start;
- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info;
- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block;
- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure;
@end

@interface CASCombineProcessor ()
@property (nonatomic,assign) NSInteger count;
@end

@implementation CASCombineProcessor { // todo; bench this against -averageSum, upgrage -averageSum to vDSP, combine the two models
    vImage_Buffer _final;
    NSInteger _totalExposureTimeMS;
}

- (void)start
{
    [super start];
    
    bzero(&_final,sizeof(_final));
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    NSParameterAssert(exposure);
    
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
    
    _totalExposureTimeMS += exposure.params.ms;

    vDSP_vadd(fbuf,1,_final.data,1,_final.data,1,_final.width*_final.height);
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    if (self.mode == kCASCombineProcessorAverage){
        
        float fcount = self.count;
        vDSP_vsdiv(_final.data,1,(float*)&fcount,_final.data,1,_final.width*_final.height);
    }

    NSInteger exposureTime = 0;
    if (self.mode == kCASCombineProcessorAverage){
        exposureTime = _totalExposureTimeMS / self.count;
    }else{
        exposureTime = _totalExposureTimeMS;
    }

    CASCCDExposure* result = [CASCCDExposure exposureWithFloatPixels:[NSData dataWithBytesNoCopy:_final.data length:_final.height*_final.rowBytes freeWhenDone:YES]
                                                              camera:nil
                                                              params:CASExposeParamsMake(_final.width,_final.height,0,0,_final.width,_final.height,1,1,self.first.params.bps,exposureTime)
                                                                time:[NSDate date]];
    
    result.type = self.first.type;

    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:result.meta];
    NSString* modeStr = (self.mode == kCASCombineProcessorAverage) ? @"average" : @"sum";
    [mutableMeta setObject:@[@{@"stack":@{@"images":self.history,@"mode":modeStr}}] forKey:@"history"];
    if (self.mode == kCASCombineProcessorAverage){
        exposureTime = _totalExposureTimeMS / self.count;
        [mutableMeta setObject:[NSString stringWithFormat:@"Average of %@",self.first.displayName] forKey:@"displayName"];
    }else{
        exposureTime = _totalExposureTimeMS;
        [mutableMeta setObject:[NSString stringWithFormat:@"Sum of %@",self.first.displayName] forKey:@"displayName"];
    }
    [mutableMeta setObject:[self.first.meta objectForKey:@"device"] forKey:@"device"];
    [mutableMeta setObject:self.first.meta[@"time"] forKey:@"time"];
    result.meta = [mutableMeta copy];
    result.format = kCASCCDExposureFormatFloat;

    if (!self.autoSave){
        block(nil,result);
    }
    else{
        [[CASCCDExposureLibrary sharedLibrary] addExposure:result toProject:self.project save:YES block:^(NSError *error, NSURL *url) {
            NSLog(@"Added combined exposure at %@",url);
            block(error,result);
        }];
    }
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    return @{@"uuid":exposure.uuid};
}

@end

@implementation CASCCDCorrectionProcessor {
    CASCCDExposure* _normalisedFlat;
}

- (BOOL)save
{
    return NO;
}

- (CASCCDExposure*)_subtractDarkBiasFromExposure:(CASCCDExposure*)exposure
{
    if (self.dark){
        return [self.imageProcessor subtract:self.dark from:exposure];
    }
    else if (self.bias){
        return [self.imageProcessor subtract:self.bias from:exposure];
    }
    
    // todo; dark, bias history

    return [exposure copy];
}

- (void)start
{
    [super start];
    
    if (!self.flat) self.flat = self.project.masterFlat;
    if (!self.dark) self.dark = self.project.masterDark;
    if (!self.bias) self.bias = self.project.masterBias;
    
    // todo; flat darks and bias frames

    // create a normalised flat
    if (self.flat){
        
        self.flat = [self _subtractDarkBiasFromExposure:self.flat];
        
        _normalisedFlat = [self.imageProcessor normalise:self.flat];
    }
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    NSParameterAssert(exposure);

    if (exposure.type != kCASCCDExposureLightType){
        NSLog(@"%@: Ignoring exposure of type %d",NSStringFromSelector(_cmd),exposure.type);
        return;
    }
    if (exposure.rgba){
        NSLog(@"%@: Ignoring RGBA exposure",NSStringFromSelector(_cmd));
        return;
    }
    
    if (!self.first){
        self.first = exposure;
    }
    
    // subtract dark/bias from exposure
    self.result = [self _subtractDarkBiasFromExposure:exposure];
    
    // divide out the flat if we've got one
    if (self.flat){
    
        const CASSize size1 = self.flat.actualSize;
        const CASSize size2 = self.result.actualSize;
        if (size1.width != size2.width || size1.height != size2.height){
            NSLog(@"%@: Image sizes don't match",NSStringFromSelector(_cmd));
            return;
        }
        
        float* fbuf = (float*)[self.result.floatPixels bytes];
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
                                                       params:self.result.params
                                                         time:[NSDate date]];
        
        NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:self.first.meta];
        [mutableMeta setObject:@[@{@"flat-correction":@{@"flat":self.flat.uuid,@"light":self.result.uuid}}] forKey:@"history"];
        [mutableMeta setObject:@"Flat Corrected" forKey:@"displayName"];
        id device = [self.first.meta objectForKey:@"device"];
        if (device){
            [mutableMeta setObject:device forKey:@"device"];
        }
        id time = self.first.meta[@"time"];
        if (time){
            [mutableMeta setObject:time forKey:@"time"];
        }
        self.result.meta = [mutableMeta copy];
        self.result.format = kCASCCDExposureFormatFloat;
    }

    [self writeResult:self.result fromExposure:exposure error:nil];
}

- (BOOL)writeResult:(CASCCDExposure*)result fromExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    NSError* error = nil;

    if (result && exposure.io){
        
        // factor this out so it can be re-implemented by a subclass
        
        // cache the corrected exposure in the derived data folder of the original exposure
        NSString* path = [[[exposure.io derivedDataURLForName:kCASCCDExposureCorrectedKey] path] stringByAppendingPathExtension:@"caExposure"];
        CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
        if (!io){
            NSLog(@"%@: No IO for %@",NSStringFromSelector(_cmd),path);
        }
        else{
        
            // remove any existing corrected exposure
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            
            // write the corrected exposure out
            result.io = io;
            result.format = kCASCCDExposureFormatFloat;
            if ([io writeExposure:result writePixels:YES error:&error]){
                NSLog(@"Wrote corrected exposure to %@",path);
            }
            else {
                NSLog(@"Error %@ writing corrected exposure to %@",error,path);
            }
        }
    }
    
    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
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

@interface CASCCDStackingProcessor ()
@property (nonatomic,strong) CASCCDExposure* first;
@property (nonatomic,strong) NSMutableData* working;
@property (nonatomic,strong) NSMutableData* accumulate;
@property (nonatomic,strong) NSMutableArray* history;
@end

@implementation CASCCDStackingProcessor {
    CGRect _searchFrame;
    CASRect _initialSearchFrame;
    CASSize _actualSize;
    NSPoint _referenceStar;
    CGFloat _searchInsetFraction;
    CGFloat _xThresh, _yThresh;
    NSInteger _totalExposureTimeMS;
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
    NSParameterAssert(exposure);

    if (exposure.type != kCASCCDExposureLightType){
        NSLog(@"%@: Ignoring exposure of type %d",NSStringFromSelector(_cmd),exposure.type);
        return;
    }
     
    // use a corrected exposure for stacking if one is available (similarly for debayered)
    exposure = [self exposureFromExposure:exposure];
    
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
            _totalExposureTimeMS = self.first.params.ms;
            
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
            
            // locate the reference star making sure we're using a luminance frame
            CASCCDExposure* subframe = [self.imageProcessor luminance:[self.first subframeWithRect:_initialSearchFrame]];

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
    
    if (exposure.rgba != self.first.rgba){
        NSLog(@"%@: Pixel formats don't match",NSStringFromSelector(_cmd));
        return;
    }
        
    // search within the same area that we found the reference star for the corresponding one
    const NSPoint star = [self.guideAlgorithm locateStar:[self.imageProcessor luminance:[exposure subframeWithRect:_initialSearchFrame]] inArea:_searchFrame];
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
        .rowBytes = _actualSize.width * exposure.pixelSize
    };
    
    vImage_Buffer output = {
        .data = [self.working mutableBytes],
        .width = _actualSize.width,
        .height = _actualSize.height,
        .rowBytes = _actualSize.width * exposure.pixelSize
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
    
    // accumulate the exposure time
    _totalExposureTimeMS += exposure.params.ms;
    
    // translate the exposure relative to the reference star
    if (CGAffineTransformIsIdentity(xform)){
        memcpy([self.working mutableBytes],[[exposure floatPixels] bytes],_actualSize.width*_actualSize.height*exposure.pixelSize);
    }
    else {
        const vImage_AffineTransform vxform = {
            .a = xform.a, .b = xform.b, .c = xform.c, .d = xform.d,
            .tx = xform.tx, .ty = xform.ty
        };
        if (exposure.rgba){
            vImageAffineWarp_ARGBFFFF(&input, &output, nil, &vxform, 0, kvImageHighQualityResampling|kvImageEdgeExtend);
        }
        else {
            vImageAffineWarp_PlanarF(&input, &output, nil, &vxform, 0, kvImageHighQualityResampling|kvImageEdgeExtend);
        }
    }
    
    // add the translated pixels to accumulation buffer
    const NSInteger length = exposure.rgba ? _actualSize.width*_actualSize.height*4 : _actualSize.width*_actualSize.height;
    vDSP_vadd([self.accumulate mutableBytes],1,output.data,1,[self.accumulate mutableBytes],1,length);
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    const float fcount = [self.history count] + 1;

    // divide by number of images in the stack
    if (fcount > 1){
        const NSInteger length = self.first.rgba ? _actualSize.width*_actualSize.height*4 : _actualSize.width*_actualSize.height;
        vDSP_vsdiv([self.accumulate mutableBytes],1,(float*)&fcount,[self.accumulate mutableBytes],1,length);
        // clip ?
    }
    
    CASCCDExposure* result = nil;
    if (self.first.rgba){
        result = [CASCCDExposure exposureWithRGBAFloatPixels:self.accumulate
                                                      camera:nil
                                                      params:CASExposeParamsMake(_actualSize.width,_actualSize.height,0,0,_actualSize.width,_actualSize.height,1,1,self.first.params.bps,_totalExposureTimeMS)
                                                        time:[NSDate date]];
    }
    else {
        result = [CASCCDExposure exposureWithFloatPixels:self.accumulate
                                                  camera:nil
                                                  params:CASExposeParamsMake(_actualSize.width,_actualSize.height,0,0,_actualSize.width,_actualSize.height,1,1,self.first.params.bps,_totalExposureTimeMS)
                                                    time:[NSDate date]];
    }
    
    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:self.first.meta];
    mutableMeta[@"time"] = [result.meta objectForKey:@"time"];
    mutableMeta[@"history"] = @[@{@"stack":@{@"images":self.history,@"mode":@"average"}}];
    mutableMeta[@"displayName"] = [NSString stringWithFormat:@"Stack of %ld",(NSInteger)fcount];
    mutableMeta[@"exposure"] = NSStringFromCASExposeParams(result.params);
    result.meta = [mutableMeta copy];
    
    result.format = self.first.rgba ? kCASCCDExposureFormatFloatRGBA : kCASCCDExposureFormatFloat;

    if (!self.autoSave){
        block(nil,result);
    }
    else{
        [[CASCCDExposureLibrary sharedLibrary] addExposure:result toProject:self.project save:YES block:^(NSError *error, NSURL *url) {
            NSLog(@"Added stacked exposure at %@",url);
            block(error,result);
        }];
    }
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    return nil;
}

@end

@interface CASCCDDebayerProcessor : CASBatchProcessor
@property (nonatomic,assign) NSInteger mode;
@property (nonatomic,strong) CASImageDebayer* imageDebayer;
@end

@implementation CASCCDDebayerProcessor

- (id)init
{
    self = [super init];
    if (self) {
        self.imageDebayer = [CASImageDebayer imageDebayerWithIdentifier:nil];
    }
    return self;
}

- (CASCCDExposure*)exposureFromExposure:(CASCCDExposure*)exposure
{
    // get any corrected exposure (not getting any debayered one for obvious reasons)
    if (exposure.correctedExposure){
        exposure = exposure.correctedExposure;
    }
    return exposure;
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    NSParameterAssert(exposure);

    self.imageDebayer.mode = self.mode;
    
    exposure = [self exposureFromExposure:exposure];

    self.imageDebayer.mode = self.mode; // todo; should really be an arg to -debayer:
    
    CASCCDExposure* debayered = [self.imageDebayer debayer:exposure];
    
    // fixup metadata
    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:debayered.meta];

    [mutableMeta setObject:[exposure.meta objectForKey:@"device"] forKey:@"device"];
    
    // get current history, append this value
    NSMutableArray* history = nil;
    id existingHistory = exposure.meta[@"history"];
    if (existingHistory){
        if ([existingHistory isKindOfClass:[NSArray class]]){
            history = [NSMutableArray arrayWithArray:existingHistory];
        }
        else {
            history = [NSMutableArray arrayWithObject:existingHistory];
        }
    }
    if (!history){
        history = [NSMutableArray arrayWithCapacity:1];
    }
    NSString* modeStr;
    switch (self.mode) {
        case kCASImageDebayerRGGB:
            modeStr = @"RGGB";
            break;
        case kCASImageDebayerGRBG:
            modeStr = @"GRBG";
            break;
        case kCASImageDebayerBGGR:
            modeStr = @"BGGR";
            break;
        case kCASImageDebayerGBRG:
            modeStr = @"GBRG";
            break;
    }
    [history addObject:@{@"debayer":@{@"images":exposure.uuid,@"mode":modeStr}}];
    [mutableMeta setObject:[history copy] forKey:@"history"];
    
    // preserve exposure time
    [mutableMeta setObject:exposure.meta[@"time"] forKey:@"time"];

    debayered.meta = [mutableMeta copy];

    // cache the debayered exposure in the derived data folder of the original exposure
    NSString* path = [[[exposure.io derivedDataURLForName:kCASCCDExposureDebayeredKey] path] stringByAppendingPathExtension:@"caExposure"];
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
    if (!io){
        NSLog(@"%@: No IO for %@",NSStringFromSelector(_cmd),path);
    }
    else{
    
        // remove any existing debayered exposure
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        
        debayered.io = io;
        
        NSError* error = nil;
        if ([io writeExposure:debayered writePixels:YES error:&error]){
            NSLog(@"Wrote debayered exposure to %@",path);
        }
        else {
            NSLog(@"Error %@ writing corrected exposure to %@",error,path);
        }
    }
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

@interface CASCCDRevertProcessor : CASBatchProcessor
@end

@implementation CASCCDRevertProcessor

- (CASCCDExposure*)exposureFromExposure:(CASCCDExposure*)exposure
{
    return exposure;
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
    NSParameterAssert(exposure);

    BOOL isDirectory;
    NSString* path = [[[exposure.io derivedDataURLForName:kCASCCDExposureDebayeredKey] path] stringByDeletingLastPathComponent];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]){
        if (isDirectory){
            NSError* error;
            if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]){
                NSLog(@"Failed to revert exposure: %@",error);
            }
        }
    }
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    block(nil,nil);
}

@end

@implementation CASBatchProcessor

- (id)init
{
    self = [super init];
    if (self) {
        self.autoSave = YES;
    }
    return self;
}

- (void)start
{
    self.history = [NSMutableArray arrayWithCapacity:100];
}

- (CASCCDExposure*)exposureFromExposure:(CASCCDExposure*)exposure
{
    CASCCDExposure* corrected = exposure.correctedExposure;
    if (corrected){
        exposure = corrected;
    }
    CASCCDExposure* debayered = exposure.debayeredExposure;
    if (debayered){
        exposure = debayered;
    }
    return exposure;
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
        @{@"id":@"combine.average",@"name":@"Combine Average"},
        @{@"category":@"Debayer",@"actions":@[
                  @{@"id":@"debayer.RGGB",@"name":@"Debayer RGGB"},
                  @{@"id":@"debayer.GRBG",@"name":@"Debayer GRBG"},
                  @{@"id":@"debayer.BGGR",@"name":@"Debayer BGGR"},
                  @{@"id":@"debayer.GBRG",@"name":@"Debayer GBRG"}]},
        @{@"id":@"revert",@"name":@"Revert to Original"}
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

    if ([identifier hasPrefix:@"debayer."]){
        
        CASCCDDebayerProcessor* debayer = [[CASCCDDebayerProcessor alloc] init];
        
        if ([identifier hasSuffix:@"RGGB"]){
            debayer.mode = kCASImageDebayerRGGB;
        }
        else if ([identifier hasSuffix:@"GRBG"]){
            debayer.mode = kCASImageDebayerGRBG;
        }
        else if ([identifier hasSuffix:@"BGGR"]){
            debayer.mode = kCASImageDebayerBGGR;
        }
        else if ([identifier hasSuffix:@"GBRG"]){
            debayer.mode = kCASImageDebayerGBRG;
        }
        else {
            NSLog(@"Unrecognised debayer identifier %@",identifier);
            debayer = nil;
        }

        return debayer;
    }

    if ([@"revert" isEqualToString:identifier]){
        CASCCDRevertProcessor* revert = [[CASCCDRevertProcessor alloc] init];
        return revert;
    }
    

    NSLog(@"*** No batch processor with identifier: %@",identifier);
    
    return nil;
}

@end
