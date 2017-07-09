//
//  ViewController.m
//  camera-client
//
//  Created by Simon Taylor on 26/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "ViewController.h"
#import "SXIORemoteControl.h"
@import MultipeerConnectivity;

@interface ViewController ()<MCBrowserViewControllerDelegate>
@property (strong) UIViewController* devices;
@property (strong) MCBrowserViewController* browser;
@end

@implementation ViewController {
    BOOL _shownBrowser;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connected:) name:kSXIORemoteControlConnectedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disconnected:) name:kSXIORemoteControlConnectionLostNotification object:nil];
    
    [[SXIORemoteControl sharedControl] start];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!_shownBrowser){
        _shownBrowser = YES;
        [self browse:nil];
    }
}

- (void)connected:note
{
    [self completeBrowsing];
}

- (void)disconnected:note
{
    // tear down devices view controller
}

- (IBAction)browse:(id)sender
{
    if (self.browser){
        return;
    }
    
    self.browser = [[MCBrowserViewController alloc] initWithBrowser:[SXIORemoteControl sharedControl].browser
                                                            session:[SXIORemoteControl sharedControl].session];
    self.browser.delegate = self;
    self.browser.minimumNumberOfPeers = 0;
    self.browser.maximumNumberOfPeers = 1;
    [self presentViewController:self.browser animated:YES completion:nil];
}

- (void)completeBrowsing
{
    if (!self.browser || self.devices){
        return;
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        if ([[SXIORemoteControl sharedControl].session.connectedPeers count]){
            UIStoryboard* sb = [UIStoryboard storyboardWithName:@"Camera" bundle:nil];
            self.devices = [sb instantiateInitialViewController];
            [self presentViewController:self.devices animated:YES completion:nil];
        }
        self.browser = nil;
    }];
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController
{
    [self completeBrowsing];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController shouldPresentNearbyPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    return YES;
}

@end
