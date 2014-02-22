//
//  CASCCDProperties.h
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

#import <Foundation/Foundation.h>

@interface NSObject (CASCCDProperties)
- (NSSet*)cas_properties;
- (NSDictionary*)cas_propertyValues;
@end

@interface CASCCDProperties : NSObject
@property (nonatomic,assign) NSInteger width;
@property (nonatomic,assign) NSInteger height;
@property (nonatomic,assign) CGSize pixelSize;
@property (nonatomic,assign) CGSize sensorSize;
@property (nonatomic,assign) NSInteger bitsPerPixel;
@end


typedef struct
{
    NSInteger x;
    NSInteger y;

} CASPoint;


typedef struct
{
    NSUInteger width;
    NSUInteger height;

} CASSize;


typedef struct
{
    CASPoint origin; // bottom-left corner
    CASSize size;

} CASRect;


typedef struct
{
    CASSize bin;
    CASPoint origin; // origin of the subframe
    CASSize size;    // size of the subframe
    CASSize frame;   // size of the whole frame
    NSUInteger bps;  // bits per pixel
    NSUInteger ms;   // exposure time in milliseconds
    
} CASExposeParams; // WLT-QQQ: Did you mean CASExposureParams ?


NS_INLINE CASPoint CASPointMake(NSInteger x, NSInteger y) {
    CASPoint pt = {.x = x, .y = y};
    return pt;
}

NS_INLINE CASSize CASSizeMake(NSUInteger w, NSUInteger h) {
    CASSize sz = {.width = w, .height = h};
    return sz;
}

NS_INLINE CASRect CASRectMake(CASPoint pt, CASSize sz) {
    CASRect rect = {.origin = pt, .size = sz};
    return rect;
}

NS_INLINE CASRect CASRectMake2(NSInteger x, NSInteger y, NSUInteger w, NSUInteger h) {
    CASRect rect = {.origin = CASPointMake(x, y), .size = CASSizeMake(w, h)};
    return rect;
}

NS_INLINE CASRect CASRectFromCGRect(CGRect r) {
    CASRect rect = {.origin = CASPointMake(r.origin.x, r.origin.y), .size = CASSizeMake(r.size.width, r.size.height)};
    return rect;
}

NS_INLINE CGRect CASCGRectFromCASRect(CASRect r) {
    CGRect rect = {.origin = CGPointMake(r.origin.x, r.origin.y), .size = CGSizeMake(r.size.width, r.size.height)};
    return rect;
}

NS_INLINE NSString* NSStringFromCASPoint(CASPoint pt) {
    return [NSString stringWithFormat:@"{%ld,%ld}",pt.x,pt.y];
}

NS_INLINE NSString* NSStringFromCGPoint(CGPoint pt) {
    return [NSString stringWithFormat:@"{%f,%f}",pt.x,pt.y];
}

NS_INLINE NSString* NSStringFromCASSize(CASSize sz) {
    return [NSString stringWithFormat:@"{%ld,%ld}",sz.width,sz.height];
}

NS_INLINE NSString* NSStringFromCASRect(CASRect rect) {
    return [NSString stringWithFormat:@"{%@,%@}",NSStringFromCASPoint(rect.origin),NSStringFromCASSize(rect.size)];
}

NS_INLINE NSString* NSStringFromCASRect2(CASRect rect) {
    return [NSString stringWithFormat:@"{%ld,%ld,%ld,%ld}",rect.origin.x,rect.origin.y,rect.size.width,rect.size.height];
}

NS_INLINE CASPoint CASPointFromNSString(NSString* s) {
    CASPoint point;
    bzero(&point, sizeof point);
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([s length] > 0 && [s characterAtIndex:0] == '{' && [s characterAtIndex:[s length] - 1] =='}'){
        s = [s substringWithRange:NSMakeRange(1, [s length] - 1)];
        NSArray* comps = [s componentsSeparatedByString:@","];
        if ([comps count] > 1){
            point.x = [[comps objectAtIndex:0] integerValue];
            point.y = [[comps objectAtIndex:1] integerValue];
        }
    }
    return point;
}

