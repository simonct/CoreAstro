//
//  SXIOAppDelegate.m
//  xpc-test
//
//  Created by Simon Taylor on 16/11/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOAppDelegate.h"

@protocol Echo <NSObject>

- (void)echo:(NSString*)string reply:(void(^)(NSString*))reply;

@end

@interface SXIOAppDelegate ()
@property (nonatomic,strong) NSMutableArray* connections;
@end

@implementation SXIOAppDelegate {
    BOOL _once;
}

- (IBAction)button:(id)sender {

    NSXPCConnection* connection;
    
    // work around the XPC limitation of one instance per service type by defining multiple service types
    // which all do the same thing. If the implemenation is all in a shared framework the size overhead may
    // be minimal. Obviously this would introduce a hard limit on the number of instances that could be run
    if (!_once){
        _once = YES;
        connection = [[NSXPCConnection alloc] initWithServiceName:@"org.coreastro.XPC-Test"];
    }
    else {
        connection = [[NSXPCConnection alloc] initWithServiceName:@"org.coreastro.XPC-Test-2"];
    }
    
    if (!self.connections){
        self.connections = [NSMutableArray arrayWithCapacity:5];
    }
    [self.connections addObject:connection];

    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Echo)];
    
    [connection resume];
    
    __weak NSXPCConnection* weakConnection = connection;
    connection.interruptionHandler = ^(){
        NSLog(@"interruptionHandler: %@",weakConnection.serviceName);
    };
    
    connection.invalidationHandler = ^(){
        NSLog(@"invalidationHandler: %@",weakConnection.serviceName);
    };
    
    id<Echo> proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        NSLog(@"remoteObjectProxyWithErrorHandler: %@",error);
    }];
    
    [proxy echo:@"Hello" reply:^(NSString* reply){
        NSLog(@"SXIOAppDelegate: %@",reply);
    }];
}

@end
