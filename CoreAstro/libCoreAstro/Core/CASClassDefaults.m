//
//  CASClassDefaults.m
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "CASClassDefaults.h"

@implementation CASClassDefaults

- (NSString*)domainName
{
    return [NSString stringWithFormat:@"org.coreastro.%@",self.name];
}

- (NSDictionary*) domain
{
    NSDictionary* result = [[NSUserDefaults standardUserDefaults] persistentDomainForName:self.domainName];
    return result ? result : @{};
}

- (void)setDomain:(NSDictionary *)domain
{
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:domain forName:self.domainName];
}

- (void)observeKeys:(NSArray*)keys ofInstance:(id)instance
{
    for (id keyPath in keys){
        [instance addObserver:self forKeyPath:keyPath options:0 context:(__bridge void *)(self)];
    }
}

- (void)unobserveKeys:(NSArray*)keys ofInstance:(id)instance
{
    for (id keyPath in keys){
        [instance removeObserver:self forKeyPath:keyPath context:(__bridge void *)(self)];
    }
}

- (void)registerKeys:(NSArray*)keys ofInstance:(id)instance
{
    NSDictionary* domain = self.domain;
    if ([domain count]){
        
        for (id keyPath in keys){
            id value = [domain objectForKey:keyPath];
            if (!value){
                value = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@_%@",self.name,keyPath]];
            }
            if (value){
                [instance setValue:value forKeyPath:keyPath];
            }
        }
    }
    
    [self observeKeys:keys ofInstance:instance];
}

- (void)unregisterKeys:(NSArray*)keys ofInstance:(id)instance
{
    [self unobserveKeys:keys ofInstance:instance];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        //NSLog(@"Observed property with keyPath %@ on %@ changed to %@",keyPath,object,[object valueForKeyPath:keyPath]);
        
        NSMutableDictionary* domain = [self.domain mutableCopy];
        id value = [object valueForKeyPath:keyPath];
        if (value){
            domain[keyPath] = value;
        }
        else {
            [domain removeObjectForKey:keyPath];
        }
        self.domain = domain;
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

+ (CASClassDefaults*)defaultsForClassname:(NSString*)name
{
    CASClassDefaults* result = nil;
    
    @synchronized(self){
        static NSMutableDictionary* defaults = nil;
        if (!defaults){
            defaults = [NSMutableDictionary dictionaryWithCapacity:10];
        }
        result = defaults[name];
        if (!result){
            result = [[[self class] alloc] init];
            result.name = name;
            defaults[name] = result;
        }
    }
    
    return result;
}

@end

@implementation CASDeviceDefaults

- (NSString*)domainName
{
    return [NSString stringWithFormat:@"org.coreastro.device.%@",self.name];
}

@end
