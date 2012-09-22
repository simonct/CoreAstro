//
//  CASImageView.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASImageView.h"

@implementation CASImageView

@synthesize firstShowEditPanel;

- (BOOL)hasEffectsMode
{
    return NO;
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (theEvent.clickCount == 2){
        [IKImageEditPanel sharedImageEditPanel].dataSource = (id<IKImageEditPanelDataSource>)self;
        if (!self.firstShowEditPanel){
            self.firstShowEditPanel = YES;
            const NSRect frame = [IKImageEditPanel sharedImageEditPanel].frame;
            const NSRect windowFrame = self.window.frame;
            [[IKImageEditPanel sharedImageEditPanel] setFrameOrigin:NSMakePoint(NSMinX(windowFrame) + NSWidth(windowFrame)/2 - NSWidth(frame)/2, NSMinY(windowFrame) + NSHeight(windowFrame)/2 - NSHeight(frame)/2)];
        }
        [[IKImageEditPanel sharedImageEditPanel] makeKeyAndOrderFront:nil];
        [[IKImageEditPanel sharedImageEditPanel] setHidesOnDeactivate:YES];
    }
}

@end
