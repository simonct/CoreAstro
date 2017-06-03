//
//  astrometry_test_Tests.m
//  astrometry-test Tests
//
//  Created by Simon Taylor on 2/15/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <CoreAstro/CoreAstro.h>

@interface astrometry_test_Tests : XCTestCase

@end

@implementation astrometry_test_Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRA_HM {
    
    CASHMAngle angle;
    
    angle = CASHMAngleFromDegrees(0);
    XCTAssert(angle.h == 0);
    XCTAssert(angle.m == 0);
    
    angle = CASHMAngleFromDegrees(45.5);
    XCTAssert(angle.h == 3);
    XCTAssert(round(angle.m) == 2);
    
    angle = CASHMAngleFromDegrees(90);
    XCTAssert(angle.h == 6);
    XCTAssert(angle.m == 0);
    
    angle = CASHMAngleFromDegrees(180);
    XCTAssert(angle.h == 12);
    XCTAssert(angle.m == 0);
    
    angle = CASHMAngleFromDegrees(270);
    XCTAssert(angle.h == 18);
    XCTAssert(angle.m == 0);
    
    angle = CASHMAngleFromDegrees(360);
    XCTAssert(angle.h == 24); // or 0 ?
    XCTAssert(angle.m == 0);
}

- (void)testDec_DM {
    
    CASDMAngle angle;
    
    angle = CASDMAngleFromDegrees(90);
    XCTAssert(angle.d == 90);
    XCTAssert(angle.m == 0);
    
    angle = CASDMAngleFromDegrees(45.5);
    XCTAssert(angle.d == 45);
    XCTAssert(angle.m == 30);
    
    angle = CASDMAngleFromDegrees(45.55);
    XCTAssert(angle.d == 45);
    XCTAssert(angle.m == 33);
    
    angle = CASDMAngleFromDegrees(0);
    XCTAssert(angle.d == 0);
    XCTAssert(angle.m == 0);
    
    angle = CASDMAngleFromDegrees(-45.5);
    XCTAssert(angle.d == -45);
    XCTAssert(angle.m == 30);
    
    angle = CASDMAngleFromDegrees(-90);
    XCTAssert(angle.d == -90);
    XCTAssert(angle.m == 0);

    angle = CASDMAngleFromDegrees(-0.5);
    XCTAssert(angle.d == 0); // note; might need a sign flag for this case
    XCTAssert(angle.m == 30);
}

- (void)testRA_HMS {
    
    CASHMSAngle angle;
    
    angle = CASHMSAngleFromDegrees(0);
    XCTAssert(angle.h == 0);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
    
    angle = CASHMSAngleFromDegrees(45.5); // 3h 2m 0s
    XCTAssert(angle.h == 3);
    XCTAssert(angle.m == 2);
    XCTAssert(angle.s == 0);
    
    angle = CASHMSAngleFromDegrees(45.55); // 3h 2m 11.9s
    XCTAssert(angle.h == 3);
    XCTAssert(angle.m == 2);
    XCTAssert(angle.s == 12);
    
    angle = CASHMSAngleFromDegrees(90);
    XCTAssert(angle.h == 6);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
    
    angle = CASHMSAngleFromDegrees(180);
    XCTAssert(angle.h == 12);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
    
    angle = CASHMSAngleFromDegrees(270);
    XCTAssert(angle.h == 18);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
    
    angle = CASHMSAngleFromDegrees(360);
    XCTAssert(angle.h == 24); // or 0 ?
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
}

- (void)testDec_DMS {
    
    CASDMSAngle angle;
    
    angle = CASDMSAngleFromDegrees(90);
    XCTAssert(angle.d == 90);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
    
    angle = CASDMSAngleFromDegrees(45.5);
    XCTAssert(angle.d == 45);
    XCTAssert(angle.m == 30);
    XCTAssert(angle.s == 0);
    
    angle = CASDMSAngleFromDegrees(45.55);
    XCTAssert(angle.d == 45);
    XCTAssert(angle.m == 33);
    XCTAssert(angle.s == 0);
    
    angle = CASDMSAngleFromDegrees(0);
    XCTAssert(angle.d == 0);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
    
    angle = CASDMSAngleFromDegrees(-45.55);
    XCTAssert(angle.d == -45);
    XCTAssert(angle.m == 33);
    XCTAssert(angle.s == 0);
    
    angle = CASDMSAngleFromDegrees(-90);
    XCTAssert(angle.d == -90);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
}

- (void)testHighPrecisionFormatting {
    
    const double ra = 94.511300; // 6h 18m 2.7s
    const double dec = 22.660000; // 22° 39' 36"
    
    NSString* hpra = [CASLX200Commands highPrecisionRA:ra];
    XCTAssertEqualObjects(hpra,@"06:18:03");
    
    NSString* hpdec = [CASLX200Commands highPrecisionDec:dec];
    XCTAssertEqualObjects(hpdec,@"+22*39:36");
    
    const double ra2 = [CASLX200Commands fromRAString:hpra asDegrees:YES];
    XCTAssertEqualWithAccuracy(ra,ra2,0.003); // not sure if this rounding error is justifiable or not
    
    const double dec2 = [CASLX200Commands fromDecString:hpdec];
    XCTAssertEqualWithAccuracy(dec,dec2,0.003); // not sure if this rounding error is justifiable or not
}

- (void)testHighPrecisionFormatting2 {
    
    const double ra = 274.633525; // 18h 18m 32s
    const double dec = -45.983797; // -45° 59' 1.67"
    
    NSString* hpra = [CASLX200Commands highPrecisionRA:ra];
    XCTAssertEqualObjects(hpra,@"18:18:32");
    
    NSString* hpdec = [CASLX200Commands highPrecisionDec:dec];
    XCTAssertEqualObjects(hpdec,@"-45*59:02");
    
    const double ra2 = [CASLX200Commands fromRAString:hpra asDegrees:YES];
    XCTAssertEqualWithAccuracy(ra,ra2,0.003); // not sure if this rounding error is justifiable or not
    
    const double dec2 = [CASLX200Commands fromDecString:hpdec];
    XCTAssertEqualWithAccuracy(dec,dec2,0.003); // not sure if this rounding error is justifiable or not
}

- (void)testLowPrecisionFormatting {
    
    const double ra = 94.511300; // 6h 18m 2.7s"
    const double dec = 22.660000; // 22° 39' 36"
    
    NSString* lpra = [CASLX200Commands lowPrecisionRA:ra];
    XCTAssertEqualObjects(lpra,@"06:18.0");
    
    NSString* lpdec = [CASLX200Commands lowPrecisionDec:dec];
    XCTAssertEqualObjects(lpdec,@"22*40");
}

- (void)testLowPrecisionFormatting2 {
    
    const double ra = 274.633525; // 18h 18m 32s
    const double dec = -45.983797; // -45° 59' 1.67"
    
    NSString* lpra = [CASLX200Commands lowPrecisionRA:ra];
    XCTAssertEqualObjects(lpra,@"18:18.5");
    
    NSString* lpdec = [CASLX200Commands lowPrecisionDec:dec];
    XCTAssertEqualObjects(lpdec,@"-45*59");
}

- (void)testLatitideLongitide {
    XCTFail(@"testLatitideLongitide");
}

@end
