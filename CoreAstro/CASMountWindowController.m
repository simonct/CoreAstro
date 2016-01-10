//
//  CASMountWindowController.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMountWindowController.h"
#import "SXIOPlateSolveOptionsWindowController.h" // for +focalLengthWithCameraKey:
#if defined(SXIO)
#import "SX_IO-Swift.h"
#import "SXIOAppDelegate.h"
#else
#import "CCD_IO-Swift.h"
#endif
#if defined(SXIO) || defined(CCDIO)
#import "SXIOAppDelegate.h"
#import "SXIOCameraWindowController.h"
#endif
#import <CoreAstro/CoreAstro.h>
#import <CoreAstro/ORSSerialPortManager.h>

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

@interface CASMountWindowController ()<CASMountMountSynchroniserDelegate>
@property (nonatomic,strong) CASMount* mount;
@property (nonatomic,strong) CASMountController* mountController;
@property (nonatomic,copy) NSString* searchString;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSPopUpButton *cameraPopupButton;
@property (nonatomic,readonly) NSArray* cameraControllers;
@property (strong) IBOutlet NSArrayController *camerasArrayController;
@property (nonatomic) CASCameraController* selectedCameraController;
@property (nonatomic,strong) CASMountSynchroniser* mountSynchroniser;
@property (weak) IBOutlet NSTextField *pierSideLabel;
@property (strong) IBOutlet NSPanel *morePanel;
@property (strong) IBOutlet NSWindow *mountConnectWindow;
@property (weak) ORSSerialPort* selectedSerialPort;
@property (strong) ORSSerialPortManager* serialPortManager;
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

- (instancetype)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.mountSynchroniser = [CASMountSynchroniser new];
        self.mountSynchroniser.delegate = self;
    }
    return self;
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
    if (self.mountSynchroniser.busy){
        // need a way of cancelling a solve
        NSLog(@"Currently solving...");
        return;
    }
    
    if (self.mountSynchroniser.busy){
        [self.mountSynchroniser cancel];
    }
    [self.mount disconnect];
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromWindowMenu:self];
#endif
    
    [self cleanup];

    [self close];
}

- (void)cleanup
{
    [[CASDeviceManager sharedManager] removeMountController:self.mountController];
    self.mountController = nil;
    
    // check this is being called...
    [self.mount disconnect];
    self.mount = nil; // unbinds
    
    self.mountSynchroniser = nil; // unbinds
}

- (void)close
{
    [super close];

    [self.mountWindowDelegate mountWindowControllerDidClose:self];
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
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
    if (!self.mount.connected || self.mount.slewing){
        return;
    }
    [self selectBookmarkAtIndex:sender.indexOfSelectedItem];
}

- (BOOL)selectBookmarkAtIndex:(NSInteger)index
{
    if (index != -1){
        NSDictionary* bookmark = [self.bookmarks objectAtIndex:index];
        CASPlateSolveSolution* solution = [CASPlateSolveSolution solutionWithDictionary:bookmark[CASBookmarks.solutionDictionaryKey]];
        if (solution){
            [self setTargetRA:solution.centreRA dec:solution.centreDec];
        }
        else {
            [self setTargetRA:[bookmark[CASBookmarks.centreRaKey] doubleValue] dec:[bookmark[CASBookmarks.centreDecKey] doubleValue]];
        }
        return YES;
    }
    return NO;
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
        self.mountSynchroniser.cameraController = cameraController;
        if (!_cameraController){
            self.mountWindowDelegate = nil;
        }
        else{
            NSString* const focalLengthKey = [SXIOPlateSolveOptionsWindowController focalLengthWithCameraKey:_cameraController];
            NSNumber* focalLength = [[NSUserDefaults standardUserDefaults] objectForKey:focalLengthKey];
            if ([focalLength isKindOfClass:[NSNumber class]]){
                self.mountSynchroniser.focalLength = [focalLength floatValue];
            }
            
#if defined(SXIO) || defined(CCDIO)
            SXIOCameraWindowController* cameraWindowController = (SXIOCameraWindowController*)[[SXIOAppDelegate sharedInstance] findWindowController:cameraController];
            if ([cameraWindowController isKindOfClass:[SXIOCameraWindowController class]]){

                self.mountWindowDelegate = (id)cameraWindowController;
                CASPlateSolveSolution* solution = cameraWindowController.exposureView.plateSolveSolution;
                if (solution){
                    // todo; check to see we're not slewing, etc
                    [self setTargetRA:solution.centreRA dec:solution.centreDec];
                }
            }
#endif
        }
    }
}

