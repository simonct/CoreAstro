//
//  MKOAppDelegate.m
//  astrometry-test
//
//  Created by Simon Taylor on 12/24/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//
//  Inspired by http://stargazerslounge.com/topic/143540-star-hopping-with-on-the-fly-astrometry/
//

#import "MKOAppDelegate.h"
#import "CASEQMacClient.h"
#import "CASConfigureIPMountWindowController.h"
#import "CASPlateSolveImageView.h"
#import "CASFolderWatcher.h"
#import "iEQMount.h"
#import "ORSSerialPortManager.h"
#import "CASLX200Commands.h"
#import <CoreAstro/CoreAstro.h>

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASPlateSolveSolution* solution;
@property (nonatomic,strong) CASLX200IPClient* ipMountClient;
@property (nonatomic,strong) CASConfigureIPMountWindowController* configureIPController;
@property (nonatomic,strong) CASPlateSolver* plateSolver;
@property (nonatomic,assign) float arcsecsPerPixel;
@property (nonatomic,assign) CGSize fieldSizeDegrees;
@property (nonatomic,copy) NSString* fieldSizeDisplay;
@property (nonatomic,strong) CASFolderWatcher* watcher;
@property (nonatomic,strong) NSMutableOrderedSet* pendingWatchedPaths;
@property (nonatomic,strong) CASPlateSolver* solver;
@property (nonatomic,weak) ORSSerialPort* selectedSerialPort;
@property (nonatomic,strong) ORSSerialPortManager* serialPortManager;
@property (nonatomic,strong) iEQMount* ieqMount;
@property (nonatomic,strong) IBOutlet NSWindow *ieqWindow;
@end

@implementation MKOAppDelegate

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
     @"CASIPMountHost":@"localhost",
     @"CASIPMountPort":@(4030),
     @"CASPixelSizeMicrometer":@(9),
     @"CASFocalLengthMillemeter":@(540),
     @"CASBinningFactor":@(1),
     @"CASPlateSolveSaveSolution":@YES
     }];
}

- (void)awakeFromNib
{
    self.solver = [CASPlateSolver plateSolverWithIdentifier:nil]; // this is purely to provide access to the plate solve index directory

    self.spinner.hidden = YES;
    self.spinner.usesThreadedAnimation = YES;
    
    self.imageView.acceptDrop = YES;
    [self.imageView bind:@"annotations" toObject:self withKeyPath:@"solution.objects" options:nil];
    
    [self.imageView addObserver:self forKeyPath:@"url" options:0 context:(__bridge void *)(self)];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASPixelSizeMicrometer" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASFocalLengthMillemeter" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASBinningFactor" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASSensorWidthMillimeter" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASSensorHeightMillimeter" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASPlateSolveWatchFolderURL" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASEnablePlateSolveWatchFolder" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [[NSColorPanel sharedColorPanel] orderOut:nil];
    [[NSColorPanel sharedColorPanel] setHidesOnDeactivate:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if (object == self.imageView){
            self.solution = nil;
            NSString* title = [[NSFileManager defaultManager] displayNameAtPath:self.imageView.url.path];
            self.window.title = title ? title : @"";
            NSString* solutionPath = [self plateSolutionPathForImagePath:self.imageView.url.path];
            if ([[NSFileManager defaultManager] fileExistsAtPath:solutionPath isDirectory:nil]){
                NSData* solutionData = [NSData dataWithContentsOfFile:solutionPath];
                if ([solutionData length]){
                    self.solution = [CASPlateSolveSolution solutionWithData:solutionData];
                }
            }
            [self.window setRepresentedURL:self.imageView.url];
        }
        else if (object == [NSUserDefaultsController sharedUserDefaultsController]){
            [self calculateImageScale];
            [self calculateFieldSize];
            if ([@[@"values.CASPlateSolveWatchFolderURL",@"values.CASEnablePlateSolveWatchFolder"] containsObject:keyPath]){
                [self updateWatchFolder];
            }
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSURL*)watchDirectoryURL
{
    NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:@"CASPlateSolveWatchFolderURL"];
    return s ? [NSURL fileURLWithPath:s] : nil;
}

- (void)setWatchDirectoryURL:(NSURL*)url
{
    [[NSUserDefaults standardUserDefaults] setValue:[url path] forKey:@"CASPlateSolveWatchFolderURL"];
}

- (void)setFieldSizeDegrees:(CGSize)fieldSizeDegrees
{
    _fieldSizeDegrees = fieldSizeDegrees;
    if (_fieldSizeDegrees.width == 0 && _fieldSizeDegrees.height == 0){
        self.fieldSizeDisplay = nil;
    }
    else {
        self.fieldSizeDisplay = [NSString stringWithFormat:@"%.2f\u2032x%.2f\u2032",_fieldSizeDegrees.width,_fieldSizeDegrees.height];
    }
}

- (void)updateWatchFolder
{
    NSString* watchPath = self.watchDirectoryURL.path;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CASEnablePlateSolveWatchFolder"] && [[NSFileManager defaultManager] fileExistsAtPath:watchPath]){
        
        self.watcher = [CASFolderWatcher watcherWithPath:watchPath callback:^(NSArray *paths) { // regex for filenames/extensions to watch ?
            for (NSString* path in paths){
                [self handleAddedFileAtPath:path];
            }
        }];
        NSDirectoryEnumerator* dirEnum = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:watchPath]
                                                              includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants|NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles
                                                                            errorHandler:nil];
        NSURL* imageURL;
        while ((imageURL = [dirEnum nextObject]) != nil) {
            [self handleAddedFileAtPath:imageURL.path];
        }
    }
    else {
        self.watcher = nil;
    }
}

