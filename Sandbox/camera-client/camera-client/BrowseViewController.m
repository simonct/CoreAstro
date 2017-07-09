//
//  Browse.m
//  camera-client
//
//  Created by Simon Taylor on 31/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "BrowseViewController.h"
#import "SXIORemoteControl.h"
@import MultipeerConnectivity;

@interface BrowseViewController ()<MCNearbyServiceBrowserDelegate>
@property (strong) NSMutableArray* peers;
@end

@implementation BrowseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Browse";
    self.peers = [NSMutableArray arrayWithCapacity:5];
    
    [[SXIORemoteControl sharedControl] start];
    
    [SXIORemoteControl sharedControl].browser.delegate = self;
    [[SXIORemoteControl sharedControl].browser startBrowsingForPeers];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.peers count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Browse"];
    if (!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Browse"];
    }
    
    cell.textLabel.text = [self.peers[indexPath.row] displayName];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MCPeerID* peer = self.peers[indexPath.row];
    NSLog(@"Inviting peer %@",peer); // detect completion in didChangeState
    [[SXIORemoteControl sharedControl].browser invitePeer:peer toSession:[SXIORemoteControl sharedControl].session withContext:nil timeout:0];
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    [self.peers addObject:peerID];
    [self.tableView reloadData];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    [self.peers removeObject:peerID];
    [self.tableView reloadData];
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"didNotStartBrowsingForPeers: %@",error);
}

@end
