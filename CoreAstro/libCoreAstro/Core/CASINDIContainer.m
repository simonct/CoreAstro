//
//  CASINDIContainer.m
//  indi-client
//
//  Created by Simon Taylor on 4/3/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "CASINDIContainer.h"

@interface CASINDIDevice ()
@property (copy) NSString* name;
@property (nonatomic,strong) NSMutableDictionary* vectors;
@property (weak) CASINDIContainer* container;
@end

@implementation CASINDIDevice

- (NSMutableDictionary*)vectors
{
    if (!_vectors){
        _vectors = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    return _vectors;
}

@end

@interface CASINDGroup : NSObject
// type eg. text. number, etc
@property (copy) NSString* name;
@property (strong) NSMutableArray* items; // array of CASINDVector
@end

@implementation CASINDGroup
@end

@class CASINDIVector;

@interface CASINDIValue ()
@property (copy) NSString* name;
@property (copy) NSString* label;
@property (copy) NSString* value;
@property (weak) CASINDIVector* vector;
// state, perm, etc
@end

@implementation CASINDIValue
@end

@interface CASINDIVector ()
// type eg. text. number, etc
@property (copy) NSString* name;
@property (copy) NSString* label;
@property (copy) NSString* group;
@property (copy) NSString* state;
@property (weak) CASINDIDevice* device;
@property (copy) NSString* type;
@property (copy) NSString* perm;
@property (copy) NSString* rule;
@property (nonatomic,strong) NSMutableDictionary* items; // CASINDIValue
@end

@implementation CASINDIVector

NSString* const kCASINDIUpdatedVectorNotification = @"kCASINDIUpdatedVectorNotification";
NSString* const kCASINDIDefinedVectorNotification = @"kCASINDIDefinedVectorNotification";

- (instancetype)initWithXMLElement:(NSXMLElement*)xmlElement device:(CASINDIDevice*)device
{
    self = [super init];
    if (self){
        self.device = device;
        [self defineVector:xmlElement];
    }
    return self;
}

+ (instancetype)newVectorWithXMLElement:(NSXMLElement*)xmlElement device:(CASINDIDevice*)device
{
    return [[[self class] alloc] initWithXMLElement:xmlElement device:device];
}

- (NSMutableDictionary*) items
{
    if (!_items){
        _items = [NSMutableDictionary dictionaryWithCapacity:3];
    }
    return _items;
}

- (NSArray*) switches
{
    return nil; // all items of type Switch
}

// server sent an xml document defining a new vector for this device
- (void)defineVector:(NSXMLElement*)root
{
    self.name = [root attributeForName:@"name"].stringValue;
    self.label = [root attributeForName:@"label"].stringValue;
    self.group = [root attributeForName:@"group"].stringValue; // lookup/create group
    self.state = [root attributeForName:@"state"].stringValue;
    self.rule = [root attributeForName:@"rule"].stringValue;
    self.perm = [root attributeForName:@"perm"].stringValue;

    // extract the type from the xml element name
    NSMutableString* type = [root.name mutableCopy];
    [type deleteCharactersInRange:[type rangeOfString:@"def"]];
    [type deleteCharactersInRange:[type rangeOfString:@"Vector"]];
    self.type = type;
    
    [root.children enumerateObjectsUsingBlock:^(NSXMLElement* child, NSUInteger idx, BOOL *stop) {
        CASINDIValue* value = [CASINDIValue new];
        value.vector = self;
        value.name = [child attributeForName:@"name"].stringValue;
        value.label = [child attributeForName:@"label"].stringValue;
        value.value = [child.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.items[value.name] = value;
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kCASINDIDefinedVectorNotification object:self];
}

// server sent an xml document to update the value of an existing vector
- (void)updateVector:(NSXMLElement*)root
{
    [root.children enumerateObjectsUsingBlock:^(NSXMLElement* child, NSUInteger idx, BOOL *stop) {
        NSString* const name = [child attributeForName:@"name"].stringValue;
        CASINDIValue* value = self.items[name];
        if (!value){
            NSLog(@"Attempt to update undefined vector %@",name);
        }
        else {
            value.value = [child.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [[NSNotificationCenter defaultCenter] postNotificationName:kCASINDIUpdatedVectorNotification object:self userInfo:@{@"value":value}];
        }
    }];
}

- (NSString*)stringForValue:(id)value
{
    NSString* valueString;
    if ([self.type isEqualToString:@"Switch"]){
        valueString = [value boolValue] ? @"On" : @"Off";
    }
    else {
        valueString = [value description];
    }
    return valueString;
}

// we're sending a value to the server to change the value of a vector - currently the caller does this but we should probably let our contaning device do it
- (void)setValue:(NSString*)name to:(id)newValue
{
    CASINDIValue* value = self.items[name];
    if (!value){
        NSLog(@"No such value '%@'",name);
    }
    else {
        const BOOL isSwitch = [self.type isEqualToString:@"Switch"];
        NSMutableString* command = [[NSString stringWithFormat:@"<new%@Vector device='%@' name='%@'>",self.type,self.device.name,self.name] mutableCopy];
        if (!isSwitch || [self.rule isEqualToString:@"OneOfMany"]){
            [command appendFormat:@"<one%@ name='%@'>%@</one%@>",self.type,value.name,[self stringForValue:newValue],self.type];
        }
        else {
            NSString* const valueOn = [newValue boolValue] ? @"On" : @"Off";
            NSString* const valueOff = [newValue boolValue] ? @"Off" : @"On";
            [self.items enumerateKeysAndObjectsUsingBlock:^(id key, CASINDIValue* obj, BOOL *stop) {
                NSString* onOff = ([name isEqualToString:obj.name]) ? valueOn : valueOff;
                [command appendFormat:@"<one%@ name='%@'>%@</one%@>",self.type,obj.name,onOff,self.type];
            }];
        }
        [command appendString:[NSString stringWithFormat:@"</new%@Vector>",self.type]];
        
        [self.device.container.client enqueue:[command dataUsingEncoding:NSASCIIStringEncoding]];
    }
}

@end

@interface CASINDIContainer ()
@property (strong) NSNetService* service;
@property (strong) CASXMLSocketClient* client;
@property (strong) NSMutableArray* devices;
@property BOOL connected;
@end

@implementation CASINDIContainer

NSString* const kCASINDIContainerAddedDeviceNotification = @"kCASINDIContainerAddedDeviceNotification";

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.client = [CASXMLSocketClient new];
        self.client.delegate = self;
        self.client.host = [NSHost hostWithName:@"localhost"];
        self.client.port = 7624;
    }
    return self;
}

- (instancetype)initWithService:(NSNetService*)service
{
    self = [super init];
    if (self) {
        self.service = service;
        self.client = [CASXMLSocketClient new];
        self.client.delegate = self;
        self.client.host = [NSHost hostWithName:service.hostName ];
        self.client.port = service.port;
    }
    return self;
}

- (BOOL)connect
{
    const BOOL connected = [self.client connect];
    if (!connected){
        NSLog(@"Failed to connect to %@",self.client);
    }
    else {
        [self getProperties];
    }
    return connected;
}

- (void)getProperties
{
    [self.client enqueue:[@"<getProperties version='1.7'/>\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSString*)description
{
    if (!self.client){
        return [NSString stringWithFormat:@"%@: not connected",[super description]];
    }
    else {
        return [NSString stringWithFormat:@"%@: %@.%ld",[super description],self.client.host.name,self.client.port];
    }
}

- (void)client:(CASXMLSocketClient*)client receivedDocument:(NSXMLDocument*)document
{
    NSXMLElement* root = document.rootElement;
    
    NSString* deviceName = [root attributeForName:@"device"].stringValue;
    if (!deviceName){
        NSLog(@"No device name attribute");
        return;
    }
    NSString* rootName = [root attributeForName:@"name"].stringValue;
    if (!rootName){
        NSLog(@"No root name attribute");
        return;
    }
    
    // find/create device
    if (!self.devices){
        self.devices = [NSMutableArray arrayWithCapacity:5];
    }
    CASINDIDevice* device;
    for (CASINDIDevice* d in self.devices){
        if ([d.name isEqualToString:deviceName]){
            device = d;
            break;
        }
    }
    if (!device){
        device = [CASINDIDevice new];
        device.name = deviceName;
        device.container = self;
        [self.devices addObject:device];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCASINDIContainerAddedDeviceNotification object:self userInfo:@{@"device":device}];
    }
    
    // handle basic commands
    if ([@[@"defSwitchVector",@"defTextVector",@"defNumberVector",@"defBLOBVector",@"defLightVector"] containsObject:root.name]){
        CASINDIVector* vector = [CASINDIVector newVectorWithXMLElement:root device:device];
        if (vector){
            device.vectors[rootName] = vector;
        }
    }
    else if ([@[@"setSwitchVector",@"setTextVector",@"setNumberVector",@"setBLOBVector",@"setLightVector"] containsObject:root.name]){
        [device.vectors[rootName] updateVector:root];
    }
    else {
        NSLog(@"*** Unrecognised INDI command: %@",root.name);
    }
    
#if 0
    if ([root.name isEqualToString:@"setSwitchVector"]){
        CASINDIVector* vector = device.vectors[rootName];
        if (vector){
            [vector updateVector:root];
            if ([rootName isEqualToString:@"CONNECTION"]){
                CASINDIValue* value = vector.items[@"CONNECT"];
                self.connected = ([value.value isEqualToString:@"On"]);
                NSLog(@"_connected: %d",_connected);
            }
        }
    }
    else if ([root.name isEqualToString:@"setBLOBVector"]){
        
        CASINDIVector* vector = device.vectors[rootName];
        [vector updateVector:root];
        
        NSString* state = [root attributeForName:@"state"].stringValue;
        if ([state isEqualToString:@"Ok"]){
            NSArray* nodes = [document nodesForXPath:@"/setBLOBVector/oneBLOB[@format='.fits']" error:nil];
            NSString* fitsString = [nodes.firstObject stringValue];
            NSData* encodedData = [fitsString dataUsingEncoding:NSASCIIStringEncoding];
            NSData* exposureData = [[NSData alloc] initWithBase64EncodedData:encodedData options:NSDataBase64DecodingIgnoreUnknownCharacters];
            NSLog(@"read %ld bytes, decoded to %ld bytes",encodedData.length,exposureData.length);
            [exposureData writeToFile:[@"~/Desktop/indi-image.fit" stringByExpandingTildeInPath] atomically:YES];
        }
    }
#endif
}

@end

@interface CASINDIServiceBrowser ()<NSNetServiceBrowserDelegate,NSNetServiceDelegate>
@property (strong) NSNetServiceBrowser* browser;
@property (strong) NSMutableArray* services;
@end

@implementation CASINDIServiceBrowser

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.services = [NSMutableArray arrayWithCapacity:5];
        self.browser = [NSNetServiceBrowser new];
        self.browser.delegate = self;
        [self.browser scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [self.browser searchForServicesOfType:@"_indi._tcp." inDomain:@"local."];
    }
    return self;
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    aNetService.delegate = self;
    [aNetService resolveWithTimeout:5.0];
    [self.services addObject:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    [self.delegate serviceBrowser:self didRemoveService:aNetService];
    [self.services removeObject:aNetService];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    [self.delegate serviceBrowser:self didResolveService:sender];
}

@end
