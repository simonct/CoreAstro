//
//  CASLX200Commands.m
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASLX200Commands.h"

@implementation CASLX200Commands

+ (NSString*)getTelescopeAltitude {
    return @":GA#";
}

+ (NSString*)getTargetAltitude {
    return @":Ga#";
}

+ (NSString*)getDate {
    return @":GC#";
}

+ (NSString*)getTelescopeDeclination {
    return @":GD#";
}

+ (NSString*)getTargetDeclination {
    return @":Gd#";
}

+ (NSString*)getUTCOffsetTime {
    return @":GG#";
}

+ (NSString*)getSiteLongitude {
    return @":Gg#";
}

+ (NSString*)getHighLimit {
    return @":Gh#";
}

+ (NSString*)getLocalTime {
    return @":GL#";
}

+ (NSString*)getLowerLimit {
    return @":Go#";
}

+ (NSString*)getTelescopeRightAscension {
    return @":GR#";
}

+ (NSString*)getTargetRightAscension {
    return @":Gr#";
}

+ (NSString*)getSiderealTime {
    return @":GS#";
}

+ (NSString*)getTrackingRate {
    return @":GT#";
}

+ (NSString*)getSiteLatitude {
    return @":Gt#";
}

+ (NSString*)getFirmwareDate {
    return @":GVD#";
}

+ (NSString*)getFirmwareNumber {
    return @":GVN#";
}

+ (NSString*)getProductName {
    return @":GVP#";
}

+ (NSString*)getFirmwareTime {
    return @":GVT#";
}

+ (NSString*)getTelescopeAzimuth {
    return @":GZ#";
}

+ (NSString*)setTargetObjectDeclination:(NSString*)dec {
    return [NSString stringWithFormat:@":Sds%@#",dec];
}

+ (NSString*)setTargetObjectRightAscension:(NSString*)ra {
    return [NSString stringWithFormat:@":Sr%@#",ra];
}

+ (NSString*)slewToTargetObject {
    return @":MS#";
}

+ (NSString*)getDistanceBars {
    return @":D#";
}

+ (NSString*)highPrecisionRA:(double)ra {
    
    const double trunc_ra = trunc(ra);
    
    const double h = trunc_ra;
    const double m = trunc((ra - trunc_ra)*60.0);
    const double s = (ra - trunc_ra)*60.0*60.0 - 60.0*m;
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d:%02d:%02d",(int)h,(int)m,(int)s];
    
    return formattedRA;
}

+ (NSString*)lowPrecisionRA:(double)ra {
    
    const double trunc_ra = trunc(ra);
    
    const double h = trunc_ra;
    const double m = (ra - trunc_ra)*60.0;
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d:%02.1f",(int)h,m];
    
    return formattedRA;
}

+ (NSString*)highPrecisionDec:(double)dec {
    
    const double trunc_dec = trunc(dec);
    
    const double h = trunc_dec;
    const double m = trunc((dec - trunc_dec)*60.0);
    const double s = (dec - trunc_dec)*60.0*60.0 - 60.0*m;
    
    NSString* formattedRA;
    if (dec < 0){
        formattedRA = [NSString stringWithFormat:@"%03d*%02d:%02d",(int)h,(int)m,(int)s];
    }
    else {
        formattedRA = [NSString stringWithFormat:@"%02d*%02d:%02d",(int)h,(int)m,(int)s];
    }

    return formattedRA;
}

+ (NSString*)lowPrecisionDec:(double)dec {
    
    const double trunc_dec = trunc(dec);
    
    const double h = trunc_dec;
    const double m = (dec - trunc_dec)*60.0;
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d*%02d",(int)h,(int)m];
    
    return formattedRA;
}

@end
