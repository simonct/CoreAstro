//
//  CASFolderWatcher.h
//  astrometry-test
//
//  Created by Simon Taylor on 10/20/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASFolderWatcher : NSObject
@property (nonatomic,copy,readonly) void (^callback)(NSArray*);
@property (nonatomic,copy,readonly) NSString* path;
+ (instancetype)watcherWithPath:(NSString*)path callback:(void (^)(NSArray*))callback;
@end
