//
//  CASCoordinateUtils.m
//  eqmac-client
//
//  Created by Simon Taylor on 29/5/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASCoordinateUtils.h"
#import "libnova/angular_separation.h"

static inline double toRadians(double degrees)
{
    return degrees * (M_PI/180.0);
}

static inline double toDegrees(double radians)
{
    return radians / (M_PI/180.0);
}

CASDMAngle CASDMAngleFromDegrees(double degrees)
{
    const double trunc_degrees = trunc(degrees);
    
    const double d = trunc_degrees;
    const double m = round(fabs((degrees - trunc_degrees)*60.0));

    CASDMAngle result = {
        .d = d,
        .m = m
    };
    return result;
}

CASHMAngle CASHMAngleFromDegrees(double degrees)
{
    while (degrees > 360) {
        degrees -= 360.0;
    }
    
    const double hrs = fabs(degrees)/CASDegreesPerHour;
    
    const double h = trunc(hrs);
    const double s = (hrs-h)*3600.0;
    const double m = round(s/60.0);
    
    CASHMAngle result = {
        .h = h,
        .m = m
    };
    return result;
}

CASDMSAngle CASDMSAngleFromDegrees(double degrees)
{
    const double trunc_degrees = trunc(degrees);
    
    const double d = trunc_degrees;
    const double m = fabs(trunc((degrees - trunc_degrees)*60.0));
    const double s = trunc(fabs(degrees - trunc_degrees)*3600.0 - 60.0*m);
    
    CASDMSAngle result = {
        .d = d,
        .m = m,
        .s = s
    };
    return result;
}

CASHMSAngle CASHMSAngleFromDegrees(double degrees)
{
    while (degrees > 360) {
        degrees -= 360.0;
    }

    const double hrs = fabs(degrees)/CASDegreesPerHour;
    
    const double h = trunc(hrs);
    const double m = trunc((hrs-h)*60.0);
    const double s = trunc((((hrs-h)*60.0)-m)*60.0);
    
    CASHMSAngle result = {
        .h = h,
        .m = m,
        .s = s
    };
    return result;
}

double CASAngularSeparation(double ra1,double dec1,double ra2,double dec2)
{
    struct ln_equ_posn p1 = {
        .ra = ra1, .dec = dec1
    };
    struct ln_equ_posn p2 = {
        .ra = ra2, .dec = dec2
    };
    return ln_get_angular_separation(&p1,&p2);
}
