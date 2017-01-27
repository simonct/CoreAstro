//
//  SXIOBookmarkWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 09/09/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOBookmarkWindowController.h"
#import "SXIOAppDelegate.h"

#if defined(SXIO)
#import "SX_IO-Swift.h"
#else
#import "CCD_IO-Swift.h"
#endif

@interface SXIOEditingBookmark : NSObject
@property (copy) NSString* name;
@property (copy) NSString* ra;
@property (copy) NSString* dec;
@property (copy) NSNumber* originalRA;
@property (copy) NSNumber* originalDec;
@property (strong) CASPlateSolveSolution* solution;
@end

@implementation SXIOEditingBookmark

- (BOOL)validateValue:(inout __autoreleasing id *)ioValue forKey:(NSString *)inKey error:(out NSError *__autoreleasing *)outError
{
    if ([inKey isEqualToString:@"name"]){
        NSString* name = *ioValue;
        if (name.length < 1){
            if (outError){
                *outError = [NSError errorWithDomain:@"SXIOEditingBookmark" code:1 userInfo:@{NSLocalizedFailureReasonErrorKey:@"You cannot have an empty bookmark name"}];
            }
            return NO;
        }
    }
    return YES;
}

+ (instancetype)bookmarkWithName:(NSString*)name solution:(CASPlateSolveSolution*)solution
{
    SXIOEditingBookmark* editingBookmark = [SXIOEditingBookmark new];
    editingBookmark.name = name;
    editingBookmark.ra = solution.displayCentreRA;
    editingBookmark.dec = solution.displayCentreDec;
    editingBookmark.solution = solution;
    return editingBookmark;
}

+ (instancetype)bookmarkWithName:(NSString*)name ra:(double)ra dec:(double)dec
{
    SXIOEditingBookmark* editingBookmark = [SXIOEditingBookmark new];
    editingBookmark.name = name;
    editingBookmark.ra = [CASLX200Commands highPrecisionRA:ra]; // todo; want a more natual presention format
    editingBookmark.dec = [CASLX200Commands highPrecisionDec:dec];
    editingBookmark.originalRA = @(ra);
    editingBookmark.originalDec = @(dec);
    return editingBookmark;
}

@end

@interface SXIOBookmarkWindowController ()
@property (weak) IBOutlet NSTableView *bookmarksTableView;
@property (strong) IBOutlet NSArrayController *bookmarksArrayController;
@property (nonatomic,copy) NSString* searchString;
@end

@implementation SXIOBookmarkWindowController

+ (SXIOBookmarkWindowController*)sharedController
{
    static SXIOBookmarkWindowController* _shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [SXIOBookmarkWindowController createWindowController];
    });
    return _shared;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSButton* closeButton = [self.window standardWindowButton:NSWindowCloseButton];
    [closeButton setTarget:self];
    [closeButton setAction:@selector(closeWindow:)];

    // no longer here - in solution setter?
    if (!self.solution){
        self.bookmarksArrayController.selectedObjects = @[];
    }
    else{
        SXIOEditingBookmark* bookmark = [SXIOEditingBookmark bookmarkWithName:@"Untitled" solution:self.solution];
        NSMutableArray* bookmarks = [self mutableArrayValueForKey:@"bookmarks"];
        [bookmarks addObject:bookmark];
        self.bookmarksArrayController.selectedObjects = @[bookmark];
        [self.bookmarksTableView editColumn:0 row:bookmarks.count - 1 withEvent:nil select:YES];
    }
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self]; // todo; check already in it ?
#endif
}

- (void)closeWindow:sender
{
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromWindowMenu:self];
#endif
    
    [self close];
}

- (NSMutableArray*)bookmarks
{
    NSArray* storedBookmarks = self.sharedBookmarks.bookmarks;
    NSMutableArray* bookmarks = [NSMutableArray arrayWithCapacity:storedBookmarks.count ?: 10];
    for (NSDictionary* bookmark in storedBookmarks){
        CASPlateSolveSolution* solution = [CASPlateSolveSolution solutionWithDictionary:bookmark[CASBookmarks.solutionDictionaryKey]];
        if (solution){
            [bookmarks addObject:[SXIOEditingBookmark bookmarkWithName:bookmark[CASBookmarks.nameKey] solution:solution]];
        }
        else {
            [bookmarks addObject:[SXIOEditingBookmark bookmarkWithName:bookmark[CASBookmarks.nameKey] ra:[bookmark[CASBookmarks.centreRaKey] doubleValue] dec:[bookmark[CASBookmarks.centreDecKey] doubleValue]]];
        }
    }
    return bookmarks;
}

- (CASBookmarks*)sharedBookmarks
{
    return CASBookmarks.sharedInstance;
}

+ (NSSet*)keyPathsForValuesAffectingBookmarks
{
    return [NSSet setWithObject:@"sharedBookmarks.bookmarks"];
}

- (void)setSearchString:(NSString *)searchString
{
    if (searchString != _searchString){
        _searchString = [searchString copy];
        if (!_searchString){
            self.bookmarksArrayController.filterPredicate = nil;
        }
        else {
            self.bookmarksArrayController.filterPredicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@",_searchString];
        }
    }
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    self.bookmarksArrayController.sortDescriptors = tableView.sortDescriptors;
}

- (IBAction)ok:(id)sender
{
    NSMutableArray* existingBookmarks = self.bookmarks;
    NSMutableArray* bookmarks = [NSMutableArray arrayWithCapacity:existingBookmarks.count];
    for (SXIOEditingBookmark* bookmark in existingBookmarks){
        NSDictionary* solutionDictionary = bookmark.solution.solutionDictionary;
        if (solutionDictionary){
            [bookmarks addObject:@{CASBookmarks.nameKey:bookmark.name,CASBookmarks.solutionDictionaryKey:solutionDictionary}];
        }
        else {
            [bookmarks addObject:@{CASBookmarks.nameKey:bookmark.name,
                                   CASBookmarks.centreRaKey:@(bookmark.originalRA.doubleValue),
                                   CASBookmarks.centreDecKey:@(bookmark.originalDec.doubleValue)}];
        }
    }
    
    self.sharedBookmarks.bookmarks = bookmarks;
    
    [self endSheetWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
    [self endSheetWithCode:NSCancelButton];
}

@end
