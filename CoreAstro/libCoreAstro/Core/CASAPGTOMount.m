//
//  CASAPMount.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASAPGTOMount.h"
#import "CASLX200Commands.h"
#import "CASCoordinateUtils.h"

@interface CASAPGTOMount ()
@property (nonatomic,assign) BOOL connected;
@property (nonatomic,copy) NSString* name;
@end

@implementation CASAPGTOMount {
    CASMountDirection _direction;
    CASAPGTOMountMovingRate _movingRate;
    CASAPGTOMountTrackingRate _trackingRate;
    NSTimeInterval _lastMountPollTime;
}

@synthesize name, connected;

- (void)initialiseMount
{
    NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
    NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
    if (!latitude || !longitude){
        [self completeInitialiseMount:[NSError errorWithDomain:@"CASAPGTOMount" code:1 userInfo:@{@"NSLocalizedDescriptionKey":@"Location must be set to initialise an AP mount"}]];
        return;
    }
    
    self.name = @"Astro-Physics GTO"; // command to get this ?
    
    [self sendCommand:@"#"];
    [self sendCommand:@":U#"];
    
    // :Br DD*MM:SS# or :Br HH:MM:SS# or :Br HH:MM:SS.S# -> 1
    [self sendCommand:@":Br 00:00:00#" readCount:1 completion:^(NSString *response) {
        NSLog(@"Set backlash: %@",response);
    }];
    
    NSDate* date = [NSDate date];
    // :SL HH:MM:SS# -> 1
    [self sendCommand:[CASLX200Commands setTelescopeLocalTime:date] readCount:1 completion:^(NSString* response){
        NSLog(@"Set local time: %@",response);
    }];
    // :SC MM/DD/YY# -> 32 spaces followed by “#”, followed by 32 spaces, followed by “#”
    [self sendCommand:[CASLX200Commands setTelescopeLocalDate:date] readCount:66 completion:^(NSString* response){
        NSLog(@"Set local date: %@",response);
    }];
    
    // :St sDD*MM# or :St sDD*MM:SS -> 1
    [self sendCommand:[CASLX200Commands setTelescopeLatitude:latitude.doubleValue] readCount:1 completion:^(NSString* response){
        NSLog(@"Set latitude: %@",response);
    }];
    // :Sg DDD*MM# or :Sg DDD*MM:SS# -> 1
    [self sendCommand:[CASLX200Commands setTelescopeLongitude:longitude.doubleValue] readCount:1 completion:^(NSString* response){
        NSLog(@"Set longitude: %@",response);
    }];

    NSTimeZone* tz = [NSCalendar currentCalendar].timeZone;
    // :SG sHH# or :SG sHH:MM.M# or :SG sHH:MM:SS# -> 1
    [self sendCommand:[CASLX200Commands setTelescopeGMTOffset:tz] readCount:1 completion:^(NSString* response){
        
        NSLog(@"Set GMT offset: %@",response);

        // I'm assuming this will be the last command that gets a response so at this point we're done (although the mount may not yet have actually processed the PO and Q commands)
        [self completeInitialiseMount:nil];
    }];

    [self sendCommand:@":PO#"];
    [self sendCommand:@":Q#"];
}

- (void)completeInitialiseMount:(NSError*)error
{
    if (self.connectCompletion){
        self.connectCompletion(error);
        self.connectCompletion = nil;
    }
    if (!error){;
        self.connected = YES;
        
        self.movingRate = CASAPGTOMountMovingRate600;
        self.trackingRate = CASAPGTOMountTrackingRateSidereal;
        
        [self sendCommand:@":RG1#"]; // 0.5x guide rate
        [self sendCommand:@":RC1#"]; // 64x centering rate

        // magic delay seemingly required after setting rates...
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pollMountStatus];
        });
    }
}

