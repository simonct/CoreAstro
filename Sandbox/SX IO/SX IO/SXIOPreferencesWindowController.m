//
//  SXIOPreferencesWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/7/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "SXIOPreferencesWindowController.h"
#import <CoreAstro/CoreAstro.h>
#import <CoreLocation/CoreLocation.h>

@interface SXIOPreferencesWindowController ()
@property (nonatomic,strong) CASPlateSolver* solver;
@property (nonatomic,assign) NSInteger fileFormatIndex;
@property (weak) IBOutlet NSTextField *locationLabel;
@property (nonatomic,strong) CLLocationManager* locationManager;
@end

@implementation SXIOPreferencesWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.solver = [CASPlateSolver plateSolverWithIdentifier:nil];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSButton* closeButton = [self.window standardWindowButton:NSWindowCloseButton];
    [closeButton setTarget:self];
    [closeButton setAction:@selector(close:)];
}

- (NSInteger)fileFormatIndex
{
    NSString* format = [[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"];
    if ([@"png" isEqualToString:format]){
        return 1;
    }
    return 0; // fits
}

- (void)setFileFormatIndex:(NSInteger)fileFormatIndex
{
    if (fileFormatIndex == 0){
        [[NSUserDefaults standardUserDefaults] setObject:@"fits" forKey:@"SXIODefaultExposureFileType"];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setObject:@"png" forKey:@"SXIODefaultExposureFileType"];
    }
}

- (IBAction)close:sender
{
    [self close];
    [self.locationManager stopUpdatingLocation];
    self.locationManager = nil;
}

- (IBAction)updatePressed:(id)sender
{
    if (!self.locationManager){
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = (id)self;
    }
    CLLocation* location = self.locationManager.location;
    if (location){
        [self handleLocationUpdate:location];
    }
    [self.locationManager startUpdatingLocation];
}

- (IBAction)clearPressed:(id)sender
{
    [self.locationManager stopUpdatingLocation];
    self.locationManager = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SXIOSiteLatitude"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SXIOSiteLongitude"];
    self.locationLabel.stringValue = @"";
}

- (void)handleLocationUpdate:(CLLocation*)location
{
    if (location){
        [[NSUserDefaults standardUserDefaults] setDouble:location.coordinate.latitude forKey:@"SXIOSiteLatitude"];
        [[NSUserDefaults standardUserDefaults] setDouble:location.coordinate.longitude forKey:@"SXIOSiteLongitude"];
    }
}

- (void)locationManager:(CLLocationManager *)manager
	didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation
{
    [self handleLocationUpdate:newLocation];
}

- (void)locationManager:(CLLocationManager *)manager
	 didUpdateLocations:(NSArray *)locations
{
    [self handleLocationUpdate:[locations lastObject]];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLog(@"locationManager:didChangeAuthorizationStatus: %u",status);
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    NSLog(@"locationManager:didFailWithError: %@",error);
}

// todo; utilities to download plate solving indexes
// todo; background plate solving option

@end
