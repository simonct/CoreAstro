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
    return degrees * M_PI/180.0;
}

static inline double toDegrees(double radians)
{
    return radians / M_PI/180.0;
}

CASHMAngle CASHMAngleFromDegrees(double degrees)
{
    const double trunc_degrees = trunc(degrees);
    
    const double h = trunc_degrees;
    const double m = (degrees - trunc_degrees)*60.0;

    CASHMAngle result = {
        .h = h,
        .m = m
    };
    return result;
}

CASHMSAngle CASHMSAngleFromDegrees(double degrees)
{
    const double trunc_degrees = trunc(degrees);
    
    const double h = trunc_degrees;
    const double m = trunc((degrees - trunc_degrees)*60.0);
    const double s = (degrees - trunc_degrees)*60.0*60.0 - 60.0*m; // round ?
    
    CASHMSAngle result = {
        .h = h,
        .m = m,
        .s = s
    };
    return result;
}

extern double CASAngularSeparation(double ra1,double dec1,double ra2,double dec2)
{
    NSCAssert(NO, @"CASAngularSeparation not implememted");
    return 0;
}