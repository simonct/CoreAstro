//
//  CASLibraryBrowserViewController.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASLibraryBrowserViewController.h"
#import "CASLibraryBrowserView.h"
#import "CASBatchProcessor.h"
#import "CASProgressWindowController.h"
#import "CASExposuresController.h"

#import <Quartz/Quartz.h>
#import <CoreAstro/CoreAstro.h>

@interface CASLibraryBrowserViewController ()
@property (nonatomic,strong) IBOutlet NSWindow *titleEditingSheet;
@property (nonatomic,copy) NSString* currentEditingTitle;
@property (nonatomic,readonly) NSArray* exposures;
@property (nonatomic,strong) NSArray* groups;
@property (nonatomic,strong) NSMutableDictionary* wrappers;
@property (nonatomic,copy) NSString* groupKeyPath;
@property (assign) NSUInteger version;
- (IBAction)editTitleOK:(NSButton*)sender;
- (IBAction)editTitleCancel:(NSButton*)sender;
@end

@interface CASCCDExposure (CASLibraryBrowserViewController)<NSPasteboardWriting>
@end

@implementation CASCCDExposure (CASLibraryBrowserViewController)

- (id)groupInfoDeviceName
{
    NSString* name = self.displayDeviceName;
    if (!name){
        name = @"Unknown";
    }
    return @{
        @"name":name,
        @"value":name,
        @"sortKey":@"displayDeviceName"
    };
}

- (NSDate*) _dateDay
{
    NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:self.date];
    return [[NSCalendar currentCalendar] dateFromComponents:comps];
}

- (id)groupInfoDateDay
{
    static NSDateFormatter* formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
    });
    NSDate* dateDay = [self _dateDay];
    return @{
        @"name":[formatter stringFromDate:dateDay],
        @"value":dateDay,
        @"sortKey":@"_dateDay"
    };
}

- (id)groupInfoDeviceType
{
    return @{
        @"name":self.displayType,
        @"value":self.displayType,
        @"sortKey":@"displayType"
    };
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    if (aProtocol == @protocol(NSPasteboardWriting)){
        return YES;
    }
    return [super conformsToProtocol:aProtocol];
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[(id)kUTTypeUTF8PlainText];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    return self.uuid;
}

@end

@interface CASLibraryBrowserBackgroundView : NSView
@end

@implementation CASLibraryBrowserBackgroundView

- (BOOL)isOpaque
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor lightGrayColor] set];
    NSRectFill(self.bounds);
}

@end

@interface CASCCDExposureWrapper : NSObject
@property (nonatomic,strong) CASCCDExposure* exposure;
@property (nonatomic,unsafe_unretained) CASLibraryBrowserViewController* viewController; // can't have a weak ref to a VC in 10.7
@end

@implementation CASCCDExposureWrapper {
    NSImage* _image;
}

- (NSString *)imageRepresentationType
{
	return IKImageBrowserNSImageRepresentationType;
}

- (id)imageRepresentation
{
    if (!_image){
        CASCCDExposure* exposure = self.exposure;
        if (exposure.correctedExposure){
            exposure = exposure.correctedExposure;
        }
        if (exposure.debayeredExposure){
            exposure = exposure.debayeredExposure;
        }
        _image = exposure.thumbnail;
        if (!_image){
            // NSLog(@"No thumbnail for %@",self.exposure.date); // make one from the full res image
        }
    }
	return _image;
}

- (NSString *)imageUID
{
    return self.exposure.uuid;
}

- (NSString *) imageTitle
{
    NSString* note = self.exposure.note;
    if ([note length]){
        return note;
    }
    return self.exposure.displayName;
}

- (NSString *) imageSubtitle
{
    return self.exposure.displayDate;
}

- (NSUInteger) imageVersion
{
    return self.viewController.version;
//    NSDate* date;
//    if ([self.exposure.io.url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil]){
//        NSLog(@"self.exposure.io.url: %@ -> %@",self.exposure.io.url,date);
//        return (NSUInteger)[date timeIntervalSinceReferenceDate];
//    }
//    return 0;
}

+ (CASCCDExposureWrapper*)wrapperWithExposure:(CASCCDExposure*)exposure
{
    CASCCDExposureWrapper* wrapper = [[CASCCDExposureWrapper alloc] init];
    wrapper.exposure = exposure;
    return wrapper;
}

