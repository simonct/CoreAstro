//
//  SXIOExportMovieWindowController.m
//  MakeMovie
//
//  Created by Simon Taylor on 11/7/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOExportMovieWindowController.h"
#import "CASExposureView.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOExportMovieWindowController ()
@property (nonatomic,strong) CASMovieExporter* exporter;
@property (nonatomic,assign) int32_t fps;
@property (nonatomic,assign) float progress;
@property (nonatomic,assign) BOOL cancelled;
@property (nonatomic,assign) NSInteger compressionLevel;
@property (nonatomic,assign) NSInteger fontSize;
@property (nonatomic,assign) BOOL showDateTime, showFilename, showCustom;
@property (nonatomic,copy) NSString* customAnnotation;
@property (nonatomic,strong) IBOutlet NSView *saveAccessoryView;
@property (nonatomic,copy) NSString* movieFilename;
@property (nonatomic,strong) IBOutlet NSWindow *progressWindow;
@property (nonatomic,strong) NSArray* URLs;
@property (nonatomic,copy) void(^completion)(NSError*,NSURL*);
@property (nonatomic,assign) NSInteger frameCount, currentFrame;
@property (weak) IBOutlet CASExposureView *exposureView;

typedef NS_ENUM(NSInteger, SXIOExportMovieSortMode) {
    SXIOExportMovieDateSort,
    SXIOExportMovieNameSort
};
@property (nonatomic,assign) SXIOExportMovieSortMode sortMode;

@end

@implementation SXIOExportMovieWindowController

+ (void)initialize
{
    if (self == [SXIOExportMovieWindowController class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
                                                                  @"SXIOExportMovieWindowControllerFPS":@(4),
                                                                  @"SXIOExportMovieWindowControllerFontSize":@(14)
                                                                  }];
    }
}

- (int32_t)fps
{
    return (int32_t)[[NSUserDefaults standardUserDefaults] integerForKey:@"SXIOExportMovieWindowControllerFPS"];
}

- (void)setFps:(int32_t)fps
{
    [[NSUserDefaults standardUserDefaults] setInteger:fps forKey:@"SXIOExportMovieWindowControllerFPS"];
}

- (NSInteger)fontSize
{
    return (int32_t)[[NSUserDefaults standardUserDefaults] integerForKey:@"SXIOExportMovieWindowControllerFontSize"];
}

- (void)setFontSize:(NSInteger)fontSize
{
    [[NSUserDefaults standardUserDefaults] setInteger:fontSize forKey:@"SXIOExportMovieWindowControllerFontSize"];
}

- (CASCCDExposure*)exposureWithURL:(NSURL*)url
{
    NSError* error;
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:url.path];
    CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
    [io readExposure:exposure readPixels:YES error:&error];
    exposure.io = io; // ensure pixels can be purged in -reset
    if (error){
        NSLog(@"exposureWithURL: %@",error);
    }
    return error ? nil : exposure;
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([key isEqualToString:@"fps"]){
        self.fps = 1;
    }
    else {
        [super setNilValueForKey:key];
    }
}

- (void)callCompletion:(NSError*)error url:(NSURL*)url
{
    if (self.completion){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completion(error,self.cancelled ? nil : url);
        });
    }
}

- (void)runWithCompletion:(void(^)(NSError*,NSURL*))completion
{
    if (!self.window.isVisible){
        [self.window center];
        [self.window makeKeyAndOrderFront:nil];
    }
    
    self.progress = 0;
    self.cancelled = NO;
    self.movieFilename = nil;
    self.completion = completion;
    
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.canChooseDirectories = NO;
    open.canChooseFiles = YES;
    open.allowedFileTypes = @[@"fit",@"fits"];
    open.allowsMultipleSelection = YES;
    open.message = @"Select exposures to make into a movie";
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result != NSFileHandlingPanelOKButton || [open.URLs count] < 2){
            [self callCompletion:nil url:nil];
        }
        else {
            self.URLs = open.URLs;
            self.frameCount = [self.URLs count];
            _currentFrame = NSNotFound;
            self.currentFrame = 0;
        }
    }];
}

- (void)setCurrentFrame:(NSInteger)currentFrame
{
    if (currentFrame != _currentFrame){
        
        _currentFrame = currentFrame;
        
        // todo; do this async 
        CASCCDExposure* exp = [CASCCDExposureIO exposureWithPath:[self.URLs[_currentFrame] path] readPixels:YES error:nil];
        self.exposureView.currentExposure = exp;
        
        [self.exposureView zoomImageToFit:nil];
    }
}

