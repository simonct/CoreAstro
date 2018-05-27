//
//  SXIOSkyMapWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 30/09/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import "SXIOSkyMapWindowController.h"
#import "CASSkyMapView.h"
#import "NSApplication+CASScripting.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOSkyMapViewController : NSViewController
@property (weak) IBOutlet CASSkyMapView *skyMapView;
@property (strong) IBOutlet NSArrayController *mountsController;
@property (nonatomic,weak) CASMountController* selectedMountController;
@end

@implementation SXIOSkyMapViewController

static void* kvoContext;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.skyMapView.showsRaDec = YES;
        
    NSString* path = [[NSBundle mainBundle] pathForResource:@"stars-6.00" ofType:@"plist"];
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (data){
        NSArray* stars = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
        if ([stars isKindOfClass:[NSArray class]]){
            [stars enumerateObjectsUsingBlock:^(NSArray*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                const double ra = [obj[7] doubleValue] * 15;
                const double dec = [obj[8] doubleValue];
                const double mag = [obj[10] doubleValue];
                [self.skyMapView addStarAtRA:ra dec:dec mag:mag];
            }];
        }
    }
}

- (NSArray*)mountControllers
{
    return [NSApplication sharedApplication].mountControllers;
}

- (void)setSelectedMountController:(CASMountController *)selectedMountController
{
    [_selectedMountController.mount removeObserver:self forKeyPath:@"ra" context:&kvoContext];
    [_selectedMountController.mount removeObserver:self forKeyPath:@"dec" context:&kvoContext];

    _selectedMountController = selectedMountController;

    [_selectedMountController.mount addObserver:self forKeyPath:@"ra" options:0 context:&kvoContext];
    [_selectedMountController.mount addObserver:self forKeyPath:@"dec" options:0 context:&kvoContext];
    
    if (!_selectedMountController){
        self.skyMapView.showsScope = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if (object == self.selectedMountController.mount){
            NSNumber* ra = self.selectedMountController.mount.ra;
            NSNumber* dec = self.selectedMountController.mount.dec;
            if (ra && dec){
                [self.skyMapView setScopeRA:[ra doubleValue] dec:[dec doubleValue]];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

@interface SXIOSkyMapWindowController ()
@property (weak) IBOutlet SXIOSkyMapViewController *skyMapViewController;
@end

@implementation SXIOSkyMapWindowController

+ (SXIOSkyMapWindowController*)sharedController
{
    static SXIOSkyMapWindowController* _shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [NSStoryboard storyboardWithName:@"SXIOSkyMapWindowController" bundle:nil].instantiateInitialController;
    });
    return _shared;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
}

@end
