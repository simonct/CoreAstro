//
//  CASAPGTOGuidePort.m
//  guide-socket-test
//
//  Created by Simon Taylor on 27/05/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import "CASAPGTOGuidePort.h"

#import <AppKit/AppKit.h>
#import <sys/socket.h>
#import <sys/un.h>

@interface CASAPGTOGuidePort ()
@property (strong) NSFileHandle* listenHandle;
@property (strong) NSFileHandle* readHandle;
@property (strong) NSArray* observers;
@property (strong) NSRegularExpression* regex;
@end

@implementation CASAPGTOGuidePort {
    int _socket;
}

- (instancetype)initWithDelegate:(id<CASAPGTOGuidePortDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        self.delegate = delegate;
        
        self.regex = [NSRegularExpression regularExpressionWithPattern:@"([A-Z]) ([0-9]+)\\#" options:NSRegularExpressionCaseInsensitive error:nil];
        if (!self.regex){
            return nil;
        }
        
        if (![self createSocket]){
            return nil;
        }
        
        if (![self listen]){
            return nil;
        }
        
        [self accept];
    }
    return self;
}

- (void)dealloc
{
    if (_socket > 0) {
        close(_socket);
    }
    [self.observers enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [[NSNotificationCenter defaultCenter] removeObserver:obj];
    }];
}

- (BOOL)createSocket
{
    if (_socket > 0){
        return YES;
    }
    
    const char* path = "/tmp/sxio-apgto-guider";
    
    struct sockaddr_un sa;
    sa.sun_family = AF_UNIX;
    strcpy(sa.sun_path, path);
    sa.sun_len = SUN_LEN(&sa);
    unlink(path);
    
    _socket = socket(AF_UNIX, SOCK_STREAM, 0);
    if (_socket == -1){
        perror("CASAPGTOGuidePort");
        return NO;
    }
    
    const int result = bind(_socket, (struct sockaddr*)&sa, (socklen_t)SUN_LEN(&sa));
    if (result == -1){
        perror("CASAPGTOGuidePort");
        return NO;
    }
    
    return YES;
}

- (BOOL)listen
{
    NSMutableArray* mobs = [NSMutableArray arrayWithCapacity:2];
    
    id obs = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleConnectionAcceptedNotification
                                                               object:nil
                                                                queue:[NSOperationQueue mainQueue]
                                                           usingBlock:^(NSNotification * _Nonnull note) {
                                                               
                                                               if (self.readHandle != nil) {
                                                                   NSLog(@"Closed existing read socket");
                                                                   [self.readHandle closeFile];
                                                                   self.readHandle = nil;
                                                               }
                                                               
                                                               self.readHandle = note.userInfo[NSFileHandleNotificationFileHandleItem];
                                                               [self.readHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]];
                                                               
                                                               NSLog(@"reading");
                                                               
                                                               [self accept];
                                                           }];
    [mobs addObject:obs];
    
    obs = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadCompletionNotification
                                                            object:nil
                                                             queue:[NSOperationQueue mainQueue]
                                                        usingBlock:^(NSNotification * _Nonnull note) {
                                                            
                                                            NSData* payload = [note userInfo][NSFileHandleNotificationDataItem];
                                                            if (payload.length > 0) {
                                                                [self handleMessage:[[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding]];
                                                                [self.readHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]];
                                                            }
                                                        }];
    [mobs addObject:obs];
    
    self.observers = [mobs copy];
    
    const int result = listen(_socket, 0);
    if (result == -1){
        perror("CASAPGTOGuidePort");
        return NO;
    }
    
    self.listenHandle = [[NSFileHandle alloc] initWithFileDescriptor:_socket closeOnDealloc:YES];
    
    NSLog(@"CASAPGTOGuidePort listening: %d",_socket);
    
    return YES;
}

- (void)accept
{
    [self.listenHandle acceptConnectionInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]]; 
    
    NSLog(@"CASAPGTOGuidePort accepting");
}

- (void)handleMessage:(NSString*)message
{
    // todo; accumulate, find matches, process matches
    NSLog(@"CASAPGTOGuidePort read: '%@'",message);
    
    NSArray<NSTextCheckingResult *> *matches = [self.regex matchesInString:message options:0 range:NSMakeRange(0, message.length)];
    if (matches.count == 0){
        NSLog(@"CASAPGTOGuidePort: Unrecognised message");
    }
    else {
        [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if (obj.numberOfRanges == 3) {
                NSString* direction = [message substringWithRange:[obj rangeAtIndex:1]];
                const NSInteger milliseconds = [[message substringWithRange:[obj rangeAtIndex:2]] integerValue];
                NSLog(@"direction = %@",direction);
                NSLog(@"milliseconds = %ld",milliseconds);
                [self.delegate pulseInDirection:0 ms:milliseconds];
            }
            else {
                NSLog(@"CASAPGTOGuidePort: Badly formatted message");
            }
        }];
    }
}

@end