@end

@interface CASLibraryBrowserGroupInfo : NSObject
@property (nonatomic,copy) NSString* name;
@property (nonatomic,assign) NSRange range;
@end

@implementation CASLibraryBrowserGroupInfo
@end

@implementation CASLibraryBrowserViewController {
    NSArray* _groups;
    BOOL _suppressKeyValueObserving;
}

#pragma mark - View Controller

- (void)loadView
{
    [super loadView];
    
    [self.browserView setDataSource:self];
    [self.browserView setDelegate:self];
    [self.browserView setCellsStyleMask:IKCellsStyleTitled|IKCellsStyleSubtitled|IKCellsStyleShadowed];
    [self.browserView setZoomValue:0.5];
//    [self.browserView setDraggingDestinationDelegate:self];
//    [self.browserView setAllowsDroppingOnItems:YES];
//    [self.browserView registerForDraggedTypes:@[(id)kUTTypeUTF8PlainText]];
    [self.browserView setValue:[NSColor lightGrayColor] forKey:IKImageBrowserBackgroundColorKey];
    
    if ([self.browserView respondsToSelector:@selector(setViewController:)]){
        [self.browserView performSelector:@selector(setViewController:) withObject:self];
    }
}

#pragma mark - Exposures

- (void)setExposuresController:(CASExposuresController *)exposuresController
{
    if (exposuresController != _exposuresController){
        
        [_exposuresController removeObserver:self forKeyPath:@"selectedObjects" context:(__bridge void *)(self)];
        [_exposuresController removeObserver:self forKeyPath:@"arrangedObjects" context:(__bridge void *)(self)];
        
        _exposuresController = exposuresController;
        
        self.browserView.project = _exposuresController.project;
        
        [_exposuresController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
        [_exposuresController addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
        
        NSArray* currentSelection = [_exposuresController.selectedObjects copy];
        
        // set filter predicate to remove images with no uuid - probably remove this in prod builds as this should never happen in practice
        [_exposuresController setFilterPredicate:[NSPredicate predicateWithBlock:^BOOL(CASCCDExposure* exposure, NSDictionary *bindings) {
            return ([exposure.uuid length] > 0);
        }]];
        
        [_exposuresController setSelectedObjects:currentSelection];
        
        [self updateForCurrentGroupKey];
        [self.browserView reloadData];
    }
}

- (NSArray*)exposures
{
    return [self.exposuresController arrangedObjects];
}

- (CASExposuresController*)exposuresControllerWithExposures:(NSArray*)exposures
{
    CASExposuresController* exposuresController = [[CASExposuresController alloc] initWithContent:exposures];
    exposuresController.project = self.exposuresController.project;
    return exposuresController;
}

#pragma mark - Groups

- (NSArray*)groups
{
    if (!_groups){
        _groups = [NSMutableArray arrayWithCapacity:10];
    }
    return _groups;
}

- (void)updateForCurrentGroupKey
{
    NSSortDescriptor* defaultSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
    if (![_groupKeyPath length]){
        self.groups = nil;
        [self.exposuresController setSortDescriptors:@[defaultSortDescriptor]];
    }
    else {
        NSSet* groupInfos = [NSSet setWithArray:[self.exposures valueForKeyPath:_groupKeyPath]];
        if (![groupInfos count]){
            self.groups = nil;
            [self.exposuresController setSortDescriptors:@[defaultSortDescriptor]];
        }
        else {
            self.groups = [[groupInfos allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"value" ascending:NO]]];
            [self.exposuresController setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:self.groups[0][@"sortKey"] ascending:NO],defaultSortDescriptor]];
        }
    }
    
    _suppressKeyValueObserving = YES; // yuk
    @try {
        [self.exposuresController rearrangeObjects];
    }
    @finally {
        _suppressKeyValueObserving = NO;
    }
}

- (void)setGroupKeyPath:(NSString *)groupKeyPath
{
    if (_groupKeyPath != groupKeyPath){
        _groupKeyPath = [groupKeyPath copy];
        [self updateForCurrentGroupKey];
        [self.browserView reloadData];
    }
}

#pragma mark - IKImageBrowserView Support

