//
//  CASPlateSolvedObject+Drawing.m
//  CoreAstro
//
//  Created by Simon Taylor on 6/8/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASPlateSolvedObject+Drawing.h"

@implementation CASAnnotationLayer
@end

@implementation CASPlateSolvedObject (Drawing)

- (CASAnnotationLayer*)createCircularLayerAtPosition:(CGPoint)position radius:(CGFloat)radius annotation:(NSString*)annotation inLayer:(CALayer*)annotationLayer withFont:(NSFont*)font andColour:(CGColorRef)colour
{
    CASAnnotationLayer* objectLayer = [CASAnnotationLayer layer];
    
    // flip y
    position.y = annotationLayer.bounds.size.height - position.y;
    
    objectLayer.borderColor = colour;
    objectLayer.borderWidth = 2.5;
    objectLayer.cornerRadius = radius;
    objectLayer.bounds = CGRectMake(0, 0, 2*radius, 2*radius);
    objectLayer.position = position;
    objectLayer.masksToBounds = NO;
    
    [annotationLayer addSublayer:objectLayer];
    
    if (annotation){
        
        CATextLayer* textLayer = [CATextLayer layer];
        textLayer.string = annotation;
        const CGSize size = [textLayer.string sizeWithAttributes:@{NSFontAttributeName:font}];
        textLayer.font = (__bridge CFTypeRef)(font);
        textLayer.fontSize = font.pointSize;
        textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
        textLayer.position = CGPointMake(CGRectGetMidX(objectLayer.frame) + size.width/2 + 10, CGRectGetMidY(objectLayer.frame) + size.height/2 + 10);
        textLayer.alignmentMode = @"center";
        textLayer.foregroundColor = colour;
        
        [annotationLayer addSublayer:textLayer];
        
        objectLayer.textLayer = textLayer;
        
        // want the inverse of the text bounding box as a clip mask for the circle layer
        CAShapeLayer* shape = [CAShapeLayer layer];
        CGPathRef path = CGPathCreateWithRect(objectLayer.bounds, nil);
        CGMutablePathRef mpath = CGPathCreateMutableCopy(path);
        CGPathAddRect(mpath, NULL, [annotationLayer convertRect:objectLayer.textLayer.frame toLayer:objectLayer]);
        shape.path = mpath;
        shape.fillRule = kCAFillRuleEvenOdd;
        objectLayer.mask = shape;
        CGPathRelease(mpath);
        CGPathRelease(path);
    }
    
    return objectLayer;
}

- (CASAnnotationLayer*)createLayerInLayer:(CALayer*)annotationLayer withFont:(NSFont*)font andColour:(CGColorRef)colour scaling:(NSInteger)scaling
{
    const CGFloat x = [[self.annotation objectForKey:@"pixelx"] doubleValue] * scaling;
    const CGFloat y = [[self.annotation objectForKey:@"pixely"] doubleValue] * scaling;
    const CGFloat radius = [[self.annotation objectForKey:@"radius"] doubleValue] * scaling;
    
    CASAnnotationLayer* result = [self createCircularLayerAtPosition:CGPointMake(x, y) radius:radius annotation:self.name inLayer:annotationLayer withFont:font andColour:colour];
    
    result.object = self;
    
    return result;
}

@end
