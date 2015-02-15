//
//  CASCoordinateUtils.h
//  eqmac-client
//
//  Created by Simon Taylor on 29/5/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

// all function expect RA as 0-360, Dec -90-90

typedef struct {
    int d;
    double m;
} CASDMAngle;

extern CASDMAngle CASDMAngleFromDegrees(double degrees);

typedef struct {
    int h;
    double m;
} CASHMAngle;

extern CASHMAngle CASHMAngleFromDegrees(double degrees);

typedef struct {
    int d, m, s;
} CASDMSAngle;

extern CASDMSAngle CASDMSAngleFromDegrees(double degrees);

typedef struct {
    int h, m, s;
} CASHMSAngle;

extern CASHMSAngle CASHMSAngleFromDegrees(double degrees);

extern double CASAngularSeparation(double ra1,double dec1,double ra2,double dec2);