- (void)calculateImageScale
{
    const float pixelSize = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] floatForKey:@"CASPixelSizeMicrometer"];
    const float focalLength = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] floatForKey:@"CASFocalLengthMillemeter"];
    const float binningFactor = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] floatForKey:@"CASBinningFactor"];
    
    if (focalLength == 0){
        self.arcsecsPerPixel = 0;
    }
    else {
        self.arcsecsPerPixel = binningFactor*(206.3*pixelSize/focalLength);
    }
}

- (void)calculateFieldSize
{
    const float focalLength = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] floatForKey:@"CASFocalLengthMillemeter"];
    const float ccdWidth = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] floatForKey:@"CASSensorWidthMillimeter"];
    const float ccdHeight = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] floatForKey:@"CASSensorHeightMillimeter"];

    CGSize fieldSize;
    if (focalLength == 0){
        fieldSize.width = fieldSize.height = 0;
    }
    else {
        fieldSize.width = 3438*ccdWidth/focalLength/60.0;
        fieldSize.height = 3438*ccdHeight/focalLength/60.0;
    }
    self.fieldSizeDegrees = fieldSize;
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
}

- (void)setSolution:(CASPlateSolveSolution *)solution
{
    if (solution != _solution){
        
        _solution = solution;
        
        if (!_solution){
            self.solutionRALabel.stringValue = self.solutionDecLabel.stringValue = self.solutionAngleLabel.stringValue = @"";
            self.pixelScaleLabel.stringValue = self.fieldWidthLabel.stringValue = self.fieldHeightLabel.stringValue = @"";
        }
        else {
            self.solutionRALabel.stringValue = self.solution.displayCentreRA;
            self.solutionDecLabel.stringValue = self.solution.displayCentreDec;
            self.solutionAngleLabel.stringValue = self.solution.centreAngle;
            self.pixelScaleLabel.stringValue = self.solution.pixelScale;
            self.fieldWidthLabel.stringValue = self.solution.fieldWidth;
            self.fieldHeightLabel.stringValue = self.solution.fieldHeight;
        }
    }
}

