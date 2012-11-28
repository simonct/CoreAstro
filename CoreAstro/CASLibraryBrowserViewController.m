//
//  CASLibraryBrowserViewController.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASLibraryBrowserViewController.h"
#import "CASLibraryBrowserView.h"
#import "CASExposuresController.h"

#import <Quartz/Quartz.h>
#import <CoreAstro/CoreAstro.h>

@interface CASCCDExposure (CASLibraryBrowserViewController)
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
            NSLog(@"No thumbnail for %@",self.exposure.date); // make one from the full res image
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

@interface CASLibraryBrowserViewController ()<CASLibraryBrowserViewDelegate>
@property (nonatomic,strong) NSArray* exposures;
@property (nonatomic,strong) NSArray* groups;
@property (nonatomic,strong) NSMutableDictionary* wrappers;
@property (nonatomic,copy) NSString* groupKeyPath;
@end

@implementation CASLibraryBrowserViewController {
    NSArray* _groups;
    NSArray* _exposures;
}

- (void)loadView
{
    [super loadView];
    self.browserView.libraryDelegate = self;
    [self.browserView setDataSource:self];
    [self.browserView setDelegate:self];
    [self.browserView setCellsStyleMask:IKCellsStyleTitled|IKCellsStyleSubtitled|IKCellsStyleShadowed];
    [self.browserView setZoomValue:0.5];
    [self.browserView reloadData];
}

- (NSArray*)defaultExposuresArray
{
    NSMutableArray* defaultExposuresArray = [NSMutableArray arrayWithCapacity:[[self.exposuresController arrangedObjects] count]];
    for (CASCCDExposure* exp in [self.exposuresController arrangedObjects]){
        if (exp.uuid){
            [defaultExposuresArray addObject:exp];
        }
        else {
            NSLog(@"No uuid: %@",exp);
        }
    }
    return [defaultExposuresArray copy];
}

- (void)setExposuresController:(CASExposuresController *)exposuresController
{
    if (exposuresController != _exposuresController){
        [_exposuresController removeObserver:self forKeyPath:@"selectedObjects"];
        [_exposuresController removeObserver:self forKeyPath:@"arrangedObjects"];
        _exposuresController = exposuresController;
        [_exposuresController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
        [_exposuresController addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
    }
}

- (NSArray*)exposures
{
    if (!_exposures){
        _exposures = [self defaultExposuresArray];
    }
    return _exposures;
}

- (NSArray*)groups
{
    if (!_groups){
        _groups = [NSMutableArray arrayWithCapacity:10];
    }
    return _groups;
}

- (void)updateForCurrentGroupKey
{
    if (![_groupKeyPath length]){
        self.groups = nil;
        self.exposures = [self defaultExposuresArray];
    }
    else {
        NSSet* groupInfos = [NSSet setWithArray:[self.exposures valueForKeyPath:_groupKeyPath]];
        if (![groupInfos count]){
            self.groups = nil;
            self.exposures = [self defaultExposuresArray];
        }
        else {
            self.groups = [[groupInfos allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"value" ascending:NO]]];
            self.exposures = [self.defaultExposuresArray sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:self.groups[0][@"sortKey"] ascending:NO],[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
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

/*!
 @method imageBrowser:groupAtIndex:
 @abstract Returns the group at index 'index'
 @discussion A group is defined by a dictionay. Keys for this dictionary are defined below.
 */
- (NSDictionary *) imageBrowser:(IKImageBrowserView *) aBrowser groupAtIndex:(NSUInteger) index
{
    NSDictionary* groupInfo = self.groups[index];
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"%K == %@",groupInfo[@"sortKey"],groupInfo[@"value"]];
    NSArray* groupItems = [self.exposures filteredArrayUsingPredicate:predicate];
    NSRange groupRange = NSMakeRange([self.exposures indexOfObject:groupItems[0]],[groupItems count]);
    return [NSDictionary dictionaryWithObjectsAndKeys:
            groupInfo[@"name"],IKImageBrowserGroupTitleKey,
            [NSValue valueWithRange:groupRange],IKImageBrowserGroupRangeKey,
            [NSNumber numberWithInt:IKGroupDisclosureStyle],IKImageBrowserGroupStyleKey,
            nil];
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index
{
    if ([self.exposureDelegate respondsToSelector:@selector(focusOnExposure:)]){
        [self.exposureDelegate focusOnExposure:[self.exposures objectAtIndex:index]];
        // so, how do I get back to the full browser view ?
    }
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasRightClickedAtIndex:(NSUInteger) index withEvent:(NSEvent *) event
{
    NSLog(@"cellWasRightClickedAtIndex: %lu",index);
    
    // contextual menu
}

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser
{
    [self.exposuresController setSelectionIndexes:[aBrowser selectionIndexes]];
}

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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        if ([@"selectedObjects" isEqualToString:keyPath]){
            [self.browserView setSelectionIndexes:self.exposuresController.selectionIndexes byExtendingSelection:NO];
            // scroll to selection
        }
        else if ([@"arrangedObjects" isEqualToString:keyPath]){
            [self updateForCurrentGroupKey];
            [self.browserView reloadData];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Library view delegate

- (void)deleteSelectedExposures
{
    if ([[self.exposuresController selectedObjects] count]){
        [self.exposuresController promptToDeleteCurrentSelectionWithWindow:self.browserView.window];
    }
}

@end
