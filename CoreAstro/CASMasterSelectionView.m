//
//  CASMasterView.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASMasterSelectionView.h"
#import "CASUtilities.h"
#import <objc/runtime.h>

@implementation CASCCDExposureLibraryProject (CASMasterSelectionView)

static const char exposuresControllerKey;

- (CASExposuresController*) exposuresController {
    return objc_getAssociatedObject(self,&exposuresControllerKey);
}

- (void)setExposuresController:(CASExposuresController *)exposuresController {
    objc_setAssociatedObject(self, &exposuresControllerKey, exposuresController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface CASCCDExposureLibraryProject (CASMasterSelectionView1)<NSPasteboardWriting>
@end

NSString* const kCASCCDExposureLibraryProjectUTI = @"org.coreastro.project-uuid";

@implementation CASCCDExposureLibraryProject (CASMasterSelectionView1)

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    if (aProtocol == @protocol(NSPasteboardWriting)){
        return YES;
    }
    return [super conformsToProtocol:aProtocol];
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[kCASCCDExposureLibraryProjectUTI];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    return self.uuid;
}

@end

@interface CASMasterSelectionViewNullCamera : NSObject
@end

@implementation CASMasterSelectionViewNullCamera
@end

@implementation CASMasterSelectionView {
    NSMutableArray* nodes;
    BOOL delegateRespondsToCameraWasSelected:1;
    BOOL delegateRespondsToLibraryWasSelected:1;
    NSTreeNode* _editingNode;
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

- (void)completeSetup
{
    [self reloadData];
    [self expandItem:[nodes objectAtIndex:0] expandChildren:YES];
    [self expandItem:[nodes objectAtIndex:1] expandChildren:YES];
    
    [self registerForDraggedTypes:@[(id)kUTTypeUTF8PlainText,kCASCCDExposureLibraryProjectUTI]];

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

- (void)selectProject:(CASCCDExposureLibraryProject*)project
{
    NSInteger projectRow = NSNotFound;
    if (project){
        projectRow = [self rowForItem:[self nodeWithProjectUUID:project.uuid]];
    }
    else{
        NSTreeNode* node = [[self.exposuresTreeNode childNodes] objectAtIndex:0];
        projectRow = [self rowForItem:node];
        project = node.representedObject;
    }
    if (projectRow != NSNotFound){
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:projectRow] byExtendingSelection:NO];
        if (delegateRespondsToLibraryWasSelected){
            [self.masterViewDelegate libraryWasSelected:project];
        }
    }
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

- (NSMenu*)menuForEvent:(NSEvent *)event
{
    NSMenu* menu = nil;
    const NSInteger row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    if (row != -1){
        
        NSTreeNode* node = [self itemAtRow:row];
        id project = [node representedObject];
        if ([project isKindOfClass:[CASCCDExposureLibraryProject class]]){
            
            NSMenuItem* item = nil;
            menu = [[NSMenu alloc] initWithTitle:@""];
            if (project == [CASCCDExposureLibrary sharedLibrary].currentProject){
                item = [[NSMenuItem alloc] initWithTitle:@"Clear Current Project" action:@selector(clearCurrentProject:) keyEquivalent:@""];
            }
            else {
                item = [[NSMenuItem alloc] initWithTitle:@"Make Current Project" action:@selector(makeCurrentProject:) keyEquivalent:@""];
            }
            [item setRepresentedObject:project];
            [menu addItem:item];
        }
    }
    return menu;
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
                            
                            __block BOOL currentCameraRemoved = NO;
                            [[self selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                                NSTreeNode* node = [self itemAtRow:idx];
                                if (node == child){
                                    currentCameraRemoved = YES;
                                }
                            }];
                            
                            [[camerasTreeNode mutableChildNodes] removeObject:child];

                            if (currentCameraRemoved){
                                if (delegateRespondsToCameraWasSelected){
                                    [self.masterViewDelegate cameraWasSelected:nil];
                                }
                            }
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

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(NSTreeNode*)item
{
    NSMutableAttributedString* mas = [[NSMutableAttributedString alloc] initWithAttributedString:[cell attributedStringValue]];
    if ([item representedObject] == [CASCCDExposureLibrary sharedLibrary].currentProject){
        [mas setAttributes:@{@"NSFont":[NSFont fontWithName:@"LucidaGrande-Bold" size:13]} range:NSMakeRange(0, [mas length])];
        cell.attributedStringValue = mas;
    }
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

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTreeNode* node = item;
    if (node.parentNode == self.exposuresTreeNode && node != self.exposuresTreeNode.childNodes[0]){
        _editingNode = node;
        return YES;
    }
    return NO;
}

- (NSString *)outlineView:(NSOutlineView *)outlineView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(NSTreeNode*)item mouseLocation:(NSPoint)mouseLocation
{
    if (item.parentNode == self.camerasTreeNode){
        CASCameraController* controller = item.representedObject;
        if ([controller isKindOfClass:[CASCameraController class]]){
            return controller.camera.path;
        }
    }
    return nil;
}

- (void) textDidEndEditing: (NSNotification *) notification
{
    const NSInteger reason = [[[notification userInfo] objectForKey:@"NSTextMovement"] integerValue];
    switch (reason) {
        case NSReturnTextMovement:
        case NSOtherTextMovement:{
            NSTextView* field = [notification object];
            CASCCDExposureLibraryProject* project = [_editingNode representedObject];
            NSString* name = [field string];
            if ([name length]){
                project.name = name;
            }
            [self abortEditing];
        }
            break;
    }
    _editingNode = nil;
}

#pragma mark - Actions

- (IBAction)addProject:(id)sender
{
    CASCCDExposureLibraryProject* project = [[CASCCDExposureLibraryProject alloc] init];
    
    static NSDateFormatter* formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    });
    project.name = [NSString stringWithFormat:@"Project %@",[formatter stringFromDate:[NSDate date]]];
    
    [[CASCCDExposureLibrary sharedLibrary] addProjects:[NSSet setWithObject:project]];
    
    NSTreeNode* node = [NSTreeNode treeNodeWithRepresentedObject:project];
    [[self.exposuresTreeNode mutableChildNodes] addObject:node];
    [self reloadData];
    
    [CASCCDExposureLibrary sharedLibrary].currentProject = project;
    
    const NSInteger row = [self rowForItem:[[self.exposuresTreeNode childNodes] lastObject]];
    if (row != -1){
        [self editColumn:0 row:row withEvent:nil select:YES];
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        _editingNode = node;
    }
}

- (IBAction)removeProject:(id)sender
{
    NSIndexSet* selection = [self selectedRowIndexes];
    [selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        
        NSTreeNode* node = [self itemAtRow:idx];
        if (node.parentNode == self.exposuresTreeNode && node != self.exposuresTreeNode.childNodes[0]){
            
            // ensure the exposures controller unbinds first
            CASCCDExposureLibraryProject* project = (CASCCDExposureLibraryProject*)node.representedObject;
            project.exposuresController = nil;
            
            [[CASCCDExposureLibrary sharedLibrary] removeProjects:[NSSet setWithObject:project]];
            [[self.exposuresTreeNode mutableChildNodes] removeObject:node];
        }
    }];
    [self reloadData];
}

