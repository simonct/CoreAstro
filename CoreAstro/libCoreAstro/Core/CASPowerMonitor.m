//
//  CASPowerMonitor.m
//  power-observer2
//
//  Created by Simon Taylor on 22/08/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASPowerMonitor.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

@interface CASPowerMonitor ()
@property BOOL onWallPower;
@end

@implementation CASPowerMonitor {
    CFRunLoopRef _runLoop;
    CFRunLoopSourceRef _runLoopSource;
    IOPMAssertionID _sleepAssertion;
    NSInteger _refCount;
}

static void CASPowerMonitorCallback(void *context)
{
    CASPowerMonitor* pm = (__bridge CASPowerMonitor *)(context);
    
    CFStringRef source = IOPSGetProvidingPowerSourceType(NULL);
    if (source){
        pm.onWallPower = [@"AC Power" isEqualToString:(__bridge NSString *)(source)];
        CFRelease(source);
    }
    
    if (!pm.onWallPower){
        // const IOPSLowBatteryWarningLevel level = IOPSGetBatteryWarningLevel();
        // NSLog(@"battery level: %u",level);
    }
    else {
        CFDictionaryRef extp = IOPSCopyExternalPowerAdapterDetails();
        if (extp) CFRelease(extp);
    }
}

+ (instancetype)sharedInstance
{
    static CASPowerMonitor* _shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [CASPowerMonitor new];
    });
    return _shared;
}

- (id)init
{
    self = [super init];
    if (self) {
        _runLoop = CFRunLoopGetMain();
        if (IOPSCreateLimitedPowerNotification){ // this is only on 10.9+
            _runLoopSource = IOPSCreateLimitedPowerNotification(CASPowerMonitorCallback,(__bridge void *)(self));
        }
        else {
            _runLoopSource = IOPSNotificationCreateRunLoopSource(CASPowerMonitorCallback,(__bridge void *)(self));
        }
        if (_runLoop && _runLoopSource){
            CFRunLoopAddSource(_runLoop,_runLoopSource,kCFRunLoopDefaultMode);
        }
        CASPowerMonitorCallback((__bridge void *)(self)); // get current power state
    }
    return self;
}

- (void)dealloc
{
    if (_runLoopSource && _runLoop){
        CFRunLoopRemoveSource(_runLoop,_runLoopSource,kCFRunLoopDefaultMode);
    }
    if (_runLoopSource){
        CFRelease(_runLoopSource);
    }
    [self releasePowerAssertion];
}

- (void)createPowerAssertion
{
    if (!_sleepAssertion){
        NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        NSString* assertionMessage = [NSString stringWithFormat:@"%@: capturing frames",appName];
        IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep, kIOPMAssertionLevelOn, (__bridge CFStringRef)(assertionMessage), &_sleepAssertion);
        NSLog(@"%@: Disabled idle sleep",NSStringFromClass([self class]));
    }
}

- (void)releasePowerAssertion
{
    if (_sleepAssertion){
        IOPMAssertionRelease(_sleepAssertion);
        _sleepAssertion = 0;
        NSLog(@"%@: Enabled idle sleep",NSStringFromClass([self class]));
    }
}

- (BOOL)disableSleep
{
    return (_sleepAssertion != 0);
}

- (void)setDisableSleep:(BOOL)disableSleep
{
    if (disableSleep){
        if (_refCount++ == 0){
            [self createPowerAssertion];
        }
    }
    else {
        if (--_refCount == 0){
            [self releasePowerAssertion];
        }
        NSAssert(_refCount >= 0,@"CASPowerMonitor ref count over decremented");
    }
}

@end
