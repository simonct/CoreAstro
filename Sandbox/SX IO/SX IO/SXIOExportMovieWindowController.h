//
//  SXIOExportMovieWindowController.h
//  MakeMovie
//
//  Created by Simon Taylor on 11/7/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@interface SXIOExportMovieWindowController : NSWindowController

@property (nonatomic,copy) NSURL* saveURL;
@property (nonatomic,assign) BOOL showDateTime, showFilename, showCustom;
@property (nonatomic,copy) NSString* customAnnotation;
@property (nonatomic,strong) NSArray* URLs;
@property (nonatomic,strong) CASFilterPipeline* filterPipeline;

- (void)runExporterWithCompletion:(void(^)(NSError*))completion;
- (void)runWithCompletion:(void(^)(NSError*,NSURL*))completion;

+ (instancetype)loadWindowController;

@end
