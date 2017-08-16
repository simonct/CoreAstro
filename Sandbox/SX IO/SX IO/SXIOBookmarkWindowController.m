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
@property (weak) IBOutlet NSTextField *lookupField;
@property (nonatomic,copy) NSString* lookupString;
@property (weak) IBOutlet NSProgressIndicator *lookupSpinner;
@property (strong) CASObjectLookup* lookup;
@end

@implementation SXIOBookmarkWindowController {
    NSMutableArray* _bookmarks;
}

static void* context;

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

    self.bookmarksArrayController.selectedObjects = @[];
    
    [CASBookmarks.sharedInstance addObserver:self forKeyPath:@"bookmarks" options:NSKeyValueObservingOptionInitial context:&context];
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] addWindowToMenus:self]; // todo; check already in it ?
#endif
}

- (void)closeWindow:sender
{
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromMenus:self];
#endif
    
    [self ok:nil];
    
    [self close];
}

- (void)addSolutionBookmark:(CASPlateSolveSolution*)solution
{
    if (!solution){
        return;
    }
    
    // todo; check for duplicates ?
    
    SXIOEditingBookmark* bookmark = [SXIOEditingBookmark bookmarkWithName:@"Untitled" solution:solution];
    NSMutableArray* bookmarks = [self mutableArrayValueForKey:@"bookmarks"];
    [bookmarks addObject:bookmark];
    self.bookmarksArrayController.selectedObjects = @[bookmark];
    [self.bookmarksTableView editColumn:0 row:bookmarks.count - 1 withEvent:nil select:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)aContext
{
    if (aContext == &context) {
        [self refreshBookmarks];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)refreshBookmarks
{
    NSArray* storedBookmarks = self.sharedBookmarks.bookmarks;
    _bookmarks = [NSMutableArray arrayWithCapacity:storedBookmarks.count ?: 10];
    for (NSDictionary* bookmark in storedBookmarks){
        CASPlateSolveSolution* solution = [CASPlateSolveSolution solutionWithDictionary:bookmark[CASBookmarks.solutionDictionaryKey]];
        if (solution){
            [_bookmarks addObject:[SXIOEditingBookmark bookmarkWithName:bookmark[CASBookmarks.nameKey] solution:solution]];
        }
        else {
            [_bookmarks addObject:[SXIOEditingBookmark bookmarkWithName:bookmark[CASBookmarks.nameKey] ra:[bookmark[CASBookmarks.centreRaKey] doubleValue] dec:[bookmark[CASBookmarks.centreDecKey] doubleValue]]];
        }
    }
}

- (NSMutableArray*)bookmarks
{
    if (!_bookmarks){
        [self refreshBookmarks];
    }
    return _bookmarks;
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
    // todo; only want to save changes if there have actually been edits
    NSMutableArray* bookmarks = [NSMutableArray arrayWithCapacity:_bookmarks.count];
    for (SXIOEditingBookmark* bookmark in _bookmarks){
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

- (IBAction)lookupTapped:(id)sender
{
    if (![self.lookupString length] || self.lookup){
        NSBeep();
        return;
    }
    
    [self.lookupSpinner startAnimation:nil];
    
    self.lookup = [CASObjectLookup new];
    [self.lookup lookupObject:self.lookupString withCompletion:^(CASObjectLookupResult* result) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.lookup = nil;
            
            [self.lookupSpinner stopAnimation:nil];
            
            if (!result.foundIt){
                [[NSAlert alertWithMessageText:@"Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Target couldn't be found"] runModal];
            }
            else {
                NSLog(@"Found %@",result.object);
                //[self willChangeValueForKey:@"bookmarks"];
                [CASBookmarks.sharedInstance addBookmark:self.lookupString ra:result.ra dec:result.dec];
                //[self didChangeValueForKey:@"bookmarks"];
            }
        });
    }];
}

@end
