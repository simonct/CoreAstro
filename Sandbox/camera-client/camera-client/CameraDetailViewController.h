//
//  CameraViewController.h
//  camera-client
//
//  Created by Simon Taylor on 27/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MultipeerConnectivity;

@interface CameraDetailViewController : UIViewController
@property (strong) MCPeerID* peerID;
@property (strong) MCSession* session;
@property (nonatomic,strong) NSDictionary* camera;
@end
