//
//  SXIOBookmarkWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 09/09/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOBookmarkWindowController.h"

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

@end

@interface SXIOBookmarkWindowController ()
@end

@implementation SXIOBookmarkWindowController {
    NSMutableArray* _bookmarks;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    if (self.solution){
        [[self mutableArrayValueForKey:@"bookmarks"] addObject:[SXIOEditingBookmark bookmarkWithName:@"Untitled" solution:self.solution]];
    }
}

- (NSMutableArray*)bookmarks
{
    if (!_bookmarks){
        NSArray* storedBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:@"SXIOBookmarks"];
        _bookmarks = [NSMutableArray arrayWithCapacity:storedBookmarks.count ?: 10];
        for (NSDictionary* bookmark in storedBookmarks){
            CASPlateSolveSolution* solution = [CASPlateSolveSolution solutionWithData:bookmark[@"solutionData"]];
            if (solution){
                [_bookmarks addObject:[SXIOEditingBookmark bookmarkWithName:bookmark[@"name"] solution:solution]];
            }
        }
    }
    return _bookmarks;
}

- (IBAction)ok:(id)sender {
    
    NSMutableArray* bookmarks = [NSMutableArray arrayWithCapacity:_bookmarks.count];
    for (SXIOEditingBookmark* bookmark in _bookmarks){
        NSData* solutionData = bookmark.solution.solutionData;
        if (solutionData){
            [bookmarks addObject:@{@"name":bookmark.name,@"solutionData":solutionData}];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:bookmarks forKey:@"SXIOBookmarks"];
    
    [self endSheetWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender {
    [self endSheetWithCode:NSCancelButton];
}

@end
