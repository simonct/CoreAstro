//
//  CameraListViewController.m
//  camera-client
//
//  Created by Simon Taylor on 29/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CameraListViewController.h"
#import "CameraDetailViewController.h"
#import "MountDetailViewController.h"
#import "SXIORemoteControl.h"
@import MultipeerConnectivity;

@interface CameraListViewController ()
@property (nonatomic,strong) NSArray* cameras;
@property (nonatomic,strong) NSArray* mounts;
@end

@implementation CameraListViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Devices";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraConnected:) name:kSXIORemoteControlCameraConnectedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraDisconnected:) name:kSXIORemoteControlCameraDisconnectedNotification object:nil];
    
    // mount connected/disconnected ?
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self reloadCameraList];
    [self reloadMountList];
}

- (void)reloadCameraList
{
    [[SXIORemoteControl sharedControl] listCameras:^(NSError *error, NSDictionary *response) {
        self.cameras = response[@"cameras"];
    }];
}

- (void)reloadMountList
{
    [[SXIORemoteControl sharedControl] listMounts:^(NSError *error, NSDictionary *response) {
        self.mounts = response[@"mounts"];
    }];
}

- (void)cameraConnected:(NSNotification*)note
{
    [self reloadCameraList];
}

- (void)cameraDisconnected:(NSNotification*)note
{
    NSDictionary* msg = [note userInfo];
    CameraDetailViewController* cvc = (CameraDetailViewController*)self.navigationController.topViewController;
    if ([cvc isKindOfClass:[CameraDetailViewController class]]){
        if ([[cvc.camera[@"id"] description] isEqualToString:[msg[@"id"] description]]){
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
    
    [self reloadCameraList];
}

- (void)setCameras:(NSArray *)cameras
{
    if (cameras != _cameras){
        _cameras = cameras;
        [self.tableView reloadData];
    }
}

- (void)setMounts:(NSArray *)mounts
{
    if (mounts != _mounts){
        _mounts = mounts;
        [self.tableView reloadData];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0){
        return @"Cameras";
    }
    if (section == 1){
        return @"Mounts";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0){
        return [self.cameras count];
    }
    if (section == 1){
        return [self.mounts count];
    }
    return 0;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Camera"];
    if (!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Camera"];
    }
    
    if (indexPath.section == 0){
        cell.textLabel.text = self.cameras[indexPath.row][@"name"];
    }
    if (indexPath.section == 1){
        cell.textLabel.text = self.mounts[indexPath.row][@"name"];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0){
        CameraDetailViewController* cvc = [self.storyboard instantiateViewControllerWithIdentifier:@"camera"];
        cvc.peerID = [[SXIORemoteControl sharedControl].session.connectedPeers firstObject];
        cvc.session = [SXIORemoteControl sharedControl].session;
        cvc.camera = self.cameras[self.tableView.indexPathForSelectedRow.row];
        [self.navigationController pushViewController:cvc animated:YES];
    }
    if (indexPath.section == 1){
        MountDetailViewController* mvc = [UIStoryboard storyboardWithName:@"Mount" bundle:nil].instantiateInitialViewController;
        mvc.peerID = [[SXIORemoteControl sharedControl].session.connectedPeers firstObject];
        mvc.session = [SXIORemoteControl sharedControl].session;
        mvc.mount = self.mounts[self.tableView.indexPathForSelectedRow.row];
        [self.navigationController pushViewController:mvc animated:YES];
    }
}

@end