- (NSString*)plateSolutionPathForImagePath:(NSString*)imagePath
{
    NSString* solutionPath = [imagePath stringByDeletingLastPathComponent];
    NSString* solutionName = [[[imagePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"plateSolution"];
    return [solutionPath stringByAppendingPathComponent:solutionName];
}

- (void)addPendingWatchedPathsObject:(NSString *)path
{
    if (!self.pendingWatchedPaths){
        self.pendingWatchedPaths = [NSMutableOrderedSet orderedSet];
    }
    if (![self.pendingWatchedPaths containsObject:path]){
        [self.pendingWatchedPaths addObject:path];
        NSLog(@"Adding %@ to pending list",[path stringByAbbreviatingWithTildeInPath]);
    }
}

- (void)handleAddedFileAtPath:(NSString*)path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]){
        return;
    }
    if ([[path pathExtension] isEqualToString:@"plateSolution"] || [[NSFileManager defaultManager] fileExistsAtPath:[self plateSolutionPathForImagePath:path]]){
        return;
    }
    
    if (!self.plateSolver){
        self.imageView.url = [NSURL fileURLWithPath:path];
        if (self.imageView.url){
            [self solve:nil];
        }
        else {
            [self addPendingWatchedPathsObject:path]; // assume it's an image file that's just not completed writing so retry indefinitely
        }
    }
    else {
        [self addPendingWatchedPathsObject:path];
    }
}

- (void)checkForPendingWatchPaths
{
    if ([self.pendingWatchedPaths count]){
        NSString* path = [self.pendingWatchedPaths[0] copy];
        [self.pendingWatchedPaths removeObjectAtIndex:0];
        [self handleAddedFileAtPath:path]; // path will be added back to the watch list if required
    }
}

- (void)solveImageAtPath:(NSString*)imagePath
{
    NSError* error;
    self.plateSolver = [CASPlateSolver plateSolverWithIdentifier:nil];
    if (![self.plateSolver canSolveExposure:nil error:&error]){
        [NSApp presentError:error];
        self.plateSolver = nil;
    }
    else{

        void (^completeWithError)(NSString*) = ^(NSString* error) {
            if (error){
                [self presentAlertWithMessage:error];
            }
            self.imageView.acceptDrop = YES;
            self.solveButton.enabled = YES;
            self.imageView.alphaValue = 1;
            self.spinner.hidden = YES;
            [self.spinner stopAnimation:nil];
            self.plateSolver = nil;
        };
        
        self.solution = nil;
        
        self.imageView.acceptDrop = NO;
        self.solveButton.enabled = NO;
        self.imageView.alphaValue = 0.5;
        self.spinner.hidden = NO;
        [self.spinner startAnimation:nil];

        // solve async - beware of races here since we're doing this async
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            __weak MKOAppDelegate* weakSelf = self;
            self.plateSolver.outputBlock = ^(NSString* string){
                MKOAppDelegate* strongSelf = weakSelf;
                if (strongSelf){
                    [strongSelf.outputLogTextView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:string]];
                    [strongSelf.outputLogTextView scrollToEndOfDocument:nil];
                }
            };
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CASUsePlateSolvePixelScale"]){
                self.plateSolver.arcsecsPerPixel = self.arcsecsPerPixel;
            }
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CASUsePlateSolveFieldSize"]){
                self.plateSolver.fieldSizeDegrees = self.fieldSizeDegrees;
            }
            
            // simply get the pixels from the image view ??
            
            BOOL removeWhenDone = NO;
            NSString* path = imagePath;
            NSData* data = [CASPlateSolveImageView imageDataFromExposurePath:imagePath error:nil];
            if (data){
                path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"plate-solve-tmp-%d.png",getpid()]];
                removeWhenDone = [data writeToFile:path options:NSDataWritingAtomic error:nil];
            }
            else {
                NSLog(@"No image data - file is probably still being written");
            }
            
            [self.plateSolver solveImageAtPath:path completion:^(NSError *error, NSDictionary* results) {
                
                if (removeWhenDone){
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    completeWithError([error localizedDescription]);

                    self.solution = results[@"solution"];
                    self.plateSolver = nil;
                    
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CASPlateSolveSaveSolution"]){
                        if (![[self.solution solutionData] writeToFile:[self plateSolutionPathForImagePath:self.imageView.url.path] atomically:YES]){
                            [self presentAlertWithMessage:@"There was a problem saving the solution to the same folder as the image"];
                        }
                    }
                    
                    [self checkForPendingWatchPaths];
                });
            }];
        });
    }
}

- (IBAction)solve:(id)sender
{
    if (!self.imageView.image || self.plateSolver){
        return;
    }
    
    [self solveImageAtPath:self.imageView.url.path];
}

