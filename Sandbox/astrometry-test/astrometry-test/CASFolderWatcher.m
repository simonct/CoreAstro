//
//  CASFolderWatcher.m
//  astrometry-test
//
//  Created by Simon Taylor on 10/20/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASFolderWatcher.h"

static NSString* kCASFolderWatcherFSUpdate = @"CASFolderWatcherFSUpdate";

@interface CASFolderWatcher ()
@property (nonatomic,copy) void (^callback)(NSArray*);
@property (nonatomic,copy) NSString* path;
@end

@implementation CASFolderWatcher {
    FSEventStreamRef _eventsRef;
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
            [added addObject:path];
        }
        if (flags&kFSEventStreamEventFlagItemRemoved){
            [removed addObject:path];
        }
        if (flags&kFSEventStreamEventFlagItemRenamed){
            [modified addObject:path];
        }
        ++i;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASFolderWatcherFSUpdate object:nil userInfo:@{@"added":added,@"removed":removed,@"modified":modified}];
}

- (void)dealloc
{
    [self stopFSEvents];
}

- (void)stopFSEvents
{
    if (_eventsRef){
        FSEventStreamStop(_eventsRef);
        FSEventStreamInvalidate(_eventsRef);
        FSEventStreamRelease(_eventsRef);
        _eventsRef = NULL;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCASFolderWatcherFSUpdate object:nil];
}

- (void)registerForFSEvents
{
    [self stopFSEvents];
    
    if (self.path){
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processFSUpdate:) name:kCASFolderWatcherFSUpdate object:nil];

        _eventsRef = FSEventStreamCreate(NULL, CASFSEventStreamCallback, nil, (__bridge CFArrayRef)@[self.path], kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagFileEvents|kFSEventStreamCreateFlagUseCFTypes);
        
        if (_eventsRef){
            FSEventStreamScheduleWithRunLoop(_eventsRef,CFRunLoopGetMain(),kCFRunLoopCommonModes);
            FSEventStreamStart(_eventsRef);
        }
    }
}

- (void)processFSUpdate:(NSNotification*)note
{
    NSMutableSet* added = note.userInfo[@"added"];
    NSMutableSet* modified = note.userInfo[@"modified"];
    [added unionSet:modified];
    if ([added count] && self.callback){
        self.callback([added allObjects]);
    }
}

- (void)setPath:(NSString *)path
{
    if (path != _path){
        _path = path;
        [self registerForFSEvents];
    }
}

+ (instancetype)watcherWithPath:(NSString*)path callback:(void (^)(NSArray*))callback
{
    CASFolderWatcher* result = [[CASFolderWatcher alloc] init];
    result.callback = callback;
    result.path = path;
    return result;
}

@end
