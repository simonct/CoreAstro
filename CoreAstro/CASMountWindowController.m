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

@interface CASMountWindowController ()<NSWindowDelegate,NSPopoverDelegate,CASMountMountSynchroniserDelegate>
@property (nonatomic,readonly) CASMount* mount; // bindings convenience accessor
@property (nonatomic,weak) CASMountController* mountController;
@property (nonatomic,copy) NSString* searchString;
@property (nonatomic,copy) NSString* lastSearchString;
@property (strong) IBOutlet NSArrayController *camerasArrayController;
@property (strong) IBOutlet NSPanel *morePanel;
@property (strong) IBOutlet NSWindow *mountConnectWindow;
@property (weak) IBOutlet NSProgressIndicator *lookupSpinner;
@property (weak) IBOutlet NSButton *syncButton;
@property (weak) ORSSerialPort* selectedSerialPort;
@property (strong) ORSSerialPortManager* serialPortManager;
@property NSInteger selectedMountType;
@property (copy) void(^slewCompletion)(NSError*);
@property NSInteger solutionBookmarkCount;
@property (strong) NSNumber* targetRA;
@property (strong) NSNumber* targetDec;
@property (strong) CASObjectLookup* lookup;
@property (strong) CASMountSlewObserver* slewObserver;
@property (strong) NSPopover* mountPopover;
@property (strong) CASMountSynchroniser* synchroniser;
@property BOOL synced;
@property BOOL slewAfterFindLocation;
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookmarksChanged:) name:CASPlateSolveSolutionRegisteryChangedNotification object:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
#if defined(SXIO) || defined(CCDIO)
        [[SXIOAppDelegate sharedInstance] updateWindowInMenus:self];
#endif
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] addWindowToMenus:self];
#endif
}

- (void)disconnect // called from the app delegate
{
    [self disconnectButtonPressed:nil]; // this results in -close being called when the device is removed
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
    [[SXIOAppDelegate sharedInstance] removeWindowFromMenus:self];
#endif
    
    [self cleanup];

    [self close];
}

- (void)cleanup
{
    CASMountController* mountController = self.mountController;
    
    [mountController disconnect];
    
    self.mountController = nil;
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil
                     defaultButton:NSLocalizedString(@"OK", @"OK")
                   alternateButton:nil
                       otherButton:nil
         informativeTextWithFormat:@"%@",message] runModal];
}

- (void)setSearchString:(NSString *)searchString
{
    if (searchString != _searchString){
        _searchString = [searchString copy];
        self.targetRA = nil;
        self.targetDec = nil;
        if (_searchString.length){
            CASObjectLookup* lookup = [CASObjectLookup new];
            [lookup cachedLookupObject:_searchString withCompletion:^(CASObjectLookupResult *result) {
                if (result.foundIt && [_searchString isEqualToString:searchString]){
                    self.targetRA = @(result.ra);
                    self.targetDec = @(result.dec);
                }
            }];
        }
    }
}

- (void)findLocationAndSlew:(BOOL)slew // todo; check the mount is in its last park position
{
    if (!self.mountController.cameraController){
        NSLog(@"Camera controller must be set before finding location");
        return;
    }
    self.slewAfterFindLocation = slew;
    self.synchroniser = [[CASMountSynchroniser alloc] init];
    self.synchroniser.mountController = self.mountController;
    self.synchroniser.delegate = self;
    [self.synchroniser findLocation];
}

#pragma mark - Bindings convenience

- (id)mount
{
    return self.mountController.mount; // only called from bindings
}

+ (NSSet*)keyPathsForValuesAffectingMount
{
    return [NSSet setWithObject:@"mountController"];
}

#pragma mark - Bookmarks

