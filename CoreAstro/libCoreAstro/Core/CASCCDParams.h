//
//  CASCCDParams.h
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

@interface NSObject (CASCCDParams)
- (NSSet*)cas_properties;
- (NSDictionary*)cas_propertyValues;
@end

@interface CASCCDParams : NSObject
@property (nonatomic,assign) NSInteger width;
@property (nonatomic,assign) NSInteger height;
@property (nonatomic,assign) float pixelWidth;
@property (nonatomic,assign) float pixelHeight;
@property (nonatomic,assign) NSInteger bitsPerPixel;
@end

typedef struct {
    NSInteger width, height; // NSUInteger ?
} CASSize;

typedef struct {
    CASSize bin;
    CASSize origin;
    CASSize size;
    CASSize frame;
    NSUInteger bps;
    NSUInteger ms;
} CASExposeParams;

NS_INLINE CASSize CASSizeMake(NSInteger w,NSInteger h) {
    CASSize sz = {.width = w, .height = h};
    return sz;
}

NS_INLINE NSString* NSStringFromCASSize(CASSize sz) {
    return [NSString stringWithFormat:@"{%ld,%ld}",sz.width,sz.height];
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

NS_INLINE CASExposeParams CASExposeParamsMake(NSInteger w,NSInteger h,NSInteger x,NSInteger y,NSInteger fw, NSInteger fh,NSInteger bx,NSInteger by,NSUInteger bps,NSUInteger ms) {
    CASSize sz = CASSizeMake(w,h);
    CASSize ori = CASSizeMake(x,y);
    CASSize bin = CASSizeMake(bx,by);
    CASSize frm = CASSizeMake(fw,fh);
    CASExposeParams exp = {.bin = bin, .origin = ori, .size = sz, .frame = frm, .bps = bps, .ms = ms};
    return exp;
}

NS_INLINE NSString* NSStringFromCASExposeParams(CASExposeParams exp) {
    return [NSString stringWithFormat:@"{%@|%@|%@|%@|%ld|%ld}",NSStringFromCASSize(exp.origin),NSStringFromCASSize(exp.size),NSStringFromCASSize(exp.bin),NSStringFromCASSize(exp.frame),exp.bps,exp.ms];
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
                .origin = CASSizeFromNSString([comps objectAtIndex:0]), 
                .size = CASSizeFromNSString([comps objectAtIndex:1]),
                .bin = CASSizeFromNSString([comps objectAtIndex:2]),
                .frame = CASSizeFromNSString([comps objectAtIndex:3]),
                .bps = [[comps objectAtIndex:4] integerValue],
                .ms = [[comps objectAtIndex:5] integerValue]
            };
            params = exp;
        }
    }
    return params;
}
