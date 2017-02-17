//
//  CASMountWindowController.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMountWindowController.h"
#if defined(SXIO)
#import "SX_IO-Swift.h"
#import "SXIOAppDelegate.h"
#elif defined(CCDIO)
#import "CCD_IO-Swift.h"
#endif
#if defined(SXIO) || defined(CCDIO)
#import "SXIOAppDelegate.h"
#import "SXIOCameraWindowController.h"
#endif
#import <CoreAstro/CoreAstro.h>
#import <CoreAstro/ORSSerialPortManager.h>

// todo; AP-specific options:
// Force recal, sidereal diff to use
// Use full sync vs re-cal, or Sync button
// Load view xib from driver and embed in mount window, accessor on mount to get xib name
// Don't have a pop-up for the slew rate...

@interface CASPierSideTransformer : NSValueTransformer
@end

@implementation CASPierSideTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    switch ([value integerValue]) {
        case CASMountPierSideEast:
            return @"East";
        case CASMountPierSideWest:
            return @"West";
    }
    return @"--";
}

@end

@interface CASMountWindowController ()<NSWindowDelegate,NSPopoverDelegate>
@property (nonatomic,readonly) CASMount* mount; // bindings convenience accessor
@property (nonatomic,strong) CASMountController* mountController;
@property (nonatomic,copy) NSString* searchString;
@property (nonatomic,copy) NSString* lastSearchString;
@property (nonatomic,readonly) NSArray* cameraControllers;
@property (strong) IBOutlet NSArrayController *camerasArrayController;
@property (strong) IBOutlet NSPanel *morePanel;
@property (strong) IBOutlet NSWindow *mountConnectWindow;
@property (weak) IBOutlet NSProgressIndicator *lookupSpinner;
@property (weak) ORSSerialPort* selectedSerialPort;
@property (strong) ORSSerialPortManager* serialPortManager;
@property (copy) void(^slewCompletion)(NSError*);
@property BOOL hasCurrentSolutionBookmark;
@property (strong) NSNumber* targetRA;
@property (strong) NSNumber* targetDec;
@property (strong) CASObjectLookup* lookup;
@property (strong) CASMountSlewObserver* slewObserver;
@property (weak) IBOutlet NSButton *mountConfigurationButton;
@property (strong) NSPopover* mountPopover;
@end

// todo;
// not reflecting initial slew state
// ra/dec all zeros ?

@interface CASNumberStringTransformer : NSValueTransformer
@end

@implementation CASNumberStringTransformer

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)value
{
    return [value description];
}

- (id)reverseTransformedValue:(id)value
{
    return @([value integerValue]);
}

@end

@implementation CASMountWindowController

static void* kvoContext;

@synthesize cameraControllers = _cameraControllers;

+ (void)initialize
{
    [NSValueTransformer setValueTransformer:[CASLX200RATransformer new] forName:@"CASLX200RATransformer"];
    [NSValueTransformer setValueTransformer:[CASLX200DecTransformer new] forName:@"CASLX200DecTransformer"];
    [NSValueTransformer setValueTransformer:[CASPierSideTransformer new] forName:@"CASPierSideTransformer"];
    [NSValueTransformer setValueTransformer:[CASNumberStringTransformer new] forName:@"CASNumberStringTransformer"];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASMountWindowControllerBinning":@(4),
                                                              @"CASMountWindowControllerDuration":@(5),
                                                              @"CASMountWindowControllerConvergence":@(0.02)}];
}

- (void)dealloc
{
    [self cleanup];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
#if defined(SXIO) || defined(CCDIO)
    [self.window addObserver:self forKeyPath:@"title" options:0 context:&kvoContext];
#endif
    
    self.window.delegate = self;
    
    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(hideWindow:)];
    
    self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
    self.selectedSerialPort = [self.serialPortManager.availablePorts firstObject];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
#if defined(SXIO) || defined(CCDIO)
        [[SXIOAppDelegate sharedInstance] updateWindowInWindowMenu:self];
#endif
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];

#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self];
#endif
}

- (void)hideWindow:sender
{
    [self close];
}

- (void)closeWindow:sender
{
    if (self.mountController.synchronising){
        // need a way of cancelling a solve
        NSLog(@"Currently solving...");
        return;
    }
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromWindowMenu:self];
#endif

    [self close];
}