NS_INLINE CASSize CASSizeFromNSString(NSString* s) {
    CASSize size;
    bzero(&size, sizeof size);
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([s length] > 0 && [s characterAtIndex:0] == '{' && [s characterAtIndex:[s length] - 1] =='}'){
        s = [s substringWithRange:NSMakeRange(1, [s length] - 1)];
        NSArray* comps = [s componentsSeparatedByString:@","];
        if ([comps count] > 1){
            size.width = [[comps objectAtIndex:0] integerValue];
            size.height = [[comps objectAtIndex:1] integerValue];
        }
    }
    return size;
}

NS_INLINE CASRect CASRectFromNSString(NSString* s) {
    CASRect rect;
    bzero(&rect, sizeof rect);
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([s length] > 0 && [s characterAtIndex:0] == '{' && [s characterAtIndex:[s length] - 1] =='}'){
        s = [s substringWithRange:NSMakeRange(1, [s length] - 1)];
        NSArray* comps = [s componentsSeparatedByString:@","];
        if ([comps count] > 1){
            rect.origin.x = [[comps objectAtIndex:0] integerValue];
            rect.origin.y = [[comps objectAtIndex:1] integerValue];
            rect.size.width = [[comps objectAtIndex:2] integerValue];
            rect.size.height = [[comps objectAtIndex:3] integerValue];
        }
    }
    return rect;
}

NS_INLINE CASExposeParams CASExposeParamsMake(NSUInteger w, NSUInteger h, NSInteger x, NSInteger y, NSUInteger fw, NSUInteger fh, NSUInteger bw, NSUInteger bh, NSUInteger bps, NSUInteger ms) {
    CASSize sz = CASSizeMake(w,h);
    CASPoint ori = CASPointMake(x,y);
    CASSize bin = CASSizeMake(bw,bh);
    CASSize frm = CASSizeMake(fw,fh);
    CASExposeParams exp = {.bin = bin, .origin = ori, .size = sz, .frame = frm, .bps = bps, .ms = ms};
    return exp;
}

NS_INLINE NSString* NSStringFromCASExposeParams(CASExposeParams exp) {
    // todo: make this a dictionary, this is getting slightly ridiculous...
    return [NSString stringWithFormat:@"{%@|%@|%@|%@|%ld|%ld}",NSStringFromCASPoint(exp.origin),NSStringFromCASSize(exp.size),NSStringFromCASSize(exp.bin),NSStringFromCASSize(exp.frame),exp.bps,exp.ms];
}

NS_INLINE CASExposeParams CASExposeParamsFromNSString(NSString* s) {
    CASExposeParams params;
    bzero(&params, sizeof params);
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([s length] > 0 && [s characterAtIndex:0] == '{' && [s characterAtIndex:[s length] - 1] =='}'){
        s = [s substringWithRange:NSMakeRange(1, [s length] - 1)];
        NSArray* comps = [s componentsSeparatedByString:@"|"];
        if ([comps count] > 4){
            CASExposeParams exp = {
                .origin = CASPointFromNSString([comps objectAtIndex:0]),
                .size = CASSizeFromNSString([comps objectAtIndex:1]),
                .bin = CASSizeFromNSString([comps objectAtIndex:2]),
                .frame = CASSizeFromNSString([comps objectAtIndex:3]),
                .bps = (NSUInteger)[[comps objectAtIndex:4] integerValue],
                .ms = (NSUInteger)[[comps objectAtIndex:5] integerValue]
            };
            params = exp;
        }
    }
    return params;
}

NS_INLINE CGRect CASCGRectConstrainWithinRect(CGRect frame,CGRect container) {
    
    frame.origin.x = MAX(0,frame.origin.x);
    frame.origin.y = MAX(0,frame.origin.y);
    frame.size.width = MIN(frame.size.width,container.size.width);
    frame.size.height = MIN(frame.size.height,container.size.height);
    if (CGRectGetMaxX(frame) > CGRectGetMaxX(container)){
        frame.origin.x = CGRectGetMaxX(container) - frame.size.width;
    }
    if (CGRectGetMaxY(frame) > CGRectGetMaxY(container)){
        frame.origin.y = CGRectGetMaxY(container) - frame.size.height;
    }
    return frame;
}

