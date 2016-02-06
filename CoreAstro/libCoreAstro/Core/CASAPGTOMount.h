//
//  CASAPMount.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASLX200Mount.h"

@interface CASAPGTOMount : CASLX200Mount

@property (copy) NSString* longitude;
@property (copy) NSString* latitude;
@property (copy) NSString* localTime;
@property (copy) NSString* gmtOffset;
@property (copy) NSString* siderealTime;

@end

@interface CASAPGTOMount (APSpecific)

typedef NS_ENUM(NSInteger, CASAPGTOMountMovingRate) {
    CASAPGTOMountMovingRate12,
    CASAPGTOMountMovingRate64,
    CASAPGTOMountMovingRate600,
    CASAPGTOMountMovingRate1200
};

@property (nonatomic) CASAPGTOMountMovingRate movingRate;

typedef NS_ENUM(NSInteger, CASAPGTOMountTrackingRate) {
    CASAPGTOMountTrackingRateLunar,
    CASAPGTOMountTrackingRateSolar,
    CASAPGTOMountTrackingRateSidereal,
    CASAPGTOMountTrackingRateZero
};

@property (nonatomic) CASAPGTOMountTrackingRate trackingRate;

@end