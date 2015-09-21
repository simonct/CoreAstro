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

#define SXIO_USE_MOVIE_MAIN_WINDOW 0

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
                                                                  @"SXIOExportMovieWindowControllerFontSize":@(14),
                                                                  @"SXIOExportMovieWindowControllerCompressionLevel":@(1),
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

- (NSInteger)compressionLevel
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"SXIOExportMovieWindowControllerCompressionLevel"];
}

- (void)setCompressionLevel:(NSInteger)compressionLevel
{
    [[NSUserDefaults standardUserDefaults] setInteger:compressionLevel forKey:@"SXIOExportMovieWindowControllerCompressionLevel"];
}

- (BOOL)showDateTime
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOExportMovieWindowControllerShowDateTime"];
}

- (void)setShowDateTime:(BOOL)showDateTime
{
    [[NSUserDefaults standardUserDefaults] setBool:showDateTime forKey:@"SXIOExportMovieWindowControllerShowDateTime"];
}

- (BOOL)showFilename
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOExportMovieWindowControllerShowFilename"];
}

- (void)setShowFilename:(BOOL)showFilename
{
    [[NSUserDefaults standardUserDefaults] setBool:showFilename forKey:@"SXIOExportMovieWindowControllerShowFilename"];
}

- (BOOL)showCustom
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOExportMovieWindowControllerShowCustom"];
}

- (void)setShowCustom:(BOOL)showCustom
{
    [[NSUserDefaults standardUserDefaults] setBool:showCustom forKey:@"SXIOExportMovieWindowControllerShowCustom"];
}

- (NSString*)customAnnotation
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"SXIOExportMovieWindowControllerCustomAnnotation"];
}

- (void)setCustomAnnotation:(NSString *)customAnnotation
{
    [[NSUserDefaults standardUserDefaults] setObject:customAnnotation forKey:@"SXIOExportMovieWindowControllerCustomAnnotation"];
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
#if SXIO_USE_MOVIE_MAIN_WINDOW
    if (!self.window.isVisible){
        [self.window center];
        [self.window makeKeyAndOrderFront:nil];
    }
#else
    // temp - we're not using the main window but we need to force it to load to resolve outlets
    (void)self.window;
#endif
    
    self.progress = 0;
    self.cancelled = NO;
    self.movieFilename = nil;
    self.completion = completion;
    
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.canChooseDirectories = NO;
    open.canChooseFiles = YES;
    open.allowedFileTypes = @[@"fit",@"fits"]; // todo; add png
    open.allowsMultipleSelection = YES;
    open.message = @"Select exposures to make into a movie";
    
#if SXIO_USE_MOVIE_MAIN_WINDOW
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
#else
    [open beginWithCompletionHandler:^(NSInteger result) {
#endif
        if (result != NSFileHandlingPanelOKButton || [open.URLs count] < 2){
            [self callCompletion:nil url:nil];
        }
        else {
            self.URLs = open.URLs;
#if SXIO_USE_MOVIE_MAIN_WINDOW
            self.frameCount = [self.URLs count];
            _currentFrame = NSNotFound;
            self.currentFrame = 0;
#else
            dispatch_async(dispatch_get_main_queue(), ^{ // let this NSOpenPanel session unwind before starting the NSSavePanel one
                [self savePressed:nil];
            });
#endif
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
    
#if SXIO_USE_MOVIE_MAIN_WINDOW
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
#else
    [save beginWithCompletionHandler:^(NSInteger result) {
#endif
        if (result != NSFileHandlingPanelOKButton){
            
            [self callCompletion:nil url:nil];
        }
        else{
            
            self.movieFilename = [save.URL.path lastPathComponent];
            
            [[NSFileManager defaultManager] removeItemAtURL:save.URL error:nil];
            
            self.exporter = [CASMovieExporter exporterWithURL:save.URL];
            if (self.exporter){
                
                NSArray* sortedURLs;
                switch (self.sortMode) {
                    case SXIOExportMovieDateSort:
                        sortedURLs = [CASMovieExporter sortedExposuresByDate:self.URLs];
                        break;
                    case SXIOExportMovieNameSort:
                        sortedURLs = [CASMovieExporter sortedExposuresByName:self.URLs];
                        break;
                }
                
                NSError* error;
                __block NSInteger frame = 0;
                NSEnumerator* urlEnum = [sortedURLs objectEnumerator];
                
                __weak __typeof(self) weakSelf = self;
                self.exporter.input = ^(CASCCDExposure** expPtr,CMTime* time, NSString** annotationPtr){
                    
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
                        
                        NSMutableString* annotation = [NSMutableString stringWithCapacity:256];
                        
                        // draw timecode
                        if (weakSelf.showDateTime){
                            NSString* displayDate = (*expPtr).displayDate;
                            if (displayDate) {
                                [annotation appendString:displayDate];
                            }
                        }
                        
                        // draw filename
                        if (weakSelf.showFilename){
                            NSString* name = [(*expPtr).io.url resourceValuesForKeys:@[NSURLNameKey] error:nil][NSURLNameKey];
                            if ([name length]){
                                if ([annotation length]){
                                    [annotation appendString:@", "];
                                }
                                [annotation appendString:name];
                            }
                        }
                        
                        // draw custom
                        if (weakSelf.showCustom && [weakSelf.customAnnotation length]){
                            if ([annotation length]){
                                [annotation appendString:@", "];
                            }
                            [annotation appendString:weakSelf.customAnnotation];
                        }
                        
                        if (weakSelf.filterPipeline){
                            // filter exposure
                        }
                        
                        *annotationPtr = annotation;
                        
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
                
#if SXIO_USE_MOVIE_MAIN_WINDOW
                [NSApp beginSheet:self.progressWindow modalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
#else
                [self.progressWindow center];
                [self.progressWindow makeKeyAndOrderFront:nil];
#endif
            }
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
