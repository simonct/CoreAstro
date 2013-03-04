//
//  CASExposuresController.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASExposuresController.h"
#import <CoreAstro/CoreAstro.h>

@interface CASExposuresController ()
@property (nonatomic,weak) id container;
@property (nonatomic,copy) NSString* keyPath;
@property (nonatomic,strong) NSMutableArray* navigationObjects;
@end

@implementation CASExposuresController

- (id)initWithContent:(id)content
{
    self = [super initWithContent:content];
    if (self) {
        [self setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    }
    return self;
}

- (id)initWithContainer:(id)container keyPath:(NSString*)keyPath
{
    self = [super initWithContent:[container valueForKeyPath:keyPath]];
    if (self) {
        self.keyPath = keyPath;
        self.container = container;
        [self.container addObserver:self forKeyPath:self.keyPath options:0 context:(__bridge void *)(self)];
    }
    return self;
}

- (void)dealloc
{
    [self.container removeObserver:self forKeyPath:self.keyPath];
}

- (NSArray *)arrangeObjects:(NSArray *)objects
{
    if (self.navigateSelection){
        objects = [self.navigationObjects copy];
    }
    return [super arrangeObjects:objects];
}

- (void)setNavigateSelection:(BOOL)navigateSelection
{
    if (navigateSelection != _navigateSelection){
        _navigateSelection = navigateSelection;
        if (_navigateSelection){
            self.navigationObjects = [self.selectedObjects mutableCopy];
            if ([self.navigationObjects count]){
                self.selectedObjects = @[self.selectedObjects[0]];
            }
        }
        else {
            self.navigationObjects = nil;
        }
        [self rearrangeObjects];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        NSLog(@"Fixme: move exposures controller into library project");
        self.content = [self.container valueForKeyPath:self.keyPath];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)removeObject:(id)object
{
    if (object){
        [self removeObjects:@[object]];
    }
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

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index deletingPermanently:(BOOL)deletingPermanently
{
    if (index != NSNotFound){
        id exposure = [[self arrangedObjects] objectAtIndex:index];
        if (deletingPermanently){
            [exposure deleteExposure];
        }
        [super removeObjectAtArrangedObjectIndex:index];
        if (self.navigationObjects){
            [self.navigationObjects removeObject:exposure];
            [self rearrangeObjects];
        }
    }
}

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index
{
    [self removeObjectAtArrangedObjectIndex:index deletingPermanently:YES];
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
            [self removeObjectAtArrangedObjectIndex:[indexes firstIndex] deletingPermanently:deletingPermanently];
        }
        else {
            NSArray* exposures = [arrangedObjects objectsAtIndexes:indexes];
            if (deletingPermanently){
                [exposures makeObjectsPerformSelector:@selector(deleteExposure)];
            }
            [super removeObjectsAtArrangedObjectIndexes:indexes];
            if (self.navigationObjects){
                [self.navigationObjects removeObjectsInArray:exposures];
                [self rearrangeObjects];
            }
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

