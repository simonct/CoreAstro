//
//  MountDetailViewController.m
//  camera-client
//
//  Created by Simon Taylor on 08/07/2017.
//  Copyright (c) 2017 Simon Taylor. All rights reserved.
//

#import "MountDetailViewController.h"
#import "SXIORemoteControl.h"
#import "CASLX200Commands.h"

@interface MountDetailViewController ()
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UILabel *raLabel;
@property (weak, nonatomic) IBOutlet UILabel *decLabel;
@property (weak, nonatomic) IBOutlet UILabel *altLabel;
@property (weak, nonatomic) IBOutlet UILabel *azLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl *rateSegmentControl;
@property (weak, nonatomic) IBOutlet UIButton *northButton;
@property (weak, nonatomic) IBOutlet UIButton *eastButton;
@property (weak, nonatomic) IBOutlet UIButton *southButton;
@property (weak, nonatomic) IBOutlet UIButton *westButton;
@property (strong) CASLX200RATransformer* raTransformer;
@property (strong) CASLX200DecTransformer* decTransformer;
@end

@implementation MountDetailViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Mount";
    
    self.raTransformer = [[CASLX200RATransformer alloc] init];
    self.decTransformer = [[CASLX200DecTransformer alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusChanged:) name:kSXIORemoteControlMountStatusChangedNotification object:nil];
    
    for (UIButton* button in @[self.northButton,self.southButton,self.eastButton,self.westButton]) {
        [button addTarget:self action:@selector(touchDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(touchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(touchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
    }
}

- (IBAction)touchDown:(id)sender {
    if (sender == self.northButton) {
        [[SXIORemoteControl sharedControl] moveMount:_mount[@"id"] inDirection:1];
    }
    else if (sender == self.eastButton) {
        [[SXIORemoteControl sharedControl] moveMount:_mount[@"id"] inDirection:2];
    }
    else if (sender == self.southButton) {
        [[SXIORemoteControl sharedControl] moveMount:_mount[@"id"] inDirection:3];
    }
    else if (sender == self.westButton) {
        [[SXIORemoteControl sharedControl] moveMount:_mount[@"id"] inDirection:4];
    }
}

- (IBAction)touchUpInside:(id)sender {
    [self stop:sender];
}

- (IBAction)touchUpOutside:(id)sender {
    [self stop:sender];
}

- (IBAction)stop:(id)sender {
    [[SXIORemoteControl sharedControl] stopMountMove:_mount[@"id"]];
}

- (IBAction)rateSegmentControlChanged:(id)sender {
    [[SXIORemoteControl sharedControl] setMount:_mount[@"id"] moveRate:self.rateSegmentControl.selectedSegmentIndex + 1];
}

- (void)statusChanged:(NSNotification*)note
{
    NSAssert([NSThread isMainThread], @"statusChanged");
    
    NSDictionary* msg = [note userInfo];
    if ([[_mount[@"id"] description] isEqualToString:[msg[@"id"] description]]){
        [self processMountStatus:msg];
    }
}

- (void)processMountStatus:(NSDictionary*)status
{
    NSAssert([NSThread isMainThread], @"processMountStatus");

    // todo; formatters
    self.raLabel.text = [self.raTransformer transformedValue:status[@"ra"]];
    self.decLabel.text = [self.decTransformer transformedValue:status[@"dec"]];
    self.altLabel.text = [self.decTransformer transformedValue:status[@"alt"]];
    self.azLabel.text = [self.decTransformer transformedValue:status[@"az"]];
    
    NSNumber* movingRate = status[@"movingRate"];
    if (movingRate){
        self.rateSegmentControl.enabled = YES;
        self.rateSegmentControl.selectedSegmentIndex = [movingRate integerValue] - 1;
    }
    else {
        self.rateSegmentControl.enabled = NO;
        self.rateSegmentControl.selectedSegmentIndex = 0;
    }
    
    NSString* statusText;
    
    if ([status[@"tracking"] boolValue]){
        statusText = @"Tracking";
    }
    else if ([status[@"slewing"] boolValue]){
        statusText = @"Slewing";
    }
    else {
        statusText = @"Stopped";
    }
    
    if ([status[@"pierSide"] integerValue] == 1){
        statusText = [NSString stringWithFormat:@"%@, E", statusText];
    }
    else if ([status[@"pierSide"] integerValue] == 2) {
        statusText = [NSString stringWithFormat:@"%@, W", statusText];
    }
    
    if ([status[@"weightsHigh"] boolValue]){
        statusText = [NSString stringWithFormat:@"%@, WH", statusText];
    }
    
    self.statusLabel.text = statusText;
}

- (void)setMount:(NSDictionary *)mount
{
    if (mount != _mount){
        _mount = mount;
        self.title = _mount[@"name"];
        if (_mount){
            [[SXIORemoteControl sharedControl] mountStatusWithMount:_mount[@"id"] completion:^(NSError *error, NSDictionary *response) {
                if (!error){
                    [self processMountStatus:response[@"status"]];
                }
            }];
        }
    }
}

@end
