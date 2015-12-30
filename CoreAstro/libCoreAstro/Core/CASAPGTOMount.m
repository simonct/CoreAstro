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
@property BOOL synced; // YES if the initial sync command has been sent
@end

@implementation CASAPGTOMount {
    CASMountDirection _direction;
    CASAPGTOMountMovingRate _movingRate;
    CASAPGTOMountTrackingRate _trackingRate;
    NSTimeInterval _lastMountPollTime;
}

@synthesize name, connected;

@synthesize longitude = _longitude;
@synthesize latitude = _latitude;
@synthesize localTime = _localTime;
@synthesize gmtOffset = _gmtOffset;
@synthesize siderealTime = _siderealTime;

- (void)initialiseMount
{
    NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
    NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
    if (!latitude || !longitude){
        [self completeInitialiseMount:[NSError errorWithDomain:@"CASAPGTOMount" code:1 userInfo:@{@"NSLocalizedDescriptionKey":@"Location must be set to initialise an AP mount"}]];
        return;
    }
    
    self.name = @"Astro-Physics GTO";
    
    [self sendCommand:@"#"];
    [self sendCommand:@":U#"];

    // get mount local time to try and see if it's already been configured
    [self sendCommand:@":GL#" completion:^(NSString* response){

        NSDate* date = [NSDate date];
        
        BOOL scopeConfigured = NO;
        NSDateFormatter* dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"HH:mm:ss.S";
        NSDate* scopeTime = [dateFormatter dateFromString:response];
        if (!scopeTime){
            NSLog(@"Failed to parse scope local time of %@",response);
        }
        else {
            NSCalendar* cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
            NSDateComponents* scopeComps = [cal components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:scopeTime];
            NSDateComponents* localComps = [cal components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:date];
            scopeConfigured = fabs([cal dateFromComponents:scopeComps].timeIntervalSinceReferenceDate - [cal dateFromComponents:localComps].timeIntervalSinceReferenceDate) < 60; // todo; check gmt offset as well, also doesn't account for site lat/lon
        }

        if (scopeConfigured){
            NSLog(@"Looks like the mount is already configured, skipping the rest of the setup");
            [self completeInitialiseMount:nil];
        }
        else {
            
            // :Br DD*MM:SS# or :Br HH:MM:SS# or :Br HH:MM:SS.S# -> 1
            [self sendCommand:@":Br 00:00:00#" readCount:1 completion:^(NSString *response) {
                if (![response isEqualToString:@"1"]) NSLog(@"Set backlash: %@",response);
            }];
            
            // :SL HH:MM:SS# -> 1
            [self sendCommand:[CASLX200Commands setTelescopeLocalTime:date] readCount:1 completion:^(NSString* response){
                if (![response isEqualToString:@"1"]) NSLog(@"Set local time: %@",response);
            }];
            // :SC MM/DD/YY# -> 32 spaces followed by “#”, followed by 32 spaces, followed by “#”
            [self sendCommand:[CASLX200Commands setTelescopeLocalDate:date] readCount:66 completion:^(NSString* response){
                // NSLog(@"Set local date: %@",response);
            }];
            
            // :St sDD*MM# or :St sDD*MM:SS -> 1
            [self sendCommand:[CASLX200Commands setTelescopeLatitude:latitude.doubleValue] readCount:1 completion:^(NSString* response){
                if (![response isEqualToString:@"1"]) NSLog(@"Set latitude: %@",response);
            }];
            // :Sg DDD*MM# or :Sg DDD*MM:SS# -> 1
            [self sendCommand:[CASLX200Commands setTelescopeLongitude:longitude.doubleValue] readCount:1 completion:^(NSString* response){
                if (![response isEqualToString:@"1"]) NSLog(@"Set longitude: %@",response);
            }];
            
            NSTimeZone* tz = [NSCalendar currentCalendar].timeZone;
            // :SG sHH# or :SG sHH:MM.M# or :SG sHH:MM:SS# -> 1
            [self sendCommand:[CASLX200Commands setTelescopeGMTOffset:tz] readCount:1 completion:^(NSString* response){
                
                if (![response isEqualToString:@"1"]) NSLog(@"Set GMT offset: %@",response);
                
                // I'm assuming this will be the last command that gets a response so at this point we're done (although the mount may not yet have actually processed the PO and Q commands)
                [self completeInitialiseMount:nil];
            }];
            
            [self sendCommand:@":PO#"]; // this will cause problems if the mount is already unparked hence the time check above
            [self sendCommand:@":Q#"];
        }
    }];
}

