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
                                                              params:CASExposeParamsMake(_final.width,_final.height,0,0,_final.width,_final.height,1,1,0,0)
                                                                time:[NSDate date]];
    
    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:result.meta];
    [mutableMeta setObject:@{@"stack":self.history} forKey:@"history"];
    [mutableMeta setObject:@{@"name":@"Average"} forKey:@"device"];
    result.meta = [mutableMeta copy];
    
    // this really should be associated with the parent device folder and live in there - perhaps with a special name indicating that it's a combined frame ?
    
    [[CASCCDExposureLibrary sharedLibrary] addExposure:result save:YES block:^(NSError *error, NSURL *url) {
        
        NSLog(@"Added exposure at %@",url);
        
        block(error,result);
    }];
}

- (NSDictionary*)historyWithExposure:(CASCCDExposure*)exposure
{
    NSString* modeStr = (self.mode == kCASCombineProcessorAverage) ? @"average" : @"sum";
    return @{@"uuid":exposure.uuid,@"mode":modeStr};
}

@end

@interface CASFlatDividerProcessor ()
@property (nonatomic,readonly) BOOL save;
@property (nonatomic,strong) CASCCDExposure* first;
@property (nonatomic,strong) CASCCDExposure* result;
@end

@implementation CASFlatDividerProcessor {
    NSMutableData* _normalisedFlat;
}

- (BOOL)save
{
    return YES;
}

- (void)start
{
    [super start];

    // get average flat value
    float average = 0;
    float* fbuf = (float*)[self.flat.floatPixels bytes];
    vDSP_meamgv(fbuf,1,&average,[self.flat.floatPixels length]/sizeof(float));
    //NSLog(@"average: %f",average);
    
    if (average == 0){
        return;
    }
    
    // make a copy with the normalised values
    _normalisedFlat = [NSMutableData dataWithLength:[self.flat.floatPixels length]];
    if (_normalisedFlat){
        float* fnorm = (float*)[_normalisedFlat mutableBytes];
        vDSP_vsdiv(fbuf,1,(float*)&average,fnorm,1,[_normalisedFlat length]/sizeof(float));
//        {
//            float average = 0;
//            vDSP_meamgv(fnorm,1,&average,[_normalisedFlat length]/sizeof(float));
//            NSLog(@"average: %f",average);
//        }
    }
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
    float* fnorm = (float*)[_normalisedFlat mutableBytes];
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
    
    if (self.save){
        
        NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:self.result.meta];
        [mutableMeta setObject:@{@"flat-correction":@{@"flat":self.flat.uuid,@"light":exposure.uuid}} forKey:@"history"];
        [mutableMeta setObject:@{@"name":@"Corrected"} forKey:@"device"];
        self.result.meta = [mutableMeta copy];
        
        [[CASCCDExposureLibrary sharedLibrary] addExposure:self.result save:YES block:^(NSError *error, NSURL *url) {
            
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
    }
    else {
        [mutableMeta setObject:@{@"bias-correction":@{@"bias":self.base.uuid,@"light":exposure.uuid}} forKey:@"history"];
    }
    [mutableMeta setObject:@{@"name":@"Corrected"} forKey:@"device"];
    result.meta = [mutableMeta copy];
    
    [[CASCCDExposureLibrary sharedLibrary] addExposure:result save:YES block:^(NSError *error, NSURL *url) {
        
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

@implementation CASCCDReductionProcessor

- (BOOL)save
{
    return NO;
}

- (void)_subtractExposure:(CASCCDExposure*)base from:(CASCCDExposure*)exposure
{
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
    return [exposures count] ? @[
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
    
    NSLog(@"*** No batch processor with identifier: %@",identifier);
    
    return nil;
}

@end