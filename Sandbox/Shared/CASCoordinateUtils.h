//
//  CASCoordinateUtils.h
//  eqmac-client
//
//  Created by Simon Taylor on 29/5/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    int h;
    double m;
} CASHMAngle;

extern CASHMAngle CASHMAngleFromDegrees(double degrees);

typedef struct {
    int h, m, s;
} CASHMSAngle;

extern CASHMSAngle CASHMSAngleFromDegrees(double degrees);

extern double CASAngularSeparation(double ra1,double dec1,double ra2,double dec2);