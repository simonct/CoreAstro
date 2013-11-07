//
//  SXIOExportMovieWindowController.m
//  MakeMovie
//
//  Created by Simon Taylor on 11/7/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOExportMovieWindowController.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOExportMovieWindowController ()
@property (nonatomic,strong) CASMovieExporter* exporter;
@property (nonatomic,assign) int32_t fps;
@property (nonatomic,assign) float progress;
@property (strong) IBOutlet NSView *saveAccessoryView;
@end

@implementation SXIOExportMovieWindowController

+ (void)initialize
{
    if (self == [SXIOExportMovieWindowController class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"SXIOExportMovieWindowControllerFPS":@(4)}];
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

- (void)runWithCompletion:(void(^)(NSError*,NSURL*))completion
{
    if (!self.window.isVisible){
        [self.window center];
        [self.window makeKeyAndOrderFront:nil];
    }
    
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.canChooseDirectories = NO;
    open.canChooseFiles = YES;
    open.allowedFileTypes = @[@"fit",@"fits"];
    open.allowsMultipleSelection = YES;
    open.message = @"Select exposures to make into a movie";
    
    void (^callCompletion)() = ^(NSError* error, NSURL* url) {
        if (completion){
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error,url);
            });
        }
    };
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result != NSFileHandlingPanelOKButton || [open.URLs count] < 2){
            
            callCompletion(nil,nil);
        }
        else{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                NSSavePanel* save = [NSSavePanel savePanel];
                
                save.allowedFileTypes = @[@"mp4"];
                save.canCreateDirectories = YES;
                save.message = @"Choose where to save the movie file";
                save.directoryURL = [open.URLs.firstObject URLByDeletingLastPathComponent];
                save.nameFieldStringValue = @"movie";
                save.accessoryView = self.saveAccessoryView;
                
                [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
                    
                    if (result != NSFileHandlingPanelOKButton){
                        
                        callCompletion(nil,nil);
                    }
                    else{
                    
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            [[NSFileManager defaultManager] removeItemAtURL:save.URL error:nil];
                            
                            self.exporter = [CASMovieExporter exporterWithURL:save.URL];
                            if (self.exporter){
                                
                                NSArray* sortedURLs = [open.URLs sortedArrayWithOptions:0 usingComparator:^NSComparisonResult(NSURL* obj1, NSURL* obj2) {
                                    NSDictionary* d1 = [obj1 resourceValuesForKeys:@[NSURLCreationDateKey] error:nil];
                                    NSDictionary* d2 = [obj2 resourceValuesForKeys:@[NSURLCreationDateKey] error:nil];
                                    return [d1[NSURLCreationDateKey] compare:d2[NSURLCreationDateKey]];
                                }];
                                
                                NSError* error;
                                __block NSInteger frame = 0;
                                NSEnumerator* urlEnum = [sortedURLs objectEnumerator];
                                
                                __weak __typeof(self) weakSelf = self;
                                self.exporter.input = ^(CASCCDExposure** expPtr,CMTime* time){
                                    
                                    NSURL* nextURL = [urlEnum nextObject];
                                    if (!nextURL){
                                        
                                        [weakSelf.exporter complete];
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            
                                            weakSelf.exporter = nil;
                                            
                                            callCompletion(nil,save.URL);
                                        });
                                    }
                                    else {
                                        *time = CMTimeMake(++frame,weakSelf.fps);
                                        *expPtr = [weakSelf exposureWithURL:nextURL];
                                        weakSelf.progress = (float)frame / (float)[open.URLs count];
                                    }
                                };
                                
                                [self.exporter startWithExposure:[self exposureWithURL:sortedURLs.firstObject] error:&error];
                            }
                        });
                    }
                }];
            });
        }
    }];
}

+ (instancetype)loadWindowController
{
    return [[[self class] alloc] initWithWindowNibName:@"SXIOExportMovieWindowController"];
}

@end
