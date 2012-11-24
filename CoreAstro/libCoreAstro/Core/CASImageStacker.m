//
//  CASImageStacker.m
//  CoreAstro
//
//  Created by Simon Taylor on 20/11/2012.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASImageStacker.h"
#import "CASCCDExposure.h"
#import <Accelerate/Accelerate.h>

@implementation CASImageStacker


- (void)stackWithProvider:(void(^)(NSInteger index,CASCCDExposure** exposure,CASImageStackerInfo* info))provider count:(NSInteger)count block:(void(^)(CASCCDExposure*))block
{
    NSParameterAssert(provider);
    NSParameterAssert(block);
    NSParameterAssert(count > 1);

    CASCCDExposure* first = nil;
    float* outputData = nil;

    vImage_Buffer final;
    bzero(&final,sizeof(final));
    
    NSMutableArray* stackHistory = [NSMutableArray arrayWithCapacity:count];
    
    for (NSInteger i = 0; i < count; ++i){
        
        CASImageStackerInfo info;
        bzero(&info,sizeof(info));

        CASCCDExposure* exposure = nil;
        provider(i,&exposure,&info);
        if (!exposure){
            break;
        }
        if (!first){
            first = exposure;
        }
        
        const CASSize size = exposure.actualSize;

        if (!final.data){
            final.data = calloc(size.width*size.height*sizeof(float),1);
            final.width = size.width;
            final.height = size.height;
            final.rowBytes = size.width*sizeof(float);
        }
        else {
            if (final.width != size.width || final.height != size.height){
                NSLog(@"%@: Ignoring exposure as it's the wrong size",NSStringFromSelector(_cmd));
                continue;
            }
        }
        
        if (!final.data){
            NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
            return;
        }
        
        float* fbuf = (float*)[exposure.floatPixels bytes];
        if (!outputData){
            outputData = malloc(size.width*size.height*sizeof(float));
        }
        
        vImage_Buffer input = {
            .data = fbuf,
            .width = size.width,
            .height = size.height,
            .rowBytes = size.width * sizeof(float)
        };
        
        vImage_Buffer output = {
            .data = outputData,
            .width = size.width,
            .height = size.height,
            .rowBytes = size.width * sizeof(float)
        };
        
        CGAffineTransform xform = CGAffineTransformIdentity;
        
        // translate
        NSDictionary* translateInfo = @{};
        if (info.offset.x != 0 || info.offset.y != 0){
            xform = CGAffineTransformConcat(xform,CGAffineTransformMakeTranslation(info.offset.x,info.offset.y));
            translateInfo = @{@"x":[NSNumber numberWithDouble:info.offset.x],@"y":[NSNumber numberWithDouble:info.offset.y]};
        }
        
        // rotate
        NSDictionary* rotateInfo = @{};
        if (info.angle != 0){
            const CGFloat originX = (input.width/2.0);
            const CGFloat originY = (input.height/2.0);
            xform = CGAffineTransformConcat(xform,CGAffineTransformMakeTranslation(-originX,-originY));
            xform = CGAffineTransformConcat(xform,CGAffineTransformMakeRotation(info.angle));
            xform = CGAffineTransformConcat(xform,CGAffineTransformMakeTranslation(originX,originY));
            rotateInfo = @{@"angle":[NSNumber numberWithDouble:info.angle],@"origin":@{@"x":[NSNumber numberWithDouble:originX],@"y":[NSNumber numberWithDouble:originY]}};
        }
        
        // add entries to history
        [stackHistory addObject:@{
            @"uuid":exposure.uuid,@"translate":translateInfo,@"angle":rotateInfo,@"mode":@"average"
         }];
        
        if (CGAffineTransformIsIdentity(xform)){
            memcpy(outputData,fbuf,size.width*size.height*sizeof(float));
        }
        else {
            const vImage_AffineTransform vxform = {
                .a = xform.a, .b = xform.b, .c = xform.c, .d = xform.d,
                .tx = xform.tx, .ty = xform.ty
            };
            vImageAffineWarp_PlanarF(&input, &output, nil, &vxform, 0, kvImageHighQualityResampling);
        }
        
        // add to accumulation buffer
        vDSP_vadd(final.data,1,output.data,1,final.data,1,final.width*final.height);
    }

    if (outputData){
        free(outputData);
    }
    
    if (final.data){
        // divide by number of images
        if (count > 1){
            float fcount = count;
            vDSP_vsdiv(final.data,1,(float*)&fcount,final.data,1,final.width*final.height);
        }
    }
    
    CASCCDExposure* result = [CASCCDExposure exposureWithFloatPixels:[NSData dataWithBytesNoCopy:final.data length:final.height*final.rowBytes freeWhenDone:YES] camera:nil params:first.params time:nil];
    
    NSMutableDictionary* mutableMeta = [NSMutableDictionary dictionaryWithDictionary:result.meta];
    [mutableMeta setObject:@{@"stack":stackHistory} forKey:@"history"];
    result.meta = [mutableMeta copy];
    
    block(result);
}

+ (id)createImageStackerWithIdentifier:(NSString*)ident
{
    return [[CASImageStacker alloc] init];
}

@end