- (void)cleanup
{
    // check this is being called...
    [self.mountController.mount disconnect];

    [[CASDeviceManager sharedManager] removeMountController:self.mountController];
    self.mountController = nil;
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
}

- (void)presentAlertWithTitle:(NSString*)title message:(NSString*)message
{
    [[NSAlert alertWithMessageText:title
                     defaultButton:nil
                   alternateButton:nil
                       otherButton:nil
         informativeTextWithFormat:@"%@",message] runModal];
}

#pragma mark - Bindings convenience

- (id)mount
{
    return self.mountController.mount;
}

+ (NSSet*)keyPathsForValuesAffectingMount
{
    return [NSSet setWithObject:@"mountController"];
}

#pragma mark - Bookmarks

- (NSArray*)bookmarks
{
    // this is only being called once when the window is first created...
    
    NSMutableArray* bookmarks = [CASBookmarks.sharedInstance.bookmarks mutableCopy];
    
    // if the delegate has a solution, add that as a temp bookmark (would be nice to be able to add a separator but we're using bindings atm)
    // todo; pick up changes in the delegate's solution
    __block BOOL hasCurrentSolutionBookmark = NO;
    NSArray<CASPlateSolveSolution*>* solutions = [CASPlateSolveSolutionRegistery sharedRegistry].solutions;
    [solutions enumerateObjectsUsingBlock:^(CASPlateSolveSolution * _Nonnull solution, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary* solutionDictionary = solution.solutionDictionary;
        if (solutionDictionary){
            NSString* name = [NSString stringWithFormat:@"Current Solution (%@, %@)",solution.displayCentreRA,solution.displayCentreDec];
            NSDictionary* bookmark = @{CASBookmarks.nameKey:name,CASBookmarks.solutionDictionaryKey:solutionDictionary};
            [bookmarks insertObject:bookmark atIndex:0];
            [bookmarks insertObject:@{CASBookmarks.nameKey:@"<separator>"} atIndex:1];
            hasCurrentSolutionBookmark = YES;
        }
    }];
    
    self.hasCurrentSolutionBookmark = hasCurrentSolutionBookmark;

    return [bookmarks copy];
}

- (IBAction)didSelectBookmark:(NSPopUpButton*)sender
{
    if (!self.mountController.mount.connected || self.mountController.mount.slewing){
        return;
    }
    [self selectBookmarkAtIndex:sender.indexOfSelectedItem];
}

- (void)menuNeedsUpdate:(NSMenu *)menu // menu delegate for swapping placeholders for actual separator items
{
    NSArray* items = menu.itemArray.copy;
    for (NSMenuItem* item in items) {
        if ([item.title isEqualToString:@"<separator>"]) {
            [menu insertItem:[NSMenuItem separatorItem] atIndex:[menu indexOfItem:item]];
            [menu removeItem:item];
        }
    }
}

- (void)selectBookmarkAtIndex:(NSInteger)index
{
    if (index != -1){
        
        // if items 0 and 1 are a current location bookmark, fixup the index into the bookmarks array
        if (self.hasCurrentSolutionBookmark && index > 1){
            index -= 2;
        }
        
        NSDictionary* bookmark = [self.bookmarks objectAtIndex:index];
        CASPlateSolveSolution* solution = [CASPlateSolveSolution solutionWithDictionary:bookmark[CASBookmarks.solutionDictionaryKey]];
        if (solution){
            self.targetRA = @(solution.centreRA);
            self.targetDec = @(solution.centreDec);
        }
        else {
            NSNumber* centreRA = bookmark[CASBookmarks.centreRaKey];
            NSNumber* centreDec = bookmark[CASBookmarks.centreDecKey];
            if (centreRA && centreDec){
                self.targetRA = centreRA;
                self.targetDec = centreDec;
            }
        }
    }
}

#pragma mark - Mount/Camera

- (NSArray*)cameraControllers
{
    return [CASDeviceManager sharedManager].cameraControllers;
}

