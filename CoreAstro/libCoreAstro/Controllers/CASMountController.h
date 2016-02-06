//
//  CASMountController.h
//  CoreAstro
//
//  Created by Simon Taylor on 1/9/16.
//  Copyright © 2016 Simon Taylor. All rights reserved.
//
//  This will eventually absorb most of the mount handling functionality
//  scattered about the app but for now its mainly just to enable scripting

#import "CASDeviceController.h"
#import "CASMount.h"

@interface CASMountController : CASDeviceController

- (instancetype)initWithMount:(CASMount*)mount;

@property (nonatomic,readonly,strong) CASDevice<CASMount>* mount;

@end