- (IBAction)savePressed:(id)sender
{
    NSSavePanel* save = [NSSavePanel savePanel];
    
    save.allowedFileTypes = @[@"mov"];
    save.canCreateDirectories = YES;
    save.message = @"Choose where to save the movie file";
    save.directoryURL = [self.URLs.firstObject URLByDeletingLastPathComponent];
    save.nameFieldStringValue = @"movie";
    save.accessoryView = self.saveAccessoryView;
    
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result != NSFileHandlingPanelOKButton){
            
            [self callCompletion:nil url:nil];
        }
        else{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                self.movieFilename = [save.URL.path lastPathComponent];
                
                [[NSFileManager defaultManager] removeItemAtURL:save.URL error:nil];
                
                self.exporter = [CASMovieExporter exporterWithURL:save.URL];
                if (self.exporter){
                    
                    NSArray* sortedURLs;
                    switch (self.sortMode) {
                        case SXIOExportMovieDateSort:{
                            NSMutableArray* dates = [NSMutableArray arrayWithCapacity:[self.URLs count]];
                            for (NSURL* url in self.URLs){
                                @autoreleasepool {
                                    CASCCDExposure* exp = [CASCCDExposureIO exposureWithPath:url.path readPixels:NO error:nil];
                                    if (exp){
                                        NSDate* date = exp.date;
                                        if (date){
                                            [dates addObject:@{@"url":url, @"date":date}];
                                        }
                                    }
                                }
                            }
                            
                            if ([dates count] != [self.URLs count]){
                                NSLog(@"Counts don't match");
                            }
                            
                            sortedURLs = [[dates sortedArrayWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(NSDictionary* obj1, NSDictionary* obj2) {
                                NSDate* d1 = obj1[@"date"];
                                NSDate* d2 = obj2[@"date"];
                                return [d1 compare:d2];
                            }] valueForKey:@"url"];
                        }
                            break;
                        case SXIOExportMovieNameSort:
                            sortedURLs = [self.URLs sortedArrayWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(NSURL* obj1, NSURL* obj2) {
                                NSDictionary* d1 = [obj1 resourceValuesForKeys:@[NSURLNameKey] error:nil];
                                NSDictionary* d2 = [obj2 resourceValuesForKeys:@[NSURLNameKey] error:nil];
                                
                                NSString* name1 = d1[NSURLNameKey];
                                NSString* name2 = d2[NSURLNameKey];
                                const NSRange name1Range = NSMakeRange(0, [name1 length]);
                                
                                return [name1 compare:name2
                                              options:NSCaseInsensitiveSearch|NSNumericSearch|NSWidthInsensitiveSearch|NSForcedOrderingSearch
                                                range:name1Range
                                               locale:[NSLocale currentLocale]];
                            }];
                            break;
                    }
                    
                    NSError* error;
                    __block NSInteger frame = 0;
                    NSEnumerator* urlEnum = [sortedURLs objectEnumerator];
                    
                    __weak __typeof(self) weakSelf = self;
                    self.exporter.input = ^(CASCCDExposure** expPtr,CMTime* time, NSString** annotatioPtr){
                        
                        NSURL* nextURL = weakSelf.cancelled ? nil : [urlEnum nextObject];
                        if (!nextURL){
                            [weakSelf.exporter complete];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                weakSelf.exporter = nil;
                                [weakSelf callCompletion:nil url:save.URL];
                            });
                        }
                        else {
                            *time = CMTimeMake(frame++,weakSelf.fps);
                            *expPtr = [weakSelf exposureWithURL:nextURL];
                            if (weakSelf.filterPipeline){
                                // filter exposure
                            }
                            weakSelf.progress = (float)frame / (float)[weakSelf.URLs count];
                        }
                    };
                    
                    self.exporter.showDateTime = self.showDateTime;
                    self.exporter.fontSize = self.fontSize;
                    self.exporter.compressionLevel = self.compressionLevel;
                    self.exporter.showFilename = self.showFilename;
                    self.exporter.showCustom = self.showCustom;
                    self.exporter.customAnnotation = self.customAnnotation;
                    
                    [self.exporter startWithExposure:[self exposureWithURL:sortedURLs.firstObject] error:&error];
                }
            });
        }
    }];
}

- (IBAction)cancelPressed:(NSButton*)sender
{
    self.cancelled = YES;
    [sender setEnabled:NO];
}

+ (instancetype)loadWindowController
{
    return [[[self class] alloc] initWithWindowNibName:@"SXIOExportMovieWindowController"];
}

@end
