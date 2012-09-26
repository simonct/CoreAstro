//
//  CASGuideAlgorithm.h
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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
//  Guiding algorithms by Craig Stark ( http://www.stark-labs.com )
//
//  WARNING: THIS CODE IS HIGHLY EXPERIMENTAL ! IT HAS NOT BEEN TESTED, IS ALMOST CERTAINLY
//  EXTREMELY BUGGY AND WILL PROBABLY CHANGE A GREAT DEAL OVER A SHORT PERIOD OF TIME.
//

#import "CASCCDExposure.h"
#import "CASImageProcessor.h"

@protocol CASGuider <NSObject>

typedef enum {
    kCASGuiderDirection_None = 0,
    kCASGuiderDirection_RAPlus,
    kCASGuiderDirection_RAMinus,
    kCASGuiderDirection_DecPlus,
    kCASGuiderDirection_DecMinus
} CASGuiderDirection;

- (void)pulse:(CASGuiderDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block;

@end

// interface to an object which can issue guide offsets given a sequence of images
@protocol CASGuideAlgorithm <NSObject>
@optional

@property (nonatomic,weak) id<CASGuider> guider;
@property (nonatomic,weak) id<CASImageProcessor> imageProcessor;
@property (nonatomic,copy,readonly) NSString* status;

@property (nonatomic,assign,readonly) CGPoint starLocation; // current start point
@property (nonatomic,assign,readonly) CGPoint lockLocation; // start guide point
@property (nonatomic,assign,readonly) CGFloat searchRadius;

- (NSArray*)locateStars:(CASCCDExposure*)exposure; // returns an array of NSValue boxed NSPoint/CGPoints in image co-ords

- (void)resetStarLocation:(CGPoint)star;

- (void)updateWithExposure:(CASCCDExposure*)exposure; // pass block whih returns the guide command and optional error object

@end

@interface CASGuideAlgorithm : NSObject<CASGuideAlgorithm>

+ (id<CASGuideAlgorithm>)guideAlgorithmWithIdentifier:(NSString*)type;

@end
