//
//  SXIOBookmarkWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 09/09/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOBookmarkWindowController.h"
#if defined(SXIO)
#import "SX_IO-Swift.h"
#else
#import "CCD_IO-Swift.h"
#endif

@interface SXIOEditingBookmark : NSObject
@property (copy) NSString* name;
@property (copy) NSString* ra;
@property (copy) NSString* dec;
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
    return editingBookmark;
}

@end

@interface SXIOBookmarkWindowController ()
@property (weak) IBOutlet NSTableView *bookmarksTableView;
@property (strong) IBOutlet NSArrayController *bookmarksArrayController;
@property (nonatomic,copy) NSString* searchString;
@end

@implementation SXIOBookmarkWindowController {
    NSMutableArray* _bookmarks;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
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

- (NSMutableArray*)bookmarks
{
    if (!_bookmarks){
        NSArray* storedBookmarks = CASBookmarks.sharedInstance.bookmarks;
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
    return _bookmarks;
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
    NSMutableArray* bookmarks = [NSMutableArray arrayWithCapacity:_bookmarks.count];
    for (SXIOEditingBookmark* bookmark in _bookmarks){
        NSDictionary* solutionDictionary = bookmark.solution.solutionDictionary;
        if (solutionDictionary){
            [bookmarks addObject:@{CASBookmarks.nameKey:bookmark.name,CASBookmarks.solutionDictionaryKey:solutionDictionary}];
        }
        else {
            [bookmarks addObject:@{CASBookmarks.nameKey:bookmark.name,
                                   CASBookmarks.centreRaKey:@([CASLX200Commands fromRAString:bookmark.ra asDegrees:NO]),
                                   CASBookmarks.centreDecKey:@([CASLX200Commands fromDecString:bookmark.dec])}];
        }
    }
    
    CASBookmarks.sharedInstance.bookmarks = bookmarks;
    
    [self endSheetWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
    [self endSheetWithCode:NSCancelButton];
}

@end
