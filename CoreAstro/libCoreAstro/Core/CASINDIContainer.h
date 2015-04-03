//
//  CASINDIContainer.h
//  indi-client
//
//  Created by Simon Taylor on 4/3/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

@interface CASINDIDevice : NSObject
@property (copy) NSString* name;
@property (nonatomic,strong) NSMutableDictionary* vectors;
// CASXMLSocketClient ?
@end

@interface CASINDIVector : NSObject
// type eg. text. number, etc
@property (copy) NSString* name;
@property (copy) NSString* label;
@property (copy) NSString* group;
@property (copy) NSString* state;
@property (weak) CASINDIDevice* device;
@property (copy) NSString* type;
@property (copy) NSString* rule;
@property (nonatomic,strong) NSMutableDictionary* items; // CASINDIValue
@property (nonatomic,readonly) NSArray* switches;
- (instancetype)initWithXMLElement:(NSXMLElement*)xmlElement device:(CASINDIDevice*)device;
- (NSString*)setVector:(NSString*)name to:(id)newValue;
// delegate ?
// kvo for values ?
extern NSString* const kCASINDIDefinedVectorNotification;
extern NSString* const kCASINDIUpdatedVectorNotification;
@end

@interface CASINDIValue : NSObject
@property (copy) NSString* name;
@property (copy) NSString* label;
@property (copy) NSString* value;
@property (weak) CASINDIVector* vector;
// state, perm, etc
@end

@interface CASINDIContainer : NSObject<CASXMLSocketClientDelegate>
- (instancetype)init;
- (instancetype)initWithService:(NSNetService*)service;
@property (strong) CASXMLSocketClient* client;
@property (strong) NSMutableArray* devices;
@property BOOL connected;
extern NSString* const kCASINDIContainerAddedDeviceNotification;
@end

@class CASINDIServiceBrowser;

@protocol CASINDIServiceBrowserDelegate <NSObject>
- (void)serviceBrowser:(CASINDIServiceBrowser*)browser didResolveService:(NSNetService*)service;
@end

@interface CASINDIServiceBrowser : NSObject
@property (weak) id<CASINDIServiceBrowserDelegate> delegate;
@end