- (NSArray*)bookmarks
{
    NSMutableArray* bookmarks = [CASBookmarks.sharedInstance.bookmarks mutableCopy];
    
    // gather all current solutions from the registry
    NSMutableArray<CASPlateSolveSolution*>* solutions = [NSMutableArray array];
    [[CASPlateSolveSolutionRegistery sharedRegistry].solutions enumerateObjectsUsingBlock:^(CASPlateSolveSolution * _Nonnull solution, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary* solutionDictionary = solution.solutionDictionary;
        if (solutionDictionary){
            [solutions addObject:solution];
        }
    }];

    // record the count
    self.solutionBookmarkCount = solutions.count;

    // prepend the bookmarks array with the solutions and add a separator
    if (self.solutionBookmarkCount > 0){
        // todo; use camera id rather than 'Solution'
        [solutions enumerateObjectsUsingBlock:^(CASPlateSolveSolution* solution, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString* name = [NSString stringWithFormat:NSLocalizedString(@"Solution (%@, %@)", @"Solution (%@, %@)"),solution.displayCentreRA,solution.displayCentreDec];
            NSDictionary* bookmark = @{CASBookmarks.nameKey:name,CASBookmarks.solutionDictionaryKey:solution.solutionDictionary};
            [bookmarks insertObject:bookmark atIndex:idx];
        }];
        [bookmarks insertObject:@{CASBookmarks.nameKey:@"<separator>"} atIndex:1];
    }
    
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
    if (index == -1){
        return;
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

- (void)bookmarksChanged:note
{
    [self willChangeValueForKey:@"bookmarks"];
    [self didChangeValueForKey:@"bookmarks"];
}

#pragma mark - Mount/Camera

- (CASCameraController*)cameraController // this should only be used by bindings
{
    return self.mountController.cameraController;
}

+ (NSSet*)keyPathsForValuesAffectingCameraController
{
    return [NSSet setWithObject:@"mountController.cameraController"];
}

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

- (void)flagsChanged:(NSEvent *)event
{
    [super flagsChanged:event];
    
    if ((event.modifierFlags & NSEventModifierFlagOption) != 0){
        [self.syncButton setTitle:NSLocalizedString(@"Auto", @"Auto")];
    }
    else {
        [self.syncButton setTitle:NSLocalizedString(@"Sync", @"Sync")];
    }
}

#pragma mark - Actions

- (IBAction)sync:(id)sender
{
    if (([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagOption) != 0){
        [self findLocationAndSlew:NO];
    }
    else {
        
        // get the selected bookmark
        NSNumber* ra = self.targetRA;
        NSNumber* dec = self.targetDec;
        if (ra && dec){
            const NSModalResponse response = [[NSAlert alertWithMessageText:NSLocalizedString(@"Confirm Sync", @"Confirm Sync")
                                                              defaultButton:NSLocalizedString(@"Sync", @"Sync")
                                                            alternateButton:NSLocalizedString(@"Cancel", @"Cancel")
                                                                otherButton:nil
                                                  informativeTextWithFormat:NSLocalizedString(@"Confirm that you want to sync the mount to this target", @"Confirm that you want to sync the mount to this target")] runModal];
            if (response == NSOKButton){
                [self.mountController.mount fullSyncToRA:ra.doubleValue dec:dec.doubleValue completion:^(CASMountSlewError error) {
                    if (error != CASMountSlewErrorNone){
                        [self presentAlertWithMessage:NSLocalizedString(@"Failed to sync the mount", @"Failed to sync the mount")];
                    }
                    else {
                        self.synced = YES;
                        [self presentAlertWithMessage:NSLocalizedString(@"The mount is now synced to the sky", @"The mount is now synced to the sky")];
                    }
                }];
            }
        }
        else {
            [self presentAlertWithMessage:NSLocalizedString(@"You must select a bookmark or perform a lookup before syncing the mount", @"You must select a bookmark or perform a lookup before syncing the mount")];
        }
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
        NSLog(@"No target location has been set");
        return;
    }
    
    // check synced, offer to find location and then slew
    if (!self.synced){
        
        // check can slew without sync flag
        
        const NSInteger response = [[NSAlert alertWithMessageText:NSLocalizedString(@"Sync Mount", @"Sync Mount")
                                                    defaultButton:NSLocalizedString(@"Sync", @"Sync")
                                                  alternateButton:NSLocalizedString(@"Slew", @"Slew")
                                                      otherButton:NSLocalizedString(@"Cancel", @"Cancel")
                                        informativeTextWithFormat:NSLocalizedString(@"The mount should be synced before slewing. Press Sync to sync the mount first.", @"The mount should be synced before slewing. Press Sync to sync the mount first.")] runModal];
        if (response == -1){
            return;
        }
        
        if (response == 1){
            [self findLocationAndSlew:YES];
            return;
        }
    }
    
    // slew to the current target location
    __weak __typeof (self) weakSelf = self;
    [self.mountController setTargetRA:self.targetRA.doubleValue dec:self.targetDec.doubleValue completion:^(NSError* error) {
        if (error){
            [NSApp presentError:error];
        }
        else {
            const BOOL usePlateSolving = weakSelf.mountController.usePlateSolving;
            [weakSelf.mountController slewToTargetWithCompletion:^(NSError* error) {
                if (error){
                    [NSApp presentError:error];
                }
                else {
                    if (usePlateSolving){
                        self.synced = YES;
                    }
                }
            }];
        }
    }];
}

- (IBAction)stop:(id)sender
{
    self.slewAfterFindLocation = NO;
    
    [self.mountController stop];
}

- (IBAction)park:(id)sender
{
    [self parkWithCompletion:^(NSError *error) {}];
}

- (IBAction)lookup:(id)sender
{
    if (![self.searchString length] || self.lookup){
        NSBeep();
        return;
    }
    
    self.targetRA = nil;
    self.targetDec = nil;
    
    // check for something that looks like an ra/dec
    NSString* text = self.searchString;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"(-?[\\d])+" options:0 error:nil];
    NSArray<NSTextCheckingResult*>* matches = [regex matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    if (matches.count >= 4){
        
        self.targetRA = @(15*([[text substringWithRange:matches[0].range] doubleValue] +
                              [[text substringWithRange:matches[1].range] doubleValue]/60.0 +
                              [[text substringWithRange:matches[2].range] doubleValue]/3600.0));
        
        const double decDegrees = [[text substringWithRange:matches[3].range] doubleValue];
        const double decMinutes = matches.count > 4 ? [[text substringWithRange:matches[4].range] doubleValue] : 0;
        const double decSeconds = matches.count > 5 ? [[text substringWithRange:matches[5].range] doubleValue] : 0;
        self.targetDec = @((decDegrees < 0 ? -1 : 1) * (fabs(decDegrees) + decMinutes/60.0 + decSeconds/3600));
        
        return;
    }
    
    [self.lookupSpinner startAnimation:nil];
    
    self.lookup = [CASObjectLookup new];
    [self.lookup lookupObject:self.searchString withCompletion:^(CASObjectLookupResult* result) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.lookup = nil;
            
            [self.lookupSpinner stopAnimation:nil];
            
            if (!result.foundIt){
                [[NSAlert alertWithMessageText:NSLocalizedString(@"Not Found", @"Not Found")
                                 defaultButton:NSLocalizedString(@"OK", @"OK")
                               alternateButton:nil
                                   otherButton:nil
                     informativeTextWithFormat:NSLocalizedString(@"Target couldn't be found", @"Target couldn't be found")] runModal];
            }
            else {
                NSLog(@"Found %@",result.object);
                self.lastSearchString = self.searchString;
                self.targetRA = @(result.ra);
                self.targetDec = @(result.dec);
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
        [[NSAlert alertWithMessageText:NSLocalizedString(@"No Target Set", @"No Target Set")
                         defaultButton:NSLocalizedString(@"OK", @"OK")
                       alternateButton:nil
                           otherButton:nil
             informativeTextWithFormat:NSLocalizedString(@"No mount target has been set via a successful lookup", @"No mount target has been set via a successful lookup")] runModal];
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
    [self closeWindow:sender];
}

// todo; we should really embed the config UI in the main window in the Mount section
- (IBAction)mountButtonPressed:(NSButton*)sender
{
    NSViewController* configure = self.mountController.mount.configurationViewController;
    if (!configure){
        [self presentAlertWithMessage:NSLocalizedString(@"This mount doesn't provide a configuration UI", @"This mount doesn't provide a configuration UI")];
    }
    else {
        self.mountPopover = [[NSPopover alloc] init];
        self.mountPopover.delegate = self;
        self.mountPopover.contentViewController = configure;
        self.mountPopover.behavior = NSPopoverBehaviorTransient;
        [self.mountPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMaxXEdge];
    }
}

#pragma mark - Mount sync delegate

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCaptureExposure:(CASCCDExposure*)exposure
{
    // todo; same code as in mount controller, find location should probably be in there
    NSDictionary* userInfo = exposure ? @{@"exposure":exposure} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASMountControllerCapturedSyncExposureNotification object:self.mountController userInfo:userInfo];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didSolveExposure:(CASPlateSolveSolution*)solution
{
    // todo; same code as in mount controller, find location should probably be in there
    NSDictionary* userInfo = solution ? @{@"solution":solution} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASMountControllerSolvedSyncExposureNotification object:self.mountController userInfo:userInfo];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCompleteWithError:(NSError*)error
{
    if (error){
        [NSApp presentError:error];
    }
    else {
        self.synced = YES;
        if (self.slewAfterFindLocation){
            [self slew:nil];
        }
        else {
            [self presentAlertWithMessage:NSLocalizedString(@"The mount is now synced to the sky", @"The mount is now synced to the sky")];
        }
    }
    
    self.synchroniser = nil;
}

- (void)mountSynchroniserDidSyncMount:(CASMountSynchroniser*)mountSynchroniser
{
    // or should this just be a state on the mount controller ?
    self.synced = YES;
}

#pragma mark - Popover delegate

- (void)popoverDidClose:(NSNotification *)notification
{
    self.mountPopover = nil;
}

#pragma mark - Window delegate

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    // force the bookmarks menu to redraw in case the associated window controller has a current plate solution
    // todo; this is a workaround, we should bind to the mount window delegate somehow
    [self bookmarksChanged:nil];
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
        completion([NSError errorWithDomain:NSStringFromClass([self class])
                                       code:5
                                   userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"No serial port has been selected", @"No serial port has been selected")}]);
        return;
    }
    
    if (port.isOpen){
        completion([NSError errorWithDomain:NSStringFromClass([self class])
                                       code:9
                                   userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Selected serial port is already open", @"Selected serial port is already open")}]);
        return;
    }
    
    CASMount* mount;
    switch (self.selectedMountType) {
        case 0:
            mount = [[CASAPGTOMount alloc] initWithSerialPort:port];
            break;
        case 1:
            mount = [[iEQMount alloc] initWithSerialPort:port];
            break;
        case 2:
            mount = [[CASSimulatedMount alloc] initWithSerialPort:port];
            break;
        default:
            completion([NSError errorWithDomain:NSStringFromClass([self class])
                                           code:10
                                       userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Unrecognised mount type", @"Unrecognised mount type")}]);
            return;
    }
    
    if (mount.slewing){
        completion([NSError errorWithDomain:NSStringFromClass([self class])
                                       code:6
                                   userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Mount is slewing. Please try again when it's stopped", @"Mount is slewing. Please try again when it's stopped")}]);
        return;
    }
    
    [self connectToMount:mount completion:^(NSError* error) {
        if (error){
            [port close];
            completion(error);
        }
        else {
            
            [self showWindow:nil];
            
            CASMountController* mountController = [[CASMountController alloc] initWithMount:mount];
            [[CASDeviceManager sharedManager] addMountController:mountController];
            self.mountController = mountController;
            
            completion(nil);
        }
    }];
}

- (void)connect:(void(^)())completion
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
                        [NSApp presentError:error];
                    }
                    else {
                        completion();
                    }
                }];
            }
        }];
    }
}

