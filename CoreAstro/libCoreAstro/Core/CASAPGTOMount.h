//
//  CASAPMount.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASLX200Mount.h"

@interface CASAPGTOMount : CASLX200Mount
@end

@interface CASAPGTOMount (APSpecific)

typedef NS_ENUM(NSInteger, CASAPGTOMountMovingRate) {
    CASAPGTOMountMovingRateUndefined,
    CASAPGTOMountMovingRate1200,
    CASAPGTOMountMovingRate900,
    CASAPGTOMountMovingRate600
};

@property (nonatomic) CASAPGTOMountMovingRate movingRate;

typedef NS_ENUM(NSInteger, CASAPGTOMountTrackingRate) {
    CASAPGTOMountTrackingRateUndefined,
    CASAPGTOMountTrackingRateLunar,
    CASAPGTOMountTrackingRateSolar,
    CASAPGTOMountTrackingRateSidereal,
    CASAPGTOMountTrackingRateZero
};

@property (nonatomic) CASAPGTOMountTrackingRate trackingRate;

@end