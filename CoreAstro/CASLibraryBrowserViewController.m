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

@interface CASCCDExposure (CASLibraryBrowserViewController)<NSPasteboardWriting>
@end

@implementation CASCCDExposure (CASLibraryBrowserViewController)

- (id)groupInfoDeviceName
{
    return @{
        @"name":self.displayDeviceName,
        @"value":self.displayDeviceName,
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
        _image = self.exposure.thumbnail;
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
    return self.exposure.displayDeviceName;
}

- (NSString *) imageSubtitle
{
    return self.exposure.displayDate;
}

+ (CASCCDExposureWrapper*)wrapperWithExposure:(CASCCDExposure*)exposure
{
    CASCCDExposureWrapper* wrapper = [[CASCCDExposureWrapper alloc] init];
    wrapper.exposure = exposure;
    return wrapper;
}

@end

@interface CASLibraryBrowserGroupInfo
@property (nonatomic,copy) NSString* name;
@property (nonatomic,assign) NSRange range;
@end
@implementation CASLibraryBrowserGroupInfo
@end

@interface CASLibraryBrowserViewController ()
@property (nonatomic,strong) NSArray* exposures;
@property (nonatomic,strong) NSArray* groups;
@property (nonatomic,strong) NSMutableDictionary* wrappers;
@property (nonatomic,copy) NSString* groupKeyPath;
@end

@implementation CASLibraryBrowserViewController {
    NSArray* _groups;
    NSArray* _exposures;
    NSArray* _defaultExposuresArray;
    BOOL _inImageBrowserSelectionDidChange;
}

#pragma mark - View Controller

- (void)loadView
{
    [super loadView];
    [self.browserView setDataSource:self];
    [self.browserView setDelegate:self];
    [self.browserView setCellsStyleMask:IKCellsStyleTitled|IKCellsStyleSubtitled|IKCellsStyleShadowed];
    [self.browserView setZoomValue:0.5];
    [self.browserView setDraggingDestinationDelegate:self];
    [self.browserView setAllowsDroppingOnItems:YES];
    [self.browserView registerForDraggedTypes:@[(id)kUTTypeUTF8PlainText]];
    [self.browserView setValue:[NSColor lightGrayColor] forKey:IKImageBrowserBackgroundColorKey];
}

#pragma mark - Exposures

- (NSArray*)defaultExposuresArray
{
    // todo; cache this, clearing when appropriate - or possibly move into the exposures controller
    NSMutableArray* defaultExposuresArray = [NSMutableArray arrayWithCapacity:[[self.exposuresController arrangedObjects] count]];
    for (CASCCDExposure* exp in [self.exposuresController arrangedObjects]){
        if (exp.uuid){
            [defaultExposuresArray addObject:exp];
        }
        else {
            NSLog(@"No uuid: %@",exp); // I'm using the uuid as the image browser key - could use the url instead ?
        }
    }
    return [defaultExposuresArray copy];
}

- (void)setExposuresController:(CASExposuresController *)exposuresController
{
    if (exposuresController != _exposuresController){
        
        [_exposuresController removeObserver:self forKeyPath:@"selectedObjects" context:(__bridge void *)(self)];
        [_exposuresController removeObserver:self forKeyPath:@"arrangedObjects" context:(__bridge void *)(self)];
        
        _exposuresController = exposuresController;
        
        [_exposuresController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
        [_exposuresController addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
        
        _exposures = nil;
        [self.browserView reloadData];
    }
}

- (NSArray*)exposures
{
    if (!_exposures){
        _exposures = [self defaultExposuresArray];
    }
    return _exposures;
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
    NSArray* defaultExposuresArray = self.defaultExposuresArray;
    if (![_groupKeyPath length]){
        self.groups = nil;
        self.exposures = defaultExposuresArray;
    }
    else {
        NSSet* groupInfos = [NSSet setWithArray:[defaultExposuresArray valueForKeyPath:_groupKeyPath]];
        if (![groupInfos count]){
            self.groups = nil;
            self.exposures = defaultExposuresArray;
        }
        else {
            // todo; set sort descriptors on exposuresController rather than doing it on a copy
            self.groups = [[groupInfos allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"value" ascending:NO]]];
            self.exposures = [defaultExposuresArray sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:self.groups[0][@"sortKey"] ascending:NO],[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
        }
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

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index
{
    if ([self.exposureDelegate respondsToSelector:@selector(focusOnExposure:)]){
        
        if (self.exposuresController.project.masterBias || self.exposuresController.project.masterFlat){
            
            const NSTimeInterval t = CASTimeBlock(^{
                
                CASCCDReductionProcessor* reduction = [[CASCCDReductionProcessor alloc] init];
                reduction.bias = self.exposuresController.project.masterBias;
                reduction.flat = self.exposuresController.project.masterFlat;
                [reduction processWithExposures:[NSArray arrayWithObject:[self.exposures objectAtIndex:index]] completion:^(NSError *error, CASCCDExposure *final) {
                    
                    if (!error){
                        [self.exposureDelegate focusOnExposure:final];
                    }
                }];
            });
            
            NSLog(@"t=%fs",t);
        }
        else {
            [self.exposureDelegate focusOnExposure:[self.exposures objectAtIndex:index]];
        }
        
        // so, how do I get back to the full browser view ?
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
    }
    else if ([exposures count] > 1) {
        
        menu = [[NSMenu alloc] initWithTitle:@""];
        NSArray* processors = [CASBatchProcessor batchProcessorsForExposures:exposures];
        for (NSDictionary* processor in processors){
            [menu addItem:createMenuItem(processor[@"name"],processor[@"id"],@selector(batchItemSelected:))];
        }
    }
    
    // separator, then commands that involve more UI e.g. divide flat where we have to select a flat
    
    // reveal in finder command
    
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
    _inImageBrowserSelectionDidChange = YES; // yuk
    @try {
        [self.exposuresController setSelectedObjects:[self.exposures objectsAtIndexes:[aBrowser selectionIndexes]]];
    }
    @finally {
        _inImageBrowserSelectionDidChange = NO;
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

- (void)_refresh
{
    if (![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _refresh];
        });
    }
    else {
        [self updateForCurrentGroupKey];
        [self.browserView reloadData];
    }
}

- (void)_runBatchProcessor:(CASBatchProcessor*)processor withExposures:(NSArray*)exposures
{
    // ask processor to check compatibility ... e.g. all the same size, sensor, etc
    
    // start progress hud
    CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
    [progress beginSheetModalForWindow:self.browserView.window];
    [progress configureWithRange:NSMakeRange(0, [exposures count]) label:NSLocalizedString(@"Processing...", @"Batch processing label")];
    
    // run the processor in the background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // listen for exposure added notifications and add them to the controller
        id proxy = [[NSNotificationCenter defaultCenter] addObserverForName:kCASCCDExposureLibraryExposureAddedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            id exposure = [note userInfo][@"exposure"];
            if (exposure && ![[self.exposuresController arrangedObjects] containsObject:exposure]){
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
                [self _refresh];
                
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
    // update
}

- (void)setAsMasterBias:(NSMenuItem*)sender
{
    self.exposuresController.project.masterBias = sender.representedObject;
    // update
}

- (void)setAsMasterFlat:(NSMenuItem*)sender
{
    self.exposuresController.project.masterFlat = sender.representedObject;
    // update
}

- (void)divideExposures:(NSArray*)exposures byFlat:(CASCCDExposure*)flat
{
    CASFlatDividerProcessor* processor = [[CASFlatDividerProcessor alloc] init];
    processor.flat = flat;
    [self _runBatchProcessor:processor withExposures:exposures];
}

- (void)subtractExposure:(CASCCDExposure*)base from:(NSArray*)exposures
{
    CASSubtractProcessor* processor = [[CASSubtractProcessor alloc] init];
    processor.base = base;
    [self _runBatchProcessor:processor withExposures:exposures];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        if ([@"selectedObjects" isEqualToString:keyPath]){
            if (!_inImageBrowserSelectionDidChange){
                [self.browserView setSelectionIndexes:self.exposuresController.selectionIndexes byExtendingSelection:NO];
                // scroll to selection
            }
        }
        else if ([@"arrangedObjects" isEqualToString:keyPath]){
            [self _refresh];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Drag & Drop

- (NSInteger)_indexOfItemAtPoint:(NSPoint)point
{
    return [self.browserView indexOfItemAtPoint:[self.browserView convertPoint:point fromView:nil]];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self _indexOfItemAtPoint:[sender draggingLocation]] == NSNotFound ? NSDragOperationNone : NSDragOperationCopy; // NSDragOperationLink ?
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    const NSInteger index = [self _indexOfItemAtPoint:[sender draggingLocation]];
    if (index == NSNotFound){
        return NO;
    }
    
    CASCCDExposureWrapper* targetWrapper = (CASCCDExposureWrapper*)[self imageBrowser:self.browserView itemAtIndex:index];
    
    NSMutableArray* sourceExposures = [NSMutableArray arrayWithCapacity:[[[sender draggingPasteboard] pasteboardItems] count]];
    for (NSPasteboardItem* item in [[sender draggingPasteboard] pasteboardItems]){
        NSString* uuid = [item propertyListForType:(id)kUTTypeUTF8PlainText];
        if ([uuid isKindOfClass:[NSString class]]){
            NSArray* exposures = [self.exposures filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"uuid == %@",uuid]];
            if ([exposures count]){
                [sourceExposures addObject:[exposures lastObject]];
            }
        }
    }
    
    if ([sourceExposures count]){
        
        // popover with buttons for available operations + cancel
        
        // dragging exposures onto a flat implements flat division
        if (targetWrapper.exposure.type == kCASCCDExposureFlatType){
            dispatch_async(dispatch_get_current_queue(), ^{
                [self divideExposures:sourceExposures byFlat:targetWrapper.exposure];
            });
            return YES;
        }
        if (targetWrapper.exposure.type == kCASCCDExposureBiasType || targetWrapper.exposure.type == kCASCCDExposureDarkType){
            dispatch_async(dispatch_get_current_queue(), ^{
                [self subtractExposure:targetWrapper.exposure from:sourceExposures];
            });
            return YES;
        }

    }
    
    return NO;
}

@end