- (NSUInteger) numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser
{
    return [self.exposures count];
}

- (id /*IKImageBrowserItem*/) imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index
{
    if (!self.wrappers){
        self.wrappers = [NSMutableDictionary dictionaryWithCapacity:[self.exposures count]];
    }
    CASCCDExposure* exposure = self.exposures[index];
    CASCCDExposureWrapper* wrapper = self.wrappers[exposure.uuid];
    if (!wrapper && exposure.uuid){
        wrapper = [CASCCDExposureWrapper wrapperWithExposure:exposure];
        wrapper.viewController = self;
        [self.wrappers setObject:wrapper forKey:exposure.uuid];
    }
    return wrapper;
}

- (NSUInteger) numberOfGroupsInImageBrowser:(IKImageBrowserView *) aBrowser
{
    return [self.groups count];
}

- (NSDictionary *) imageBrowser:(IKImageBrowserView *) aBrowser groupAtIndex:(NSUInteger) index
{
    NSDictionary* groupInfo = self.groups[index];
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"%K == %@",groupInfo[@"sortKey"],groupInfo[@"value"]];
    NSArray* groupItems = [self.exposures filteredArrayUsingPredicate:predicate];
    NSRange groupRange;
    if (![groupItems count]){
        groupRange = NSMakeRange(0, 0);
    }
    else {
        groupRange = NSMakeRange([self.exposures indexOfObject:groupItems[0]],[groupItems count]);
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            groupInfo[@"name"],IKImageBrowserGroupTitleKey,
            [NSValue valueWithRange:groupRange],IKImageBrowserGroupRangeKey,
            [NSNumber numberWithInt:IKGroupDisclosureStyle],IKImageBrowserGroupStyleKey,
            nil];
}

- (void)_editTitleSheetCompleted:(NSWindow*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sender orderOut:nil];
    
    if (returnCode == NSOKButton){
        CASCCDExposure* exposure = (__bridge CASCCDExposure *)(contextInfo);
        exposure.displayName = self.currentEditingTitle;
    }
}

- (IBAction)editTitleOK:(NSButton*)sender
{
    [NSApp endSheet:sender.window returnCode:NSOKButton];
}

