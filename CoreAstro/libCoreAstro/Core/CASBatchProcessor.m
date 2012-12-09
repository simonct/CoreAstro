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

@interface CASCombineProcessor ()
@property (nonatomic,assign) NSInteger count;
@property (nonatomic,strong) CASCCDExposure* first;
@end

@implementation CASCombineProcessor { // todo; bench this against -averageSum, upgrage -averageSum to vDSP, combine the two models
    vImage_Buffer _final;
}

- (void)start
{
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
    //        [mutableMeta setObject:@{@"stack":stackHistory} forKey:@"history"];
    [mutableMeta setObject:@{@"name":@"Average"} forKey:@"device"];
    result.meta = [mutableMeta copy];
    
    // this really should be associated with the parent device folder and live in there - perhaps with a special name indicating that it's a combined frame ?
    
    [[CASCCDExposureLibrary sharedLibrary] addExposure:result save:YES block:^(NSError *error, NSURL *url) {
        
        NSLog(@"Added exposure at %@",url);
        
        block(error,result);
    }];
}

@end

@interface CASFlatDividerProcessor ()
@property (nonatomic,strong) CASCCDExposure* first;
@end

@implementation CASFlatDividerProcessor {
    NSMutableData* _normalisedFlat;
}

- (void)start
{
    // get average flat value
    float average = 0;
    float* fbuf = (float*)[self.flat.floatPixels bytes];
    vDSP_meamgv(fbuf,1,&average,[self.flat.floatPixels length]/sizeof(float));
    
    if (average == 0){
        return;
    }
    
    // make a copy with the normalised values
    _normalisedFlat = [NSMutableData dataWithLength:[self.flat.floatPixels length]];
    if (_normalisedFlat){
        float* fnorm = (float*)[_normalisedFlat mutableBytes];
        vDSP_vsdiv(fbuf,1,(float*)&average,fnorm,1,[_normalisedFlat length]/sizeof(float));
        {
            float average = 0;
            vDSP_meamgv(fnorm,1,&average,[self.flat.floatPixels length]/sizeof(float));
        }
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
    
    CASCCDExposure* result = [CASCCDExposure exposureWithFloatPixels:corrected
                                                              camera:nil
                                                              params:CASExposeParamsMake(size1.width,size1.height,0,0,size1.width,size1.height,1,1,0,0)
                                                                time:[NSDate date]];

    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:result.meta];
    //        [mutableMeta setObject:@{@"stack":stackHistory} forKey:@"history"];
    [mutableMeta setObject:@{@"name":@"Corrected"} forKey:@"device"];
    result.meta = [mutableMeta copy];

    // this really should be associated with the parent device folder and live in there - perhaps with a special name indicating that it's a combined frame ?

    [[CASCCDExposureLibrary sharedLibrary] addExposure:result save:YES block:^(NSError *error, NSURL *url) {

        NSLog(@"Added exposure at %@",url);
    }];
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
    block(nil,nil);
}

@end

@implementation CASBatchProcessor

- (void)start
{
}

- (void)processExposure:(CASCCDExposure*)exposure withInfo:(NSDictionary*)info
{
}

- (void)completeWithBlock:(void(^)(NSError* error,CASCCDExposure*))block
{
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
                
        [self processExposure:exposure withInfo:info];
        
        [exposure reset];
    }
    
    [self completeWithBlock:completion];
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
