//
//  CASINDIContainer.h
//  indi-client
//
//  Created by Simon Taylor on 4/3/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

@interface CASINDIDevice : NSObject
@property (copy,readonly) NSString* name;
@property (nonatomic,strong,readonly) NSMutableDictionary* vectors;
// CASXMLSocketClient ?
@end

@interface CASINDIVector : NSObject
// type eg. text. number, etc
@property (copy,readonly) NSString* name;
@property (copy,readonly) NSString* label;
@property (copy,readonly) NSString* group;
@property (copy,readonly) NSString* state;
@property (weak,readonly) CASINDIDevice* device;
@property (copy,readonly) NSString* type;
@property (copy,readonly) NSString* rule;
@property (nonatomic,strong,readonly) NSMutableDictionary* items; // CASINDIValue
- (instancetype)initWithXMLElement:(NSXMLElement*)xmlElement device:(CASINDIDevice*)device;
- (NSString*)setVector:(NSString*)name to:(id)newValue;
// delegate ?
// kvo for values ?
extern NSString* const kCASINDIDefinedVectorNotification;
extern NSString* const kCASINDIUpdatedVectorNotification;
@end

@interface CASINDIValue : NSObject
@property (copy,readonly) NSString* name;
@property (copy,readonly) NSString* label;
@property (copy,readonly) NSString* value;
@property (weak,readonly) CASINDIVector* vector;
// state, perm, etc
@end

@interface CASINDIContainer : NSObject<CASXMLSocketClientDelegate>
- (instancetype)init;
- (instancetype)initWithService:(NSNetService*)service;
@property (strong,readonly) NSNetService* service;
@property (strong,readonly) CASXMLSocketClient* client;
@property (strong,readonly) NSMutableArray* devices;
@property (readonly) BOOL connected;
extern NSString* const kCASINDIContainerAddedDeviceNotification;
@end

@class CASINDIServiceBrowser;

@protocol CASINDIServiceBrowserDelegate <NSObject>
- (void)serviceBrowser:(CASINDIServiceBrowser*)browser didResolveService:(NSNetService*)service;
- (void)serviceBrowser:(CASINDIServiceBrowser*)browser didRemoveService:(NSNetService*)service;
@end

@interface CASINDIServiceBrowser : NSObject
@property (weak) id<CASINDIServiceBrowserDelegate> delegate;
@end