- (IBAction)editTitleCancel:(NSButton*)sender
{
    [NSApp endSheet:sender.window returnCode:NSCancelButton];
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index
{
    IKImageBrowserCell* cell = [aBrowser cellForItemAtIndex:index];
    if (!cell){
        return;
    }
    
    // ignore multiple selections for now
    if ([self.exposuresController.selectedObjects count] > 1){
        return;
    }
    
    NSPoint point = [aBrowser convertPoint:[[aBrowser.window currentEvent] locationInWindow] fromView:nil];
    if (NSPointInRect(point, [cell titleFrame])){
        
        // you can't add subviews to an IKImageBrowserView so use a sheet for now
        CASCCDExposureWrapper* wrapper = cell.representedItem;
        self.currentEditingTitle = wrapper.exposure.displayName;
        [NSApp beginSheet:self.titleEditingSheet modalForWindow:aBrowser.window modalDelegate:self didEndSelector:@selector(_editTitleSheetCompleted:returnCode:contextInfo:) contextInfo:(__bridge void *)(wrapper.exposure)];
    }
    else {
        
        if ([self.exposureDelegate respondsToSelector:@selector(focusOnExposures:)]){
            [self.exposureDelegate focusOnExposures:self.exposuresController];
            // todo; back button to return to the browser view
        }
    }
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasRightClickedAtIndex:(NSUInteger) index withEvent:(NSEvent *) event
{
    NSMenuItem* (^createMenuItem)(NSString*,id,SEL) = ^(NSString* title,id repo,SEL action){
        NSMenuItem *item = [[NSMenuItem alloc] init];
        [item setTitle:title];
        [item setRepresentedObject:repo];
        [item setTarget:self];
        [item setAction:action];
        return item;
    };
    
    NSMenu* menu = nil;
    
    NSArray* exposures = [self.exposuresController selectedObjects];
    if ([exposures count] == 1 && self.exposuresController.project != nil){
        
        menu = [[NSMenu alloc] initWithTitle:@""];
        CASCCDExposure* exposure = exposures[0];
        
        if (exposure.type == kCASCCDExposureDarkType){
            if (exposure == self.exposuresController.project.masterDark){
                [menu addItem:createMenuItem(@"Clear Master Dark",nil,@selector(setAsMasterDark:))];
            }
            else {
                [menu addItem:createMenuItem(@"Set as Master Dark",exposure,@selector(setAsMasterDark:))];
            }
        }
        else if (exposure.type == kCASCCDExposureBiasType){
            if (exposure == self.exposuresController.project.masterBias){
                [menu addItem:createMenuItem(@"Clear Master Bias",nil,@selector(setAsMasterBias:))];
            }
            else {
                [menu addItem:createMenuItem(@"Set as Master Bias",exposure,@selector(setAsMasterBias:))];
            }
        }
        else if (exposure.type == kCASCCDExposureFlatType){
            if (exposure == self.exposuresController.project.masterFlat){
                [menu addItem:createMenuItem(@"Clear Master Flat",nil,@selector(setAsMasterFlat:))];
            }
            else {
                [menu addItem:createMenuItem(@"Set as Master Flat",exposure,@selector(setAsMasterFlat:))];
            }
        }
        else {
            menu = nil;
        }
    }
    
    if (!menu && [exposures count] > 0){
        menu = [[NSMenu alloc] initWithTitle:@""];
        NSArray* processors = [CASBatchProcessor batchProcessorsForExposures:exposures];
        for (NSDictionary* processor in processors){
            if (processor[@"id"]){
                [menu addItem:createMenuItem(processor[@"name"],processor[@"id"],@selector(batchItemSelected:))];
            }
            else if (processor[@"category"]){
                NSMenuItem* item = createMenuItem(processor[@"category"],nil,nil);
                NSMenu* submenu = [[NSMenu alloc] initWithTitle:processor[@"category"]];
                for (NSDictionary* action in processor[@"actions"]){
                    [submenu addItem:createMenuItem(action[@"name"],action[@"id"],@selector(batchItemSelected:))];
                }
                [item setSubmenu:submenu];
                [menu addItem:item];
            }
        }
    }
    
    // separator, then commands that involve more UI e.g. divide flat where we have to select a flat
    
    // reveal in finder command
    if (menu){
        if ([[menu itemArray] count]){
            [menu addItem:[NSMenuItem separatorItem]];
        }
        [menu addItem:createMenuItem(@"Reveal In Finder",exposures,@selector(revealInFinder:))];
    }
    
    if ([[menu itemArray] count]){
        [NSMenu popUpContextMenu:menu withEvent:event forView:self.browserView];
    }
}

- (BOOL) imageBrowser:(IKImageBrowserView *) aBrowser moveItemsAtIndexes: (NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex
{
    // called when items are dropped
    return NO;
}

- (NSUInteger) imageBrowser:(IKImageBrowserView *) aBrowser writeItemsAtIndexes:(NSIndexSet *) itemIndexes toPasteboard:(NSPasteboard *)pasteboard;
{
    [pasteboard clearContents];
    
    NSArray* exposures = [self.exposures objectsAtIndexes:itemIndexes];
    if (![pasteboard writeObjects:exposures]){
        return 0;
    }
    
    return [exposures count];
}

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser
{
    _suppressKeyValueObserving = YES; // yuk
    @try {
        [self.exposuresController setSelectedObjects:[self.exposures objectsAtIndexes:[aBrowser selectionIndexes]]];
    }
    @finally {
        _suppressKeyValueObserving = NO;
    }
}

#pragma mark - Actions

// space key looks at current selection
// if 1, selects that exposure
// if > 1 sets all those exposures in a multi-exposure view and allows flipping between them

- (IBAction)zoomSliderDidChange:(id)sender
{
    [self.browserView setZoomValue:[sender floatValue]];
    [self.browserView setNeedsDisplay:YES];
}

- (IBAction)groupByMenuChanged:(NSPopUpButton*)sender
{
    switch (sender.selectedItem.tag) {
        case 0:
            self.groupKeyPath = nil;
            break;
        case 1:
            self.groupKeyPath = @"groupInfoDeviceName";
            break;
        case 2:
            self.groupKeyPath = @"groupInfoDateDay";
            break;
        case 3:
            self.groupKeyPath = @"groupInfoDeviceType";
            break;
    }
}

 - (void)refresh
{
    if (![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refresh];
        });
    }
    else {
        ++self.version;
        [self updateForCurrentGroupKey];
        [self.browserView reloadData];
    }
}

- (void)_runBatchProcessor:(CASBatchProcessor*)processor withExposures:(NSArray*)exposures
{
    // ask processor to check compatibility ... e.g. all the same size, sensor, etc
    
    // set the project to give it a sense of context
    processor.project = self.exposuresController.project;

    // start progress hud
    CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
    [progress beginSheetModalForWindow:self.browserView.window];
    [progress configureWithRange:NSMakeRange(0, [exposures count]) label:NSLocalizedString(@"Processing...", @"Batch processing label")];
    
    // run the processor in the background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // listen for exposure added notifications and add them to the controller
        id proxy = [[NSNotificationCenter defaultCenter] addObserverForName:kCASCCDExposureLibraryExposureAddedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            id exposure = [note userInfo][@"exposure"];
            if (exposure && ![self.exposures containsObject:exposure]){
                [self.exposuresController addObject:exposure];
            }
        }];

        NSEnumerator* enumerator = [exposures objectEnumerator];
        
        [processor processWithProvider:^(CASCCDExposure **exposure, NSDictionary **info) {
            
            *exposure = [enumerator nextObject];
            
            // update progress bar
            dispatch_async(dispatch_get_main_queue(), ^{
                progress.progressBar.doubleValue++;
            });
            
        } completion:^(NSError *error, CASCCDExposure *result) {
            
            // run completion on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (error){
                    [NSApp presentError:error];
                }
                
                // dismiss progress sheet/hud
                [progress endSheetWithCode:NSOKButton];
                
                // lazy...
                [self refresh];
                
                // remove observer
                [[NSNotificationCenter defaultCenter] removeObserver:proxy];;
            });
        }];
    });
}

