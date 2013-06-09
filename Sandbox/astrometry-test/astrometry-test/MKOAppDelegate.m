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
#import "CASPlateSolver.h"
#import "CASConfigureIPMountWindowController.h"
#import "CASPlateSolveImageView.h"

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASPlateSolveSolution* solution;
@property (nonatomic,strong) CASLX200IPClient* ipMountClient;
@property (nonatomic,strong) CASConfigureIPMountWindowController* configureIPController;
@property (nonatomic,strong) CASPlateSolver* plateSolver;
@end

@implementation MKOAppDelegate

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASIPMountHost":@"localhost",@"CASIPMountPort":@(4030)}];
}

- (void)awakeFromNib
{
    self.spinner.hidden = YES;
    self.spinner.usesThreadedAnimation = YES;
        
    if (self.indexDirectoryURL){
        if (![[NSFileManager defaultManager] fileExistsAtPath:[self.indexDirectoryURL path] ]){
            self.indexDirectoryURL = nil;
        }
    }
    
    self.imageView.acceptDrop = YES;
    [self.imageView bind:@"annotations" toObject:self withKeyPath:@"solution.objects" options:nil];
    
    [self.imageView addObserver:self forKeyPath:@"url" options:0 context:(__bridge void *)(self)];
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
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSURL*)indexDirectoryURL
{
    NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:kCASAstrometryIndexDirectoryURLKey];
    return s ? [NSURL fileURLWithPath:s] : nil;
}

- (void)setIndexDirectoryURL:(NSURL*)url
{
    [[NSUserDefaults standardUserDefaults] setValue:[url path] forKey:kCASAstrometryIndexDirectoryURLKey];
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
}

- (IBAction)solve:(id)sender
{
    if (!self.imageView.image || self.plateSolver){
        return;
    }
    
    if (!self.indexDirectoryURL){
        [self presentAlertWithMessage:@"You need to select the location of the astrometry.net indexes before solving"];
        return;
    }

    NSError* error;
    self.plateSolver = [CASPlateSolver plateSolverWithIdentifier:nil];
    if (![self.plateSolver canSolveExposure:nil error:&error]){
        [NSApp presentError:error];
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

        // bindings...
        self.solutionRALabel.stringValue = self.solutionDecLabel.stringValue = self.solutionAngleLabel.stringValue = @"";
        self.pixelScaleLabel.stringValue = self.fieldWidthLabel.stringValue = self.fieldHeightLabel.stringValue = @"";
        
        self.solveButton.enabled = NO;
        self.imageView.alphaValue = 0.5;
        self.spinner.hidden = NO;
        [self.spinner startAnimation:nil];

        // solve async - beware of races here since we're doing this async
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // output log...
            
            [self.plateSolver solveImageAtPath:self.imageView.url.path completion:^(NSError *error, NSDictionary* results) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    completeWithError([error localizedDescription]);

                    self.solution = results[@"solution"];

                    // bindings...
                    if (self.solution){
                        self.solutionRALabel.stringValue = self.solution.displayCentreRA;
                        self.solutionDecLabel.stringValue = self.solution.displayCentreDec;
                        self.solutionAngleLabel.stringValue = self.solution.centreAngle;
                        self.pixelScaleLabel.stringValue = self.solution.pixelScale;
                        self.fieldWidthLabel.stringValue = self.solution.fieldWidth;
                        self.fieldHeightLabel.stringValue = self.solution.fieldHeight;
                    }

                    self.plateSolver = nil;
                    
#if 0 // DEBUG
                    NSString* solutionPath = [self.imageView.url.path stringByDeletingLastPathComponent];
                    NSString* solutionName = [[[self.imageView.url.path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
                    [report writeToFile:[solutionPath stringByAppendingPathComponent:solutionName] atomically:YES];
#endif

                });
            }];
        });
    }
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
    
    open.allowedFileTypes = [NSImage imageFileTypes];
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
    if (menuItem.action == @selector(saveDocument:) || menuItem.action == @selector(goToInEQMac:) || menuItem.action == @selector(goToInIPMount:)){
        return (self.solution != nil);
    }
    return YES;
}

@end

@implementation MKOAppDelegate (EQMacSupport)

- (void)setIpMountClient:(CASLX200IPClient *)ipMountClient
{
    if (ipMountClient != _ipMountClient){
        _ipMountClient = ipMountClient;
        self.imageView.ipMountClient = _ipMountClient;
    }
}

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

@end
