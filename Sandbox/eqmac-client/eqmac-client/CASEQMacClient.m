//
//  CASEQMacClient.m
//  eqmac-client
//
//  Created by Simon Taylor on 04/04/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASEQMacClient.h"
#import "CASSocketClient.h"
#import "CASLX200Commands.h"

@interface CASEQMacClientClientRequest : CASSocketClientRequest
@property (nonatomic) BOOL limitToReadCount;
@end

@implementation CASEQMacClientClientRequest

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

@interface CASEQMacClient ()
@property (nonatomic,copy) NSString* ra;
@property (nonatomic,copy) NSString* dec;
@property (nonatomic,copy) void(^connectCompletion)();
@property (nonatomic) CASEQMacClientPrecision precision;
@end

@implementation CASEQMacClient {
    CASEQMacClientPrecision _precision;
}

+ (NSUInteger)standardPort {
    return 4030;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"connected" options:0 context:(__bridge void *)(self)];
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"connected" context:(__bridge void *)(self)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if (self.connected){
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
    CASEQMacClientClientRequest* request = (CASEQMacClientClientRequest*)[self makeRequest];
    
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
    
    [self enqueueRequest:request];

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
        
        if ([self.dec length]){
            self.precision = [self.dec length] > 5 ? CASEQMacClientPrecisionHigh : CASEQMacClientPrecisionLow;
        }

        [self enqueueCommand:[CASLX200Commands getTelescopeRightAscension] completion:^(NSString *raResponse) {
            
            self.ra = raResponse;
            
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
    [self connect];
}

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(BOOL))completion
{
    // :SdsDD*MM#, :SdsDD*MM:SS
    // :SrHH:MM.T#, :SrHH:MM:SS#
        
    NSString* formattedRA;
    NSString* formattedDec;
    
    if (self.precision == CASEQMacClientPrecisionUnknown){
        NSLog(@"Attempt to slew with unknown precision");
        if (completion){
            completion(NO);
        }
        return;
    }
    
    if (self.precision == CASEQMacClientPrecisionHigh){
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
    return [[CASEQMacClientClientRequest alloc] init];
}

@end