- (void)connectAtPath:(NSString*)path completion:(void(^)(NSError*,CASMountController*))completion
{
    NSParameterAssert(completion);
    
    //    // check to see if we're already connected to this mount
    //    if ([self.mountController.mount respondsToSelector:@selector(port)]){
    //        ORSSerialPort* port = [self.mountController.mount valueForKey:@"port"];
    //        if ([port.path isEqualToString:path]){
    //            // completion(nil,self.mountController); // except this seems to cause the make applevent handler to be called again ?
    //            NSError* error = [NSError errorWithDomain:NSStringFromClass([self class]) code:9 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Mount '%@' already connected",self.mountController.mount.deviceName]}];
    //            completion(error,nil);
    //        }
    //        return;
    //    }
    
    // enforce a single mount connected policy
    if (self.mountController.mount){
        NSError* error = [NSError errorWithDomain:NSStringFromClass([self class])
                                             code:8
                                         userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:NSLocalizedString(@"The mount window is already connected to the mount '%@'", @"The mount window is already connected to the mount '%@'"),self.mountController.mount.deviceName]}];
        completion(error,nil);
        return;
    }
    
    ORSSerialPort* port = [[ORSSerialPortManager sharedSerialPortManager].availablePorts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"path == %@",path]].firstObject;
    if (!port){
        completion([NSError errorWithDomain:NSStringFromClass([self class])
                                       code:7
                                   userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:NSLocalizedString(@"There is no serial port with the path '%@'", @"There is no serial port with the path '%@'"),path]}],nil);
    }
    else {
        [self connectToMountWithPort:port completion:^(NSError* error) {
            completion(error,self.mountController);
        }];
    }
}

- (void)parkWithCompletion:(void(^)(NSError*))completion
{
    __weak __typeof (self) weakSelf = self;
    
    // this won't work if the mount was externally parked e.g. via a sequence or scripting
    [self.mountController parkMountWithCompletion:^(NSError *error) {
        if (error != nil){
            completion(error);
            [NSApp presentError:error];
        }
        else {
            // this is a rather arbitrary delay to allow the park mode command to make it to the mount and have an effect
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf disconnectButtonPressed:nil];
                [weakSelf presentAlertWithMessage:NSLocalizedString(@"The mount is now parked", @"The mount is now parked")]; // this blocks, want it to auto-dismiss
                completion(error);
            });
        }
    }];
}

@end

