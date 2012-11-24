//
//  CASImageStacker.h
//  CoreAstro
//
//  Created by Simon Taylor on 20/11/2012.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CASCCDExposure;

@interface CASImageStacker : NSObject

typedef struct {
    CGPoint offset;
    CGFloat angle;
} CASImageStackerInfo;

- (void)stackWithProvider:(void(^)(NSInteger index,CASCCDExposure** exposure,CASImageStackerInfo* info))provider count:(NSInteger)count block:(void(^)(CASCCDExposure*))block;

+ (id)createImageStackerWithIdentifier:(NSString*)ident;

@end