//- (CASCameraController*)cameraController
//{
//    return self.mountController.cameraController;
//}
//
//- (void)setCameraController:(CASCameraController *)cameraController
//{
//    self.mountController.cameraController = self.cameraController;
//
////    NSAssert(self.mountController, @"Need a mount controller");
////
////    if (self.mountController.cameraController != cameraController){
////        
////        self.mountController.cameraController = cameraController;
////        
////        if (!cameraController){
////            self.mountWindowDelegate = nil;
////        }
////        else{
////            
////#if defined(SXIO) || defined(CCDIO)
////            SXIOCameraWindowController* cameraWindowController = (SXIOCameraWindowController*)[[SXIOAppDelegate sharedInstance] findDeviceWindowController:cameraController];
////            if ([cameraWindowController isKindOfClass:[SXIOCameraWindowController class]]){
////                
////                self.mountWindowDelegate = (id)cameraWindowController;
////                /*
////                 CASPlateSolveSolution* solution = cameraWindowController.exposureView.plateSolveSolution;
////                 if (solution){
////                 // todo; check to see we're not slewing, etc
////                 [self.mountController setTargetRA:solution.centreRA dec:solution.centreDec];
////                 }
////                 */
////            }
////            else {
////                self.mountWindowDelegate = nil;
////            }
////#endif
////        }
////    }
//}

- (void)startMoving:(CASMountDirection)direction
{
//    NSLog(@"startMoving: %ld",direction);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving) object:nil];
    [self performSelector:@selector(stopMoving) withObject:nil afterDelay:0.25 inModes:@[NSRunLoopCommonModes]];
    [self.mountController.mount startMoving:direction];
}

- (void)stopMoving
{
//    NSLog(@"stopMoving");
    [self.mountController.mount stopMoving];
}

#pragma mark - Actions

- (IBAction)sync:(id)sender
{
    NSNumber* ra = self.mount.ra;
    NSNumber* dec = self.mount.dec;
    if (ra && dec){
        const NSModalResponse response = [[NSAlert alertWithMessageText:@"Confirm Sync"
                                                          defaultButton:@"Sync"
                                                        alternateButton:@"Cancel"
                                                            otherButton:nil
                                              informativeTextWithFormat:@"Confirm that you want to sync the mount to this target"] runModal];
        if (response == NSOKButton){
            [self.mount fullSyncToRA:ra.doubleValue dec:dec.doubleValue completion:^(CASMountSlewError error) {
                if (error != CASMountSlewErrorNone){
                    [self presentAlertWithMessage:@"Failed to sync the mount"];
                }
            }];
        }
    }
    else {
        [self presentAlertWithMessage:@"The mount is not currently reporting a positon so cannot be synced"];
    }
}

- (IBAction)north:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionNorth];
}

- (IBAction)soutgh:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionSouth];
}

- (IBAction)west:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionWest];
}

- (IBAction)east:(id)sender // called continuously while the button is held down
{
    [self startMoving:CASMountDirectionEast];
}

- (IBAction)slew:(id)sender
{
    if (!self.targetRA || !self.targetDec){
        return;
    }
    
    __weak __typeof (self) weakSelf = self;
    [self.mountController setTargetRA:self.targetRA.doubleValue dec:self.targetDec.doubleValue completion:^(NSError* error) {
        if (error){
            [weakSelf presentAlertWithMessage:error.localizedDescription];
        }
        else{
            [weakSelf.mountController slewToTargetWithCompletion:^(NSError* error) {
                if (error){
                    [weakSelf presentAlertWithMessage:error.localizedDescription];
                }
            }];
        }
    }];
}

- (IBAction)stop:(id)sender
{
    [self.mountController stop];
}

- (IBAction)home:(id)sender
{
    __weak __typeof (self) weakSelf = self;
    [self.mountController.mount gotoHomePosition:^(CASMountSlewError error, CASMountSlewObserver* observer){
        if (error != CASMountSlewErrorNone) {
            [self presentAlertWithMessage:@"Failed to home the mount"];
        }
        else {
            self.slewObserver = observer;
            self.slewObserver.completion = ^(NSError* error){
                if (error){
                    [weakSelf presentAlertWithMessage:error.localizedDescription];
                }
                else {
                    [weakSelf presentAlertWithTitle:@"Home Complete" message:@"The mount is now in its Home position"];
                }
            };
        }
    }];
}

