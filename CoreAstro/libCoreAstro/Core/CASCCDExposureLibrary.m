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
#import "CASUtilities.h"

@interface CASCCDExposureLibrary ()
@end

@interface CASCCDExposureLibraryProject ()<NSCoding>
@property (nonatomic,copy) NSString* uuid;
@end

@implementation CASCCDExposureLibraryProject

- (id)init
{
    self = [super init];
    if (self) {
        self.uuid = CASCreateUUID();
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        id uuid = [coder decodeObjectForKey:@"uuid"];
        if (uuid){
            self.uuid = uuid;
        }
        self.name = [coder decodeObjectForKey:@"name"];
        self.masterBias = [[CASCCDExposureLibrary sharedLibrary] exposureWithUUID:[coder decodeObjectForKey:@"masterBias"]];
        self.masterDark = [[CASCCDExposureLibrary sharedLibrary] exposureWithUUID:[coder decodeObjectForKey:@"masterDark"]];
        self.masterFlat = [[CASCCDExposureLibrary sharedLibrary] exposureWithUUID:[coder decodeObjectForKey:@"masterFlat"]];
        self.parent = [coder decodeObjectForKey:@"parent"];
        self.children = [coder decodeObjectForKey:@"children"];
        NSArray* uuids = [coder decodeObjectForKey:@"exposures"];
        if ([uuids count]){
            __block NSMutableArray* exposures = [NSMutableArray arrayWithCapacity:[uuids count]];
            [uuids enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                id exposure = [[CASCCDExposureLibrary sharedLibrary] exposureWithUUID:obj];
                if (exposure){
                    [exposures addObject:exposure];
                }
                else {
                    NSLog(@"Exposure with uuid %@ not found",obj);
                }
            }];
            self.exposures = exposures;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.uuid forKey:@"uuid"];
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.masterBias.uuid forKey:@"masterBias"];
    [aCoder encodeObject:self.masterDark.uuid forKey:@"masterDark"];
    [aCoder encodeObject:self.masterFlat.uuid forKey:@"masterFlat"];
    [aCoder encodeObject:[self.exposures valueForKeyPath:@"uuid"] forKey:@"exposures"];
    [aCoder encodeConditionalObject:self.parent forKey:@"parent"];
    [aCoder encodeConditionalObject:self.children forKey:@"children"];
}

- (void)setName:(NSString *)name
{
    if (name != _name){
        _name = [name copy];
        [[CASCCDExposureLibrary sharedLibrary] projectWasUpdated:self];
    }
}

- (void)addExposures:(NSSet *)objects
{
    if (![objects count]){
        return;
    }
    if (!_exposures){
        _exposures = [NSMutableArray arrayWithCapacity:[objects count]]; // just make this a set ? display order is a presentation responsibility
    }
    NSMutableSet* ms = [NSMutableSet setWithSet:objects];
    [ms minusSet:[NSSet setWithArray:self.exposures]];
    if ([ms count]){
        [[self mutableArrayValueForKey:@"exposures"] addObjectsFromArray:[ms allObjects]];
        [[CASCCDExposureLibrary sharedLibrary] projectWasUpdated:self];
    }
    else {
        NSLog(@"Exposures with UUIDs %@ already in project with UUIDs %@",[objects valueForKeyPath:@"meta.uuid"],[_exposures valueForKeyPath:@"meta.uuid"]);
    }
}

- (void)removeExposures:(NSSet *)objects
{
    if ([[NSSet setWithArray:self.exposures] intersectsSet:objects]){ // slow ?
        [[self mutableArrayValueForKey:@"exposures"] removeObjectsInArray:[objects allObjects]];
        [[CASCCDExposureLibrary sharedLibrary] projectWasUpdated:self];
    }
}

- (void)setMasterDark:(CASCCDExposure *)masterDark
{
    if (masterDark != _masterDark){
        _masterDark = masterDark;
        [[CASCCDExposureLibrary sharedLibrary] projectWasUpdated:self];
    }
}

- (void)setMasterBias:(CASCCDExposure *)masterBias
{
    if (masterBias != _masterBias){
        _masterBias = masterBias;
        [[CASCCDExposureLibrary sharedLibrary] projectWasUpdated:self];
    }
}

