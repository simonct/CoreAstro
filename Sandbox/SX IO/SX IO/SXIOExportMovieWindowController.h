//
//  SXIOExportMovieWindowController.h
//  MakeMovie
//
//  Created by Simon Taylor on 11/7/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@interface SXIOExportMovieWindowController : NSWindowController

@property (nonatomic,strong) CASFilterPipeline* filterPipeline;

- (void)runWithCompletion:(void(^)(NSError*,NSURL*))completion;

+ (instancetype)loadWindowController;

@end