- (IBAction)park:(id)sender
{
    __weak __typeof (self) weakSelf = self;
    [self.mountController.mount park:^(CASMountSlewError error, CASMountSlewObserver* observer) {
        if (error != CASMountSlewErrorNone){
            [self presentAlertWithMessage:@"Failed to park the mount"];
        }
        else {
            self.slewObserver = observer;
            self.slewObserver.completion = ^(NSError* error){
                if (error){
                    [weakSelf presentAlertWithMessage:error.localizedDescription];
                }
                else {
                    [weakSelf presentAlertWithTitle:@"Park Complete" message:@"The mount is now parked"];
                }
            };
        }
    }];
}

- (IBAction)lookup:(id)sender
{
    if (![self.searchString length] || self.lookup){
        NSBeep();
        return;
    }
    
    self.targetRA = nil;
    self.targetDec = nil;
    
    [self.lookupSpinner startAnimation:nil];
    
    self.lookup = [CASObjectLookup new];
    [self.lookup lookupObject:self.searchString withCompletion:^(BOOL success, NSString* objectName, double ra, double dec) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.lookup = nil;
            
            [self.lookupSpinner stopAnimation:nil];
            
            if (!success){
                [[NSAlert alertWithMessageText:@"Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Target couldn't be found"] runModal];
            }
            else {
                NSLog(@"Found %@",objectName);
                self.lastSearchString = self.searchString;
                self.targetRA = @(ra);
                self.targetDec = @(dec);
            }
        });
    }];
}

- (IBAction)more:(id)sender
{
    [self.window beginSheet:self.morePanel completionHandler:^(NSModalResponse returnCode) {
        NSLog(@"CASMountWindowControllerBinning %@",[[NSUserDefaultsController sharedUserDefaultsController].defaults objectForKey:@"CASMountWindowControllerBinning"]);
        NSLog(@"CASMountWindowControllerDuration %@",[[NSUserDefaultsController sharedUserDefaultsController].defaults objectForKey:@"CASMountWindowControllerDuration"]);
    }];
}

- (IBAction)add:(id)sender
{
    if (self.lastSearchString &&
        self.targetRA &&
        self.targetDec){
        [self willChangeValueForKey:@"bookmarks"];
        [CASBookmarks.sharedInstance addBookmark:self.lastSearchString
                                              ra:self.targetRA.doubleValue
                                             dec:self.targetDec.doubleValue];
        [self didChangeValueForKey:@"bookmarks"];
    }
    else {
        [[NSAlert alertWithMessageText:@"No Target Set" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"No mount target has been set via a successful lookup"] runModal];
    }
}

- (IBAction)moreDone:(id)sender
{
    [self.window endSheet:self.morePanel returnCode:NSModalResponseContinue];
}

- (IBAction)connectPressed:(id)sender
{
    [self.window endSheet:self.mountConnectWindow returnCode:NSModalResponseContinue];
}

- (IBAction)cancelPressed:(id)sender
{
    [self.window endSheet:self.mountConnectWindow returnCode:NSModalResponseCancel];
}

- (IBAction)disconnectButtonPressed:(id)sender
{
    if (self.mountController.synchronising){
        // need a way of cancelling a solve
        NSLog(@"Currently solving...");
        return;
    }

#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromWindowMenu:self];
#endif

    [self cleanup];
    
    [self close];
}

// todo; we should really embed the config UI in the main window in the Mount section
- (IBAction)mountButtonPressed:(NSButton*)sender
{
    NSViewController* configure = self.mount.configurationViewController;
    if (!configure){
        [self presentAlertWithMessage:@"This mount doesn't provide a configuration UI"];
    }
    else {
        self.mountPopover = [[NSPopover alloc] init];
        self.mountPopover.delegate = self;
        self.mountPopover.contentViewController = configure;
        self.mountPopover.behavior = NSPopoverBehaviorTransient;
        [self.mountPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMaxXEdge];
    }
}

#pragma mark - Popover delegate

- (void)popoverDidClose:(NSNotification *)notification
{
    self.mountPopover = nil;
}

#pragma mark - Window delegate

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [self willChangeValueForKey:@"bookmarks"];
    // force the bookmarks menu to redraw in case the associated window controller has a current plate solution
    // todo; this is a workaround, we should bind to the mount window delegate somehow 
    [self didChangeValueForKey:@"bookmarks"];
}

@end

@implementation CASMountWindowController (Global)

