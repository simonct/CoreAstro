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

- (id)initWithContent:(id)content
{
    self = [super initWithContent:content];
    if (self) {
        [self setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    }
    return self;
}

- (void)removeObjects:(NSArray *)objects
{
    if ([objects count]){
        NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
        for (id object in objects){
            const NSInteger index = [[self arrangedObjects] indexOfObject:object];
            if (index != NSNotFound){
                [indexes addIndex:index];
            }
        }
        if ([indexes count]){
            [self removeObjectsAtArrangedObjectIndexes:indexes];
        }
    }
}

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index
{
    if (index != NSNotFound){
        [[[self arrangedObjects] objectAtIndex:index] deleteExposure];
        [super removeObjectAtArrangedObjectIndex:index];
    }
}

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes deletingPermanently:(BOOL)deletingPermanently
{
    if ([indexes count]){
        id nextObject = nil;
        const NSInteger firstIndex = [indexes firstIndex];
        const NSInteger lastIndex = [indexes lastIndex];
        NSArray* arrangedObjects = [self arrangedObjects];
        if (lastIndex+1 < [arrangedObjects count]){
            nextObject = [arrangedObjects objectAtIndex:lastIndex+1];
        }
        else if (firstIndex - 1 >= 0){
            nextObject = [arrangedObjects objectAtIndex:firstIndex-1];
        }
        if ([indexes count] == 1){
            [self removeObjectAtArrangedObjectIndex:[indexes firstIndex]];
        }
        else {
            if (deletingPermanently){
                [[arrangedObjects objectsAtIndexes:indexes] makeObjectsPerformSelector:@selector(deleteExposure)];
            }
            [super removeObjectsAtArrangedObjectIndexes:indexes];
        }
        if (nextObject){
            [self setSelectedObjects:[NSArray arrayWithObject:nextObject]];
        }
        if (self.project){
            [[CASCCDExposureLibrary sharedLibrary] projectWasUpdated:self.project]; // yuk
        }
    }
}

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
    [self removeObjectsAtArrangedObjectIndexes:indexes deletingPermanently:!self.project];
}

- (void)promptToDeleteCurrentSelectionWithWindow:(NSWindow*)window
{
    if(self.isEditable) {
        
        const NSInteger count = [[self selectedObjects] count];
        if (count > 0){
            
            NSString* message = message = (count == 1) ? @"Are you sure you want to delete this exposure ? This cannot be undone." : [NSString stringWithFormat:@"Are you sure you want to delete these %ld exposures ? This cannot be undone.",count];

            if (self.project){
                message = [NSString stringWithFormat:@"%@\n\nPress Project Only to only remove it from the project\n",message];
            }
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"Delete Exposure"
                                             defaultButton:nil
                                           alternateButton:@"Cancel"
                                               otherButton:self.project ? @"Project Only" : nil
                                 informativeTextWithFormat:message,nil];
            
            [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(deleteConfirmSheetCompleted:returnCode:contextInfo:) contextInfo:nil];
        }
    }
}

- (void)removeCurrentlySelectedExposuresWithWindow:(NSWindow*)window
{
    [self promptToDeleteCurrentSelectionWithWindow:window];
}

- (void)deleteConfirmSheetCompleted:(NSAlert*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    switch (returnCode) {
        case NSAlertDefaultReturn:
            [self removeObjectsAtArrangedObjectIndexes:[self selectionIndexes] deletingPermanently:YES];
            break;
        case NSAlertOtherReturn:
            [self removeObjectsAtArrangedObjectIndexes:[self selectionIndexes] deletingPermanently:NO];
            break;
        default:
            break;
    }
}

@end

