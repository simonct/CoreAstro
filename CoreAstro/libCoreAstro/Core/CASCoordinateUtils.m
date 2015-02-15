//
//  CASCoordinateUtils.m
//  eqmac-client
//
//  Created by Simon Taylor on 29/5/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASCoordinateUtils.h"

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
    
    const double hrs = fabs(degrees)/(360.0/24.0);
    
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

    const double hrs = fabs(degrees)/(360.0/24.0);
    
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

extern double CASAngularSeparation(double ra1,double dec1,double ra2,double dec2)
{
    return toDegrees(acos(sin(toRadians(dec1))*sin(toRadians(dec2)) + cos(toRadians(dec1))*cos(toRadians(dec2))*cos(toRadians(ra1 - ra2))));
}