+ (instancetype)sharedMountWindowController
{
    static CASMountWindowController* mountController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mountController = [[[self class] alloc] initWithWindowNibName:@"CASMountWindowController"];
    });
    return mountController;
}

- (void)connectToMount:(CASMount*)mount completion:(void(^)(NSError*))completion
{
    NSParameterAssert(mount);
    NSParameterAssert(completion);
    
#if CAS_SLEW_AND_SYNC_TEST
    _testError = 1;
#endif
    
    [mount connect:^(NSError* error){
        if (mount.connected){
            [self showWindow:nil];
        }
        if (completion){
            completion(error);
        }
    }];
}

- (void)connectToMountWithPort:(ORSSerialPort*)port completion:(void(^)(NSError*))completion
{
    NSParameterAssert(completion);
    
    if (!port){
        completion([NSError errorWithDomain:NSStringFromClass([self class]) code:5 userInfo:@{NSLocalizedDescriptionKey:@"No serial port has been selected"}]);
        return;
    }

    if (port.isOpen){
        completion([NSError errorWithDomain:NSStringFromClass([self class]) code:5 userInfo:@{NSLocalizedDescriptionKey:@"Selected serial port is already open"}]);
        return;
    }
    
    CASMount* mount = [[CASAPGTOMount alloc] initWithSerialPort:port];
    
    if (mount.slewing){
        completion([NSError errorWithDomain:NSStringFromClass([self class]) code:6 userInfo:@{NSLocalizedDescriptionKey:@"Mount is slewing. Please try again when it's stopped"}]);
        return;
    }
    
    [self connectToMount:mount completion:^(NSError* error) {
        if (error){
            completion(error);
        }
        else {
            
            [self showWindow:nil];
            
            self.mountController = [[CASMountController alloc] initWithMount:mount];
            [[CASDeviceManager sharedManager] addMountController:self.mountController];
            
            completion(nil);
        }
    }];
}

- (void)connectToMount:(void(^)())completion
{
    NSParameterAssert(completion);

    [self showWindow:nil]; // because we need to present a sheet
    
    if (self.mountController.mount){
        if (completion){
            completion();
        }
        return;
    }
    
    self.selectedSerialPort = [self.serialPortManager.availablePorts firstObject];
    if (self.selectedSerialPort){
        
        [self.window beginSheet:self.mountConnectWindow completionHandler:^(NSModalResponse returnCode) {
            
            if (returnCode != NSModalResponseContinue){
                [self closeWindow:nil];
            }
            else {
                
                [self connectToMountWithPort:self.selectedSerialPort completion:^(NSError* error) {
                    if (error){
                        [self closeWindow:nil];
                        [self presentAlertWithTitle:nil message:[error localizedDescription]];
                    }
                    else {
                        completion();
                    }
                }];
            }
        }];
    }
}

- (void)connectToMountAtPath:(NSString*)path completion:(void(^)(NSError*,CASMountController*))completion
{
    NSParameterAssert(completion);
    
//    // check to see if we're already connected to this mount
//    if ([self.mountController.mount respondsToSelector:@selector(port)]){
//        ORSSerialPort* port = [self.mountController.mount valueForKey:@"port"];
//        if ([port.path isEqualToString:path]){
//            // completion(nil,self.mountController); // except this seems to cause the make applevent handler to be called again ?
//            NSError* error = [NSError errorWithDomain:NSStringFromClass([self class]) code:9 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Mount '%@' already connected",self.mount.deviceName]}];
//            completion(error,nil);
//        }
//        return;
//    }
    
    // enfore a single mount connected policy
    if (self.mountController.mount){
        NSError* error = [NSError errorWithDomain:NSStringFromClass([self class]) code:8 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"The mount window is already connected to the mount '%@'",self.mountController.mount.deviceName]}];
        completion(error,nil);
        return;
    }

    ORSSerialPort* port = [[ORSSerialPortManager sharedSerialPortManager].availablePorts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"path == %@",path]].firstObject;
    if (!port){
        completion([NSError errorWithDomain:NSStringFromClass([self class]) code:7 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"There is no serial port with the path '%@'",path]}],nil);
    }
    else {
        [self connectToMountWithPort:port completion:^(NSError* error) {
            completion(error,self.mountController);
        }];
    }
}

@end