- (void)setMasterFlat:(CASCCDExposure *)masterFlat
{
    if (masterFlat != _masterFlat){
        _masterFlat = masterFlat;
        [[CASCCDExposureLibrary sharedLibrary] projectWasUpdated:self];
    }
}

@end

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

static NSString* const kCASCCDExposureLibraryLocationKey = @"CASCCDExposureLibraryLocation";

@interface CASCCDExposureLibrary ()
@end

@implementation CASCCDExposureLibrary {
    NSMutableArray* _projects;
    NSMutableArray* _exposures;
}

@synthesize exposures = _exposures;

NSString* kCASCCDExposureLibraryExposureAddedNotification = @"kCASCCDExposureLibraryExposureAddedNotification";

+ (CASCCDExposureLibrary*)sharedLibrary
{
    static CASCCDExposureLibrary* _library = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _library = [[CASCCDExposureLibrary alloc] init];
    });
    return _library;
}

+ (void)initialize
{
    if (self == [CASCCDExposureLibrary class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{kCASCCDExposureLibraryLocationKey:[[NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"CoreAstro"]}];
    }
}

- (NSString*)root
{
    return [[[NSUserDefaults standardUserDefaults] stringForKey:kCASCCDExposureLibraryLocationKey] stringByResolvingSymlinksInPath];
}

- (NSString*)projectsIndexPath
{
    return [[[self root] stringByAppendingPathComponent:@"Projects"] stringByAppendingPathComponent:@"index.plist"];
}

- (NSDictionary*)readProjectsArchive
{
//    NSError* error = nil;
    NSString* path = [self projectsIndexPath];
    id propList = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    if ([propList isKindOfClass:[NSArray class]]){
        return @{@"projects":propList};
    }
    if ([propList isKindOfClass:[NSDictionary class]]){
        return propList;
    }
    return nil;
}

- (void)writeProjectsArchive
{
    NSError* error = nil;
    if (_projects){
        NSString* path = [self projectsIndexPath];
        [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
        NSMutableDictionary* archive = [NSMutableDictionary dictionaryWithCapacity:2];
        if (_projects){
            archive[@"projects"] = _projects;
        }
        if (_currentProject){
            archive[@"currentProject"] = _currentProject;
        }
        [NSKeyedArchiver archiveRootObject:archive toFile:path];
    }
    else {
//        [[NSFileManager defaultManager] removeItemAtPath:[self projectsIndexPath] error:nil];
    }
}

- (NSArray*)projects
{
    @synchronized(self){
        if (!_projects){
            NSDictionary* archive = [self readProjectsArchive];
            _projects = archive[@"projects"];
            _currentProject = archive[@"currentProject"];
        }
    }
    
    return [_projects copy];
}

- (void)setCurrentProject:(CASCCDExposureLibraryProject *)currentProject
{
    if (currentProject != _currentProject){
        _currentProject = currentProject;
        [self writeProjectsArchive];
    }
}

- (NSArray*)exposures
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _exposures = [[NSMutableArray alloc] initWithCapacity:100];
        
        NSURL* pixelsURL;
        NSDirectoryEnumerator* e = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:[self root]]
                                                        includingPropertiesForKeys:@[]
                                                                           options:NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles
                                                                      errorHandler:nil];
        while ((pixelsURL = [e nextObject]) != nil) {
            CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[pixelsURL path]];
            if (io){
                CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
                exposure.io = io;
                [_exposures addObject:exposure];
            }
        }
        
        [self addObserver:self forKeyPath:@"exposures" options:NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
    });
    
    return [_exposures copy];
}

- (void)setExposures:(NSArray*)exposures
{
    _exposures = [exposures mutableCopy];
}

- (void)removeExposureFromAllProjects:(NSArray *)exposures
{
    // todo; this probably won't scale well...
    [_projects makeObjectsPerformSelector:@selector(removeExposures:) withObject:[NSSet setWithArray:exposures]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if ([keyPath isEqualToString:@"exposures"]){
            
            switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                case NSKeyValueChangeRemoval:{
                    NSArray* exposures = [change objectForKey:NSKeyValueChangeOldKey];
                    if (![exposures isKindOfClass:[NSArray class]]){
                        exposures = @[exposures];
                    }
                    [self removeExposureFromAllProjects:exposures];
                }
                    break;
                default:
                    break;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)addExposureAndPostNotification:(CASCCDExposure*)exposure toProject:(CASCCDExposureLibraryProject*)project
{
    void (^add)() = ^(){
        [[self mutableArrayValueForKey:@"exposures"] addObject:exposure];
        [project addExposures:[NSSet setWithObject:exposure]];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCASCCDExposureLibraryExposureAddedNotification object:self userInfo:@{@"exposure":exposure}];
    };
    if ([NSThread isMainThread]){
        add();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), add);
    }
}

