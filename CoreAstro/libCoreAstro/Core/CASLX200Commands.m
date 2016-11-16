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
        ra = (trunc_ra + (ra - trunc_ra)) * CASDegreesPerHour;
    }
    
    return ra;
}

+ (NSString*)highPrecisionDec:(double)dec {
    
    const CASDMSAngle dms = CASDMSAngleFromDegrees(dec);
    const char sign = dec < 0 ? '-' : '+';
    return [NSString stringWithFormat:@"%c%02d*%02d:%02d",sign,(int)labs(dms.d),(int)dms.m,(int)dms.s];
}

+ (NSString*)lowPrecisionDec:(double)dec {
    
    const CASDMAngle dm = CASDMAngleFromDegrees(dec);
    
    NSString* formattedDec = [NSString stringWithFormat:@"%02d*%02d",(int)dm.d,(int)dm.m];
    
    return formattedDec;
}

+ (double)fromDecString:(NSString*)decs {
    
    double dec = -1;
    double fraction = 0;
    
    NSArray* comps = [decs componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"*':"]];
    if ([comps count] == 3){
        dec = [comps[0] doubleValue];
        fraction = ([comps[1] doubleValue]/60.0) + ([comps[2] doubleValue]/3600.0);
    }
    else if ([comps count] == 2){
        dec = [comps[0] doubleValue];
        fraction = ([comps[1] doubleValue]/60.0);
    }
    
    if (dec < 0){
        dec -= fraction;
    }
    else {
        dec += fraction;
    }

    return dec;
}

+ (NSDateFormatter*)dateFormatter
{
    static NSDateFormatter* _dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dateFormatter = [NSDateFormatter new];
    });
    return _dateFormatter;
}

+ (NSString*)setTelescopeLatitude:(double)latitude
{
    const CASDMSAngle dms = CASDMSAngleFromDegrees(latitude);
    const char sign = latitude < 0 ? '-' : '+';
    return [NSString stringWithFormat:@":St %c%02ld*%02ld:%02ld#",sign,(long)labs(dms.d),(long)dms.m,(long)dms.s];
}

+ (NSString*)setTelescopeLongitude:(double)longitude
{
    const CASDMSAngle dms = CASDMSAngleFromDegrees(longitude);
    const char sign = longitude < 0 ? '-' : '+';
    return [NSString stringWithFormat:@":Sg %c%03ld*%02ld:%02ld#",sign,(long)labs(dms.d),(long)dms.m,(long)dms.s];
}

+ (NSString*)setTelescopeLocalTime:(NSDate*)date
{
    NSDateFormatter* formatter = [self dateFormatter];
    formatter.dateFormat = @"HH:mm:ss";
    return [NSString stringWithFormat:@":SL %@#",[formatter stringFromDate:date]];
}
            
+ (NSString*)setTelescopeLocalDate:(NSDate*)date
{
    NSDateFormatter* formatter = [self dateFormatter];
    formatter.dateFormat = @"MM/dd/yy";
    return [NSString stringWithFormat:@":SC %@#",[formatter stringFromDate:date]];
}

+ (NSString*)setTelescopeGMTOffset:(NSTimeZone*)tz
{
    const NSInteger gmtOffset = -tz.secondsFromGMT;
    const NSInteger hours = labs(gmtOffset/3600);
    const NSInteger minutes = (labs(gmtOffset) - hours*3600)/60;
    const char sign = gmtOffset < 0 ? '-' : '+';
    return [NSString stringWithFormat:@":SG %c%02ld:%02ld#",sign,(long)hours,(long)minutes];
}

+ (NSString*)setTelescopeGMTOffsetExDST:(NSTimeZone*)tz
{
    const NSInteger gmtOffset = tz.secondsFromGMT - tz.daylightSavingTimeOffset;
    const NSInteger hours = labs(gmtOffset/3600);
    const NSInteger minutes = (labs(gmtOffset) - hours*3600)/60;
    const char sign = gmtOffset < 0 ? '-' : '+';
    return [NSString stringWithFormat:@":SG %c%02ld:%02ld#",sign,(long)hours,(long)minutes];
}

+ (NSString*)setTelescopeDaylightSavings:(NSTimeZone*)tz
{
    return tz.daylightSavingTime ? @":SDS1#" : @":SDS0#";
}

@end

@implementation CASLX200RATransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    if (!value){
        return @"--:--:--";
    }
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
    if (!value){
        return @"--*--:--";
    }
    return [CASLX200Commands highPrecisionDec:[value doubleValue]];
}

@end

