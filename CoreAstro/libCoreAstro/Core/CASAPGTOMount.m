//
//  CASAPMount.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASAPGTOMount.h"
#import "CASAPGTOGuidePort.h"
#import "CASLX200Commands.h"
#import "CASCoordinateUtils.h"
#import "CASNova.h"
#import "CASUtilities.h"

@interface CASAPGTOMount ()<CASAPGTOGuidePortDelegate>
@property (nonatomic,assign) BOOL connected;
@property (nonatomic,copy) NSString* name;
@property (copy) NSNumber* siteLongitude, *siteLatitude;
@property (nonatomic,readonly) BOOL shouldConfigureMount;
@property (strong) CASAPGTOGuidePort* guidePort;
@end

@implementation CASAPGTOMount {
    BOOL _parking;
    BOOL _synced;
    BOOL _cp3;
    NSInteger _skipSlewStateCount;
    CASMountDirection _direction;
    CASAPGTOMountMovingRate _movingRate;
    CASAPGTOMountTrackingRate _trackingRate;
    NSTimeInterval _lastMountPollTime;
    BOOL _observingDefaults;
    BOOL _sentBacklashCommands;
}

@synthesize name, connected;

@synthesize longitude = _longitude;
@synthesize latitude = _latitude;
@synthesize localTime = _localTime;
@synthesize gmtOffset = _gmtOffset;
@synthesize siderealTime = _siderealTime;

static void* kvoContext;

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"APGTOCP3Plus":@YES,
                                                              @"APGTOAllowUnsynchedSlew":@NO,
                                                              @"APGTOParkPositionIndex":@(1),
                                                              @"APGTOGuideRateIndex":@(2),
                                                              @"APGTORABacklashArcSeconds":@(0),
                                                              @"APGTODecBacklashArcSeconds":@(0)}];
}

- (void)dealloc
{
    NSLog(@"[CASAPGTOMount dealloc]");
    
    if (_observingDefaults){
        [[self configurationDefaultsKeys] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:obj context:&kvoContext];
        }];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context == &kvoContext){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateMountConfiguration];
        });
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSString*)vendorName
{
    return @"Astro-Physics";
}