- (IBAction)batchItemSelected:(NSMenuItem*)sender
{
    NSArray* exposures = [self.exposuresController selectedObjects];
    if ([exposures count] < 1){
        return;
    }
    
    CASBatchProcessor* processor = [CASBatchProcessor batchProcessorsWithIdentifier:[sender representedObject]];
    if (!processor){
        return;
    }
    
    [self _runBatchProcessor:processor withExposures:exposures];
}

- (void)setAsMasterDark:(NSMenuItem*)sender
{
    self.exposuresController.project.masterDark = sender.representedObject;
    [self.browserView reloadData]; // ideally should have a per-item reload method
}

- (void)setAsMasterBias:(NSMenuItem*)sender
{
    self.exposuresController.project.masterBias = sender.representedObject;
    [self.browserView reloadData]; // ideally should have a per-item reload method
}

- (void)setAsMasterFlat:(NSMenuItem*)sender
{
    self.exposuresController.project.masterFlat = sender.representedObject;
    [self.browserView reloadData]; // ideally should have a per-item reload method
}

- (IBAction)quickStack:(id)sender
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (IBAction)combineSum:(id)sender
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (IBAction)combineAverage:(id)sender
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)quickLookPreviewItems:(id)sender
{
    NSArray* selectedObjects = [self.exposuresController selectedObjects];
    if ([selectedObjects count] && [self.exposureDelegate respondsToSelector:@selector(focusOnExposures:)]){
        [self.exposureDelegate focusOnExposures:[self exposuresControllerWithExposures:selectedObjects]];
    }
}

- (IBAction)revealInFinder:(id)sender
{
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:[[self.exposuresController selectedObjects] valueForKeyPath:@"io.url"]];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if (!_suppressKeyValueObserving){
            
            if ([@"selectedObjects" isEqualToString:keyPath]){
                
                // todo; scroll to selection

                // prevent -imageBrowserSelectionDidChange: from being called during the selection change
                NSAssert(self.browserView.delegate == self, @"You need to update the KVO code in the browser view controller");
                self.browserView.delegate = nil;
                [self.browserView setSelectionIndexes:self.exposuresController.selectionIndexes byExtendingSelection:NO];
                self.browserView.delegate = self;
            }
            else if ([@"arrangedObjects" isEqualToString:keyPath]){
                [self refresh];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