- (void)pollMountStatus
{
    if (!self.connected){
        NSLog(@"Poll mount status not connected");
        return;
    }
    
    // the serial machinery queues up requests so we can just issue a whole bunch and they'll be sent in order
    // may need to set slew rates, etc on initialisation since we don't seem to be able to poll all of them
    
    NSNumber* currentRa = self.ra;
    NSNumber* currentDec = self.dec;
    
    // :GR# -> HH:MM:SS.S#
    [self sendCommand:@":GR#" completion:^(NSString *response) {
        NSLog(@"Get RA: %@",response);
        self.ra = @([CASLX200Commands fromRAString:response asDegrees:YES]);
    }];
    
    // :GD# -> sDD*MM:SS#
    [self sendCommand:@":GD#" completion:^(NSString *response) {
        NSLog(@"Get Dec: %@",response);
        self.dec = @([CASLX200Commands fromDecString:response]);

        if (currentRa && currentDec){
        
            // use this to indicate whether we're slewing or not
            const double degrees = CASAngularSeparation(currentRa.doubleValue,currentDec.doubleValue,self.ra.doubleValue,self.dec.doubleValue);
            const double degreesPerSecond = _lastMountPollTime ? degrees/([NSDate timeIntervalSinceReferenceDate] - _lastMountPollTime) : 0;
            NSLog(@"degrees %f, degreesPerSecond %f",degrees,degreesPerSecond);
            // may need to have a couple of 'not slewing' readings before declaring that the mount is back to tracking
            // sidereal rate ~ 0.0042 dec/sec
            // anything over ~ 2 deg/sec is slewing
            // normal tracking should be ~ 0
        }
        _lastMountPollTime = [NSDate timeIntervalSinceReferenceDate];
    }];

    // :GA# -> sDD*MM:SS#
    [self sendCommand:@":GA#" completion:^(NSString *response) {
        NSLog(@"Get Alt: %@",response);
        self.alt = @([CASLX200Commands fromDecString:response]);
    }];

    // :GZ# -> sDD*MM:SS#
    [self sendCommand:@":GZ#" completion:^(NSString *response) {
        NSLog(@"Get Az: %@",response);
        self.az = @([CASLX200Commands fromDecString:response]);
    }];
    
    // :pS# -> “East#” or “West#”
    [self sendCommand:@":pS#" completion:^(NSString *response) {
        
        NSLog(@"Get pier side: %@",response);
        
        if ([response isEqualToString:@"East"]){
            self.pierSide = CASMountPierSideEast;
        }
        else if ([response isEqualToString:@"West"]){
            self.pierSide = CASMountPierSideWest;
        }
        else {
            self.pierSide = 0;
        }
        
        // assuming this is the last command we get a response to
        [self performSelector:_cmd withObject:nil afterDelay:0.5];
    }];
    
    // slewing, tracking, etc
    // "#:D#", "#:SE?#"
}

- (void)park
{
    [self sendCommand:@":KA#"];
}

- (void)unpark
{
    [self sendCommand:@":PO#"];
}

- (void)gotoHomePosition
{
    [self park];
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
                [self sendCommand:@":Mn#"];
                break;
            case CASMountDirectionEast:
                [self sendCommand:@":Me#"];
                break;
            case CASMountDirectionSouth:
                [self sendCommand:@":Ms#"];
                break;
            case CASMountDirectionWest:
                [self sendCommand:@":Mw#"];
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
    [self sendCommand:@":Q#"];
}

- (void)stopTracking
{
    [self stopMoving];
}

- (void)stopSlewing
{
    [self stopMoving];
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
            
            [weakSelf sendCommand:@"CMR#" completion:^(NSString *slewResponse) {
                
                NSLog(@"sync response: %@",slewResponse);
                
                completion(CASMountSlewErrorNone);
            }];
        }
    }];
}

- (CASAPGTOMountTrackingRate)trackingRate
{
    return _trackingRate;
}

- (void)setTrackingRate:(CASAPGTOMountTrackingRate)trackingRate
{
    if (!self.connected){
        NSLog(@"Attempt to set tracking rate while not connected");
        return;
    }
    if (trackingRate != _trackingRate){
        _trackingRate = trackingRate;
        switch (_trackingRate) {
            case CASAPGTOMountTrackingRateLunar:
                [self sendCommand:@":RT0#"];
                break;
            case CASAPGTOMountTrackingRateSolar:
                [self sendCommand:@":RT1#"];
                break;
            case CASAPGTOMountTrackingRateSidereal:
                [self sendCommand:@":RT2#"];
                break;
            case CASAPGTOMountTrackingRateZero:
                [self sendCommand:@":RT9#"];
                break;
            default:
                NSLog(@"Unrecognised tracking rate %ld",trackingRate);
                break;
        }
    }
}

- (NSArray<NSString*>*)trackingRateValues {
    return @[@"Lunar",@"Solar",@"Sidereal",@"None"];
}

- (CASAPGTOMountMovingRate)movingRate
{
    return _movingRate;
}

- (void)setMovingRate:(CASAPGTOMountMovingRate)movingRate
{
    if (!self.connected){
        NSLog(@"Attempt to set moving rate while not connected");
        return;
    }
    if (movingRate != _movingRate){
        _movingRate = movingRate;
        switch (_movingRate) {
            case CASAPGTOMountMovingRate1200:
                [self sendCommand:@":RS2#"];
                break;
            case CASAPGTOMountMovingRate900:
                [self sendCommand:@":RS1#"];
                break;
            case CASAPGTOMountMovingRate600:
                [self sendCommand:@":RS0#"];
                break;
            default:
                NSLog(@"Unrecognised moving rate %ld",movingRate);
                break;
        }
    }
}

- (NSArray<NSString*>*)movingRateValues {
    return @[@"1200x",@"900x",@"600x"];
}

- (void)pulseInDirection:(CASMountDirection)direction ms:(NSInteger)ms
{
    NSLog(@"-pulseInDirection:ms: not implemented, needs GTPCP3");
}

@end
