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
    XCTAssert(angle.m == 2);

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
}

- (void)testRA_HMS {
    
    CASHMSAngle angle;
    
    angle = CASHMSAngleFromDegrees(0);
    XCTAssert(angle.h == 0);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
    
    angle = CASHMSAngleFromDegrees(45.5);
    XCTAssert(angle.h == 3);
    XCTAssert(angle.m == 1);
    XCTAssert(angle.s == 59);

    angle = CASHMSAngleFromDegrees(45.55);
    XCTAssert(angle.h == 3);
    XCTAssert(angle.m == 2);
    XCTAssert(angle.s == 11);

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
    XCTAssert(angle.m == 32);
    XCTAssert(angle.s == 59);

    angle = CASDMSAngleFromDegrees(0);
    XCTAssert(angle.d == 0);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);

    angle = CASDMSAngleFromDegrees(-45.55);
    XCTAssert(angle.d == -45);
    XCTAssert(angle.m == 32);
    XCTAssert(angle.s == 59);

    angle = CASDMSAngleFromDegrees(-90);
    XCTAssert(angle.d == -90);
    XCTAssert(angle.m == 0);
    XCTAssert(angle.s == 0);
}

@end
