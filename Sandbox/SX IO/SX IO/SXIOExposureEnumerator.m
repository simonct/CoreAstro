//
//  SXIOExposureEnumerator.m
//  SX IO
//
//  Created by Simon Taylor on 9/25/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOExposureEnumerator.h"

@implementation SXIOExposureEnumerator {
    FSEventStreamRef _eventsRef;
    NSUInteger _currentExposureIndex;
    NSMutableArray* _allExposures;
}

- (void)dealloc
{
    if (_eventsRef){
        FSEventStreamStop(_eventsRef);
        FSEventStreamInvalidate(_eventsRef);
        FSEventStreamRelease(_eventsRef);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SXIOExposureEnumeratorFSUpdate" object:nil];
}

- (void)setUrl:(NSURL *)url
{
    if (_url != url){
        _url = url;
        [self refreshContents];
    }
}

- (NSArray *)allObjects
{
    return [_allExposures copy];
}

- (NSArray*) allExposures
{
    return [_allExposures copy];
}

- (id)nextObject
{
    return [self nextExposure];
}

- (CASCCDExposure*) nextExposure
{
    if ([_allExposures count] > 0 && _currentExposureIndex != NSNotFound && _currentExposureIndex < [_allExposures count] - 1){
        return [_allExposures objectAtIndex:++_currentExposureIndex];
    }
    return nil;
}

- (CASCCDExposure*) previousExposure
{
    if (_currentExposureIndex != NSNotFound && _currentExposureIndex > 0){
        return [_allExposures objectAtIndex:--_currentExposureIndex];
    }
    return nil;
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
    return _allExposures[idx];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    NSLog(@"countByEnumeratingWithState: %ld",len);
    
    if(state->state == 0){
        static void* v;
        state->mutationsPtr = (unsigned long *)&v;
        state->extra[0] = 0;
        state->state = 1;
    }
    state->itemsPtr = buffer;
    
    const NSUInteger count = MIN(len,[_allExposures count] - state->extra[0]);
    if (count){
        [_allExposures getObjects:buffer range:NSMakeRange(state->extra[0], count)];
        state->extra[0] += count;
    }
    return count;
}

- (CASCCDExposure*)exposureAtIndex:(NSInteger)index
{
    NSURL* url = self[index];
    CASCCDExposure* exp;
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[url path]];
    if (io){
        exp = [[CASCCDExposure alloc] init];
        if (![io readExposure:exp readPixels:NO error:nil]){
            exp = nil;
        }
    }
    return exp;
}

static void CASFSEventStreamCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[])
{
    NSMutableSet* added = [NSMutableSet setWithCapacity:[(__bridge NSArray*)eventPaths count]];
    NSMutableSet* removed = [NSMutableSet setWithCapacity:[(__bridge NSArray*)eventPaths count]];
    NSMutableSet* modified = [NSMutableSet setWithCapacity:[(__bridge NSArray*)eventPaths count]];
    
    NSInteger i = 0;
    for (NSString* path in (__bridge NSArray*)eventPaths){
        FSEventStreamEventFlags flags = eventFlags[i];
        if (flags&kFSEventStreamEventFlagItemCreated){
            [added addObject:[NSURL fileURLWithPath:path]];
        }
        if (flags&kFSEventStreamEventFlagItemRemoved){
            [removed addObject:[NSURL fileURLWithPath:path]];
        }
        if (flags&kFSEventStreamEventFlagItemRenamed){
            [modified addObject:[NSURL fileURLWithPath:path]];
        }
        ++i;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SXIOExposureEnumeratorFSUpdate" object:nil userInfo:@{
                                                                                                                                @"added":added,
                                                                                                                                @"removed":removed,
                                                                                                                                @"modified":modified
                                                                                                                                }];
}

- (void)processFSUpdate:(NSNotification*)note
{
    // todo; check for rescan and then refresh contents
    // todo; move this logic into the fsevents callback
    
    NSMutableSet* added = note.userInfo[@"added"];
    NSMutableSet* removed = note.userInfo[@"removed"];
    NSMutableSet* modified = note.userInfo[@"modified"];
    
    for (NSString* path in [modified copy]){
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]){
            [added addObject:path];
            [removed removeObject:path];
        }
        else {
            [removed addObject:path];
            [added removeObject:path];
        }
        [modified removeObject:path];
    }
    
    for (NSURL* url in [_allExposures copy]){
        if ([removed containsObject:[url path]]){
            [[self mutableArrayValueForKey:@"allExposures"] removeObject:url];
        }
    }
    
    for (NSURL* url in added){
        if ([_allExposures containsObject:url]){
            NSLog(@"%@ already exists",url);
        }
        else if ([CASCCDExposureIO exposureIOWithPath:[url path]]) {
            [[self mutableArrayValueForKey:@"allExposures"] addObject:url];
        }
    }
}

- (void)registerForFSEvents
{
    if (_eventsRef){
        FSEventStreamStop(_eventsRef);
        FSEventStreamInvalidate(_eventsRef);
        FSEventStreamRelease(_eventsRef);
        _eventsRef = NULL;
    }
    
    if (self.url){
        
        _eventsRef = FSEventStreamCreate(NULL, CASFSEventStreamCallback, nil, (__bridge CFArrayRef)@[[self.url path]], kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagFileEvents|kFSEventStreamCreateFlagUseCFTypes);
        
        if (_eventsRef){
            FSEventStreamScheduleWithRunLoop(_eventsRef,CFRunLoopGetMain(),kCFRunLoopCommonModes);
            FSEventStreamStart(_eventsRef);
        }
    }
}

- (void)refreshContents
{
    [[self mutableArrayValueForKey:@"allExposures"] removeAllObjects];
    _currentExposureIndex = NSNotFound;
    
    if (self.url){
        
        // file system events
        
        NSDirectoryEnumerator* e = [[NSFileManager defaultManager] enumeratorAtURL:self.url
                                                        includingPropertiesForKeys:nil
                                                                           options:NSDirectoryEnumerationSkipsSubdirectoryDescendants|NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles
                                                                      errorHandler:nil];
        
        NSMutableArray* exposures = [NSMutableArray arrayWithCapacity:100];
        
        NSURL* imageURL;
        while ((imageURL = [e nextObject]) != nil) {
            CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[imageURL path]]; // inefficient
            if (io){
                [exposures addObject:imageURL]; // or exposures ??
            }
        }
        
        if ([exposures count]){
            _currentExposureIndex = 0;
            [[self mutableArrayValueForKey:@"allExposures"] addObjectsFromArray:exposures];
        }
    }
}

+ (instancetype)enumeratorWithURL:(NSURL*)url
{
    if (!url){
        return nil;
    }
    SXIOExposureEnumerator* e = [[SXIOExposureEnumerator alloc] init];
    e.url = url;
    return e;
}

@end
