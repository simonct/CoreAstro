//
//  CASLX200Commands.m
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASLX200Commands.h"
#import "CASCoordinateUtils.h"

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
    return [NSString stringWithFormat:@":Sd %@#",dec];
}

+ (NSString*)setTargetObjectRightAscension:(NSString*)ra {
    return [NSString stringWithFormat:@":Sr %@#",ra];
}

+ (NSString*)slewToTargetObject {
    return @":MS#";
}

+ (NSString*)syncToTargetObject {
    return @":CM#";
}

+ (NSString*)getDistanceBars {
    return @":D#";
}

+ (NSString*)highPrecisionRA:(double)ra {
    
    const CASHMSAngle hms = CASHMSAngleFromDegrees(ra);
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d:%02d:%02d",(int)hms.h,(int)hms.m,(int)hms.s];
    
    return formattedRA;
}

+ (NSString*)lowPrecisionRA:(double)ra {
    
    const CASHMAngle hm = CASHMAngleFromDegrees(ra);
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d:%02.1f",(int)hm.h,hm.m];
    
    return formattedRA;
}

+ (double)fromRAString:(NSString*)ras asDegrees:(BOOL)asDegrees {
    
    double ra = -1;
    
    NSArray* comps = [ras componentsSeparatedByString:@":"];
    if ([comps count] == 3){
        ra = [comps[0] doubleValue] + ([comps[1] doubleValue]/60.0) + ([comps[2] doubleValue]/3600.0);
    }
    else if ([comps count] == 2){
        ra = [comps[0] doubleValue] + ([comps[1] doubleValue]/60.0);
    }
    
    if (asDegrees){
        const double trunc_ra = trunc(ra);
        ra = (trunc_ra * (360.0/24.0)) + (ra - trunc_ra);
    }
    
    return ra;
}

+ (NSString*)highPrecisionDec:(double)dec {
    
    const CASDMSAngle dms = CASDMSAngleFromDegrees(dec);
    
    NSString* formattedDec;
    if (dec < 0){
        formattedDec = [NSString stringWithFormat:@"-%03d*%02d:%02d",(int)dms.d,(int)dms.m,(int)dms.s];
    }
    else {
        formattedDec = [NSString stringWithFormat:@"+%02d*%02d:%02d",(int)dms.d,(int)dms.m,(int)dms.s];
    }

    return formattedDec;
}

+ (NSString*)lowPrecisionDec:(double)dec {
    
    const CASDMAngle dm = CASDMAngleFromDegrees(dec);
    
    NSString* formattedDec = [NSString stringWithFormat:@"%02d*%02d",(int)dm.d,(int)dm.m];
    
    return formattedDec;
}

+ (double)fromDecString:(NSString*)decs {
    
    double dec = -1;
    
    NSArray* comps = [decs componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"*':"]];
    if ([comps count] == 3){
        dec = [comps[0] doubleValue] + ([comps[1] doubleValue]/60.0) + ([comps[2] doubleValue]/3600.0);
    }
    else if ([comps count] == 2){
        dec = [comps[0] doubleValue] + ([comps[1] doubleValue]/60.0);
    }
    
    return dec;
}

+ (NSString*)raDegreesToHMS:(double)degrees {

    const double hours = 24.0*degrees/360.0;
    const double h = trunc(hours);

    const double minutes = (hours-h)*60.0;
    const double m = trunc(minutes);
    
    const double s = (minutes-m)*60.0; // round ?

    NSString* formattedRA = [NSString stringWithFormat:@"%02d:%02d:%02d",(int)h,(int)m,(int)s];
    
    return formattedRA;
}

@end

@implementation CASLX200RATransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    return [CASLX200Commands highPrecisionRA:[value doubleValue]];
}

@end

@implementation CASLX200DecTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    return [CASLX200Commands highPrecisionDec:[value doubleValue]];
}

@end

