//
//  CASLX200Mount.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASLX200Mount.h"
#import "ORSSerialPortManager.h"
#import "CASLX200Commands.h"

// todo; there are similarities with the EQMac client code that should be consolidated

@interface CASLX200MountResponse : NSObject
@property (nonatomic,assign) BOOL useTerminator;
@property (nonatomic,assign) NSInteger readCount;
@property (nonatomic,copy) NSString* command;
@property (nonatomic,assign) BOOL inProgress;
@property (nonatomic,copy) void (^completion)(NSString*);
@end

@implementation CASLX200MountResponse
@end

@interface CASLX200Mount ()
@property (nonatomic,strong) ORSSerialPort* port;
@property (nonatomic,strong) NSMutableArray* completionStack;
@end

@interface CASLX200Mount (ORSSerialPortDelegate)<ORSSerialPortDelegate>
@end

@implementation CASLX200Mount {
    CASMountDirection _direction;
    NSMutableString* _input;
}

@synthesize connected,tracking;
@synthesize ra,dec,alt,az,targetRa,targetDec;
@synthesize pierSide = _pierSide;
@synthesize slewing = _slewing;

- (id)initWithSerialPort:(ORSSerialPort*)port
{
    self = [super init];
    if (self){
        if (!port){
            self = nil;
        }
        else {
            self.port = port;
            self.port.baudRate = @(9600);
            self.port.parity = ORSSerialPortParityNone;
            self.port.numberOfStopBits = 1;
            self.port.usesRTSCTSFlowControl = NO;
            self.port.usesDTRDSRFlowControl = NO;
            self.port.usesDCDOutputFlowControl = NO;
            self.port.delegate = self;
            NSLog(@"Connecting to mount at %@",self.port.path);
        }
    }
    return self;
}

- (void)dealloc
{
    [self.port close];
}

- (NSString*)deviceName {
    return self.name;
}

- (NSString*)deviceLocation {
    return @"Serial"; // tmp until we get a serial transport implementation
}

- (void)sendNextCommand
{
    CASLX200MountResponse* responseObject = [self.completionStack firstObject];
    if (responseObject && !responseObject.inProgress){
        responseObject.inProgress = YES;
//        NSLog(@"sending : %@",responseObject.command);
        [self.port sendData:[responseObject.command dataUsingEncoding:NSASCIIStringEncoding]];
        if (!responseObject.completion){
            [self.completionStack removeObject:responseObject];
        }
    }
    else {
        if (responseObject.command){
//            NSLog(@"%@ is in progress",responseObject.command);
        }
    }
}

- (void)sendCommand:(NSString*)command readCount:(NSInteger)readCount completion:(void (^)(NSString*))completion
{
    //    if (!self.connected){
    //        NSLog(@"sendCommand but not connected");
    //        return;
    //    }
    
    if (self.logCommands){
        NSLog(@"Command: %@",command);
    }
    
    if (!self.completionStack){
        self.completionStack = [NSMutableArray arrayWithCapacity:3];
    }
    CASLX200MountResponse* response = [CASLX200MountResponse new];
    response.completion = completion;
    response.readCount = readCount;
    response.useTerminator = (readCount == 0);
    response.command = command;
    [self.completionStack addObject:response];
    //        NSLog(@"%ld commands in stack",[self.completionStack count]);
    
    [self sendNextCommand];
}

- (void)sendCommand:(NSString*)command completion:(void (^)(NSString*))completion
{
    [self sendCommand:command readCount:0 completion:completion];
}

- (void)sendCommand:(NSString*)command
{
    [self sendCommand:command readCount:0 completion:nil];
}

- (void)callConnectionCompletion:(NSError*)error
{
    [self stopConnectionTimeout];
    
    if (self.connectCompletion){
        self.connectCompletion(error);
        self.connectCompletion = nil;
    }
}

- (void)initialiseMount
{
    NSLog(@"initialiseMount needs to be implemented by subclasses");
}

- (void)pollMountStatus
{
    NSLog(@"pollMountStatus needs to be implemented by subclasses");
}

#pragma mark - CASMount

- (void)connect:(void (^)(NSError*))completion
{
    if (self.connected){
        completion(nil);
    }
    else {
        self.connectCompletion = completion;
        [self startConnectionTimeout];
        [self.port open];
    }
}

- (void)disconnect
{
    [self stopConnectionTimeout];
    [self.port close];
    self.connected = NO;
    [super disconnect];
}

- (void)startConnectionTimeout
{
    [self performSelector:@selector(connectionTimeout) withObject:nil afterDelay:10]; // 10s should be enough for a directly connected device
}

- (void)stopConnectionTimeout
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeout) object:nil];
}

