//
//  CASExposuresWindowController.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASExposuresWindowController.h"
#import "CASExposuresController.h"
#import "CASCCDExposureLibrary.h"

@interface CASExposuresWindowController ()
@property (nonatomic,strong) IBOutlet CASExposuresController *exposuresArrayController;
- (IBAction)okPressed:(id)sender;
- (IBAction)cancelPressed:(id)sender;
@end

@implementation CASExposuresWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // clearly this is something the CASExposuresController should do...
    [self.exposuresArrayController bind:@"contentArray" toObject:self withKeyPath:@"exposures" options:nil];
    [self.exposuresArrayController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    [self.exposuresArrayController setSelectedObjects:nil];
}

- (NSArray*)exposures
{
    return [[CASCCDExposureLibrary sharedLibrary] exposures];
}

- (IBAction)cancelPressed:(id)sender
{
    [self endSheetWithCode:NSCancelButton];
}

- (IBAction)okPressed:(id)sender
{
    [self endSheetWithCode:NSOKButton];
}

- (void)beginSheetModalForWindow:(NSWindow*)window exposuresCompletionHandler:(void (^)(NSInteger,NSArray*))handler
{
    [super beginSheetModalForWindow:window completionHandler:^(NSInteger code) {
        
        if (handler){
            handler(code,self.exposuresArrayController.selectedObjects);
        }
    }];
}

@end
