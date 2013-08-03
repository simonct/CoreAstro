//
//  CASUpdateCheck.m
//  SX IO
//
//  Created by Simon Taylor on 8/3/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASUpdateCheck.h"

@implementation CASUpdateCheck

+ (void)initialize
{
    if (self == [CASUpdateCheck class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
         @"CASUpdateCheckRootURL":@"https://raw.github.com/simonct/CoreAstro/master/Updates/", // downloads and upgrade metadata in the same folder ?
         @"CASUpdateCheckUpgradeRootURL":@"https://github.com/simonct/CoreAstro/releases/download/",
         }];
    }
}

+ (instancetype)sharedUpdateCheck
{
    static CASUpdateCheck* instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    
    return instance;
}

- (void)checkForUpdate
{
    // check the last time we checked and gate it to once a day
    const NSTimeInterval checkInterval = 24*60*60; // make a default
    NSDate* lastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:@"CASUpdateCheckLastCheckDate"];
    if ([NSDate timeIntervalSinceReferenceDate] - [lastCheck timeIntervalSinceReferenceDate] < checkInterval){
        
        NSLog(@"Update check: insufficient time passed since last check");
    }
    else{
        
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"CASUpdateCheckLastCheckDate"];
        
        NSString* root = [[NSUserDefaults standardUserDefaults] stringForKey:@"CASUpdateCheckRootURL"];
        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.plist",root,[[NSBundle mainBundle] bundleIdentifier]]];
        NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
        
        NSLog(@"Update check: checking file at %@",url);

        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error) {
            
            if (error){
                NSLog(@"Update check: error during update check: %@",error);
            }
            else {
                
                NSError* error;
                NSDictionary* update = [NSPropertyListSerialization propertyListWithData:data options:0 format:0 error:&error];
                if (error){
                    NSLog(@"Update check: error parsing update check: %@",error);
                }
                else {
                    
                    if (![update isKindOfClass:[NSDictionary class]]){
                        NSLog(@"Update check: downloaded update wasn't a dictionary: %@",update);
                    }
                    else {
                        
                        NSString* latest = [update valueForKey:@"latest"];
                        if ([latest compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] options:NSNumericSearch] == NSOrderedDescending){
                            
                            // look for an absolute url
                            NSURL* url = [NSURL URLWithString:[update valueForKey:@"url"]];
                            if (!url){
                                
                                // no url specified so construct the download url from the root and provided relative path
                                NSString* path = [update valueForKey:@"path"];
                                if ([path length]){
                                    
                                    // e.g. https://github.com/simonct/CoreAstro/releases/download/sx-io_v1.0.1/SX.IO.app.zip
                                    url = [NSURL URLWithString:[[[NSUserDefaults standardUserDefaults] objectForKey:@"CASUpdateCheckUpgradeRootURL"] stringByAppendingFormat:@"%@",path]];
                                }
                            }
                            if (url){
                                
                                NSAlert* alert = [NSAlert alertWithMessageText:@"Update Available"
                                                                 defaultButton:@"Open in Browser"
                                                               alternateButton:@"Cancel"
                                                                   otherButton:nil
                                                     informativeTextWithFormat:@"An update for %@ is available. Click Open in Browser to download it using your default web browser.",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
                                if ([alert runModal] == NSOKButton){
                                    [[NSWorkspace sharedWorkspace] openURL:url];
                                }
                            }
                        }
                        else {
                            NSLog(@"Update check: running latest app");
                        }
                        NSString* root = [update valueForKey:@"root"];
                        if ([root length]){
                            
                            NSURL* url = [NSURL URLWithString:root];
                            if (url){
                                
                                // check host...
                                
                                [[NSUserDefaults standardUserDefaults] setObject:root forKey:@"CASUpdateCheckRootURL"];
                            }
                        }
                    }
                }
            }
        }];
    }
}

@end