- (void)setMountSynchroniser:(CASMountSynchroniser *)mountSynchroniser
{
    if (mountSynchroniser != _mountSynchroniser){
        [_mountSynchroniser removeObserver:self forKeyPath:@"focalLength" context:&kvoContext];
        _mountSynchroniser = mountSynchroniser;
        [_mountSynchroniser addObserver:self forKeyPath:@"focalLength" options:0 context:&kvoContext];
    }
}

- (BOOL)usePlateSolving
{
    return self.mountSynchroniser.usePlateSolving; // todo; need to refactor here, too much muddled logic shared between this and the synchroniser
}

- (void)setUsePlateSolving:(BOOL)usePlateSolving
{
    self.mountSynchroniser.usePlateSolving = usePlateSolving;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if (object == _cameraController && [keyPath isEqualToString:@"focalLength"]){
            NSString* const focalLengthKey = [SXIOPlateSolveOptionsWindowController focalLengthWithCameraKey:_cameraController];
            [[NSUserDefaults standardUserDefaults] setObject:@(self.mountSynchroniser.focalLength) forKey:focalLengthKey];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)connectToMount:(CASMount*)mount completion:(void(^)(NSError*))completion
{
    self.mount = mount;
    self.mountSynchroniser.mount = mount;
    
#if CAS_SLEW_AND_SYNC_TEST
    _testError = 1;
#endif

    [self.mount connect:^(NSError* error){
        if (self.mount.connected){
            [self.window makeKeyAndOrderFront:nil];
        }
        if (completion){
            completion(error);
        }
    }];
}

- (void)setTargetRA:(double)raDegs dec:(double)decDegs
{
    NSParameterAssert(self.mount.connected);
    NSParameterAssert(!self.mount.slewing);

    __weak __typeof (self) weakSelf = self;
    [self.mount setTargetRA:raDegs dec:decDegs completion:^(CASMountSlewError error) {
        if (error != CASMountSlewErrorNone){
            [weakSelf presentAlertWithMessage:[NSString stringWithFormat:@"Set target failed with error %ld",error]];
        }
    }];
}

- (BOOL)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees error:(NSError**)error
{
    NSParameterAssert(self.mount.connected);

    if (!self.usePlateSolving){
        [self.mount startSlewToRA:raInDegrees dec:decInDegrees completion:^(CASMountSlewError error) {
            if (error != CASMountSlewErrorNone){
                NSLog(@"*** start slew failed: %ld",(long)error);
                // call slew completion block
            }
        }];
    }
    else {
        
        if (!self.selectedCameraController){
            NSLog(@"*** No camera selected");
            return NO;
        }
        
        [self.selectedCameraController cancelCapture]; // todo; belongs in mountSynchroniser ?
        
        self.mountSynchroniser.mount = self.mount; // redundant ?
        self.mountSynchroniser.cameraController = self.selectedCameraController;
        self.mountSynchroniser.delegate = self;

        [self.mountSynchroniser startSlewToRA:raInDegrees dec:decInDegrees]; // this calls its delegate on completion
    }
    
    return YES;
}

- (void)startMoving:(CASMountDirection)direction
{
//    NSLog(@"startMoving: %ld",direction);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving) object:nil];
    [self performSelector:@selector(stopMoving) withObject:nil afterDelay:0.25];
    [self.mount startMoving:direction];
}

- (void)stopMoving
{
//    NSLog(@"stopMoving");
    [self.mount stopMoving];
}

- (BOOL)slewToTargetWithError:(NSError**)error
{
    if (!self.mount.targetRa || !self.mount.targetDec){
        if (error){
            *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:3 userInfo:@{NSLocalizedDescriptionKey:@"No slew target is set"}];
        }
        return NO;
    }
    if (!self.mount.connected || self.mount.slewing){
        if (error){
            *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:4 userInfo:@{NSLocalizedDescriptionKey:@"Mount is busy"}];
        }
        return NO;
    }
    
    [self startSlewToRA:[self.mount.targetRa doubleValue] dec:[self.mount.targetDec doubleValue] error:nil];
    
    return YES;
}

#pragma mark - Actions

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
    [self slewToTargetWithError:nil];
}

