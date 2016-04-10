//
//  SXIOM25CFixupTool.h
//  SX IO
//
//  Created by Simon Taylor on 02/04/2016.
//  Copyright © 2016 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SXIOM25CFixupTool : NSObject

- (_Nonnull instancetype)initWithPath:( NSString* _Nonnull )path;

- (BOOL)fixupWithError:(NSError* _Nonnull * _Nonnull)error;

@end
