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
    return @"";
}

@end

@interface CASMountWindowController ()
@property (nonatomic,strong) CASMountController* mountController;
@property (nonatomic,copy) NSString* searchString;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSPopUpButton *cameraPopupButton;
@property (nonatomic,readonly) NSArray* cameraControllers;
@property (strong) IBOutlet NSArrayController *camerasArrayController;
@property (nonatomic) CASCameraController* selectedCameraController;
@property (strong) IBOutlet NSPanel *morePanel;
@property (strong) IBOutlet NSWindow *mountConnectWindow;
@property (weak) ORSSerialPort* selectedSerialPort;
@property (strong) ORSSerialPortManager* serialPortManager;
@property (copy) void(^slewCompletion)(NSError*);
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
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self];
#endif
    
    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(closeWindow:)];
    
    self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
    self.selectedSerialPort = [self.serialPortManager.availablePorts firstObject];
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

- (void)close
{
    [self.mountWindowDelegate mountWindowControllerWillClose:self];

    [self cleanup];

    [super close];
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

#pragma mark - Bookmarks

- (NSArray*)bookmarks
{
    NSArray* bookmarks = CASBookmarks.sharedInstance.bookmarks;
    
    // if the delegate has a solution, add that as a temp bookmark (would be nice to be able to add a separator but we're using bindings atm)
    // todo; pick up changes in the delegate's solution
    CASPlateSolveSolution* solution = self.mountWindowDelegate.plateSolveSolution;
    if (solution){
        NSDictionary* solutionDictionary = solution.solutionDictionary;
        if (solutionDictionary){
            NSString* name = [NSString stringWithFormat:@"Current Solution (%@, %@)",solution.displayCentreRA,solution.displayCentreDec];
            NSDictionary* bookmark = @{CASBookmarks.nameKey:name,CASBookmarks.solutionDictionaryKey:solutionDictionary};
            bookmarks = [bookmarks arrayByAddingObject:bookmark];
        }
    }
    
    return bookmarks;
}

- (IBAction)didSelectBookmark:(NSPopUpButton*)sender
{
    if (!self.mountController.mount.connected || self.mountController.mount.slewing){
        return;
    }
    [self selectBookmarkAtIndex:sender.indexOfSelectedItem];
}

- (void)selectBookmarkAtIndex:(NSInteger)index
{
    void (^completion)(NSError*) = ^(NSError* error){
        if (error){
            [NSApp presentError:error];
        }
    };
    
    if (index != -1){
        NSDictionary* bookmark = [self.bookmarks objectAtIndex:index];
        CASPlateSolveSolution* solution = [CASPlateSolveSolution solutionWithDictionary:bookmark[CASBookmarks.solutionDictionaryKey]];
        if (solution){
            [self.mountController setTargetRA:solution.centreRA dec:solution.centreDec completion:completion];
        }
        else {
            [self.mountController setTargetRA:[bookmark[CASBookmarks.centreRaKey] doubleValue] dec:[bookmark[CASBookmarks.centreDecKey] doubleValue] completion:completion];
        }
    }
}

#pragma mark - Mount/Camera

- (NSArray*)cameraControllers
{
    return [CASDeviceManager sharedManager].cameraControllers;
}

- (CASCameraController*) selectedCameraController
{
    if (_cameraController){
        return _cameraController;
    }
    return self.camerasArrayController.selectedObjects.firstObject;
}

+ (NSSet*)keyPathsForValuesAffectingSelectedCameraController
{
    return [NSSet setWithObject:@"cameraController"];
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    if (cameraController != _cameraController){
        _cameraController = cameraController;
        self.mountController.cameraController = cameraController;
        if (!_cameraController){
            self.mountWindowDelegate = nil;
        }
        else{
            
#if defined(SXIO) || defined(CCDIO)
            SXIOCameraWindowController* cameraWindowController = (SXIOCameraWindowController*)[[SXIOAppDelegate sharedInstance] findWindowController:cameraController];
            if ([cameraWindowController isKindOfClass:[SXIOCameraWindowController class]]){

                self.mountWindowDelegate = (id)cameraWindowController;
                /*
                CASPlateSolveSolution* solution = cameraWindowController.exposureView.plateSolveSolution;
                if (solution){
                    // todo; check to see we're not slewing, etc
                    [self.mountController setTargetRA:solution.centreRA dec:solution.centreDec];
                }
                */
            }
#endif
        }
    }
}

- (BOOL)usePlateSolving
{
    return self.mountController.usePlateSolving; // todo; need to refactor here, too much muddled logic shared between this and the synchroniser
}

- (void)setUsePlateSolving:(BOOL)usePlateSolving
{
    self.mountController.usePlateSolving = usePlateSolving;
}

- (void)startMoving:(CASMountDirection)direction
{
//    NSLog(@"startMoving: %ld",direction);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving) object:nil];
    [self performSelector:@selector(stopMoving) withObject:nil afterDelay:0.25];
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
    NSLog(@"Sync - not implemented");
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
    [self.mountController slewToTargetWithCompletion:^(NSError* error) {
        if (error){
            [self presentAlertWithMessage:error.localizedDescription];
        }
    }];
}

- (IBAction)stop:(id)sender
{
    [self.mountController stop];
}

- (IBAction)home:(id)sender
{
    [self.mountController.mount gotoHomePosition];
}

- (IBAction)park:(id)sender
{
    [self.mountController.mount park];
}

- (IBAction)lookup:(id)sender
{
    if (![self.searchString length]){
        NSBeep();
        return;
    }
    
    __weak __typeof (self) weakSelf = self;
    
    CASObjectLookup* lookup = [CASObjectLookup new];
    [lookup lookupObject:self.searchString withCompletion:^(BOOL success,NSString*objectName,double ra, double dec) {
        if (!success){
            [[NSAlert alertWithMessageText:@"Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Target couldn't be found"] runModal];
        }
        else{
            // todo; cache locally for offline access ?
            
            // add bookmark
            [self willChangeValueForKey:@"bookmarks"];
            [CASBookmarks.sharedInstance addBookmark:self.searchString ra:ra dec:dec];
            [self didChangeValueForKey:@"bookmarks"];
            
            [weakSelf.mountController setTargetRA:ra dec:dec completion:^(NSError* error) { // probably not - do this when slew commanded as the mount may be busy ?
                if (error){
                    [NSApp presentError:error];
                }
            }];
        }
    }];
}

- (IBAction)more:(id)sender
{
    [self.window beginSheet:self.morePanel completionHandler:^(NSModalResponse returnCode) {
        NSLog(@"CASMountWindowControllerBinning %@",[[NSUserDefaultsController sharedUserDefaultsController].defaults objectForKey:@"CASMountWindowControllerBinning"]);
        NSLog(@"CASMountWindowControllerDuration %@",[[NSUserDefaultsController sharedUserDefaultsController].defaults objectForKey:@"CASMountWindowControllerDuration"]);
    }];
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
            [self.window makeKeyAndOrderFront:nil];
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
            [self.window makeKeyAndOrderFront:nil];
            self.mountController = [[CASMountController alloc] initWithMount:mount]; // todo; this should be the property, not the mount
            [[CASDeviceManager sharedManager] addMountController:self.mountController];
            completion(nil);
        }
    }];
}

- (void)connectToMount:(void(^)())completion
{
    NSParameterAssert(completion);

    [self.window makeKeyAndOrderFront:nil]; // because we need to present a sheet
    
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
                [self.window orderOut:nil];
            }
            else {
                
                [self connectToMountWithPort:self.selectedSerialPort completion:^(NSError* error) {
                    if (error){
                        [self.window orderOut:nil];
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