- (void)initialiseMount
{
    self.siteLatitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
    self.siteLongitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
    if (!self.siteLatitude || !self.siteLongitude){
        [self completeInitialisingMount:[NSError errorWithDomain:@"CASAPGTOMount" code:1 userInfo:@{@"NSLocalizedDescriptionKey":@"Location must be set to initialise an AP mount"}]];
        return;
    }
    
    self.name = @"Astro-Physics GTO";
    
    // always set this to NO when starting
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"APGTOAllowUnsynchedSlew"];
    
    _cp3 = [[NSUserDefaults standardUserDefaults] boolForKey:@"APGTOCP3Plus"];
    
    _synced = NO;
    
    [self sendCommand:@"#"];
    [self sendCommand:@":U#"];
    
    [self sendCommand:@":V#" completion:^(NSString *version) {
        NSLog(@"Version: %@",version);
    }];

    // get mount sidereal time to try and see if it's already been configured
    [self sendCommand:@":GS#" completion:^(NSString* response){

        NSDate* date = [NSDate date];
        
        BOOL scopeConfigured = NO;
        NSDateFormatter* dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"HH:mm:ss.S";
        NSDate* scopeSiderealTime = [dateFormatter dateFromString:response];
        if (!scopeSiderealTime){
            NSLog(@"Failed to parse scope sidereal time of %@",response);
        }
        else {
            
            // todo; may have to read mount longitude and use that when calculating the LST as it seems to round the values we send
            
            NSCalendar* cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
            NSDateComponents* scopeSiderealComps = [cal components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:scopeSiderealTime];
            const double scopeSiderealTimeValue = scopeSiderealComps.hour + (scopeSiderealComps.minute/60.0) + (scopeSiderealComps.second/3600.0);
            const double lst = [CASNova siderealTimeForLongitude:self.siteLongitude.doubleValue];
            const double diffSeconds = fabs(scopeSiderealTimeValue - lst)*3600.0;
            scopeConfigured = diffSeconds < 30; // todo; make this limit configurable, probably should be lower
            if (scopeConfigured){
                NSLog(@"Difference between local and scope sidereal time of %.0f seconds, skipping the rest of the setup",diffSeconds);
            }
            else {
                if (!self.shouldConfigureMount){
                    NSLog(@"Difference between local and scope sidereal time of %.0f seconds, but mount configuration is suppressed",diffSeconds);
                }
                else {
                    NSLog(@"Difference between local and scope sidereal time of %.0f seconds, assuming the mount needs configuring",diffSeconds);
                }
            }
        }

        // switch on command logging
        const BOOL saveLogCommands = self.logCommands;
        self.logCommands = YES;

        if (scopeConfigured || !self.shouldConfigureMount){
            
            _synced = YES; // not strictly true but assume that the mount has been synced externally
            
            [self completeInitialisingMount:nil];
            
            self.logCommands = saveLogCommands;
        }
        else {
            
            NSLog(@"Configuring %@",self.name);
            
            // :SL HH:MM:SS# -> 1
            [self sendCommand:[CASLX200Commands setTelescopeLocalTime:date] readCount:1 completion:^(NSString* response){
                if (![response isEqualToString:@"1"]) NSLog(@"Set local time: %@",response);
            }];
            
            // :SC MM/DD/YY# -> 32 spaces followed by “#”, followed by 32 spaces, followed by “#”
            [self sendCommand:[CASLX200Commands setTelescopeLocalDate:date] readCount:66 completion:^(NSString* response){
                // NSLog(@"Set local date: %@",response);
            }];
            
            // :St sDD*MM# or :St sDD*MM:SS -> 1
            [self sendCommand:[CASLX200Commands setTelescopeLatitude:self.siteLatitude.doubleValue] readCount:1 completion:^(NSString* response){
                if (![response isEqualToString:@"1"]) NSLog(@"Set latitude: %@",response);
            }];
            
            // :Sg DDD*MM# or :Sg DDD*MM:SS# -> 1
            const double longitudeValue = fmod(360 - self.siteLongitude.doubleValue, 360.0); // AP mounts express longitude as 0-360 going West
            [self sendCommand:[CASLX200Commands setTelescopeLongitude:longitudeValue] readCount:1 completion:^(NSString* response){
                if (![response isEqualToString:@"1"]) NSLog(@"Set longitude: %@",response);
            }];
            
            // :SG sHH# or :SG sHH:MM.M# or :SG sHH:MM:SS# -> 1 (total difference between local and GMT including any daylight savings)
            NSTimeZone* tz = [NSTimeZone systemTimeZone];
            [self sendCommand:[CASLX200Commands setTelescopeGMTOffset:tz] readCount:1 completion:^(NSString* response){
                
                if (![response isEqualToString:@"1"]) NSLog(@"Set GMT offset: %@",response);
                
                // I'm assuming this will be the last command that gets a response so at this point we're done (although the mount may not yet have actually processed the PO and Q commands)
                [self completeInitialisingMount:nil];
                
                // restore logging state
                self.logCommands = saveLogCommands;
            }];
            
            [self sendCommand:@":PO#"]; // this will cause problems if the mount is already unparked hence the time check above - not required for CP3/4 but doesn't unlock the keypad if you don't
            [self sendCommand:@":Q#"];
            
            // switch PEC off, todo; make configurable in the UI
            [self sendCommand:@":p#"];
        }
    }];
    
    if (_cp3 && !CASRunningInSandbox()){
        self.guidePort = [[CASAPGTOGuidePort alloc] initWithMount:self delegate:self];
    }
}

