//
//  ViewController.m
//  indi-client
//
//  Created by Simon Taylor on 3/15/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "ViewController.h"
#import "CASSocketClient.h"

@interface ViewController ()<CASXMLSocketClientDelegate>
@property (strong) CASXMLSocketClient* client;
@end

//@interface CASINDIClientRequest : CASSocketClientRequest
//@end
//
//@implementation CASINDIClientRequest
//
//- (NSUInteger) readCount
//{
//    return INT_MAX;
//}
//
//- (BOOL)appendResponseData:(NSData*)data
//{
//    BOOL complete = [super appendResponseData:data];
//
//    // look for terminate char
//    NSLog(@"%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
//
//    return complete;
//}
//
//@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.client = [CASXMLSocketClient new];
    self.client.delegate = self;
    self.client.host = [NSHost hostWithName:@"localhost"];
    self.client.port = 7624;
    
    if (![self.client connect]){
        NSLog(@"Failed to connect");
    }
    else {        
        CASSocketClientRequest* request = [CASSocketClientRequest new];
        request.data = [@"<getProperties version='1.7'/>\n" dataUsingEncoding:NSUTF8StringEncoding];
        request.completion = ^(NSData* response){
            NSLog(@"%@",[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
        };
        [self.client enqueueRequest:request];
    }
}

- (void)client:(CASXMLSocketClient*)client receivedDocument:(NSXMLDocument*)document
{
    NSLog(@"receivedDocument: %@",document);
}

@end