- (IBAction)showFontPanel:(id)sender
{
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager setDelegate:self];
    [fontManager orderFrontFontPanel:self];
}

- (IBAction)resetAnnotations:(id)sender
{
    [self.imageView createAnnotations];
}

- (IBAction)changeFont:(id)sender
{
    self.imageView.annotationsFont = [sender convertFont:self.imageView.annotationsFont];
    [[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:self.imageView.annotationsFont] forKey:@"CASAnnotationsFont"];
    [self.imageView updateAnnotations];
}

- (IBAction)openDocument:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = [[NSImage imageFileTypes] arrayByAddingObjectsFromArray:@[@"fits",@"fts",@"fit"]];
    open.allowsMultipleSelection = NO;
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            self.imageView.url = open.URL;
            if (self.imageView.url){
                // self.solution = nil;
            }
        }
    }];
}

- (IBAction)saveDocument:(id)sender
{
    if (!self.solution){
        return;
    }
    
    NSSavePanel* save = [NSSavePanel savePanel];
    
    save.allowedFileTypes = @[[self.imageView.url pathExtension]];
    save.canCreateDirectories = YES;
    save.nameFieldStringValue = [self.imageView.url lastPathComponent];
    
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){

            const CGSize size = self.imageView.image.extent.size;

            // create an offscreen view to render the image+annotations at full resolution
            NSWindow *offscreenWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-32000,-32000,size.width,size.height)
                                                                    styleMask:NSBorderlessWindowMask
                                                                      backing:NSBackingStoreNonretained
                                                                        defer:NO];
            CASPlateSolveImageView* offscreenImageView = [[CASPlateSolveImageView alloc] initWithFrame:NSMakeRect(0, 0, size.width,size.height)];
            offscreenImageView.wantsLayer = YES;
            offscreenImageView.layer.opacity = 1;
            [[offscreenWindow contentView] addSubview:offscreenImageView];
            
            // set the annotations and attributes
            offscreenImageView.url = self.imageView.url;
            offscreenImageView.annotationsFont = self.imageView.annotationsFont;
            offscreenImageView.annotations = self.imageView.annotations;
            
            // set annotation positions (assuming both arrays of annotations are in the same order)
            NSInteger i = 0;
            for (CALayer* layer in offscreenImageView.annotationLayer.sublayers){
                CALayer* layer2 = [self.imageView.annotationLayer.sublayers objectAtIndex:i++];
                layer.position = layer2.position;
                layer.anchorPoint = layer2.anchorPoint;
            }
            
            [[offscreenWindow contentView] addSubview:offscreenImageView];
            
            // create a bitmap to render the contents into
            CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
            CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, 8, (size.width) * 4, space, kCGImageAlphaPremultipliedLast);
            CFRelease(space);
            
            if (context){
                
                // render the view's layer
                [offscreenImageView.layer renderInContext:context];
                
                // grab the image and write to the destination url
                CGImageRef image = CGBitmapContextCreateImage(context);
                if (image){
                    
                    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)save.URL, CFSTR("public.png"), 1, nil);
                    if (!destination){
                        NSLog(@"Failed to create image destination for thumbnail at %@",save.URL);
                    }
                    else{
                        CGImageDestinationAddImage(destination,image,nil);
                        if (!CGImageDestinationFinalize(destination)){
                            NSLog(@"Failed to write thumbnail to %@",save.URL);
                        }
                        CFRelease(destination);
                    }
                    CGImageRelease(image);
                }
                CGContextRelease(context);
            }
        }
    }];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    if (menuItem.action == @selector(saveDocument:) || menuItem.action == @selector(goToIniEQ:)){
        return (self.solution != nil);
    }
    if (menuItem.action == @selector(configureIPMount:) || menuItem.action == @selector(goToInEQMac:) || menuItem.action == @selector(goToInIPMount:)){
        return NO; // unable to test so switch off for now
    }
    return YES;
}

@end

@implementation MKOAppDelegate (MountSupport)

- (void)slewToSolutionCentre
{
    [self.ipMountClient startSlewToRA:self.solution.centreRA dec:self.solution.centreDec completion:^(BOOL ok) {
        
        if (!ok){
            [self presentAlertWithMessage:@"Failed to slew to the target"];
            // hide current ra/dec
        }
        else {
            // show current ra/dec
        }
    }];
}

