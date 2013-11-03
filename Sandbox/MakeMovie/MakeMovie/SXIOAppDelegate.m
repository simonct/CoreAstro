//
//  SXIOAppDelegate.m
//  MakeMovie
//
//  Created by Simon Taylor on 11/3/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOAppDelegate.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOAppDelegate ()
@property (nonatomic,strong) CASMovieExporter* exporter;
@property (nonatomic,assign) int32_t fps;
@property (nonatomic,assign) float progress;
@property (strong) IBOutlet NSView *saveAccessoryView;
@end

@implementation SXIOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.fps = 4;
    [self openDocument:nil];
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

- (void)openDocument:sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.canChooseDirectories = NO;
    open.canChooseFiles = YES;
    open.allowedFileTypes = @[@"fit",@"fits"];
    open.allowsMultipleSelection = YES;
    open.message = @"Select exposures to make into a movie";
    
    [open beginWithCompletionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton && [open.URLs count] > 2){

            dispatch_async(dispatch_get_main_queue(), ^{
               
                NSSavePanel* save = [NSSavePanel savePanel];
                
                save.allowedFileTypes = @[@"mp4"];
                save.canCreateDirectories = YES;
                save.message = @"Choose where to save the movie file";
                save.directoryURL = [open.URLs.firstObject URLByDeletingLastPathComponent];
                save.nameFieldStringValue = @"movie";
                save.accessoryView = self.saveAccessoryView;
                
                [save beginWithCompletionHandler:^(NSInteger result) {
                    
                    if (result == NSFileHandlingPanelOKButton){
                        
                        [self.window center];
                        [self.window makeKeyAndOrderFront:nil];
                        
                        [[NSFileManager defaultManager] removeItemAtURL:save.URL error:nil];
                        
                        self.exporter = [CASMovieExporter exporterWithURL:save.URL];
                        if (self.exporter){
                            
                            NSError* error;
                            __block NSInteger frame = 0;
                            NSEnumerator* urlEnum = [open.URLs objectEnumerator];
                            
                            __weak __typeof(self) weakSelf = self;
                            self.exporter.input = ^(CASCCDExposure** expPtr,CMTime* time){
                                
                                NSURL* nextURL = [urlEnum nextObject];
                                if (!nextURL){
                                    
                                    [weakSelf.exporter complete];
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        
                                        [weakSelf.window orderOut:nil];
                                        
                                        weakSelf.exporter = nil;
                                        
                                        NSAlert* alert = [NSAlert alertWithMessageText:@"Export Complete"
                                                                         defaultButton:@"OK"
                                                                       alternateButton:@"Cancel"
                                                                           otherButton:nil
                                                             informativeTextWithFormat:@"Open the output movie ?",nil];
                                        if ([alert runModal] == NSOKButton){
                                            [[NSWorkspace sharedWorkspace] openURL:save.URL];
                                        }
                                    });
                                }
                                else {
                                    *time = CMTimeMake(++frame,weakSelf.fps);
                                    *expPtr = [weakSelf exposureWithURL:nextURL];
                                    weakSelf.progress = (float)frame / (float)[open.URLs count];
                                }
                            };
                            
                            [self.exporter startWithExposure:[self exposureWithURL:open.URLs.firstObject] error:&error];
                        }
                    }
                }];
            });
        }
    }];
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

@end
