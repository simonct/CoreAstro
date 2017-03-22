//
//  CASObjectLookup.m
//  CoreAstro
//
//  Created by Simon Taylor on 2/7/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "CASObjectLookup.h"
#import "CASLX200Commands.h"

@implementation CASObjectLookup

- (void)lookupObject:(NSString*)name withCompletion:(void(^)(BOOL success,NSString*objectName,double ra,double dec))completion
{
    NSParameterAssert(name);
    NSParameterAssert(completion);
    
    NSString* script = [NSString stringWithFormat:@"format object \"%%IDLIST(1) : %%COO(d;A D)\"\nset epoch JNOW\nset limit 1\nquery id %@\nformat display\n",name];
    script = [script stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://simbad.u-strasbg.fr/simbad/sim-script?submit=submit+script&script=%@",script]];
    
    NSURL* cacheDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL* cacheLocation = [[cacheDirectory URLByAppendingPathComponent:[name lowercaseString]] URLByAppendingPathExtension:@"txt"];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
        NSString* responseString;
        
        if (connectionError){
            NSLog(@"connectionError: %@",connectionError);
            @synchronized ([self class]) {
                responseString = [NSString stringWithContentsOfURL:cacheLocation encoding:NSUTF8StringEncoding error:nil];
            }
        }
        else {
            responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        
        BOOL foundIt = NO;
        NSString* object;
        double ra = 0, dec = 0;

        if (responseString && ![responseString containsString:@"::error"]){
            
            NSArray* responseLines = [responseString componentsSeparatedByString:@"\n"];
            
            for (NSString* line in [responseLines reverseObjectEnumerator]){
                
                NSScanner* scanner = [NSScanner scannerWithString:line];
                
                if ([scanner scanUpToString:@":" intoString:&object]){
                    
                    NSMutableCharacterSet* cs = [NSMutableCharacterSet decimalDigitCharacterSet];
                    [cs addCharactersInString:@"+-"];
                    
                    [scanner scanUpToCharactersFromSet:cs intoString:nil];
                    if ([scanner scanDouble:&ra]){
                        [scanner scanUpToCharactersFromSet:cs intoString:nil];
                        foundIt = [scanner scanDouble:&dec];
                        if (foundIt){
                            @synchronized ([self class]) {
                                [responseString writeToURL:cacheLocation atomically:YES encoding:NSUTF8StringEncoding error:nil];
                            }
                        }
                    }
                    
                    break;
                }
            };
        }

        completion(foundIt,object,ra,dec);
    }];
}

@end
