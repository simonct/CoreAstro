//
//  CASAppDelegate.h
//  fw-test
//
//  Created by Simon Taylor on 2/9/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMatrix *filterSelectionMatrix;
@property (nonatomic,strong) NSMutableArray* filterNames;

- (IBAction)setCurrentFilter:(id)sender;

@end
