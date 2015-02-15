//
//  CASLX200Commands.h
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASLX200Commands : NSObject

// Get commands
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

// Set commands
+ (NSString*)setTargetObjectDeclination:(NSString*)dec;
+ (NSString*)setTargetObjectRightAscension:(NSString*)ra;

// Move commands
+ (NSString*)slewToTargetObject;

// Sync
+ (NSString*)syncToTargetObject;

// Distance bars
+ (NSString*)getDistanceBars;

// co-ordinate formatting
+ (NSString*)highPrecisionRA:(double)ra;
+ (NSString*)lowPrecisionRA:(double)ra;
+ (double)fromRAString:(NSString*)ras asDegrees:(BOOL)asDegrees;

+ (NSString*)highPrecisionDec:(double)dec;
+ (NSString*)lowPrecisionDec:(double)dec;
+ (double)fromDecString:(NSString*)dec;

@end

@interface CASLX200RATransformer : NSValueTransformer
@end

@interface CASLX200DecTransformer : NSValueTransformer
@end

