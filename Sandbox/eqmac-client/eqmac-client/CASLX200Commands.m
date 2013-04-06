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

@end
