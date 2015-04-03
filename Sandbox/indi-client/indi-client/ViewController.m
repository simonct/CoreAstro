//
//  ViewController.m
//  indi-client
//
//  Created by Simon Taylor on 3/15/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "ViewController.h"
#import "CASINDIContainer.h"

@interface ViewController ()<CASINDIServiceBrowserDelegate>
@property (strong) CASINDIContainer* container;
@property (strong) CASINDIServiceBrowser* browser;
@property float exposureTime;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.exposureTime = 1;
    
    self.browser = [CASINDIServiceBrowser new];
    self.browser.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceAdded:) name:kCASINDIContainerAddedDeviceNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vectorDefined:) name:kCASINDIDefinedVectorNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vectorUpdated:) name:kCASINDIUpdatedVectorNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)serviceBrowser:(CASINDIServiceBrowser*)browser didResolveService:(NSNetService*)service
{
    if (self.container){
        NSLog(@"Found another INDI container but I've already got one so ignoring for now: %@",service);
        return;
    }
    
    self.container = [[CASINDIContainer alloc] initWithService:service];
    if (![self.container connect]){
        NSLog(@"Failed to connect to %@",service);
    }
    else {
        NSLog(@"Added INDI container: %@",self.container);
        self.view.window.title = [NSString stringWithFormat:@"%@:%ld",service.hostName,service.port];
    }
}

- (void)serviceBrowser:(CASINDIServiceBrowser*)browser didRemoveService:(NSNetService*)service
{
    if ([service isEqual:self.container.service]){
        self.container = nil;
        self.view.window.title = @"Disconnected";
    }
}

- (void)deviceAdded:(NSNotification*)note
{
    CASINDIDevice* device = note.userInfo[@"device"];
    NSLog(@"deviceAdded: %@",device.name);
}

- (void)vectorDefined:(NSNotification*)note
{
    CASINDIVector* vector = note.object;
    NSLog(@"vectorDefined: %@.%@",vector.device.name,vector.name);
}

- (void)vectorUpdated:(NSNotification*)note
{
    CASINDIVector* vector = note.object;
    CASINDIValue* value = note.userInfo[@"value"];
    if ([vector.type isEqualToString:@"BLOB"]){
        NSLog(@"vectorUpdated: %@.%@[%@=%ld]",vector.device.name,vector.name,value.name,value.value.length);
        //if ([vector.state isEqualToString:@"Ok"]){
            NSData* encodedData = [value.value dataUsingEncoding:NSASCIIStringEncoding];
            NSData* exposureData = [[NSData alloc] initWithBase64EncodedData:encodedData options:NSDataBase64DecodingIgnoreUnknownCharacters];
            NSLog(@"read %ld bytes, decoded to %ld bytes",encodedData.length,exposureData.length);
            [exposureData writeToFile:[@"~/Desktop/indi-image.fit" stringByExpandingTildeInPath] atomically:YES];
        //}
    }
    else {
        NSLog(@"vectorUpdated: %@.%@[%@=%@]",vector.device.name,vector.name,value.name,value.value);
    }
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"exposureTime" isEqualToString:key]){
        self.exposureTime = 0;
        return;
    }
    [super setNilValueForKey:key];
}

- (IBAction)connect:(id)sender
{
    CASINDIVector* vector = ((CASINDIDevice*)self.container.devices.firstObject).vectors[@"CONNECTION"];
    [vector setValue:@"CONNECT" to:@YES];
}

- (IBAction)exposure:sender
{
    if (self.exposureTime < 0.001){
        NSBeep();
        return;
    }
    
    // set blob mode
    NSString* cmd = [NSString stringWithFormat:@"<enableBLOB device='SX CCD SuperStar'>Also</enableBLOB>"];
    [self.container.client enqueue:[cmd dataUsingEncoding:NSUTF8StringEncoding]];

    cmd = [NSString stringWithFormat:@"<newNumberVector device='SX CCD SuperStar' name='CCD_EXPOSURE'><oneNumber name='CCD_EXPOSURE_VALUE'>%f</oneNumber></newNumberVector>",self.exposureTime];
    [self.container.client enqueue:[cmd dataUsingEncoding:NSUTF8StringEncoding]];
}

- (IBAction)dump:(id)sender
{
    void (^dumpVector)(CASINDIVector*) = ^(CASINDIVector*vector){
        NSLog(@"\t%@: %@",vector.type,vector.name);
        [vector.items enumerateKeysAndObjectsUsingBlock:^(id key, CASINDIValue* value, BOOL *stop) {
            NSLog(@"\t\t%@: %@",value.name,value.value);
        }];
    };
    
    [self.container.devices enumerateObjectsUsingBlock:^(CASINDIDevice* device, NSUInteger idx, BOOL *stop) {
        NSLog(@"Device: %@",device.name);
        [device.vectors enumerateKeysAndObjectsUsingBlock:^(id key, CASINDIVector* vector, BOOL *stop) {
            dumpVector(vector);
        }];
    }];
}

@end