- (void)completeInitialiseMount:(NSError*)error
{
    if (error){
        if (self.connectCompletion){
            self.connectCompletion(error);
            self.connectCompletion = nil;
        }
    }
    else {
        self.connected = YES;
        
        [self sendCommand:@":RG1#"]; // 0.5x guide rate (todo; try 0.25x, 0.5x defintely seems smoother than 1x)
        [self sendCommand:@":RS2#"]; // 1200x slew rate (this is used by commands that move the mount, not the NESW arrow keys which use the centring rate)

        self.movingRate = CASAPGTOMountMovingRate600;
        self.trackingRate = CASAPGTOMountTrackingRateSidereal;

        // magic delay seemingly required after setting rates... (still needed?)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pollMountStatus];
        });
    }
}

- (void)disconnect
{
    [super disconnect];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pollMountStatus) object:nil];
}

- (void)pollMountStatus
{
    if (!self.connected){
        NSLog(@"Attempt to poll mount status when not connected");
        return;
    }
    
    NSNumber* currentRa = self.ra;
    NSNumber* currentDec = self.dec;
    
    // :GR# -> HH:MM:SS.S#
    [self sendCommand:@":GR#" completion:^(NSString *response) {
        //NSLog(@"Get RA: %@",response);
        self.ra = @([CASLX200Commands fromRAString:response asDegrees:YES]);
    }];
    
    // :GD# -> sDD*MM:SS#
    [self sendCommand:@":GD#" completion:^(NSString *response) {
        //NSLog(@"Get Dec: %@",response);
        self.dec = @([CASLX200Commands fromDecString:response]);

        if (currentRa && currentDec){
        
            // use this to indicate whether we're slewing or not
            const double degrees = CASAngularSeparation(currentRa.doubleValue,currentDec.doubleValue,self.ra.doubleValue,self.dec.doubleValue);
            const double degreesPerSecond = _lastMountPollTime ? degrees/([NSDate timeIntervalSinceReferenceDate] - _lastMountPollTime) : 0;
            // NSLog(@"degrees %f, degreesPerSecond %f",degrees,degreesPerSecond);
            // may need to have a couple of 'not slewing' readings before declaring that the mount is back to tracking
            // sidereal rate ~ 0.0042 dec/sec
            // anything over ~ 2 deg/sec is slewing
            // normal tracking should be ~ 0
            self.slewing = (fabs(degreesPerSecond) > 1);
        }
        _lastMountPollTime = [NSDate timeIntervalSinceReferenceDate];
    }];

    // :GA# -> sDD*MM:SS#
    [self sendCommand:@":GA#" completion:^(NSString *response) {
        //NSLog(@"Get Alt: %@",response);
        self.alt = @([CASLX200Commands fromDecString:response]);
    }];

    // :GZ# -> sDD*MM:SS#
    [self sendCommand:@":GZ#" completion:^(NSString *response) {
        //NSLog(@"Get Az: %@",response);
        self.az = @([CASLX200Commands fromDecString:response]);
    }];
    
    // :pS# -> “East#” or “West#”
    [self sendCommand:@":pS#" completion:^(NSString *response) {
        
        //NSLog(@"Get pier side: %@",response);
        
        if ([response isEqualToString:@"East"]){
            self.pierSide = CASMountPierSideEast;
        }
        else if ([response isEqualToString:@"West"]){
            self.pierSide = CASMountPierSideWest;
        }
        else {
            self.pierSide = 0;
        }
    }];
    
    // :Gg# -> current longitude
    [self sendCommand:@":Gg#" completion:^(NSString *response) {
        //NSLog(@"Get Lon: %@",response);
        self.longitude = response;
    }];

    // :Gg# -> current latitude
    [self sendCommand:@":Gt#" completion:^(NSString *response) {
        //NSLog(@"Get Lat: %@",response);
        self.latitude = response;
    }];

    // :GL# -> local time
    [self sendCommand:@":GL#" completion:^(NSString *response) {
        //NSLog(@"Get Time: %@",response);
        self.localTime = response;
    }];
    
    // :GG# -> gmt offset
    [self sendCommand:@":GG#" completion:^(NSString *response) {
        //NSLog(@"Get Local Time: %@",response);
        self.gmtOffset = response;
    }];

    // :GS# -> sideral time
    [self sendCommand:@":GS#" completion:^(NSString *response) {
        //NSLog(@"Get Sidereal Time: %@",response);
        self.siderealTime = response;
        
        // assuming this is the last command we get a response to
        [self performSelector:_cmd withObject:nil afterDelay:0.5 inModes:@[NSRunLoopCommonModes]];
        
        // call the completion block after the first poll of the mount
        if (self.connectCompletion){
            self.connectCompletion(nil);
            self.connectCompletion = nil;
        }
    }];
}

