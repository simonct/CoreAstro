//
//  SXIOPlateSolutionLookup.h
//  SX IO
//
//  Created by Simon Taylor on 29/05/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAstro/CoreAstro.h>

@interface SXIOPlateSolutionLookup : NSObject

+ (instancetype)sharedLookup;

- (void)lookupSolutionForExposure:(CASCCDExposure*)exposure completion:(void(^)(CASCCDExposure*,CASPlateSolveSolution*))completion;
- (void)storeSolutionData:(NSData*)solutionData forUUID:(NSString*)uuid;

@end
