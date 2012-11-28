//
//  CASLibraryBrowserView.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASLibraryBrowserView.h"

@implementation CASLibraryBrowserView

- (void)keyDown:(NSEvent *)theEvent
{
    if ([[theEvent charactersIgnoringModifiers] characterAtIndex:0] == NSDeleteCharacter){
        if ([self.libraryDelegate respondsToSelector:@selector(deleteSelectedExposures)]){
            [self.libraryDelegate deleteSelectedExposures];
        }
    }
    [super keyDown:theEvent];
}

@end
