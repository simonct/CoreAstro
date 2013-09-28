//
//  SXIOExposureEnumerator.h
//  SX IO
//
//  Created by Simon Taylor on 9/25/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@interface SXIOExposureEnumerator : NSObject<NSFastEnumeration>

@property (nonatomic,copy) NSURL* url;

@property (readonly,readonly) NSArray* allExposures;

@property (nonatomic,readonly) CASCCDExposure* nextExposure;
@property (nonatomic,readonly) CASCCDExposure* previousExposure;

- (id)objectAtIndexedSubscript:(NSUInteger)idx;

+ (instancetype)enumeratorWithURL:(NSURL*)url;

@end