- (void)completeInitialisingMount:(NSError*)error
{
    if (error){
        [self callConnectionCompletion:error];
    }
    else {
        self.connected = YES;
        
        if (!self.shouldConfigureMount){
            // we can't get the rate from the mount so it needs to be marked as unknown
            self.movingRate = CASAPGTOMountMovingRateUnknown;
            self.trackingRate = CASAPGTOMountTrackingRateUnknown;
        }
        else {
            
            if (!_observingDefaults){
                _observingDefaults = YES;
                [[self configurationDefaultsKeys] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:obj options:0 context:&kvoContext];
                }];
            }
            [self updateMountConfiguration];
            
            [self sendCommand:@":RS2#"]; // 1200x slew rate (this is used by commands that move the mount to a target, not the NESW arrow keys which use the centring rate)
            
            self.movingRate = CASAPGTOMountMovingRate600; // this is button rate, not the slew rate which is set above (confusingly we don't show the slew rate in the UI)
            
            self.trackingRate = CASAPGTOMountTrackingRateSidereal;
        }

        // magic delay seemingly required after setting rates... (still needed?)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pollMountStatus];
        });
    }
}

- (void)updateMountConfiguration
{
    if (!_sentBacklashCommands){
        
        // sending the backlash commands mode than once seems to jam up the serial comms
        _sentBacklashCommands = YES;
        
        // :Br DD*MM:SS# or :Br HH:MM:SS# or :Br HH:MM:SS.S# -> 1
        {
            NSInteger backlashArcSecondsRA = MAX(0,[[NSUserDefaults standardUserDefaults] integerForKey:@"APGTORABacklashArcSeconds"]);
            
            NSInteger backlashArcMinutesRA = 0;
            while (backlashArcSecondsRA > 59) {
                backlashArcSecondsRA -= 60;
                backlashArcMinutesRA++;
            }
            
            NSString* backlashCommandRA = [NSString stringWithFormat:@":Br 00*%02ld:%02ld#",(long)backlashArcMinutesRA,(long)backlashArcSecondsRA];
            NSLog(@"RA backlash: %@",backlashCommandRA);
            
            [self sendCommand:backlashCommandRA readCount:1 completion:^(NSString *response) {
                if (![response isEqualToString:@"1"]) NSLog(@"Set RA backlash: %@",response);
            }];
        }
        
        // :Bd DD*MM:SS#  -> 1
        {
            NSInteger backlashArcSecondsDec = MAX(0,[[NSUserDefaults standardUserDefaults] integerForKey:@"APGTODecBacklashArcSeconds"]);
            
            NSInteger backlashArcMinutesDec = 0;
            while (backlashArcSecondsDec > 59) {
                backlashArcSecondsDec -= 60;
                backlashArcMinutesDec++;
            }
            
            NSString* backlashCommandDec = [NSString stringWithFormat:@":Bd 00*%02ld:%02ld#",(long)backlashArcMinutesDec,(long)backlashArcSecondsDec];
            NSLog(@"Dec backlash: %@",backlashCommandDec);
            
            [self sendCommand:backlashCommandDec readCount:1 completion:^(NSString *response) {
                if (![response isEqualToString:@"1"]) NSLog(@"Set Dec backlash: %@",response);
            }];
        }
    }
    
    // guide rate - sending this seems to bork the cp3...
    switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"APGTOGuideRateIndex"]) {
        case 0:
            [self sendCommand:@":RG0#"]; // 0.25x
            break;
        case 1:
            [self sendCommand:@":RG1#"]; // 0.5x
            break;
        case 2:
        default:
            [self sendCommand:@":RG2#"]; // 1x
            break;
    }
}

- (BOOL) shouldConfigureMount
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"CASConfigureMountOnConnect"];
}