- (void)park
{
    [self sendCommand:@":KA#"]; // stops tracking but doesn't appear to move the mount to any park position
    
    [self willChangeValueForKey:@"trackingRate"];
    _trackingRate = CASAPGTOMountTrackingRateZero;
    [self didChangeValueForKey:@"trackingRate"];
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
    [self sendCommand:@":Q#"]; // stops slewing but not tracking
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
    
    if (!self.synced && self.weightsHigh){
        NSLog(@"Attempt to perform initial sync of the mount while it's weights-high");
        completion(CASMountSlewErrorInvalidLocation); // todo; need a new error code
        return;
    }
    
    // set commanded ra and dec then issue sync command
    [self setTargetRA:ra_ dec:dec_ completion:^(CASMountSlewError error) {
        
        if (error){
            completion(error);
        }
        else {
            
            NSString* command = weakSelf.synced ? @":CMR#" : @":CM#";
            weakSelf.synced = YES;
            
            [weakSelf sendCommand:command completion:^(NSString *response) {
                NSLog(@"%@: %@",command,response);
                completion(CASMountSlewErrorNone);
            }];
        }
    }];
}

- (void)startSlewToTarget:(void (^)(CASMountSlewError))completion
{
    // todo; the mount can apparently not respond at all to this command under some circumstances
    [self sendCommand:[CASLX200Commands slewToTargetObject] readCount:1 completion:^(NSString *slewResponse) {
        NSLog(@"slew response: %@",slewResponse);
        completion([slewResponse isEqualToString:@"0"] ? CASMountSlewErrorNone : CASMountSlewErrorInvalidLocation);
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

- (NSArray<NSString*>*)trackingRateValues
{
    return @[@"Lunar",@"Solar",@"Sidereal",@"None"];
}

- (CASAPGTOMountMovingRate)movingRate
{
    return _movingRate;
}

- (void)setMovingRate:(CASAPGTOMountMovingRate)movingRate
{
    if (!self.connected){
        NSLog(@"Attempt to set centring rate while not connected");
        return;
    }
    if (movingRate != _movingRate){
        _movingRate = movingRate;
        switch (_movingRate) {
            case CASAPGTOMountMovingRate1200:
                [self sendCommand:@":RC3#"];
                break;
            case CASAPGTOMountMovingRate600:
                [self sendCommand:@":RC2#"];
                break;
            case CASAPGTOMountMovingRate64:
                [self sendCommand:@":RC1#"];
                break;
            case CASAPGTOMountMovingRate12:
                [self sendCommand:@":RC0#"];
                break;
            default:
                NSLog(@"Unrecognised moving rate %ld",movingRate);
                break;
        }
    }
}

- (NSArray<NSString*>*)movingRateValues
{
    return @[@"12x",@"64x",@"600x",@"1200x"];
}

- (void)pulseInDirection:(CASMountDirection)direction ms:(NSInteger)ms
{
    NSLog(@"-pulseInDirection:ms: not implemented, needs GTOCP3");
}

@end