- (void)addExposure:(CASCCDExposure*)exposure save:(BOOL)save block:(void (^)(NSError*,NSURL*))block
{
    [self addExposure:exposure toProject:nil save:save block:block];
}

- (void)addExposure:(CASCCDExposure*)exposure toProject:(CASCCDExposureLibraryProject*)project save:(BOOL)save block:(void (^)(NSError*,NSURL*))block;
{
    void (^complete)() = ^(NSError* error,NSURL* url){
        if (!error){
            [self addExposureAndPostNotification:exposure toProject:project ? project : [CASCCDExposureLibrary sharedLibrary].currentProject];
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
            
            // have to ensure that the pixels haven't been reset before this happens...
            NSString* name = [CASCCDExposureIO defaultFilenameForExposure:exposure];
            if ([exposure.meta objectForKey:@"history"]){
                name = [@"Processed" stringByAppendingPathComponent:name];
            }
            NSString* path = [[[self root] stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"caExposure"];
            
            // create the exposure io object
            exposure.io = [CASCCDExposureIO exposureIOWithPath:path];
            
            // write the exposure
            NSError* error = nil;
            if ([exposure.io writeExposure:exposure writePixels:YES error:&error]){
                
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
            }
            
            complete(error,[NSURL fileURLWithPath:path]);
        }
    }
}

- (void)removeExposure:(CASCCDExposure*)exposure
{
    if (!exposure){
        return;
    }
    
    // delete the physical file
    [exposure deleteExposure];

    // remove from all projects
    [self removeExposureFromAllProjects:@[exposure]];

    // from from the main exposures array
    [[self mutableArrayValueForKey:@"exposures"] removeObject:exposure];
}

- (CASCCDExposure*)exposureWithUUID:(NSString*)uuid
{
    if (!uuid){
        return nil;
    }
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"uuid == %@",uuid];
    
    NSArray* exposures = [self.exposures filteredArrayUsingPredicate:predicate];
    if ([exposures count] > 1){
        NSLog(@"*** Multiple exposure with uuid = %@",uuid);
    }
    
    return [exposures lastObject];
}

- (void)addProjects:(NSSet *)objects
{
    if (![objects count]){
        return;
    }
    if (!_projects){
        _projects = [NSMutableArray arrayWithCapacity:10];
    }
    [[self mutableArrayValueForKey:@"projects"] addObjectsFromArray:[objects allObjects]];
    [self writeProjectsArchive];
}

- (void)removeProjects:(NSSet *)objects
{
    [[self mutableArrayValueForKey:@"projects"] removeObjectsInArray:[objects allObjects]];
    [self writeProjectsArchive];
}

- (void)moveProject:(CASCCDExposureLibraryProject*)project toIndex:(NSInteger)index
{
    if (!project || index < 0 || index > [_projects count]){
        return;
    }
            
    [_projects removeObject:project];
    
    const NSInteger kvIndex = MIN(index,[_projects count]);
    
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:kvIndex] forKey:@"projects"];
    if (index > [_projects count]){
        [_projects addObject:project];
    }
    else {
        [_projects insertObjects:[NSArray arrayWithObject:project] atIndexes:[NSIndexSet indexSetWithIndex:index]];
    }
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:kvIndex] forKey:@"projects"];
    
    [self writeProjectsArchive];
}

- (CASCCDExposureLibraryProject*)projecteWithUUID:(NSString*)uuid
{
    if (!uuid){
        return nil;
    }
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"uuid == %@",uuid];
    
    NSArray* projects = [self.projects filteredArrayUsingPredicate:predicate];
    if ([projects count] > 1){
        NSLog(@"*** Multiple projects with uuid = %@",uuid);
    }
    
    return [projects lastObject];
}

- (void)projectWasUpdated:(CASCCDExposureLibraryProject*)project
{
    [self writeProjectsArchive];
}

@end
