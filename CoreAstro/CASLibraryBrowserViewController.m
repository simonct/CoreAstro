//
//  CASLibraryBrowserViewController.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASLibraryBrowserViewController.h"
#import "CASLibraryBrowserView.h"

#import <Quartz/Quartz.h>
#import <CoreAstro/CoreAstro.h>

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

@interface CASLibraryBrowserViewController ()
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
    [self.browserView setDataSource:self];
    [self.browserView setDelegate:self];
    [self.browserView setCellsStyleMask:IKCellsStyleTitled|IKCellsStyleSubtitled|IKCellsStyleShadowed];
    [self.browserView setZoomValue:0.5];
    [self.browserView reloadData];
}

- (NSArray*)defaultExposuresArray
{
    return [[[CASCCDExposureLibrary sharedLibrary] exposures] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
}

- (NSArray*)exposures
{
    if (!_exposures){
        NSArray* exposures = [self defaultExposuresArray];
        NSMutableArray* exps = [NSMutableArray arrayWithCapacity:[exposures count]];
        for (CASCCDExposure* exp in exposures){
            if (exp.uuid){
                [exps addObject:exp];
            }
            else {
                NSLog(@"No uuid: %@",exp);
            }
        }
        _exposures = [exps copy];
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

- (void)setGroupKeyPath:(NSString *)groupKeyPath
{
    if (_groupKeyPath != groupKeyPath){
        _groupKeyPath = [groupKeyPath copy];
        if (![_groupKeyPath length]){
            self.groups = nil;
            self.exposures = [self defaultExposuresArray];
        }
        else {
            NSSet* groupNames = [NSSet setWithArray:[self.exposures valueForKeyPath:_groupKeyPath]];
            self.groups = [groupNames allObjects];
            self.exposures = [self.exposures sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:_groupKeyPath ascending:YES],[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
        }
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
    NSString* groupName = self.groups[index];
    NSArray* groupItems = [self.exposures filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@",self.groupKeyPath,groupName]];
    NSRange groupRange = NSMakeRange([self.exposures indexOfObject:groupItems[0]], [groupItems count]);
    return [NSDictionary dictionaryWithObjectsAndKeys:
            groupName,IKImageBrowserGroupTitleKey,
            [NSValue valueWithRange:groupRange],IKImageBrowserGroupRangeKey,
            [NSNumber numberWithInt:IKGroupDisclosureStyle],IKImageBrowserGroupStyleKey,
            nil];
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index
{
    NSLog(@"cellWasDoubleClickedAtIndex: %lu",index);
    
    // enter editing mode
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasRightClickedAtIndex:(NSUInteger) index withEvent:(NSEvent *) event
{
    NSLog(@"cellWasRightClickedAtIndex: %lu",index);
    
    // contextual menu
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
            self.groupKeyPath = @"displayDeviceName";
            break;
        case 2:
            self.groupKeyPath = @"displayDateDay";
            break;
        case 3:
            self.groupKeyPath = @"displayType";
            break;
    }
}

// todo: group support e.g. group by device, group by date, etc

@end
