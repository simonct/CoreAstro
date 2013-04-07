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
@property (nonatomic,copy) NSString* slewRA;
@property (nonatomic,copy) NSString* slewDec;
@end

// HH:MM:SS
static NSString* CASHighPrecisionRA(double ra)
{
    const double trunc_ra = trunc(ra);
    
    const double h = trunc_ra;
    const double m = trunc((ra - trunc_ra)*60.0);
    const double s = (ra - trunc_ra)*60.0*60.0 - 60.0*m;
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d:%02d:%02d",(int)h,(int)m,(int)s];
    
    return formattedRA;
}

// HH:MM.T
static NSString* CASLowPrecisionRA(double ra)
{
    const double trunc_ra = trunc(ra);
    
    const double h = trunc_ra;
    const double m = (ra - trunc_ra)*60.0;
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d:%02.1f",(int)h,m];
    
    return formattedRA;
}

// DD*MM:SS
static NSString* CASHighPrecisionDec(double dec)
{
    const double trunc_dec = trunc(dec);
    
    const double h = trunc_dec;
    const double m = trunc((dec - trunc_dec)*60.0);
    const double s = (dec - trunc_dec)*60.0*60.0 - 60.0*m;
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d*%02d:%02d",(int)h,(int)m,(int)s];
    
    return formattedRA;
}

// DD*MM
static NSString* CASLowPrecisionDec(double dec)
{
    const double trunc_dec = trunc(dec);
    
    const double h = trunc_dec;
    const double m = (dec - trunc_dec)*60.0;
    
    NSString* formattedRA = [NSString stringWithFormat:@"%02d*%02d",(int)h,(int)m];
    
    return formattedRA;
}

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
        
        [self.client enqueue:[self.sendString dataUsingEncoding:NSASCIIStringEncoding] readCount:[self.sendString length] completion:^(NSData *response) {
            
            NSString* value = [[NSString alloc] initWithData:response encoding:NSASCIIStringEncoding];
            self.receiveTextLabel.stringValue = value ? value : @"Unknown response";
        }];
    }
}

- (IBAction)slew:(id)sender {
    
    if (self.client.connected && self.client.precision != CASEQMacClientPrecisionUnknown){
        
        NSString* formattedRA, *formattedDec;
        const double ra = [self.slewRA doubleValue];
        const double dec = [self.slewDec doubleValue];

        if (self.client.precision == CASEQMacClientPrecisionHigh){
            formattedRA = CASHighPrecisionRA(ra);
            formattedDec = CASHighPrecisionDec(dec);
        }
        else {
            formattedRA = CASLowPrecisionRA(ra);
            formattedDec = CASLowPrecisionDec(dec);
        }
        
        [self.client startSlewToRA:formattedRA dec:formattedDec completion:^(BOOL ok) {
            
            if (ok){
                NSLog(@"Slew started OK");
            }
            else {
                NSLog(@"Slew failed to start");
            }
        }];
    }
}

- (IBAction)halt:(id)sender {
    
    if (self.client.connected){
        
        [self.client halt];
    }
}

@end
