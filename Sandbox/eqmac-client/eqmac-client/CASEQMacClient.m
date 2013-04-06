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

@end

@implementation CASEQMacClientClientRequest

- (BOOL)appendResponseData:(NSData*)data
{
    [self.response appendData:data];
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
@end

@implementation CASEQMacClient

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

- (void)enqueue:(NSString*)command completion:(void (^)(NSString*))completion
{
    [self enqueue:[command dataUsingEncoding:NSASCIIStringEncoding] readCount:1 completion:^(NSData* responseData){
        if (completion){
            completion([[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding]);
        }
    }];
}

- (void)updateState
{
    [self enqueue:[CASLX200Commands getTelescopeDeclination] completion:^(NSString *decResponse) {
    
        self.dec = decResponse;

        [self enqueue:[CASLX200Commands getTelescopeRightAscension] completion:^(NSString *raResponse) {
            
            self.ra = raResponse;

            [self performSelector:_cmd withObject:nil afterDelay:2];
        }];
    }];
}

- (CASSocketClientRequest*)makeRequest
{
    return [[CASEQMacClientClientRequest alloc] init];
}

@end
