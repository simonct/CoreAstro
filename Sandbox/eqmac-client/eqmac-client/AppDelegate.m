//
//  AppDelegate.m
//  eqmac-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "AppDelegate.h"
#import "CASEQMacClient.h"

@interface AppDelegate ()
@property (nonatomic,strong) CASEQMacClient* client;
@property (nonatomic,copy) NSString* sendString;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.client = [CASEQMacClient new];
    
    self.client.port = [CASEQMacClient standardPort];
    self.client.host = [NSHost hostWithName:@"localhost"];
    
    [self.client addObserver:self forKeyPath:@"connected" options:0 context:(__bridge void *)(self)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if (self.client.connected){
            NSLog(@"Connected");
            self.connectStatusImage.image = [NSImage imageNamed:@"ok.tiff"];
            self.connectStatusLabel.stringValue = @"Connected";
        }
        else if (self.client.error) {
            NSLog(@"Error connecting: %@",self.client.error);
            self.connectStatusImage.image = [NSImage imageNamed:@"fail.tiff"];
            self.connectStatusLabel.stringValue = [self.client.error localizedDescription];
        }
        else {
            self.connectStatusImage.image = [NSImage imageNamed:@"fail.tiff"];
            self.connectStatusLabel.stringValue = @"Not connected";
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)connectOrDisconnect:(NSButton*)sender {
    
    if (self.client.connected){
        [self.client disconnect];
        sender.title = @"Connect";
    }
    else {
        [self.client connect];
        sender.title = @"Disconnect";
    }
}

- (IBAction)send:(id)sender {
    
    if (self.client.connected && [self.sendString length]){
        
        NSLog(@"self.sendString: %@",self.sendString);
        
        [self.client enqueue:[self.sendString dataUsingEncoding:NSASCIIStringEncoding] completion:^(NSData *response) {
            
            NSString* value = [[NSString alloc] initWithData:response encoding:NSASCIIStringEncoding];
            self.receiveTextLabel.stringValue = value ? value : @"Unknown response";
        }];
    }
}

@end
