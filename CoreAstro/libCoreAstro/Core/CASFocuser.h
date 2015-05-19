//
//  CASFocuser.h
//  CoreAstro
//
//  Created by Simon Taylor on 5/17/15.
//  Copyright (c) 2015 Mako Technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CASFocuser <NSObject>

@optional

typedef NS_ENUM(NSUInteger, CASFocuserDirection) {
    CASFocuserForward,
    CASFocuserReverse
};

- (void)pulse:(CASFocuserDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block;

- (void)step:(CASFocuserDirection)direction amount:(NSInteger)amount block:(void (^)(NSError*))block;

@end
