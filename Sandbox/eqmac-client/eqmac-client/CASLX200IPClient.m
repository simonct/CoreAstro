//
//  CASLX200IPClient.m
//  
//
//  Created by Simon Taylor on 08/05/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASLX200IPClient.h"
#import "CASSocketClient.h"
#import "CASLX200Commands.h"

@interface CASLX200IPClientClientRequest : CASSocketClientRequest
@property (nonatomic) BOOL limitToReadCount;
@end

@implementation CASLX200IPClientClientRequest

- (BOOL)appendResponseData:(NSData*)data
{
    [self.response appendData:data];
    
    if (self.limitToReadCount && [self.response length] >= self.readCount){
        return YES;
    }
    
    const NSRange range = [self.response rangeOfData:[@"#" dataUsingEncoding:NSASCIIStringEncoding] options:0 range:NSMakeRange(0, [self.response length])];
    if (range.location == NSNotFound){
        return NO;
    }
    
    self.response = [[self.response subdataWithRange:NSMakeRange(0, range.location)] mutableCopy];
    
    return YES;
}

@end

@interface CASLX200IPClient ()
@property (nonatomic,strong) CASSocketClient* client;
@property (nonatomic,copy) NSString* ra;
@property (nonatomic,copy) NSString* dec;
@property (nonatomic,copy) void(^connectCompletion)();
@property (nonatomic) CASLX200ClientPrecision precision;
@end

@implementation CASLX200IPClient {
    CASLX200ClientPrecision _precision;
}

+ (CASLX200IPClient*)clientWithHost:(NSHost*)host port:(NSUInteger)port
{
    CASLX200IPClient* client = [[[self class] alloc] init];
    client.client.port = port;
    client.client.host = host;
    return client;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.client = [[CASSocketClient alloc] init];
        [self.client addObserver:self forKeyPath:@"connected" options:0 context:(__bridge void *)(self)];
    }
    return self;
}

- (void)dealloc
{
    [self.client removeObserver:self forKeyPath:@"connected" context:(__bridge void *)(self)];
}

- (BOOL) connected
{
    return self.client.connected;
}

+ (NSSet*)keyPathsForValuesAffectingConnected
{
    return [NSSet setWithObject:@"client.connected"];
}

- (NSError*) error
{
    return self.client.error;
}

+ (NSSet*)keyPathsForValuesAffectingError
{
    return [NSSet setWithObject:@"client.error"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if (self.client.connected){
            [self updateState];
        }
        else {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateState) object:nil];
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)enqueueCommand:(NSString*)command completion:(void (^)(NSString*))completion
{
    [self enqueueCommand:command limitToReadCount:NO completion:completion];
}

- (void)enqueueCommand:(NSString*)command limitToReadCount:(BOOL)limitToReadCount completion:(void (^)(NSString*))completion
{
    CASLX200IPClientClientRequest* request = (CASLX200IPClientClientRequest*)[self makeRequest];
    
    request.data = [command dataUsingEncoding:NSASCIIStringEncoding];
    if (completion){
        request.completion = ^(NSData* responseData){
            if (completion){
                completion([[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding]);
            }
        };
    }
    request.readCount = 1;
    request.limitToReadCount = limitToReadCount;
    
    [self.client enqueueRequest:request];
    
    //    [self enqueue:[command dataUsingEncoding:NSASCIIStringEncoding] readCount:1 completion:^(NSData* responseData){
    //        if (completion){
    //            completion([[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding]);
    //        }
    //    }];
}

- (void)updateState
{
    // might need to run a heartbeat in here to detect if the client's gone away
    
    [self enqueueCommand:[CASLX200Commands getTelescopeDeclination] completion:^(NSString *decResponse) {
        
        self.dec = decResponse;
        
        NSLog(@"self.dec: %@ (%f)",self.dec,[CASLX200Commands fromDecString:self.dec]);
        
        if ([self.dec length]){
            self.precision = [self.dec length] > 5 ? CASLX200ClientPrecisionHigh : CASLX200ClientPrecisionLow;
        }
        
        [self enqueueCommand:[CASLX200Commands getTelescopeRightAscension] completion:^(NSString *raResponse) {
            
            self.ra = raResponse;
            
            NSLog(@"self.ra: %@ (%f° %f)",self.ra,[CASLX200Commands fromRAString:self.ra asDegrees:YES],[CASLX200Commands fromRAString:self.ra asDegrees:NO]);
            
            //            [self enqueueCommand:[CASLX200Commands getDistanceBars] completion:^(NSString *distanceBars) {
            //
            //                NSLog(@"distanceBars: %@",distanceBars);
            //
            //                [self performSelector:_cmd withObject:nil afterDelay:1];
            //            }];
            [self performSelector:_cmd withObject:nil afterDelay:1];
            
            if (self.connectCompletion){
                self.connectCompletion();
                self.connectCompletion = nil;
            }
        }];
    }];
}

- (void)connectWithCompletion:(void(^)())completion
{
    self.connectCompletion = completion;
    [self.client connect];
}

- (void)disconnect
{
    [self.client disconnect];
}

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(BOOL))completion
{
    // :SdsDD*MM#, :SdsDD*MM:SS
    // :SrHH:MM.T#, :SrHH:MM:SS#
    
    NSString* formattedRA;
    NSString* formattedDec;
    
    if (self.precision == CASLX200ClientPrecisionUnknown){
        NSLog(@"Attempt to slew with unknown precision");
        if (completion){
            completion(NO);
        }
        return;
    }
    
    if (self.precision == CASLX200ClientPrecisionHigh){
        formattedRA = [CASLX200Commands highPrecisionRA:ra];
        formattedDec = [CASLX200Commands highPrecisionDec:dec];
    }
    else {
        formattedRA = [CASLX200Commands lowPrecisionRA:ra];
        formattedDec = [CASLX200Commands lowPrecisionDec:dec];
    }
    
    NSLog(@"startSlewToRA:%f (%@) dec:%f (%@)",ra,formattedRA,dec,formattedDec);
    
    [self enqueueCommand:[CASLX200Commands setTargetObjectDeclination:formattedDec] limitToReadCount:YES completion:^(NSString *setDecResponse) {
        
        if (![setDecResponse isEqualToString:@"1"]){
            if (completion){
                completion(NO);
            }
        }
        else {
            
            [self enqueueCommand:[CASLX200Commands setTargetObjectRightAscension:formattedRA] limitToReadCount:YES completion:^(NSString *setRAResponse) {
                
                if (![setRAResponse isEqualToString:@"1"]){
                    if (completion){
                        completion(NO);
                    }
                }
                else {
                    
                    [self enqueueCommand:[CASLX200Commands slewToTargetObject] limitToReadCount:YES completion:^(NSString *slewResponse) {
                        
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
    [self enqueueCommand:@":Q#" limitToReadCount:NO completion:nil];
}

- (CASSocketClientRequest*)makeRequest
{
    return [[CASLX200IPClientClientRequest alloc] init];
}

@end