- (void)disconnect
{
    [super disconnect];
    
    [self.guidePort disconnect];
    self.guidePort = nil;
    
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
        self.ha = @(fmod(([CASNova siderealTimeForLongitude:self.siteLongitude.doubleValue]) - self.ra.doubleValue + 360, 360));
    }];
    
    // :GD# -> sDD*MM:SS#
    [self sendCommand:@":GD#" completion:^(NSString *response) {
        //NSLog(@"Get Dec: %@",response);
        
        // remove any spurious letter characters
        NSCharacterSet* letterCharacterSet = [NSCharacterSet letterCharacterSet];
        NSMutableString* mutableResponse = [response mutableCopy];
        while (1) {
            const NSRange range = [mutableResponse rangeOfCharacterFromSet:letterCharacterSet];
            if (range.location == NSNotFound){
                break;
            }
            [mutableResponse replaceCharactersInRange:range withString:@""];
        }
        response = [mutableResponse copy];

        self.dec = @([CASLX200Commands fromDecString:response]);

        if (currentRa && currentDec){
            
            double degrees = 0;
            const double threshold = 0.1; // degrees/second to be considered slewing
            
            // using angular separation doesn't work if the mount is rotating around either celestial pole
            if ((currentDec.doubleValue > 89 && self.dec.doubleValue > 89) || (currentDec.doubleValue < -89 && self.dec.doubleValue < -89)){
                degrees = currentRa.doubleValue - self.ra.doubleValue;
            }
            else {
                // use this to indicate whether we're slewing or not
                degrees = CASAngularSeparation(currentRa.doubleValue,currentDec.doubleValue,self.ra.doubleValue,self.dec.doubleValue);
            }
            
            const double degreesPerSecond = _lastMountPollTime ? degrees/([NSDate timeIntervalSinceReferenceDate] - _lastMountPollTime) : 0;
            // NSLog(@"degrees %f, degreesPerSecond %f",degrees,degreesPerSecond);
            // may need to have a couple of 'not slewing' readings before declaring that the mount is back to tracking
            // sidereal rate ~ 0.0042 dec/sec
            // anything over ~ 2 deg/sec is slewing
            // normal tracking should be ~ 0
            if (_skipSlewStateCount > 0){
                _skipSlewStateCount--; // skip the first few slew states from the mount as it may not have started moving yet
            }
            else {
                self.slewing = (fabs(degreesPerSecond) > threshold);
            }
        }
        _lastMountPollTime = [NSDate timeIntervalSinceReferenceDate];
    }];

    // :GA# -> sDD*MM:SS#
    [self sendCommand:@":GA#" completion:^(NSString *response) {
        //NSLog(@"Get Alt: %@",response);
        if (!_synced && ![[NSUserDefaults standardUserDefaults] boolForKey:@"APGTOAllowUnsynchedSlew"]){
            self.alt = nil;
        }
        else {
            self.alt = @([CASLX200Commands fromDecString:response]);
        }
    }];

    // :GZ# -> sDD*MM:SS#
    [self sendCommand:@":GZ#" completion:^(NSString *response) {
        //NSLog(@"Get Az: %@",response);
        if (!_synced && ![[NSUserDefaults standardUserDefaults] boolForKey:@"APGTOAllowUnsynchedSlew"]){
            self.az = nil;
        }
        else {
            self.az = @([CASLX200Commands fromDecString:response]);
        }
    }];
    
    // :pS# -> “East#” or “West#”
    [self sendCommand:@":pS#" completion:^(NSString *response) {
        
        if (!_synced && ![[NSUserDefaults standardUserDefaults] boolForKey:@"APGTOAllowUnsynchedSlew"]){
//            NSLog(@"Get pier side: %@ but ignoring as the mount has not yet been synced",response);
            self.pierSide = 0;
        }
        else {
//            NSLog(@"Get pier side: %@",response);
            
            if ([response isEqualToString:@"East"]){
                self.pierSide = CASMountPierSideEast;
            }
            else if ([response isEqualToString:@"West"]){
                self.pierSide = CASMountPierSideWest;
            }
            else {
                self.pierSide = 0;
            }
        }
    }];
    
    // :Gg# -> current longitude
    [self sendCommand:@":Gg#" completion:^(NSString *response) {
        //NSLog(@"Get Lon: %@",response);
        double longitude = [CASLX200Commands fromDecString:response];
        if (longitude == -1){
            self.longitude = response;
            NSLog(@"Failed to parse longitude response: %@",response);
        }
        else {
            // map back from 0-360 to -180 to +180
            if (longitude > 180){
                longitude = 360 - longitude; // east of meridian so +ve longitude
            }
            else {
                longitude = -longitude; // west of meridian so -ve longitude
            }
            self.longitude = [CASLX200Commands highPrecisionDec:longitude];
        }
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
        
        if (!_cp3) {
            // GTOCP1/2 magic return values
            if ([response hasPrefix:@"A"]){
                const NSInteger offset = [[response substringWithRange:NSMakeRange(1, 1)] integerValue];
                if (offset <= 5 && offset >= 1){
                    response = [NSString stringWithFormat:@"-%02ld:00:00",(3 - labs(offset)) + 3];
                }
            }
            else if ([response hasPrefix:@"00"]){
                response = @"-06:00:00";
            }
            else if ([response hasPrefix:@"@"]){
                const NSInteger offset = [[response substringWithRange:NSMakeRange(1, 1)] integerValue];
                if (offset <= 9 && offset >= 3){
                    response = [NSString stringWithFormat:@"-%02ld:00:00",(8 - labs(offset)) + 8];
                }
            }
        }

        self.gmtOffset = response;
    }];

    // :GS# -> sideral time
    [self sendCommand:@":GS#" completion:^(NSString *response) {
        //NSLog(@"Get Sidereal Time: %@",response);
        self.siderealTime = response;
        
        // assuming this is the last command we get a response to
        [self performSelector:_cmd withObject:nil afterDelay:0.5 inModes:@[NSRunLoopCommonModes]];
        
        // call the completion block after the first poll of the mount
        [self callConnectionCompletion:nil];
    }];
}

