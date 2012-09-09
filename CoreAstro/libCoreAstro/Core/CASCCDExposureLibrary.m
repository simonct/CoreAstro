//
//  CASCCDExposureLibrary.m
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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

#import "CASCCDExposureLibrary.h"
#import "CASCCDExposureIO.h"

@interface CASCCDExposure (CASCCDExposureLibrary)
@end

@implementation CASCCDExposure (CASCCDExposureLibrary)
- (NSInteger)exposureInMS
{
    return self.params.ms;
}
- (NSInteger)binningAsInteger
{
    return self.params.bin.width << 8 | self.params.bin.height;
}
@end

@interface CASCCDExposureLibrary ()
//@property (nonatomic,strong) NSMutableArray* exposures;
@end

@implementation CASCCDExposureLibrary

@synthesize exposures = _exposures;

+ (CASCCDExposureLibrary*)sharedLibrary
{
    static CASCCDExposureLibrary* _library = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _library = [[CASCCDExposureLibrary alloc] init];
    });
    return _library;
}

- (NSString*)root
{
    return [[NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"CoreAstro"];
}

- (NSArray*)exposures
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _exposures = [[NSMutableArray alloc] initWithCapacity:100];
        
        NSString* pixelsPath;
        NSString* root = [self root];
        NSDirectoryEnumerator* e = [[NSFileManager defaultManager] enumeratorAtPath:[self root]];
        while ((pixelsPath = [e nextObject]) != nil) {
            CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[root stringByAppendingPathComponent:pixelsPath]];
            if (io){
                CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
                exposure.io = io;
                [_exposures addObject:exposure];
            }
        }
    });
    
    return [_exposures copy];
}

- (void)setExposures:(NSArray*)exposures
{
    _exposures = [exposures mutableCopy];
}

- (void)addExposure:(CASCCDExposure*)exposure save:(BOOL)save block:(void (^)(NSError*,NSURL*))block
{
    void (^complete)() = ^(NSError* error,NSURL* url){
        if (!error){
            [_exposures addObject:exposure];
        }
        if (block){
            block(error,url);
        }
    };
    
    if (exposure){
        
        if (!save){
            complete(nil,nil);
        }
        else {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                // have to ensure that the pixels haven't been reset before this happens...
                NSString* path = [[self root] stringByAppendingPathComponent:exposure.deviceID];
                
                NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"LLL-d-Y";
                path = [path stringByAppendingPathComponent:[formatter stringFromDate:exposure.date]];
                formatter.dateFormat = @"H-m-ss.SS";
                path = [path stringByAppendingPathComponent:[formatter stringFromDate:exposure.date]];
                path = [path stringByAppendingPathExtension:@"caExposure"];
                
                exposure.io = [CASCCDExposureIO exposureIOWithPath:path];
                
                NSError* error = nil;
                [exposure.io writeExposure:exposure writePixels:YES error:&error];
                
                // make sure all the files are read-only (what about the wrapper ?)
                NSString* subPath = nil;
                NSDirectoryEnumerator* dir = [[NSFileManager defaultManager] enumeratorAtPath:path];
                while ((subPath = [dir nextObject]) != nil) {
                    subPath = [path stringByAppendingPathComponent:subPath];
                    BOOL isDirectory;
                    if ([[NSFileManager defaultManager] fileExistsAtPath:subPath isDirectory:&isDirectory]){
                        if (!isDirectory){
                            NSDictionary* attrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:0444] forKey:NSFilePosixPermissions]; // todo; get the current perms and modify rather than set this absolute value
                            if (attrs){
                                [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:subPath error:nil];
                            }
                        }
                    }
                }
                
                complete(error,[NSURL fileURLWithPath:path]);
            });
        }
    }
}

- (NSArray*)darksMatchingExposure:(CASCCDExposure*)exposure
{
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"type == %d AND deviceID == %@ AND exposureInMS == %d AND binningAsInteger == %d",1,exposure.deviceID,exposure.params.ms,exposure.binningAsInteger]; // range of exposures ?
    NSLog(@"predicate: %@",predicate);
    
    NSArray* darks = [self.exposures filteredArrayUsingPredicate:predicate];
    NSLog(@"darks: %@",darks);

    return darks;
}

- (NSArray*)flatsMatchingExposure:(CASCCDExposure*)exposure
{
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"type == %d AND deviceID == %@ AND binningAsInteger == %d",3,exposure.deviceID,exposure.binningAsInteger];
    NSLog(@"predicate: %@",predicate);
    
    NSArray* flats = [self.exposures filteredArrayUsingPredicate:predicate];
    NSLog(@"flats: %@",flats);
    
    return flats;
}

@end
