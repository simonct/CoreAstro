//
//  SXIOSaveTargetViewController.m
//  CoreAstro
//
//  Created by Simon Taylor on 21/7/13.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "SXIOSaveTargetViewController.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOSaveTargetViewController ()
@end

@implementation SXIOSaveTargetViewController

NSString* const kSaveImagesDefaultsKey = @"SaveImages";
NSString* const kSaveFolderURLDefaultsKey = @"SaveFolderURL";
NSString* const kSaveFolderBookmarkDefaultsKey = @"SaveFolderBookmark";
NSString* const kSavedImagePrefixDefaultsKey = @"SavedImagePrefix";
NSString* const kSavedImageSequenceDefaultsKey = @"SavedImageSequence";

+ (void)initialize
{
    if (self == [SXIOSaveTargetViewController class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
                                      kSaveFolderURLDefaultsKey:[@"~/Pictures" stringByExpandingTildeInPath],
                                      kSavedImageSequenceDefaultsKey:@(1)
         }];
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self){
    }
    return self;
}

- (NSURL*)saveFolderURL
{
    NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:kSaveFolderURLDefaultsKey];
    return s ? [NSURL fileURLWithPath:s] : nil;
}

- (void)setSaveFolderURL:(NSURL*)url
{
    [[NSUserDefaults standardUserDefaults] setValue:[url path] forKey:kSaveFolderURLDefaultsKey];
}

- (IBAction)resetSequence:(id)sender
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedImageSequenceDefaultsKey];
}

@end
