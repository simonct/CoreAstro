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
#import <MapKit/MapKit.h>

@interface CASSiteAnnotation : NSObject<MKAnnotation>
@end

@implementation CASSiteAnnotation

- (CLLocationCoordinate2D)coordinate
{
    return CLLocationCoordinate2DMake([[NSUserDefaults standardUserDefaults] doubleForKey:@"SXIOSiteLatitude"], [[NSUserDefaults standardUserDefaults] doubleForKey:@"SXIOSiteLongitude"]);
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    [[NSUserDefaults standardUserDefaults] setDouble:newCoordinate.latitude forKey:@"SXIOSiteLatitude"];
    [[NSUserDefaults standardUserDefaults] setDouble:newCoordinate.longitude forKey:@"SXIOSiteLongitude"];
}

@end

@interface SXIOPreferencesWindowController ()<MKMapViewDelegate,NSPopoverDelegate>
@property (nonatomic,strong) CASPlateSolver* solver;
@property (nonatomic,assign) NSInteger fileFormatIndex;
@property (weak) IBOutlet NSTextField *locationLabel;
@property (nonatomic,strong) CLLocationManager* locationManager;
@property (strong) NSPopover* popover;
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
    if (self.locationManager.location){
        [self handleLocationUpdate:self.locationManager.location];
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

- (IBAction)mapPressed:(NSButton*)sender // actually do this as click and hold on the update button
{
    if (self.popover){
        return;
    }
    
    if (![MKMapView class]){
        [[NSAlert alertWithMessageText:@"Unavailable" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Map views are only available on 10.9 and higher"] runModal];
    }
    else {
        
        NSViewController* vc = [[NSViewController alloc] initWithNibName:nil bundle:nil];
        MKMapView* mapView = [[MKMapView alloc] init];
        mapView.delegate = self;
        vc.view = mapView;
        
        self.popover = [[NSPopover alloc] init];
        self.popover.delegate = self;
        self.popover.contentViewController = vc;
        self.popover.behavior = NSPopoverBehaviorTransient;
        self.popover.contentSize = CGSizeMake(300, 300);
        [self.popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMaxXEdge]; // poor choice, covers the lat/lon text fields
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CASSiteAnnotation* annot = [[CASSiteAnnotation alloc] init];
            mapView.centerCoordinate = annot.coordinate;
            [mapView addAnnotation:annot];
        });
    }
}

- (void)popoverDidClose:(NSNotification *)notification
{
    self.popover = nil;
}

- (nullable MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    // how to continuously update pin location ?
    MKPinAnnotationView* pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pin"];
    pin.pinTintColor = [MKPinAnnotationView redPinColor];
    pin.animatesDrop = YES;
    pin.draggable = YES;
    return pin;
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
//    NSLog(@"locationManager:didChangeAuthorizationStatus: %u",status);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"locationManager:didFailWithError: %@",error);
    
    [self.locationManager stopUpdatingLocation];
    self.locationManager = nil;
}

// todo; utilities to download plate solving indexes
// todo; background plate solving option

@end
