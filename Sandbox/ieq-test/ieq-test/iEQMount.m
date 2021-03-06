//
//  iEQMount.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "iEQMount.h"
#import "ORSSerialPortManager.h"
#import "CASLX200Commands.h"

// todo; there are similarities with the EQMac client code that should be consolidated

@interface iEQMountResponse : NSObject
@property (nonatomic,assign) BOOL useTerminator;
@property (nonatomic,assign) NSInteger readCount;
@property (nonatomic,copy) NSString* command;
@property (nonatomic,assign) BOOL inProgress;
@property (nonatomic,copy) void (^completion)(NSString*);
@end

@implementation iEQMountResponse
@end

@interface iEQMount ()

@property (nonatomic,strong) ORSSerialPort* port;
@property (nonatomic,strong) NSMutableArray* completionStack;
@property (nonatomic,copy) void(^connectCompletion)(void);

@property (nonatomic,assign) BOOL connected;
@property (nonatomic,assign) BOOL slewing;
@property (nonatomic,assign) BOOL tracking;
@property (nonatomic,strong) NSNumber* ra;
@property (nonatomic,strong) NSNumber* dec;
@property (nonatomic,strong) NSNumber* targetRa;
@property (nonatomic,strong) NSNumber* targetDec;
@property (nonatomic,strong) NSNumber* alt;
@property (nonatomic,strong) NSNumber* az;
@property (nonatomic,copy) NSString* name;
@end

@interface iEQMount (ORSSerialPortDelegate)<ORSSerialPortDelegate>
@end

@implementation iEQMount {
    NSInteger _slewRate;
    CASMountDirection _direction;
    NSMutableString* _input;
}

@synthesize connected,slewing;
@synthesize ra,dec,alt,az,targetRa,targetDec;

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
        }
    }
    return self;
}

- (void)sendNextCommand
{
    iEQMountResponse* responseObject = [self.completionStack firstObject];
    if (responseObject && !responseObject.inProgress){
        responseObject.inProgress = YES;
//        NSLog(@"sending : %@",responseObject.command);
        [self.port sendData:[responseObject.command dataUsingEncoding:NSASCIIStringEncoding]];
        if (!responseObject.completion){
            [self.completionStack removeObject:responseObject];
        }
    }
}