- (void)connectionTimeout
{
    [self disconnect];
    
    NSError* error = [NSError errorWithDomain:@"CASLX200Mount" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Connection timed out"}];
    [self callConnectionCompletion:error];
}

- (void)startSlewToTarget:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion {
    
    [self sendCommand:[CASLX200Commands slewToTargetObject] readCount:1 completion:^(NSString *slewResponse) {
        const CASMountSlewError error = [slewResponse isEqualToString:@"1"] ? CASMountSlewErrorNone : CASMountSlewErrorInvalidLocation;
        CASMountSlewObserver* observer = (error == CASMountSlewErrorNone) ? [CASMountSlewObserver observerWithMount:self] : nil;
        completion(error,observer);
    }];
}

- (void)park {
    [self sendCommand:@":MP1#" readCount:1 completion:^(NSString* response) {
        NSLog(@"Park command response: %@",response);
    }];
}

- (void)unpark {
    [self sendCommand:@":MP0#" readCount:1 completion:^(NSString* response) {
        NSLog(@"Unpark command response: %@",response);
    }];
}

- (void)gotoHomePosition:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion {
    [self sendCommand:@":MH#" readCount:1 completion:^(NSString* response) {
        NSLog(@"Home command response: %@",response);
        if (completion){
            const CASMountSlewError error = [response isEqualToString:@"1"] ? CASMountSlewErrorNone : CASMountSlewErrorInvalidLocation;
            CASMountSlewObserver* observer = (error == CASMountSlewErrorNone) ? [CASMountSlewObserver observerWithMount:self] : nil;
            completion(error,observer);
        }
    }];
}

- (void)halt
{
    if (_direction != CASMountDirectionNone){
        [self stopMoving];
    }
    else {
        [self stopSlewing];
    }
    [self pollMountStatus];
}

- (void)syncToRA:(double)ra_ dec:(double)dec_ completion:(void (^)(CASMountSlewError))completion
{
    NSParameterAssert(completion);

    __weak __typeof__(self) weakSelf = self;
    
    // set commanded ra and dec then issue sync command
    [self setTargetRA:ra_ dec:dec_ completion:^(CASMountSlewError error) {
        
        if (error){
            completion(error);
        }
        else {
            
            [weakSelf sendCommand:[CASLX200Commands syncToTargetObject] readCount:1 completion:^(NSString *slewResponse) {
                
                NSLog(@"sync response: %@",slewResponse);
                
                completion([slewResponse isEqualToString:@"1"] ? CASMountSlewErrorNone : CASMountSlewErrorInvalidLocation);
            }];
        }
    }];
}

- (void)setTargetRA:(double)ra_ dec:(double)dec_ completion:(void(^)(CASMountSlewError))completion
{
    NSParameterAssert(completion);
    
    if (!(ra_ >= 0 && ra_ <= 360)) {
        completion(CASMountSlewErrorInvalidRA);
        return;
    }
    if (!(dec_ >= -90 && dec_ <= 90)) {
        completion(CASMountSlewErrorInvalidDec);
        return;
    }

    self.targetRa = @(ra_);
    self.targetDec = @(dec_);
    
    // :SdsDD*MM#, :SdsDD*MM:SS
    // :SrHH:MM.T#, :SrHH:MM:SS#
    
    NSString* formattedRA = [CASLX200Commands highPrecisionRA:ra_];
    NSString* formattedDec = [CASLX200Commands highPrecisionDec:dec_];
    
    //NSLog(@"setTargetRA:%f (%@) dec:%f (%@)",ra_,formattedRA,dec_,formattedDec);
    
    NSString* decCommand = [CASLX200Commands setTargetObjectDeclination:formattedDec];
    //NSLog(@"Dec command: %@",decCommand);
    [self sendCommand:decCommand readCount:1 completion:^(NSString *setDecResponse) {
        
        if (![setDecResponse isEqualToString:@"1"]){
            NSLog(@"Failed to set dec: %@",setDecResponse);
            if (completion){
                completion(CASMountSlewErrorInvalidDec);
            }
        }
        else {
            
            // “:Sr HH:MM:SS#”
            NSString* raCommand = [CASLX200Commands setTargetObjectRightAscension:formattedRA];
            //NSLog(@"RA command: %@",raCommand);
            [self sendCommand:raCommand readCount:1 completion:^(NSString *setRAResponse) {
                
                if (![setRAResponse isEqualToString:@"1"]){
                    NSLog(@"Failed to set ra: %@",setRAResponse);
                    if (completion){
                        completion(CASMountSlewErrorInvalidRA);
                    }
                }
                else {
                    
                    completion(CASMountSlewErrorNone);
                }
            }];
        }
    }];
}

- (void)setSlewing:(BOOL)slewing
{
    if (slewing != _slewing){
        _slewing = slewing;
        [[NSNotificationCenter defaultCenter] postNotificationName:CASMountSlewingNotification object:self userInfo:@{@"slewing":@(slewing)}];
    }
}

- (CASMountDirection) direction
{
    return _direction;
}

- (void)startMoving:(CASMountDirection)direction
{
    // unpark first ? “:MP0#”
    
    if (_direction != direction){
        
        if (_direction != CASMountDirectionNone){
            [self stopMoving];
        }
        
        _direction = direction;
        
        switch (_direction) {
            case CASMountDirectionNorth:
                [self sendCommand:@":mn#"];
                break;
            case CASMountDirectionEast:
                [self sendCommand:@":me#"];
                break;
            case CASMountDirectionSouth:
                [self sendCommand:@":ms#"];
                break;
            case CASMountDirectionWest:
                [self sendCommand:@":mw#"];
                break;
            default:
                break;
        }
        // start a safety timer ?
    }
}

- (void)stopMoving
{
    _direction = CASMountDirectionNone;
    [self sendCommand:@":q#"]; // This commands will stop moving by arrow keys or “:mn#”, “:me#”, “:ms#”, “:mw#” command. Slewing and tracking will not be affected.
}

- (void)stopTracking
{
    [self sendCommand:@":ST0#" readCount:1 completion:^(NSString* response) { // These command sets tracking state. “:ST0#” indicates stop tracking, “:ST1#” indicates start tracking.
        NSLog(@"Stop tracking command response: %@",response);
    }];
}

- (void)stopSlewing
{
    [self sendCommand:@":Q#" readCount:1 completion:^(NSString* response) { // This command will stop slewing. Tracking and moving by arrow keys will not be affected.
        NSLog(@"Stop slewing command response: %@",response);
    }];
}

- (void)pulseInDirection:(CASMountDirection)direction ms:(NSInteger)ms
{
    NSString* command;
    
    ms = MAX(ms, 1); // sending 0 starts guiding and never stops until another “:Mx00000#” command is sent
    ms = MIN(ms, 32767);
    
    switch (direction) {
        case CASMountDirectionNorth:
            command = [NSString stringWithFormat:@":Mn%05ld#",ms];
            break;
        case CASMountDirectionEast:
            command = [NSString stringWithFormat:@":Me%05ld#",ms];
            break;
        case CASMountDirectionSouth:
            command = [NSString stringWithFormat:@":Ms%05ld#",ms];
            break;
        case CASMountDirectionWest:
            command = [NSString stringWithFormat:@":Mw%05ld#",ms];
            break;
        default:
            break;
    }
    
    NSLog(@"pulseInDirection: %@",command);
    
    [self sendCommand:command completion:nil];
}

- (void)setPierSide:(CASMountPierSide)pierSide
{
    if (pierSide != _pierSide){
        const BOOL flipped = (_pierSide != 0);
        _pierSide = pierSide;
        if (flipped){
            [[NSNotificationCenter defaultCenter] postNotificationName:CASMountFlippedNotification object:self];
        }
    }
}

// guide pulse Command: “:MnXXXXX#” “:MsXXXXX#” “:MeXXXXX#” “:MwXXXXX#” Response: (none)

// select guide rate Command: “:RGnnn#” Response: “1” (Selects guide rate nnn*0.01x sidereal rate. nnn is in the range of 10 to 90, and 100.)

// start/stop tracking Command: “:ST0#” “:ST1#”

// is tracking “:AT#”

// get tracking rate “:QT#”

// select tracking rate Command: “:RT0#” “:RT1#” “:RT2#” “:RT3#” “:RT4#”

@end

@implementation CASLX200Mount (ORSSerialPortDelegate)

// todo; put into the CASSerialTransport class ?

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    // todo; see if we have to detect the trailling #
    // todo; check connected ?
    
    NSString* response = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
    //NSLog(@"didReceiveData: %@",response);

    if (![response length]){
        NSLog(@"Empty response, continuing to read");
        return;
    }
    
    if (!_input){
        _input = [NSMutableString string];
    }
    [_input appendString:response];
    
    CASLX200MountResponse* responseObject = [self.completionStack firstObject];

    if (responseObject.readCount > 0){
        responseObject.readCount -= [response length];
        if (responseObject.readCount > 0){
            //NSLog(@"%ld bytes remaining to read",responseObject.readCount);
            return;
        }
        response = _input;
    }
    else if (responseObject.useTerminator) {
        const NSRange range = [_input rangeOfString:@"#" options:NSBackwardsSearch];
        if (range.location == NSNotFound){
            //NSLog(@"No termination character, continuing to read");
            return;
        }
        response = [_input substringToIndex:range.location];
        [_input deleteCharactersInRange:NSMakeRange(0,[response length] + 1)];
    }
    
//    NSLog(@"Read complete response %@ for command %@",response,responseObject.command);
    
    void (^completion)(NSString*) = responseObject.completion;
    [self.completionStack removeObject:responseObject];
    if (completion){
        completion(response);
    }
    _input = nil;
    
    [self sendNextCommand];
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
    NSLog(@"serialPortWasRemovedFromSystem");
    
    [self stopConnectionTimeout];

    self.connected = NO;
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    NSLog(@"didEncounterError: %@",error);
    
    [self stopConnectionTimeout];

    [self callConnectionCompletion:error];
    
    self.connected = NO;
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
    NSLog(@"serialPortWasOpened");
    
    [self initialiseMount];
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
    NSLog(@"serialPortWasClosed");

    [self stopConnectionTimeout];

    self.connected = NO;
}

@end

