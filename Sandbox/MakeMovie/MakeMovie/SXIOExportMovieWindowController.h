//
//  SXIOExportMovieWindowController.h
//  MakeMovie
//
//  Created by Simon Taylor on 11/7/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SXIOExportMovieWindowController : NSWindowController

- (void)runWithCompletion:(void(^)(NSError*,NSURL*))completion;

+ (instancetype)loadWindowController;

@end