- (NSInteger)defaultParkPosition
{
    const NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"APGTOParkPositionIndex"];
    switch (index) {
        case 0:
            return 2;
        case 1:
            return 3;
        case 2:
            return 4;
    }
    return 3;
}

- (void)park:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion
{
    [self parkToPosition:[self defaultParkPosition] completion:completion];
}

- (BOOL)parkToPosition:(NSInteger)parkPosition completion:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion
{
    [self halt];
    
    double parkRA = 0, parkDec = 0;
    
    switch (parkPosition) {
        case 2:{
            parkRA = fmod(([CASNova siderealTimeForLongitude:self.siteLongitude.doubleValue]*15) + 90 + 360, 360);
            parkDec = 0;
        }
            break;
        case 3:{
            parkRA = fmod(([CASNova siderealTimeForLongitude:self.siteLongitude.doubleValue]*15) + 90 + 360, 360);
            parkDec = 90;
        }
            break;
        case 4:{
            parkRA = fmod(([CASNova siderealTimeForLongitude:self.siteLongitude.doubleValue]*15) + 360, 360);
            const double latitude = self.siteLatitude.doubleValue;
            if (latitude < 0){
                parkDec = latitude + 90;
            }
            else {
                parkDec = latitude - 90;
            }
        }
            break;
        default:
            NSLog(@"Unrecognised park position: %ld",parkPosition);
            return NO;
    }
    
    NSLog(@"Parking mount to position %ld at RA: %f DEC: %f",parkPosition,parkRA,parkDec);
    
    [self parkWithRA:parkRA dec:parkDec completion:completion];
    
    return YES;
}

- (void)parkWithRA:(double)parkRA dec:(double)parkDec completion:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion
{
    [self startSlewToRA:parkRA dec:parkDec completion:^(CASMountSlewError error,CASMountSlewObserver* observer) {
        if (error == CASMountSlewErrorNone){
            _parking = YES;
            _skipSlewStateCount = 5;
            NSLog(@"Starting mount park");
        }
        else {
            _parking = NO;
            NSLog(@"Park failed with result: %ld, ra: %f, dec: %f",error,parkRA,parkDec);
        }
        if (completion){
            completion(error,_parking ? [CASMountSlewObserver observerWithMount:self] : nil);
        }
    }];
}