- (void)sendCommand:(NSString*)command readCount:(NSInteger)readCount completion:(void (^)(NSString*))completion
{
    //    if (!self.connected){
    //        NSLog(@"sendCommand but not connected");
    //        return;
    //    }
    
    if (!self.completionStack){
        self.completionStack = [NSMutableArray arrayWithCapacity:3];
    }
    iEQMountResponse* response = [iEQMountResponse new];
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

- (void)initialiseMount
{
    void (^complete)() = ^(){
        if (self.connectCompletion){
            self.connectCompletion();
            self.connectCompletion = nil;
        }
    };
    
    [self sendCommand:@":V#" completion:^(NSString *response) {
        if (![@"V1.00" isEqualToString:response]){
            complete();
        }
        else {
            [self sendCommand:@":MountInfo#" readCount:4 completion:^(NSString *response) {
                self.connected = YES;
                self.name = response;
                complete();
                [self pollMountStatus];
            }];
        }
    }];
}

- (void)pollMountStatus
{
    if (!self.connected){
        return;
    }
    
    [self sendCommand:@":SE?#" readCount:1 completion:^(NSString *response) {
        
//        NSLog(@"Slewing: %@",response);
        
        self.slewing = [response boolValue];
        
//        [self sendCommand:@":Gr#" completion:^(NSString *response) {
//            
//            NSLog(@"Slew rate: %@",response);
//            
//            self.slewRate = [response integerValue]; // no, it's the moving rate
//            
//        }];
        
        
        [self sendCommand:@":AG#" completion:^(NSString *response) {
            
            // NSLog(@"Guide rate: %@",response);

            [self sendCommand:@":AT#" readCount:1 completion:^(NSString *response) {
                
                //            NSLog(@"Tracking: %@",response);
                
                self.tracking = [response boolValue];
                
                [self sendCommand:[CASLX200Commands getTelescopeRightAscension] completion:^(NSString *response) {
                    
                    self.ra = @([CASLX200Commands fromRAString:response asDegrees:NO]);
                    
                    // NSLog(@"RA: %@ -> %@",response,self.ra); // HH:MM:SS#
                    
                    [self sendCommand:[CASLX200Commands getTelescopeDeclination] completion:^(NSString *response) {
                        
                        self.dec = @([CASLX200Commands fromDecString:response]);
                        
                        // NSLog(@"Dec: %@ -> %@",response,self.dec); // sDD*MM:SS#
                        
                        [self sendCommand:[CASLX200Commands getTelescopeAltitude] completion:^(NSString *response) {
                            
                            self.alt = @([CASLX200Commands fromDecString:response]);
                            
                            [self sendCommand:[CASLX200Commands getTelescopeAzimuth] completion:^(NSString *response) {
                                
                                self.az = @([CASLX200Commands fromDecString:response]);
                                
                                // doesn't always seem to complete when combined with a slew ?
                                // probably if a stop command is issued you don't get a response to one of these ?
                                
                                // just do this at the end of the selector rather than in the completion block ?
                                [self performSelector:_cmd withObject:nil afterDelay:1];

//                                [self sendCommand:@":Gr#" completion:^(NSString *response) {
//                                    
//                                    NSLog(@"Moving rate: %@",response);
//                                    
//                                    [self performSelector:_cmd withObject:nil afterDelay:1];
//                                }];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)connectWithCompletion:(void(^)(void))completion
{
    if (self.connected){
        completion();
    }
    else {
        self.connectCompletion = completion;
        [self.port open];
    }
}

- (void)disconnect
{
    [self.port close];
    self.connected = NO;
}

- (void)startSlewToRA:(double)ra_ dec:(double)dec_ completion:(void (^)(CASMountSlewError))completion
{
    NSParameterAssert(completion);
    
    __weak __typeof__(self) weakSelf = self;
    
    // set commanded ra and dec then issue slew command
    [self setTargetRA:ra_ dec:dec_ completion:^(CASMountSlewError error) {
        
        if (error){
            completion(error);
        }
        else {
            
            weakSelf.targetRa = @(ra_);
            weakSelf.targetDec = @(dec_);

            [weakSelf sendCommand:[CASLX200Commands slewToTargetObject] readCount:1 completion:^(NSString *slewResponse) {
                
                NSLog(@"slew response: %@",slewResponse);
                
                completion([slewResponse isEqualToString:@"1"] ? CASMountSlewErrorNone : CASMountSlewErrorInvalidLocation);
            }];
        }
    }];
}

- (void)halt
{
    [self sendCommand:@":Q#" readCount:1 completion:^(NSString* response) {
        NSLog(@"Halt command response: %@",response);
    }];
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
    NSParameterAssert(ra_ >= 0 && ra_ <= 360);
    NSParameterAssert(dec_ >= -90 && dec_ <= 90);

    // :SdsDD*MM#, :SdsDD*MM:SS
    // :SrHH:MM.T#, :SrHH:MM:SS#
    
    NSString* formattedRA = [CASLX200Commands highPrecisionRA:ra_];
    NSString* formattedDec = [CASLX200Commands highPrecisionDec:dec_];
    
    NSLog(@"setTargetRA:%f (%@) dec:%f (%@)",ra_,formattedRA,dec_,formattedDec);
    
    NSString* decCommand = [CASLX200Commands setTargetObjectDeclination:formattedDec];
    NSLog(@"Dec command: %@",decCommand);
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
            NSLog(@"RA command: %@",raCommand);
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

// guide pulse Command: “:MnXXXXX#” “:MsXXXXX#” “:MeXXXXX#” “:MwXXXXX#” Response: (none)

// select guide rate Command: “:RGnnn#” Response: “1” (Selects guide rate nnn*0.01x sidereal rate. nnn is in the range of 10 to 90, and 100.)

// start/stop tracking Command: “:ST0#” “:ST1#”

// is tracking “:AT#”

// get tracking rate “:QT#”

// select tracking rate Command: “:RT0#” “:RT1#” “:RT2#” “:RT3#” “:RT4#”

@end

@implementation iEQMount (ORSSerialPortDelegate)

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
    
    iEQMountResponse* responseObject = [self.completionStack firstObject];

    if (responseObject.readCount > 0){
        responseObject.readCount -= [response length];
        if (responseObject.readCount > 0){
            //NSLog(@"%ld bytes remaining to read",responseObject.readCount);
            return;
        }
        [_input deleteCharactersInRange:NSMakeRange(0,[_input length])];
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
    
    if (responseObject.completion){
        responseObject.completion(response);
    }
    [self.completionStack removeObject:responseObject];
    
    [self sendNextCommand];
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
    NSLog(@"serialPortWasRemovedFromSystem");
    
    self.connected = NO;
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    NSLog(@"didEncounterError: %@",error);
    
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
}

@end

@implementation iEQMount (iEQSpecific)

- (void)dumpInfo
{
    [self sendCommand:@":FW1#" completion:^(NSString *response) {
        
        NSLog(@"Mainboard fw date: %@",response); // “YYMMDDYYMMDD#”
        
        [self sendCommand:@":FW2#" completion:^(NSString *response) {
            
            NSLog(@"Motor board fw date: %@",response); // “YYMMDDYYMMDD#”
            
            [self sendCommand:[CASLX200Commands getSiteLongitude] completion:^(NSString *response) {
                
                NSLog(@"Longitude: %@",response); //  “sDDD*MM:SS#”
                
                [self sendCommand:[CASLX200Commands getSiteLatitude] completion:^(NSString *response) {
                    
                    NSLog(@"Latitude: %@",response); // “sDD*MM:SS#”
                    
                    [self sendCommand:[CASLX200Commands getLocalTime] completion:^(NSString *response) {
                        
                        NSLog(@"Local time: %@",response); // “HH:MM:SS#”
                        
                        [self sendCommand:[CASLX200Commands getSiderealTime] completion:^(NSString *response) {
                            
                            NSLog(@"Sidereal time: %@",response); // “HH:MM:SS#”
                            
                            [self sendCommand:[CASLX200Commands getDate] completion:^(NSString *response) {
                                
                                NSLog(@"Date: %@",response); // “MM:DD:YY#”
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (CASMountDirection) direction
{
    return _direction;
}

- (void)startMoving:(CASMountDirection)direction
{
    // unpark first ? “:MP0#”
    
    if (_direction != direction){
        
        _direction = direction;
        
        switch (_direction) {
            case CASMountDirectionNorth:
                [self sendCommand:@":mn#" completion:nil];
                break;
            case CASMountDirectionEast:
                [self sendCommand:@":me#" completion:nil];
                break;
            case CASMountDirectionSouth:
                [self sendCommand:@":ms#" completion:nil];
                break;
            case CASMountDirectionWest:
                [self sendCommand:@":mw#" completion:nil];
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
    [self sendCommand:@":q#" completion:nil];
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

- (NSInteger)slewRate
{
    return _slewRate;
}

- (void)setSlewRate:(NSInteger)slewRate
{
    if (slewRate < 0 || slewRate > 9){
        return;
    }
    if (_slewRate != slewRate){
        
        _slewRate = slewRate;
        
        NSString* command = [NSString stringWithFormat:@":SR%ld#",(long)_slewRate+1];
        [self sendCommand:command readCount:1 completion:^(NSString* response) {
            NSLog(@"Set rate response: %@",response);
        }];
    }
}

@end
