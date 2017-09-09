//
//  CASINDIFactory.m
//  indi-client
//
//  Created by Simon Taylor on 03/09/17.
//  Copyright (c) 2017 Simon Taylor. All rights reserved.
//

#import "CASINDIFactory.h"
#import "CASINDICamera.h"

@interface CASINDIFactory ()<CASINDIServiceBrowserDelegate>
@property (strong) CASINDIContainer* serviceContainer;
@property (strong) CASINDIServiceBrowser* serviceBrowser;
@end

@implementation CASINDIFactory {
    CASExternalSDKCallback _deviceAdded;
    CASExternalSDKCallback _deviceRemoved;
}

@synthesize deviceAdded = _deviceAdded;
@synthesize deviceRemoved = _deviceRemoved;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)scan
{
    if (self.serviceBrowser){
        return;
    }
    
    self.serviceBrowser = [[CASINDIServiceBrowser alloc] init];
    self.serviceBrowser.delegate = self;
}

#pragma mark - Browser delegate

- (void)serviceBrowser:(CASINDIServiceBrowser*)browser didResolveService:(NSNetService*)service
{
    if (self.serviceContainer){
        NSLog(@"Found another INDI container but I've already got one so ignoring for now: %@",service);
        return;
    }
    
    self.serviceContainer = [[CASINDIContainer alloc] initWithService:service];
    if (![self.serviceContainer connect]){
        NSLog(@"Failed to connect to %@",service);
    }
    else {
        NSLog(@"Added INDI container: %@",self.serviceContainer);
    }
    
    // no, the device needs to post a notification when it becomes a camera ?
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceAdded:) name:kCASINDIContainerAddedDeviceNotification object:self.serviceContainer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraConnected:) name:kCASINDIContainerCameraConnectedNotification object:nil];
}

- (void)serviceBrowser:(CASINDIServiceBrowser*)browser didRemoveService:(NSNetService*)service
{
    if ([service isEqual:self.serviceContainer.service]){
        self.serviceContainer = nil;
    }
    
    // remove all cameras
}

- (void)deviceAdded:(NSNotification*)notification
{
    CASINDIDevice* device = notification.userInfo[@"device"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"Connecting");
        [device connect];
    });
}

- (void)cameraConnected:(NSNotification*)notification
{
    CASINDIDevice* device = notification.userInfo[@"camera"];
    if ([device conformsToProtocol:@protocol(CASINDICamera)]){
        CASINDICamera* camera = [[CASINDICamera alloc] initWithDevice:(CASINDIDevice<CASINDICamera>*)device];
        self.deviceAdded(@"",camera);
    }
}

@end
