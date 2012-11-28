//
//  CASExposuresController.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASExposuresController.h"
#import <CoreAstro/CoreAstro.h>

@implementation CASExposuresController

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index
{
    if (index != NSNotFound){
        [[[self arrangedObjects] objectAtIndex:index] deleteExposure];
        [super removeObjectAtArrangedObjectIndex:index];
    }
}

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
    if ([indexes count]){
        if ([indexes count] == 1){
            [self removeObjectAtArrangedObjectIndex:[indexes firstIndex]];
        }
        else {
            [[[self arrangedObjects] objectsAtIndexes:indexes] makeObjectsPerformSelector:@selector(deleteExposure)];
            [super removeObjectsAtArrangedObjectIndexes:indexes];
        }
    }
}

- (void)promptToDeleteCurrentSelectionWithWindow:(NSWindow*)window
{
    if(self.isEditable) {
        
        const NSInteger count = [[self selectedObjects] count];
        if (count > 0){
            
            NSString* message = (count == 1) ? @"Are you sure you want to delete this exposure ? This cannot be undone." : [NSString stringWithFormat:@"Are you sure you want to delete these %ld exposures ? This cannot be undone.",count];
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"Delete Exposure"
                                             defaultButton:nil
                                           alternateButton:@"Cancel"
                                               otherButton:nil
                                 informativeTextWithFormat:message,nil];
            
            [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(deleteConfirmSheetCompleted:returnCode:contextInfo:) contextInfo:nil];
        }
    }
}

- (void)deleteConfirmSheetCompleted:(NSAlert*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertDefaultReturn){
        [self removeObjectsAtArrangedObjectIndexes:[self selectionIndexes]];
    }
}

@end

