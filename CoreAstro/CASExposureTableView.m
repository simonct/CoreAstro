//
//  CASExposureTableView.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASExposureTableView.h"

@implementation CASExposureTableView

@synthesize exposuresController;

- (void)keyDown:(NSEvent *)event
{
    if([[event charactersIgnoringModifiers] characterAtIndex:0] == NSDeleteCharacter && self.exposuresController.isEditable) {
        
        const NSInteger count = [[self selectedRowIndexes] count];
        if (count > 0){
            
            NSString* message = (count == 1) ? @"Are you sure you want to delete this exposure ? This cannot be undone." : [NSString stringWithFormat:@"Are you sure you want to delete these %ld exposures ? This cannot be undone.",count];
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"Delete Exposure"
                                             defaultButton:nil
                                           alternateButton:@"Cancel"
                                               otherButton:nil
                                 informativeTextWithFormat:message,nil];
            
            [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(deleteConfirmSheetCompleted:returnCode:contextInfo:) contextInfo:nil];
        }
    }
    
    [super keyDown:event];
}

- (void)deleteConfirmSheetCompleted:(NSAlert*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertDefaultReturn){
        [self.exposuresController removeObjectsAtArrangedObjectIndexes:[self selectedRowIndexes]];
    }
}

@end
