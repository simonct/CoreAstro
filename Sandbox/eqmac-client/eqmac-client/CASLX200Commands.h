//
//  CASLX200Commands.h
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASLX200Commands : NSObject

+ (NSString*)getTelescopeAltitude;
+ (NSString*)getTargetAltitude;
+ (NSString*)getDate;
+ (NSString*)getTelescopeDeclination;
+ (NSString*)getTargetDeclination;
+ (NSString*)getUTCOffsetTime;
+ (NSString*)getSiteLongitude;
+ (NSString*)getHighLimit;
+ (NSString*)getLocalTime;
+ (NSString*)getLowerLimit;
+ (NSString*)getTelescopeRightAscension;
+ (NSString*)getTargetRightAscension;
+ (NSString*)getSiderealTime;
+ (NSString*)getTrackingRate;
+ (NSString*)getSiteLatitude;
+ (NSString*)getFirmwareDate;
+ (NSString*)getFirmwareNumber;
+ (NSString*)getProductName;
+ (NSString*)getFirmwareTime;
+ (NSString*)getTelescopeAzimuth;

@end