- (void)unpark
{
    [self sendCommand:@":PO#"];
}

- (void)gotoHomePosition:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion
{
    [self park:completion];
}

- (void)setSlewing:(BOOL)slewing
{
    [super setSlewing:slewing];
    
    if (_parking && !self.slewing){
        NSLog(@"Ending park");
        _parking = NO;
        self.trackingRate = CASAPGTOMountTrackingRateZero;
        [self sendCommand:@":KA#"];
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
        
        // start moving at the current centering rate
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
    _parking = NO;
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

- (void)syncCommand:(NSString*)command ToRA:(double)ra_ dec:(double)dec_ completion:(void (^)(CASMountSlewError))completion
{
    NSParameterAssert(completion);
    
    __weak __typeof__(self) weakSelf = self;
    
    // set commanded ra and dec then issue sync command
    [self setTargetRA:ra_ dec:dec_ completion:^(CASMountSlewError error) {
        
        if (error){
            completion(error);
        }
        else {
            
            [weakSelf sendCommand:command completion:^(NSString *response) {
                NSLog(@"%@: %@",command,response);
                completion(CASMountSlewErrorNone);
            }];
        }
    }];
}

- (void)syncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion
{
    [self syncCommand:@":CMR#" ToRA:ra dec:dec completion:completion];
}

- (void)fullSyncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion
{
    [self syncCommand:@":CM#" ToRA:ra dec:dec completion:^(CASMountSlewError error) {
       
        if (error == CASMountSlewErrorNone){
            _synced = YES;
        }
        if (completion){
            completion(error);
        }
    }];
}

- (void)startSlewToTarget:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion
{
    if (!_synced && ![[NSUserDefaults standardUserDefaults] boolForKey:@"APGTOAllowUnsynchedSlew"]){
        NSLog(@"Mount must be synced before slewing after full initialisation");
        completion(CASMountSlewErrorInvalidState,nil);
        return;
    }
    
    // set this immediately rather than wait for the next mount status poll
    self.slewing = YES;
    _skipSlewStateCount = 5;
    self.trackingRate = CASAPGTOMountTrackingRateSidereal;
    
    // todo; the mount can apparently not respond at all to this command under some circumstances
    [self sendCommand:[CASLX200Commands slewToTargetObject] readCount:1 completion:^(NSString *slewResponse) {
        const CASMountSlewError error = [slewResponse isEqualToString:@"0"] ? CASMountSlewErrorNone : CASMountSlewErrorInvalidLocation;
        CASMountSlewObserver* observer = (error == CASMountSlewErrorNone) ? [CASMountSlewObserver observerWithMount:self] : nil;
        if (error){
            self.slewing = NO;
        }
        completion(error,observer);
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
            case CASAPGTOMountTrackingRateUnknown:
                break;
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
    return @[@"Unknown",@"Lunar",@"Solar",@"Sidereal",@"None"];
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
            case CASAPGTOMountMovingRateUnknown:
                break;
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
    return @[@"Unknown",@"12x",@"64x",@"600x",@"1200x"];
}

- (void)pulseInDirection:(CASMountDirection)direction ms:(NSInteger)ms
{
    if (!self.connected){
        NSLog(@"APGTO: Attempt to pulse guide while not connected");
        return;
    }
    if (ms < 1){
        NSLog(@"APGTO: Pulse guide duration of %ld is < 1, ignoring",ms);
        return;
    }
    if (ms > 5000){
        NSLog(@"APGTO: Pulse guide duration of %ld is > 5000, ignoring",ms);
        return;
    }
    
    NSString* command;

- (NSArray<NSString*>*)configurationDefaultsKeys
{
    return @[@"values.APGTOGuideRateIndex",@"values.APGTORABacklashArcSeconds",@"values.APGTODecBacklashArcSeconds"];
}

- (NSViewController*)configurationViewController
{
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"CASAPGTOMount" bundle:[NSBundle bundleForClass:[self class]]];
    return [sb instantiateInitialController];
}

@end
