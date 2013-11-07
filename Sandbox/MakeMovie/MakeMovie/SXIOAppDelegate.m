//
//  SXIOAppDelegate.m
//  MakeMovie
//
//  Created by Simon Taylor on 11/3/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOAppDelegate.h"
#import "SXIOExportMovieWindowController.h"

@interface SXIOAppDelegate ()
@property (nonatomic,strong) SXIOExportMovieWindowController* exporter;
@end

@implementation SXIOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self openDocument:nil];
}

- (void)openDocument:sender
{
    if (!self.exporter){
        self.exporter = [SXIOExportMovieWindowController loadWindowController];
    }
    
    [self.exporter.window center];
    [self.exporter.window makeKeyAndOrderFront:nil];
    
    [self.exporter runWithCompletion:^(NSError *error, NSURL *movieURL) {
        
        [self.exporter.window orderOut:nil];
        self.exporter = nil;

        if (error){
            [NSApp presentError:error];
        }
        else if (movieURL) {
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"Export Complete"
                                             defaultButton:@"OK"
                                           alternateButton:@"Cancel"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Open the output movie ?",nil];
            if ([alert runModal] == NSOKButton){
                [[NSWorkspace sharedWorkspace] openURL:movieURL];
            }
        }
    }];
}

@end
