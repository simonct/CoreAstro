//
//  CASNova.m
//  CoreAstro
//
//  Created by Simon Taylor on 07/11/2015.
//  Copyright © 2015 Mako Technology Ltd. All rights reserved.
//

#import "CASNova.h"
#import "libnova/libnova.h"

@interface CASNova ()
@property double latitude, longitude;
@end

@implementation CASNova

+ (double)now
{
    return ln_get_julian_from_sys();
}

+ (double)today
{
    return floor([self now]); // zero-th second of today
}

- (instancetype)initWithObserverLatitude:(double)latitude longitude:(double)longitude
{
    self = [super init];
    if (self){
        self.latitude = latitude;
        self.longitude = longitude;
    }
    return self;
}

- (CASRST)rstForObjectRA:(double)ra dec:(double)dec jd:(double)jd
{
    CASRST result;
    bzero(&result, sizeof(result));
    
    struct ln_equ_posn object = {
        .ra = ra,
        .dec = dec
    };
    struct ln_lnlat_posn observer = {
        .lat = self.latitude,
        .lng = self.longitude
    };

    struct ln_rst_time rst;
    bzero(&rst, sizeof(rst));
    result.visibility = ln_get_object_rst(jd, &observer, &object, &rst);
    result.rise = rst.rise;
    result.transit = rst.transit;
    result.set = rst.set;
    
    return result;
}

- (CASDate)getDateTime:(double)jd
{
    struct ln_date date;
    ln_get_date(jd,&date);
    CASDate result = {
        .y = date.years,
        .m = date.months,
        .d = date.days,
        .h = date.hours,
        .min = date.minutes,
        .s = date.seconds
    };
    return result;
}

+ (double)siderealTimeForLongitude:(double)longitude
{
    const double now = [self now];
    return fmod(ln_get_mean_sidereal_time(now) + longitude/15.0 + 24, 24);
}

- (CASAltAz)objectAltAzFromRA:(double)ra dec:(double)dec;
{
    const double now = [[self class] now];
    
    struct ln_equ_posn object = {
        .ra = ra,
        .dec = dec
    };
    struct ln_lnlat_posn observer = {
        .lat = self.latitude,
        .lng = self.longitude
    };
    struct ln_hrz_posn altaz;
    ln_get_hrz_from_equ (&object, &observer, now, &altaz);
    
    const CASAltAz result = {
        .alt = altaz.alt,
        .az = altaz.az
    };
    return result;
}

@end