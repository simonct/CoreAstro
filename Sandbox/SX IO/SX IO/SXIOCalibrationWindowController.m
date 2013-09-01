//
//  SXIOCalibrationWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 8/31/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOCalibrationWindowController.h"
#import "CASProgressWindowController.h"

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

- (NSMenu*)menuForEvent:(NSEvent*)event
{
    NSLog(@"menuForEvent");
    return nil;
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
@property (nonatomic) BOOL hasCalibratedFrame;
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
                    if (self.hasCalibratedFrame){
                        // draw tick badge on it
                    }
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
@property (nonatomic,strong) SXIOCalibrationModel* biasModel, *flatModel;
@property (readonly) BOOL calibrationButtonEnabled;
@end

@implementation SXIOCalibrationWindowController {
    FSEventStreamRef _eventsRef;
}

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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SXIOCalibrationWindowControllerFSUpdate" object:nil];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processFSUpdate:) name:@"SXIOCalibrationWindowControllerFSUpdate" object:nil];
    
    [self.arrayController setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    
//    self.url = [NSURL fileURLWithPath:@"/Volumes/Media1TB/sxio-test/SX_IO/Eastern_Veil_{SXVR-M25C}"];
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
        
        // has it been calibrated ? in which case don't show it
        NSString* filename = [[path lastPathComponent] stringByDeletingPathExtension];
        if ([filename hasSuffix:@"_calibrated"]){
            NSLog(@"Ignoring calibrated frame at %@",path);
        }
        else {
            
            NSError* error;
            CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
            if (![io readExposure:exposure readPixels:NO error:&error]){
                NSLog(@"%@: error=%@",NSStringFromSelector(_cmd),error);
            }
            else{
                
                SXIOCalibrationModel* model = [[SXIOCalibrationModel alloc] init];
                model.url = [NSURL fileURLWithPath:path];
                model.exposure = exposure;
                
                // check to see if it's a calibration frame
                switch (exposure.type) {
                    case kCASCCDExposureBiasType:
                        self.biasModel = model;
                        break;
                    case kCASCCDExposureFlatType:
                        self.flatModel = model;
                        break;
                    default:
                        break;
                }
                
                // does it have a matching calibrated frame ?
                NSString* calibratedFilename = [filename stringByAppendingFormat:@"_calibrated"];
                model.hasCalibratedFrame = [[NSFileManager defaultManager] fileExistsAtPath:[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:calibratedFilename]];
                
                // add the image model (inefficient if we're adding a lot of images)
                [[self mutableArrayValueForKey:@"images"] addObject:model];
            }
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
            if (model == self.biasModel){
                self.biasModel = nil;
            }
            if (model == self.flatModel){
                self.flatModel = nil;
            }
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
    CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
    progress.canCancel = NO;
    [progress beginSheetModalForWindow:self.window];

    @try {
        
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
    }
    @finally {
        [progress endSheetWithCode:NSOKButton];
    }
}

- (void)setUrl:(NSURL *)url
{
    if (_url != url){
        _url = url;
        [self refreshContents];
    }
}

- (void)setBiasModel:(SXIOCalibrationModel *)biasModel
{
    if (biasModel != _biasModel){
        _biasModel = biasModel;
        NSLog(@"Set bias to %@",biasModel);
    }
}

- (void)setFlatModel:(SXIOCalibrationModel *)flatModel
{
    if (flatModel != _flatModel){
        _flatModel = flatModel;
        NSLog(@"Set flat to %@",flatModel);
    }
}

- (BOOL)calibrationButtonEnabled
{
    return [self.collectionView.selectionIndexes count] > 0 && (self.flatModel != nil || self.biasModel != nil);
}

+ (NSSet*)keyPathsForValuesAffectingCalibrationButtonEnabled
{
    return [NSSet setWithArray:@[@"collectionView.selectionIndexes",@"flatModel",@"biasModel"]];
}

- (IBAction)choose:(id)sender
{
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

- (IBAction)calibrate:(id)sender
{
    NSLog(@"calibrate");
}

@end
