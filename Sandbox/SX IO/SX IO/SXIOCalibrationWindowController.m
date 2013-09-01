//
//  SXIOCalibrationWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 8/31/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOCalibrationWindowController.h"
#import <QuickLook/QuickLook.h>
#import <CoreAstro/CoreAstro.h>

@interface SXIOCalibrationView : NSView
@property (nonatomic) BOOL selected;
@end

@implementation SXIOCalibrationView

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.selected){
        [[NSColor selectedControlColor] set];
        NSRectFill(self.bounds);
    }
}

@end

@interface SXIOCalibrationItem : NSCollectionViewItem
@end

@implementation SXIOCalibrationItem

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    SXIOCalibrationView* view = (SXIOCalibrationView*)self.view;
    [view setSelected:self.selected];
    [view setNeedsDisplay:YES];
}

@end

@interface SXIOCalibrationModel : NSObject
@property (nonatomic,copy) NSURL* url;
@property (nonatomic,copy) NSString* name;
@property (nonatomic,strong) NSImage* image;
@property (nonatomic,strong) CASCCDExposure* exposure;
@end

@implementation SXIOCalibrationModel

- (NSString*)name
{
    return [[NSFileManager defaultManager] displayNameAtPath:[self.url path]];
}

- (NSImage*)image
{
    if (!_image && self.url){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            CGImageRef cgImage = QLThumbnailImageCreate(NULL,(__bridge CFURLRef)(self.url),CGSizeMake(512, 512), (__bridge CFDictionaryRef)(@{(id)kQLThumbnailOptionIconModeKey:@YES}));
            if (!cgImage){
                NSLog(@"No QL thumbnail for %@",self.url);
            }
            else{
                NSImage* nsImage = [[NSImage alloc] initWithCGImage:cgImage size:NSMakeSize(CGImageGetWidth(cgImage),CGImageGetHeight(cgImage))];
                if (nsImage){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.image = nsImage;
                    });
                }
            }
        });
    }
    return _image;
}

@end

@interface SXIOCalibrationWindowController ()
@property (nonatomic,strong) NSMutableArray* images;
@property (weak) IBOutlet NSCollectionView *collectionView;
@property (strong) IBOutlet NSArrayController *arrayController;
@property (weak) IBOutlet NSButton *calibrateButton;
@end

@implementation SXIOCalibrationWindowController {
    FSEventStreamRef _eventsRef;
}

static void* kvoContext;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.images = [NSMutableArray arrayWithCapacity:10];
    }
    
    return self;
}

- (void)dealloc
{
    [self.collectionView removeObserver:self forKeyPath:@"selectionIndexes" context:&kvoContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SXIOCalibrationWindowControllerFSUpdate" object:nil];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.collectionView addObserver:self forKeyPath:@"selectionIndexes" options:NSKeyValueObservingOptionInitial context:&kvoContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processFSUpdate:) name:@"SXIOCalibrationWindowControllerFSUpdate" object:nil];
    
    [self.arrayController setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    
    self.url = [NSURL fileURLWithPath:@"/Users/simon/Desktop/"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        [self.calibrateButton setEnabled:[self.collectionView.selectionIndexes count] > 0]; // todo; and suitable calibration frames exist
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SXIOCalibrationWindowControllerFSUpdate" object:nil userInfo:@{
     @"added":added,
     @"removed":removed,
     @"modified":modified
     }];
}

- (NSArray*)modelWithPath:(NSString*)path
{
    return [self.images filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        SXIOCalibrationModel* model = evaluatedObject;
        return [[model.url path] isEqualToString:path];
    }]];
}

- (void)addImageAtPath:(NSString*)path
{
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
    if (io){
        NSError* error;
        CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
        if (![io readExposure:exposure readPixels:NO error:&error]){
            NSLog(@"%@: error=%@",NSStringFromSelector(_cmd),error);
        }
        else{
            SXIOCalibrationModel* model = [[SXIOCalibrationModel alloc] init];
            model.url = [NSURL fileURLWithPath:path];
            model.exposure = exposure;
            [[self mutableArrayValueForKey:@"images"] addObject:model]; // inefficient if we're adding a lot of images
            // check to see if it's a calibration frame and add that to the list
        }
    }
}

- (void)processFSUpdate:(NSNotification*)note
{
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

    for (SXIOCalibrationModel* model in [self.images copy]){
        if ([removed containsObject:[model.url path]]){
            [[self mutableArrayValueForKey:@"images"] removeObject:model];
        }
    }
    
    for (NSString* path in added){
        if ([[self modelWithPath:path] count]){
            NSLog(@"%@ already exists",path);
        }
        else{
            [self addImageAtPath:path];
        }
    }
    
    // check to see if calibration frames have appeared/disappeared
}

- (void)registerForFSEvents
{
    if (!_url){
        return;
    }
    
    if (_eventsRef){
        FSEventStreamStop(_eventsRef);
        FSEventStreamInvalidate(_eventsRef);
        FSEventStreamRelease(_eventsRef);
    }
    
    _eventsRef = FSEventStreamCreate(NULL, CASFSEventStreamCallback, nil, (__bridge CFArrayRef)@[[self.url path]], kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagFileEvents|kFSEventStreamCreateFlagUseCFTypes);

    if (_eventsRef){
        FSEventStreamScheduleWithRunLoop(_eventsRef,CFRunLoopGetMain(),kCFRunLoopCommonModes);
        FSEventStreamStart(_eventsRef);
    }
}

- (void)refreshContents
{
    [self registerForFSEvents];

    [[self mutableArrayValueForKey:@"images"] removeAllObjects];
        
    NSDirectoryEnumerator* e = [[NSFileManager defaultManager] enumeratorAtURL:self.url
                                                    includingPropertiesForKeys:nil
                                                                       options:NSDirectoryEnumerationSkipsSubdirectoryDescendants|NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles
                                                                  errorHandler:nil];
    
    NSURL* imageURL;
    while ((imageURL = [e nextObject]) != nil) {
        [self addImageAtPath:[imageURL path]];
    }
        
    // look for calibration frames
}

- (void)setUrl:(NSURL *)url
{
    if (_url != url){
        _url = url;
        [self refreshContents];
    }
}

- (IBAction)choose:(id)sender {
    
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.canChooseDirectories = YES;
    open.canChooseFiles = NO;
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.url = open.URL;
            });
        }
    }];
}

- (IBAction)calibrate:(id)sender {
    NSLog(@"calibrate");
}

@end
