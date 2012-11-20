//
//  CASMasterView.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASMasterSelectionView.h"

@implementation CASMasterSelectionView {
    NSMutableArray* nodes;
    BOOL delegateRespondsToCameraWasSelected:1;
    BOOL delegateRespondsToLibraryWasSelected:1;
}

- (void)completeSetup
{
    [self reloadData];
    [self expandItem:[nodes objectAtIndex:0] expandChildren:YES];
    [self expandItem:[nodes objectAtIndex:1] expandChildren:YES];
}

- (void)awakeFromNib
{
    // should probably have all this logic in a viewcontroller, especially when we get to user-defined library folders
    self.dataSource = (id)self;
    self.delegate = (id)self;
    
    nodes = [NSMutableArray arrayWithCapacity:2];
    
    NSTreeNode* devices = [NSTreeNode treeNodeWithRepresentedObject:@"CAMERAS"];
    [nodes addObject:devices];
    
    NSTreeNode* library = [NSTreeNode treeNodeWithRepresentedObject:@"LIBRARY"];
    [[library mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:@"All Exposures"]];
    [nodes addObject:library];
}

- (NSArray*)cameraControllers
{
    return [[NSApp delegate] valueForKey:@"cameraControllers"];
}

- (void)setMasterViewDelegate:(id<CASMasterSelectionViewDelegate>)masterViewDelegate
{
    if (masterViewDelegate != _masterViewDelegate){
        _masterViewDelegate = masterViewDelegate;
        delegateRespondsToCameraWasSelected = [_masterViewDelegate respondsToSelector:@selector(cameraWasSelected:)];
        delegateRespondsToLibraryWasSelected = [_masterViewDelegate respondsToSelector:@selector(libraryWasSelected:)];
    }
}
- (void)mouseDown:(NSEvent *)theEvent
{
    if ([self rowAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]] == -1){
        [self deselectAll:nil];
    }
    else {
        [super mouseDown:theEvent];
    }
}

- (void)setCamerasContainer:(id)camerasContainer
{
    if (camerasContainer != _camerasContainer){
        [_camerasContainer removeObserver:self forKeyPath:@"cameraControllers"];
        _camerasContainer = camerasContainer;
        [_camerasContainer addObserver:self forKeyPath:@"cameraControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        NSTreeNode* devicesNode = [self itemAtRow:0];
        switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                
            case NSKeyValueChangeSetting:
            case NSKeyValueChangeInsertion:{
                [[change objectForKey:NSKeyValueChangeNewKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [[devicesNode mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:obj]];
                }];
            }
                break;
                
            case NSKeyValueChangeRemoval:{
                [[change objectForKey:NSKeyValueChangeOldKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    for (NSTreeNode* child in [devicesNode mutableChildNodes]){
                        if (child.representedObject == obj){
                            [[devicesNode mutableChildNodes] removeObject:child];
                        }
                    }
                }];
            }
                break;
            default:
                break;
        }
        
        [self reloadItem:devicesNode reloadChildren:YES];

    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (!item){
        return [nodes count];
    }
    NSTreeNode* node = item;
    return [[node childNodes] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    NSTreeNode* node = item;
    return (node.parentNode == nil);
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (!item){
        return [nodes objectAtIndex:index];
    }
    NSTreeNode* node = item;
    return [[node childNodes] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSInteger)index byItem:(id)item
{
    NSTreeNode* node = item;
    id representedObject = [node representedObject];
    if ([representedObject respondsToSelector:@selector(camera)]){
        return [representedObject valueForKeyPath:@"camera.deviceName"]; // todo; make category method
    }
    return [node representedObject];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return [nodes containsObject:item];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return ![nodes containsObject:item];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    NSIndexSet* selection = [self selectedRowIndexes];
    if (![selection count]){
        if (delegateRespondsToCameraWasSelected){
            [self.masterViewDelegate cameraWasSelected:nil];
        }
        if (delegateRespondsToLibraryWasSelected){
            [self.masterViewDelegate libraryWasSelected:nil];
        }
    }
    else {
        [selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            NSTreeNode* node = [self itemAtRow:idx];
            if (node.parentNode == [nodes objectAtIndex:0]){
                if (delegateRespondsToCameraWasSelected){
                    [self.masterViewDelegate cameraWasSelected:[node representedObject]];
                }
            }
            else if (node.parentNode == [nodes objectAtIndex:1]){
                if (delegateRespondsToLibraryWasSelected){
                    [self.masterViewDelegate libraryWasSelected:[node representedObject]];
                }
            }
        }];
    }
}

@end