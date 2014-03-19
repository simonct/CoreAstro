//
//  SXIOPreferencesWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/7/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "SXIOPreferencesWindowController.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOPreferencesWindowController ()
@property (nonatomic,strong) CASPlateSolver* solver;
@property (nonatomic,assign) NSInteger fileFormatIndex;
@end

@implementation SXIOPreferencesWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.solver = [CASPlateSolver plateSolverWithIdentifier:nil];
    }
    return self;
}

- (NSInteger)fileFormatIndex
{
    NSString* format = [[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"];
    if ([@"png" isEqualToString:format]){
        return 1;
    }
    return 0; // fits
}

- (void)setFileFormatIndex:(NSInteger)fileFormatIndex
{
    if (fileFormatIndex == 0){
        [[NSUserDefaults standardUserDefaults] setObject:@"fits" forKey:@"SXIODefaultExposureFileType"];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setObject:@"png" forKey:@"SXIODefaultExposureFileType"];
    }
}

// todo; utilities to download plate solving indexes
// todo; background plate solving option

@end
