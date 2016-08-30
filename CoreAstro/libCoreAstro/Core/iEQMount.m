//
//  iEQMount.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "iEQMount.h"
#import "CASLX200Commands.h"

@interface iEQMount ()
@property (nonatomic,assign) BOOL connected;
@property (nonatomic,copy) NSString* name;
@end

@implementation iEQMount {
    NSInteger _movingRate;
}

@synthesize name, connected;

- (void)initialiseMount
{
    void (^complete)(NSError*) = ^(NSError* error){
        if (self.connectCompletion){
            self.connectCompletion(error);
            self.connectCompletion = nil;
        }
    };
    
    [self sendCommand:@":V#" completion:^(NSString *response) {
        if (![@"V1.00" isEqualToString:response]){
            NSString* message = [NSString stringWithFormat:@"Unrecognised response when connecting to mount. Expected V1.00 but got '%@'",response];
            complete([NSError errorWithDomain:NSStringFromClass([self class])
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:message}]);
        }
        else {
            [self sendCommand:@":MountInfo#" readCount:4 completion:^(NSString *response) {
                self.connected = YES;
                static NSDictionary* lookup = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    lookup = @{@"8407":@"iEQ45 EQ/iEQ30",
                               @"8497":@"iEQ45 AltAz",
                               @"8408":@"ZEQ25",
                               @"8498":@"SmartEQ",
                               @"0060":@"CEM60",
                               @"0061":@"CEM60-EC",
                               @"0045":@"iEQ45 Pro EQ",
                               @"0046":@"iEQ45 Pro AltAz"};
                });
                self.name = lookup[response] ?: response;
                complete(nil);
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOSetMountLocationAndDateTimeOnConnect"]){
                    [self setupMountTimeAndLocation];
                }
                [self pollMountStatus];
            }];
        }
    }];
}

- (void)setupMountTimeAndLocation
{
    // location
    NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
    NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
    if (latitude && longitude){
        [self sendCommand:[CASLX200Commands setTelescopeLatitude:latitude.doubleValue] readCount:1 completion:^(NSString* response){ NSLog(@"set lat: %@",response); }];
        [self sendCommand:[CASLX200Commands setTelescopeLongitude:longitude.doubleValue] readCount:1 completion:^(NSString* response){ NSLog(@"set lon: %@",response); }];
    }

    // local date/time
    NSDate* date = [NSDate date];
    [self sendCommand:[CASLX200Commands setTelescopeLocalDate:date] readCount:1 completion:^(NSString* response){ NSLog(@"set local date: %@",response); }];
    [self sendCommand:[CASLX200Commands setTelescopeLocalTime:date] readCount:1 completion:^(NSString* response){ NSLog(@"set local time: %@",response); }];

    // gmt offset
    NSTimeZone* tz = [NSCalendar currentCalendar].timeZone;
    [self sendCommand:[CASLX200Commands setTelescopeGMTOffsetExDST:tz] readCount:1 completion:^(NSString* response){ NSLog(@"set gmt off: %@",response); }];

    // daylight savings flag
    [self sendCommand:[CASLX200Commands setTelescopeDaylightSavings:tz] readCount:1 completion:^(NSString* response){ NSLog(@"set dst: %@",response); }];
}

- (void)pollMountStatus
{
    if (!self.connected){
        NSLog(@"Poll mount status not connected");
        return;
    }
    
    //    NSLog(@"Poll mount status");
    
    [self sendCommand:@":SE?#" readCount:1 completion:^(NSString *response) {
        
        //        NSLog(@"Slewing: %@",response);
        
        self.slewing = [response boolValue];
        
        [self sendCommand:@":Gr#" completion:^(NSString *response) {
            
            //            NSLog(@"Moving rate: %@",response);
            
            [self willChangeValueForKey:@"movingRate"];
            _movingRate = [response integerValue] - 1;
            [self didChangeValueForKey:@"movingRate"];
            
            [self sendCommand:@":AG#" completion:^(NSString *response) {
                
                //                NSLog(@"Guide rate: %@",response);
                
                [self sendCommand:@":AT#" readCount:1 completion:^(NSString *response) {
                    
                    //                    NSLog(@"Tracking: %@",response);
                    
                    self.tracking = [response boolValue];
                    
                    [self sendCommand:[CASLX200Commands getTelescopeRightAscension] completion:^(NSString *response) {
                        
                        self.ra = @([CASLX200Commands fromRAString:response asDegrees:YES]);
                        
                        //                        NSLog(@"RA: %@ -> %@",response,self.ra); // HH:MM:SS#
                        
                        [self sendCommand:[CASLX200Commands getTelescopeDeclination] completion:^(NSString *response) {
                            
                            self.dec = @([CASLX200Commands fromDecString:response]);
                            
                            //                            NSLog(@"Dec: %@ -> %@",response,self.dec); // sDD*MM:SS#
                            
                            [self sendCommand:[CASLX200Commands getTelescopeAltitude] completion:^(NSString *response) {
                                
                                self.alt = @([CASLX200Commands fromDecString:response]);
                                
                                [self sendCommand:[CASLX200Commands getTelescopeAzimuth] completion:^(NSString *response) {
                                    
                                    self.az = @([CASLX200Commands fromDecString:response]);
                                    
                                    [self sendCommand:@":pS#" readCount:1 completion:^(NSString * response) {
                                        
                                        switch (response.integerValue) {
                                            case 0:
                                                self.pierSide = CASMountPierSideEast;
                                                break;
                                            case 1:
                                                self.pierSide = CASMountPierSideWest;
                                                break;
                                            default:
                                                self.pierSide = 0;
                                                break;
                                        }
                                        
                                        // just do this at the end of the selector rather than in the completion block ?
                                        [self performSelector:_cmd withObject:nil afterDelay:0.5];
                                        
                                    }];
                                    
                                    // doesn't always seem to complete when combined with a slew ?
                                    // probably if a stop command is issued you don't get a response to one of these ?
                                    
                                    
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
    }];
}

@end

@implementation iEQMount (iEQSpecific)

- (NSInteger)movingRate
{
    return _movingRate;
}

- (void)setMovingRate:(NSInteger)movingRate
{
    if (movingRate < 0 || movingRate > 9){
        return;
    }
    if (_movingRate != movingRate){
        
        _movingRate = movingRate;
        
        NSString* command = [NSString stringWithFormat:@":SR%ld#",(long)_movingRate+1];
        [self sendCommand:command readCount:1 completion:^(NSString* response) {
            NSLog(@"Set rate response: %@",response);
        }];
    }
}

- (NSArray<NSString*>*)movingRateValues {
    return @[@"Unknown",@"1x",@"2x",@"8x",@"16x",@"64x",@"128x",@"256x",@"512x",@"Max"];
}

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

@end
