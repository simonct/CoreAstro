//
//  CASPlateSolver.h
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "CASCCDExposure.h"

@interface CASPlateSolvedObject : NSObject
@property (nonatomic,assign) BOOL enabled;
@property (nonatomic,readonly) NSString* name;
@property (nonatomic,strong,readonly) NSDictionary* annotation;
@end

@interface CASPlateSolveSolution : NSObject<NSCoding>
@property (nonatomic,readonly) double centreRA;
@property (nonatomic,readonly) NSString* displayCentreRA;
@property (nonatomic,readonly) double centreDec;
@property (nonatomic,readonly) NSString* displayCentreDec;
@property (nonatomic,readonly) NSString* centreAngle;
@property (nonatomic,readonly) NSString* pixelScale;
@property (nonatomic,readonly) NSString* fieldWidth;
@property (nonatomic,readonly) NSString* fieldHeight;
@property (nonatomic,readonly) NSArray* objects;
@property (nonatomic,copy) NSString* wcsPath;
- (NSData*)solutionData;
+ (instancetype)solutionWithData:(NSData*)data;
@end

@protocol CASPlateSolver <NSObject>
@optional

@property (nonatomic,copy) void (^outputBlock)(NSString*);
@property (nonatomic,copy) NSURL* indexDirectoryURL;
@property (nonatomic,assign) float arcsecsPerPixel;
@property (nonatomic,assign) CGSize fieldSizeDegrees;
@property (nonatomic,assign) float searchRA, searchDec, searchRadius;
@property BOOL solveCentre;

- (CASPlateSolveSolution*)cachedSolutionForExposure:(CASCCDExposure*)exposure;

- (BOOL)canSolveExposure:(CASCCDExposure*)exposure error:(NSError**)error;

// results dictionary is @{"solution":<CASPlateSolveSolution>, "image":<path to solved image>}
- (void)solveExposure:(CASCCDExposure*)exposure completion:(void(^)(NSError*,NSDictionary*))block;

- (void)cancel;

@end

@interface CASPlateSolver : NSObject<CASPlateSolver>

+ (id<CASPlateSolver>)plateSolverWithIdentifier:(NSString*)ident;

@end

extern NSString* const kCASAstrometryIndexDirectoryURLKey;
extern NSString* const kCASAstrometryIndexDirectoryBookmarkKey;