- (IBAction)makeCurrentProject:(id)sender
{
    [CASCCDExposureLibrary sharedLibrary].currentProject = [sender representedObject];
    [self reloadItem:self.exposuresTreeNode reloadChildren:YES];
}

- (IBAction)clearCurrentProject:(id)sender
{
    [CASCCDExposureLibrary sharedLibrary].currentProject = nil;
    [self reloadItem:self.exposuresTreeNode reloadChildren:YES];
}

#pragma mark - Drag & Drop

- (NSArray*)projectsFromDraggingInfo:(id<NSDraggingInfo>)info
{
    NSMutableArray* sourceProjects = [NSMutableArray arrayWithCapacity:[[[info draggingPasteboard] pasteboardItems] count]];
    for (NSPasteboardItem* item in [[info draggingPasteboard] pasteboardItems]){
        NSString* uuid = [item propertyListForType:kCASCCDExposureLibraryProjectUTI];
        if ([uuid isKindOfClass:[NSString class]]){
            [sourceProjects addObject:uuid];
        }
    }
    return sourceProjects;
}

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

- (NSTreeNode*)nodeWithProjectUUID:(NSString*)uuid
{
    for (NSTreeNode* node in [self.exposuresTreeNode childNodes]){
        if (node == [self.exposuresTreeNode childNodes][0]){
            continue;
        }
        CASCCDExposureLibraryProject* project = node.representedObject;
        if ([project.uuid isEqualToString:uuid]){
            return node;
        }
    }
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard
{
    [pasteboard clearContents];
    
    __block NSMutableArray* projects = [NSMutableArray arrayWithCapacity:1];
    [items enumerateObjectsUsingBlock:^(NSTreeNode* node, NSUInteger idx, BOOL *stop) {
        if (node.parentNode == self.exposuresTreeNode && node != self.exposuresTreeNode.childNodes[0]){
            [projects addObject:node.representedObject];
        }
    }];
    
    if ([projects count] && [pasteboard writeObjects:projects]){
        return YES;
    }
    
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index;
{
    NSTreeNode* node = item;
    
    NSArray* projects = [self projectsFromDraggingInfo:info];
    if ([projects count]){
        
        const NSInteger currentIndex = [[self.exposuresTreeNode childNodes] indexOfObject:[self nodeWithProjectUUID:[projects lastObject]]];
        if (node != self.exposuresTreeNode || index < 1 || index == currentIndex || index == currentIndex + 1){
            return NSDragOperationNone;
        }
        return NSDragOperationMove;
    }

    NSArray* exposures = [self exposuresFromDraggingInfo:info];
    if ([exposures count]){
        if (node.parentNode != self.exposuresTreeNode || node == self.exposuresTreeNode.childNodes[0]){
            return NSDragOperationNone;
        }
        return NSDragOperationLink;
    }
    
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
    NSArray* projects = [self projectsFromDraggingInfo:info];
    if ([projects count]){
        
        id projectUUID = [projects lastObject];
        id project = [[CASCCDExposureLibrary sharedLibrary] projecteWithUUID:projectUUID];
        if (project){
            
            if (index > [[self.exposuresTreeNode childNodes] indexOfObject:[self nodeWithProjectUUID:projectUUID]]){
                index -= 2;
            }
            else {
                index -= 1;
            }
            
            [[CASCCDExposureLibrary sharedLibrary] moveProject:project toIndex:index];
            
            [[self.exposuresTreeNode mutableChildNodes] removeObjectsInRange:NSMakeRange(1, [[self.exposuresTreeNode mutableChildNodes] count] - 1)];
            for (id project in [CASCCDExposureLibrary sharedLibrary].projects){
                [[self.exposuresTreeNode mutableChildNodes] addObject:[NSTreeNode treeNodeWithRepresentedObject:project]];
            }
            [self reloadData];
            
            return YES;
        }
        return NO;
    }
    
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
