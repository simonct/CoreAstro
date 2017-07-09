//
//  MountDetailViewController.h
//  camera-client
//
//  Created by Simon Taylor on 08/07/2017.
//  Copyright (c) 2017 Simon Taylor. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MultipeerConnectivity;

@interface MountDetailViewController : UIViewController
@property (strong) MCPeerID* peerID;
@property (strong) MCSession* session;
@property (nonatomic,strong) NSDictionary* mount;
@end
