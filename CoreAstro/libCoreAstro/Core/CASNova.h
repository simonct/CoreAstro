//
//  CASNova.h
//  CoreAstro
//
//  Created by Simon Taylor on 07/11/2015.
//  Copyright © 2015 Mako Technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASNova : NSObject

+ (double)now;
+ (double)today;

- (instancetype)initWithObserverLatitude:(double)latitude longitude:(double)longitude;

typedef struct {
    double rise, set, transit;
    int visibility;
} CASRST;
- (CASRST)rstForObjectRA:(double)ra dec:(double)dec jd:(double)jd;

typedef struct {
    int y, m, d, h, min;
    double s;
} CASDate;
- (CASDate)getDateTime:(double)jd;

@end
