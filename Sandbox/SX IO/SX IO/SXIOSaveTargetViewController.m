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
@property (weak) IBOutlet NSPathControl *pathControl;
@end

@implementation SXIOSaveTargetViewController {
    CASCCDExposureIO* _io;
}

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

- (NSString*)keyWithCameraID:(NSString*)key
{
    return self.cameraController ? [key stringByAppendingString:self.cameraController.camera.uniqueID] : key;
}

- (NSString*)saveImagesKey
{
    return [self keyWithCameraID:kSaveImagesDefaultsKey];
}

- (NSString*)saveFolderKey
{
    return [self keyWithCameraID:kSaveFolderURLDefaultsKey];
}

- (NSString*)saveFolderBookmarkKey
{
    return [self keyWithCameraID:kSaveFolderBookmarkDefaultsKey];
}

- (NSString*)prefixKey
{
    return [self keyWithCameraID:kSavedImagePrefixDefaultsKey];
}

- (NSString*)sequenceKey
{
    return [self keyWithCameraID:kSavedImageSequenceDefaultsKey];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    if ([@[@"saveImages",@"saveFolderURL",@"saveImagesPrefix",@"saveImagesSequence"] containsObject:key]){
        return [NSSet setWithObject:@"cameraController"];
    }
    return [super keyPathsForValuesAffectingValueForKey:key];
}

- (BOOL)saveImages
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:[self saveImagesKey]];
}

- (void)setSaveImages:(BOOL)saveImages
{
    [[NSUserDefaults standardUserDefaults] setBool:saveImages forKey:[self saveImagesKey]];
}

- (NSURL*)saveFolderURL
{
    NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:[self saveFolderKey]];
    if (!s){
        s = [@"~/Pictures" stringByExpandingTildeInPath];
    }
    return [NSURL fileURLWithPath:s];
}

- (void)setSaveFolderURL:(NSURL*)url
{
    // todo; create a test fits file to confirm this path works with the cfitsio library
    
    [[NSUserDefaults standardUserDefaults] setValue:[url path] forKey:[self saveFolderKey]];
    
    NSError* error;
    NSData* bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    if (bookmark){
        [[NSUserDefaults standardUserDefaults] setObject:bookmark forKey:[self saveFolderBookmarkKey]];
    }
    else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self saveFolderBookmarkKey]];
    }
}

- (NSData*) saveFolderBookmark
{
    return [[NSUserDefaults standardUserDefaults] dataForKey:[self saveFolderBookmarkKey]];
}

- (void)setSaveFolderBookmark:(NSData *)saveFolderBookmark
{
    if (saveFolderBookmark){
        [[NSUserDefaults standardUserDefaults] setObject:saveFolderBookmark forKey:[self saveFolderBookmarkKey]];
    }
    else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self saveFolderBookmarkKey]];
    }
}

- (NSString*)saveImagesPrefix
{
    NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:[self prefixKey]];
    if (!s && self.cameraController){
        s = self.cameraController.camera.deviceName;
    }
    return s ? [self sanitizePrefix:s] : nil;
}

- (void)setSaveImagesPrefix:(NSString*)prefix
{
    [[NSUserDefaults standardUserDefaults] setObject:prefix forKey:[self prefixKey]];
}

- (NSInteger)saveImagesSequence
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:[self sequenceKey]];
}

- (void)setSaveImagesSequence:(NSInteger)saveImagesSequence
{
    [[NSUserDefaults standardUserDefaults] setInteger:saveImagesSequence forKey:[self sequenceKey]];
}

- (IBAction)resetSequence:(id)sender
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self sequenceKey]];
}

- (NSString*)sanitizePrefix:(NSString*)prefix
{
    NSString* sanitized = prefix;
    if (!_io){
        _io = [CASCCDExposureIO exposureIOWithPath:[[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"]];
        NSAssert(_io, @"No IO class for current value of SXIODefaultExposureFileType default");
    }
    if (_io){
        sanitized = [[_io class] sanitizeExposurePath:prefix];
    }
    return sanitized;
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField* textField = [obj object];
    NSString* stringValue = textField.stringValue;
    NSString* sanitized = [self sanitizePrefix:textField.stringValue];
    if (![sanitized isEqualToString:stringValue]){
        textField.stringValue = sanitized;
    }
}

- (void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
    openPanel.canCreateDirectories = YES;
}

@end
