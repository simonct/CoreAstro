//
//  CASMasterView.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASMasterSelectionView.h"
#import "CASCCDExposureLibrary.h"

@interface CASMasterSelectionViewNullCamera : NSObject
@end

@implementation CASMasterSelectionViewNullCamera
@end

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
    
    [self registerForDraggedTypes:@[(id)kUTTypeUTF8PlainText]];

    NSButton* addButton = [[NSButton alloc] init];
    [addButton setTitle:@"+"];
    [addButton setBezelStyle:NSSmallSquareBezelStyle];
    [addButton setFrame:CGRectMake(1, self.bounds.size.height - 38, self.bounds.size.width/2, 20)];
    [addButton setAutoresizingMask:NSViewMinYMargin];
    [addButton setTarget:self];
    [addButton setAction:@selector(addProject:)];
    [self addSubview:addButton];

    NSButton* minusButton = [[NSButton alloc] init];
    [minusButton setTitle:@"-"];
    [minusButton setBezelStyle:NSSmallSquareBezelStyle];
    [minusButton setFrame:CGRectMake(self.bounds.size.width/2, self.bounds.size.height - 38, self.bounds.size.width/2, 20)];
    [minusButton setAutoresizingMask:NSViewMinYMargin];
    [minusButton setAction:@selector(removeProject:)];
    [self addSubview:minusButton];
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
    for (CASCCDExposureLibraryProject* project in [CASCCDExposureLibrary sharedLibrary].projects){
        [[library mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:project]];
    }
    [nodes addObject:library];
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

- (NSString*)cameraControllersKeyPath
{
    return @"cameraControllers";
}

- (NSArray*)cameraControllers
{
    return [_camerasContainer valueForKeyPath:self.cameraControllersKeyPath];
}

- (NSTreeNode*)camerasTreeNode
{
    return nodes[0];
}

- (NSTreeNode*)exposuresTreeNode
{
    return nodes[1];
}

- (void)setCamerasContainer:(id)camerasContainer
{
    if (camerasContainer != _camerasContainer){
        [_camerasContainer removeObserver:self forKeyPath:self.cameraControllersKeyPath];
        _camerasContainer = camerasContainer;
        [_camerasContainer addObserver:self forKeyPath:self.cameraControllersKeyPath options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        NSTreeNode* camerasTreeNode = self.camerasTreeNode;
        switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                
            case NSKeyValueChangeSetting:
            case NSKeyValueChangeInsertion:{
                [[change objectForKey:NSKeyValueChangeNewKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [[camerasTreeNode mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:obj]];
                }];
            }
                break;
                
            case NSKeyValueChangeRemoval:{
                [[change objectForKey:NSKeyValueChangeOldKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    for (NSTreeNode* child in [camerasTreeNode mutableChildNodes]){
                        if (child.representedObject == obj){
                            [[camerasTreeNode mutableChildNodes] removeObject:child];
                        }
                    }
                }];
            }
                break;
            default:
                break;
        }
        
        if (![self.cameraControllers count]){
            [[self.camerasTreeNode mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:[CASMasterSelectionViewNullCamera new]]];
        }
        else {
            for (NSTreeNode* child in [self.camerasTreeNode mutableChildNodes]){
                if ([child.representedObject isKindOfClass:[CASMasterSelectionViewNullCamera class]]){
                    [[self.camerasTreeNode mutableChildNodes] removeObject:child];
                }
            }
        }

        [self reloadItem:camerasTreeNode reloadChildren:YES];

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
    if ([representedObject isKindOfClass:[CASCCDExposureLibraryProject class]]){
        return ((CASCCDExposureLibraryProject*)representedObject).name;
    }
    if ([representedObject isKindOfClass:[CASMasterSelectionViewNullCamera class]]){
        return @"No Cameras Connected";
    }
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
            if (node.parentNode == self.camerasTreeNode){
                if (delegateRespondsToCameraWasSelected){
                    id camera = [node representedObject];
                    if ([camera isKindOfClass:[CASMasterSelectionViewNullCamera class]]){
                        camera = nil;
                    }
                    [self.masterViewDelegate cameraWasSelected:camera];
                }
            }
            else if (node.parentNode == self.exposuresTreeNode){
                if (delegateRespondsToLibraryWasSelected){
                    [self.masterViewDelegate libraryWasSelected:[node representedObject]];
                }
            }
        }];
    }
}

#pragma mark - Actions

- (IBAction)addProject:(id)sender
{
    CASCCDExposureLibraryProject* project = [[CASCCDExposureLibraryProject alloc] init];
    project.name = @"New Project"; // current date
    [[CASCCDExposureLibrary sharedLibrary] addProjects:[NSArray arrayWithObject:project]];
    [[self.exposuresTreeNode mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:project]];
    [self reloadData];
}

- (IBAction)removeProject:(id)sender
{
    NSIndexSet* selection = [self selectedRowIndexes];
    [selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSTreeNode* node = [self itemAtRow:idx];
        if (node.parentNode == self.exposuresTreeNode && node != self.exposuresTreeNode.childNodes[0]){
            [[CASCCDExposureLibrary sharedLibrary] removeProjects:[NSArray arrayWithObject:node.representedObject]];
            [[self.exposuresTreeNode mutableChildNodes] removeObject:node];
        }
    }];
    [self reloadData];
}

#pragma mark - Drag & Drop

- (NSArray*)exposuresFromDraggingInfo:(id<NSDraggingInfo>)info
{
    NSMutableArray* sourceExposures = [NSMutableArray arrayWithCapacity:[[[info draggingPasteboard] pasteboardItems] count]];
    for (NSPasteboardItem* item in [[info draggingPasteboard] pasteboardItems]){
        NSString* uuid = [item propertyListForType:(id)kUTTypeUTF8PlainText];
        if ([uuid isKindOfClass:[NSString class]]){
            [sourceExposures addObject:uuid];
        }
    }
    return sourceExposures;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index;
{
    NSTreeNode* node = item;
    if (node.parentNode != self.exposuresTreeNode || node == self.exposuresTreeNode.childNodes[0] || ![self exposuresFromDraggingInfo:info]){
        return NSDragOperationNone;
    }

    return NSDragOperationCopy;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
    NSArray* uuids = [self exposuresFromDraggingInfo:info];
    
    __block NSMutableArray* exposures = [NSMutableArray arrayWithCapacity:[uuids count]];
    [uuids enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id exposure = [[CASCCDExposureLibrary sharedLibrary] exposureWithUUID:obj];
        if (exposure){
            [exposures addObject:exposure];
        }
    }];
    
    if ([exposures count]){
        NSTreeNode* node = item;
        CASCCDExposureLibraryProject* project = node.representedObject;
        [project addExposures:[NSSet setWithArray:exposures]];
    }

    return YES;
}

@end