- (void)disconnectMount
{
    if (self.ipMountClient){
        [self.ipMountClient disconnect];
        self.ipMountClient = nil;
    }
}

- (void)slewMountCommon
{
    if (self.ipMountClient.connected){
        [self slewToSolutionCentre];
    }
    else {
        
        [self.ipMountClient connectWithCompletion:^{
            
            if (self.ipMountClient.connected){
                [self slewToSolutionCentre];
            }
            else {
                if ([self.ipMountClient isKindOfClass:[CASEQMacClient class]]){
                    [self presentAlertWithMessage:@"Failed to connect to EQMac."];
                }
                else{
                    [self presentAlertWithMessage:@"Failed to connect to mount."];
                }
            }
        }];
    }
}

- (IBAction)goToInEQMac:(id)sender
{
    if (!self.solution){
        return;
    }
    
    [self disconnectMount];
    
    if (!self.ipMountClient){
        self.ipMountClient = [CASEQMacClient standardClient];
    }
    
    if (![[NSRunningApplication runningApplicationsWithBundleIdentifier:@"au.id.hulse.Mount"] count]){
        [self presentAlertWithMessage:@"EQMac is not running. Please start it, connect to your mount and try again"]; // todo; offer to launch it
    }
    else {
        [self slewMountCommon];
    }
}

- (IBAction)goToInIPMount:(id)sender {
    
    if (!self.solution){
        return;
    }

    NSString* host = [[NSUserDefaults standardUserDefaults] stringForKey:@"CASIPMountHost"];
    NSString* port = [[NSUserDefaults standardUserDefaults] stringForKey:@"CASIPMountPort"];
    if (![host length] || ![port integerValue]){
        [self configureIPMount:nil];
    }
    else {
        
        [self disconnectMount];

        if (!self.ipMountClient){
            self.ipMountClient = [CASLX200IPClient clientWithHost:[NSHost hostWithName:host] port:[port integerValue]];
        }
        
        [self slewMountCommon];
    }
}

- (IBAction)configureIPMount:(id)sender {
    
    if (!self.configureIPController){
        self.configureIPController = [[CASConfigureIPMountWindowController alloc] initWithWindowNibName:@"CASConfigureIPMountWindowController"];
    }
    
    [self.configureIPController beginSheetModalForWindow:self.window completionHandler:nil];
}

- (IBAction)goToIniEQ:(id)sender
{
    if (!self.ieqMount){
        if (!self.serialPortManager){
            self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
        }
        self.selectedSerialPort = [self.serialPortManager.availablePorts firstObject];
        [self.ieqWindow makeKeyAndOrderFront:nil]; // sheet ? todo; config UI should come from the driver...
        return;
    }
    
    if (!self.ieqMount){
        NSLog(@"No iEQ mount object");
    }
    else {
        
        [self.ieqMount connectWithCompletion:^{
            
            if (!self.ieqMount.connected){
                NSLog(@"Failed to connect to iEQ mount");
            }
            else {
                
                const double dec = self.solution.centreDec;
                const double ra = [CASLX200Commands fromRAString:[CASLX200Commands raDegreesToHMS:self.solution.centreRA] asDegrees:NO];
                
                [self.ieqMount startSlewToRA:ra dec:dec completion:^(CASMountSlewError error) {
                    
                    if (error != CASMountSlewErrorNone){
                        NSLog(@"Start slew failed with error %ld",error);
                    }
                    else {
                        NSLog(@"Slewing...");
                    }
                }];
            }
        }];
    }
}

- (IBAction)connectToiEQ:(id)sender
{
    if (!self.selectedSerialPort){
        NSLog(@"No selected port");
        return;
    }
    
    if (self.selectedSerialPort.isOpen){
        NSLog(@"Selected port is open");
        return;
    }
    
    [self.ieqWindow orderOut:nil];
    
    self.ieqMount = [[iEQMount alloc] initWithSerialPort:self.selectedSerialPort];
    
    [self goToIniEQ:nil];
}

@end