- (IBAction)stop:(id)sender
{
    if (self.mountSynchroniser.mount){
        [self.mountSynchroniser cancel];
    }
    else {
        [self.mount halt];
    }
}

- (IBAction)home:(id)sender
{
    [self.mount gotoHomePosition];
}

- (IBAction)park:(id)sender
{
    [self.mount park];
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
            
            [weakSelf setTargetRA:ra dec:dec]; // probably not - do this when slew commanded as the mount may be busy ?
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

- (void)presentAlertWithTitle:(NSString*)title message:(NSString*)message
{
    [[NSAlert alertWithMessageText:title
                     defaultButton:nil
                   alternateButton:nil
                       otherButton:nil
         informativeTextWithFormat:@"%@",message] runModal];
}

- (IBAction)connectPressed:(id)sender
{
    [self.window endSheet:self.mountConnectWindow returnCode:NSModalResponseContinue];
}

- (IBAction)cancelPressed:(id)sender
{
    [self.window endSheet:self.mountConnectWindow returnCode:NSModalResponseCancel];
}

#pragma mark - Mount Synchroniser delegate

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCaptureExposure:(CASCCDExposure*)exposure
{
    [self.mountWindowDelegate mountWindowController:self didCaptureExposure:exposure];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didSolveExposure:(CASPlateSolveSolution*)solution
{
    [self.mountWindowDelegate mountWindowController:self didSolveExposure:solution];
}

- (void)mountSynchroniser:(CASMountSynchroniser*)mountSynchroniser didCompleteWithError:(NSError*)error
{
    // call slew completion block
    
    [self.mountWindowDelegate mountWindowController:self didCompleteWithError:error];
}

@end

@implementation CASMountWindowController (Sequence)

- (void)slewToBookmarkWithName:(NSString*)name completion:(void(^)(NSError*))completion
{
    if (!self.mount.connected || self.mount.slewing){
        if (completion){
            completion([NSError errorWithDomain:NSStringFromClass([self class]) code:1 userInfo:@{NSLocalizedDescriptionKey:@"Mount is busy"}]);
        }
        return;
    }
    
    NSDictionary* bookmark;
    NSArray* bookmarks = CASBookmarks.sharedInstance.bookmarks;
    
    for (NSDictionary* bm in bookmarks){
        if ([bm[CASBookmarks.nameKey] isEqualToString:name]){
            bookmark = bm;
            break;
        }
    }
    
    if (!bookmark){
        if (completion){
            completion([NSError errorWithDomain:NSStringFromClass([self class]) code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"No such bookmark '%@'",name]}]);
        }
    }
    else {
        
        self.mountSynchroniser.usePlateSolving = YES; // or pass in as a param ?
        
        if ([self selectBookmarkAtIndex:[bookmarks indexOfObject:bookmark]]){
            NSError* error;
            [self slewToTargetWithError:&error];
            if (error && completion){
                completion(error);
                return;
            }
            // need to be able to call completion block when the slew completes
        }
    }
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
    
    self.mount = [[CASAPGTOMount alloc] initWithSerialPort:port];
    
    if (self.mount.slewing){
        self.mount = nil;
        completion([NSError errorWithDomain:NSStringFromClass([self class]) code:6 userInfo:@{NSLocalizedDescriptionKey:@"Mount is slewing. Please try again when it's stopped"}]);
        return;
    }
    
    [self connectToMount:self.mount completion:^(NSError* error) {
        if (error){
            self.mount = nil;
            completion(error);
        }
        else {
            [self.window makeKeyAndOrderFront:nil];
            self.mountController = [[CASMountController alloc] initWithMount:self.mount]; // todo; this should be the property, not the mount
            [[CASDeviceManager sharedManager] addMountController:self.mountController];
            completion(nil);
        }
    }];
}

- (void)connectToMount:(void(^)())completion
{
    NSParameterAssert(completion);

    [self.window makeKeyAndOrderFront:nil]; // because we need to present a sheet
    
    if (self.mount){
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
                        self.mount = nil;
                        [self.window orderOut:nil];
                        [self presentAlertWithTitle:nil message:[error localizedDescription]];
                    }
                    else {
                        if (completion){
                            completion();
                        }
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
    if (self.mount){
        NSError* error = [NSError errorWithDomain:NSStringFromClass([self class]) code:8 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"The mount window is already connected to the mount '%@'",self.mount.deviceName]}];
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