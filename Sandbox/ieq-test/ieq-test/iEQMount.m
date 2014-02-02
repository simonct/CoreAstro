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
@property (nonatomic,assign) NSNumber* ra;
@property (nonatomic,assign) NSNumber* dec;

@end

@interface iEQMount (ORSSerialPortDelegate)<ORSSerialPortDelegate>
@end

@implementation iEQMount {
    NSInteger _slewRate;
    iEQMountDirection _direction;
    NSMutableString* _input;
}

- (id)initWithSerialPort:(ORSSerialPort*)port
{
    self = [super init];
    if (self){
        self.port = port;
        self.port.baudRate = @(9600);
        self.port.parity = ORSSerialPortParityNone;
        self.port.numberOfStopBits = 1;
        self.port.usesRTSCTSFlowControl = NO;
        self.port.usesDTRDSRFlowControl = NO;
        self.port.usesDCDOutputFlowControl = NO;
        self.port.delegate = self;
    }
    return self;
}

- (void)sendCommand:(NSString*)command readCount:(NSInteger)readCount completion:(void (^)(NSString*))completion
{
    //    if (!self.connected){
    //        NSLog(@"sendCommand but not connected");
    //        return;
    //    }
        
    // NSLog(@"sendCommand: %@",command);
    
    if (completion){
        if (!self.completionStack){
            self.completionStack = [NSMutableArray arrayWithCapacity:3];
        }
        iEQMountResponse* response = [iEQMountResponse new];
        response.completion = completion;
        response.readCount = readCount;
        response.useTerminator = (readCount == 0);
        [self.completionStack addObject:response];
//        NSLog(@"%ld commands in stack",[self.completionStack count]);
    }
    [self.port sendData:[command dataUsingEncoding:NSASCIIStringEncoding]];
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
            
            NSLog(@"Guide rate: %@",response);

            [self sendCommand:@":AT#" readCount:1 completion:^(NSString *response) {
                
                //            NSLog(@"Tracking: %@",response);
                
                self.tracking = [response boolValue];
                
                [self sendCommand:[CASLX200Commands getTelescopeRightAscension] completion:^(NSString *response) {
                    
                    self.ra = @([CASLX200Commands fromRAString:response asDegrees:NO]);
                    
                    // NSLog(@"RA: %@ -> %@",response,self.ra); // HH:MM:SS#
                    
                    [self sendCommand:[CASLX200Commands getTelescopeDeclination] completion:^(NSString *response) {
                        
                        self.dec = @([CASLX200Commands fromDecString:response]);
                        
                        // NSLog(@"Dec: %@ -> %@",response,self.dec); // sDD*MM:SS#
                        
                        [self performSelector:_cmd withObject:nil afterDelay:1];
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

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(BOOL))completion
{
    // :SdsDD*MM#, :SdsDD*MM:SS
    // :SrHH:MM.T#, :SrHH:MM:SS#
    
    NSString* formattedRA = [CASLX200Commands highPrecisionRA:ra];
    NSString* formattedDec = [CASLX200Commands highPrecisionDec:dec];
    
    NSLog(@"startSlewToRA:%f (%@) dec:%f (%@)",ra,formattedRA,dec,formattedDec);
    
    // “:Sd sDD*MM:SS#”
    [self sendCommand:[CASLX200Commands setTargetObjectDeclination:formattedDec] readCount:1 completion:^(NSString *setDecResponse) {
        
        if (![setDecResponse isEqualToString:@"1"]){
            if (completion){
                completion(NO);
            }
        }
        else {
            
            // “:Sr HH:MM:SS#”
            [self sendCommand:[CASLX200Commands setTargetObjectRightAscension:formattedRA] readCount:1 completion:^(NSString *setRAResponse) {
                
                if (![setRAResponse isEqualToString:@"1"]){
                    if (completion){
                        completion(NO);
                    }
                }
                else {
                    
                    [self sendCommand:[CASLX200Commands slewToTargetObject] readCount:1 completion:^(NSString *slewResponse) {
                        
                        if (completion){
                            completion([slewResponse isEqualToString:@"0"]);
                        }
                    }];
                }
            }];
        }
    }];
}

- (void)halt
{
    [self sendCommand:@":Q#" completion:^(NSString* response) {
        NSLog(@"Halt command response: %@",response);
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
    
    // NSLog(@"Read complete response %@",response);
    
    if (responseObject.completion){
        responseObject.completion(response);
    }
    [self.completionStack removeObject:responseObject];
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

- (iEQMountDirection) direction
{
    return _direction;
}

- (void)startMoving:(iEQMountDirection)direction
{
    if (_direction != direction){
        
        _direction = direction;
        
        switch (_direction) {
            case iEQMountDirectionNorth:
                [self sendCommand:@":mn#" completion:nil];
                break;
            case iEQMountDirectionEast:
                [self sendCommand:@":me#" completion:nil];
                break;
            case iEQMountDirectionSouth:
                [self sendCommand:@":ms#" completion:nil];
                break;
            case iEQMountDirectionWest:
                [self sendCommand:@":mw#" completion:nil];
                break;
            default:
                break;
        }
        // start a safety timer ?
        
        NSLog(@"start");
    }
}

- (void)stopMoving
{
    _direction = iEQMountDirectionNone;
    [self sendCommand:@":q#" completion:nil];
    
    NSLog(@"stop");
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
        
        NSString* command = [NSString stringWithFormat:@":SR%ld#",(long)_slewRate];
        [self sendCommand:command readCount:1 completion:^(NSString* response) {
            NSLog(@"Set rate response: %@",response);
        }];
    }
}

@end
