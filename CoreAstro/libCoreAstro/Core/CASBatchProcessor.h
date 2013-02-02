//
//  CASBatchProcessor.h
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

#import "CASCCDExposure.h"
#import "CASImageProcessor.h"
#import "CASAutoGuider.h"

@class CASCCDExposureLibraryProject;

@interface CASBatchProcessor : NSObject

@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASCCDExposureLibraryProject* project;

- (void)processWithProvider:(void(^)(CASCCDExposure** exposure,NSDictionary** info))provider completion:(void(^)(NSError* error,CASCCDExposure*))completion;
- (void)processWithExposures:(NSArray*)exposures completion:(void(^)(NSError* error,CASCCDExposure*))completion;

+ (NSArray*)batchProcessorsForExposures:(NSArray*)exposures;
+ (CASBatchProcessor*)batchProcessorsWithIdentifier:(id)identifier;

@end

@interface CASCombineProcessor : CASBatchProcessor
enum {
    kCASCombineProcessorSum,
    kCASCombineProcessorAverage
};
@property (nonatomic,assign) NSInteger mode;
@end

@interface CASFlatDividerProcessor : CASBatchProcessor
@property (nonatomic,strong) CASCCDExposure* flat;
@end

@interface CASSubtractProcessor : CASBatchProcessor
enum {
    kCASSubtractProcessorDark,
    kCASSubtractProcessorBias
};
@property (nonatomic,assign) NSInteger mode;
@property (nonatomic,strong) CASCCDExposure* base;
@end

@interface CASCCDReductionProcessor : CASFlatDividerProcessor
@property (nonatomic,strong) CASCCDExposure* bias;
@property (nonatomic,strong) CASCCDExposure* dark;
@property (nonatomic,strong) CASCCDExposure* flat;
@end

@interface CASCCDStackingProcessor : CASBatchProcessor
@property (nonatomic,strong) id<CASGuideAlgorithm> guideAlgorithm;
@end