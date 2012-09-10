//
//  CASPluginManager.m
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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

#import "CASPluginManager.h"

@implementation CASPluginManager

@synthesize browsers = _browsers;
@synthesize factories = _factories;

- (id)init
{
    self = [super init];
    if (self) {
        [self loadBundles];
    }
    return self;
}

- (void)loadBundles {
    // scan for and load extension bundles
}

- (NSArray*)browserClasses {
    return [NSArray arrayWithObject:@"CASUSBDeviceBrowser"]; // todo: get these from loadable bundles in future from the frameworks Plugins directory and NSSearchDirectories
}

- (NSArray*)factoryClasses {
    return [NSArray arrayWithObject:@"SXCCDDeviceFactory"]; // todo: get these from loadable bundles in future from the frameworks Plugins directory and NSSearchDirectories
}

- (NSArray*)createInstancesFromClasses:(NSArray*)classes {
    
    NSMutableArray* instances = [[NSMutableArray alloc] initWithCapacity:[classes count]];
    for (NSString* className in classes){
        
        @try {
            id instance = [[NSClassFromString(className) alloc] init];
            if (!instance){
                NSLog(@"Failed to create instance of %@",className);
            }
            else {
                [instances addObject:instance];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"*** Exception creating instance: %@",exception);
        }
    }
    return [NSArray arrayWithArray:instances];
}

- (NSArray*)browsers {
    @synchronized(self){
        if (!_browsers){
            _browsers = [self createInstancesFromClasses:[self browserClasses]];
        }
    }
    return _browsers;
}

- (NSArray*)factories {
    @synchronized(self){
        if (!_factories){
            _factories = [self createInstancesFromClasses:[self factoryClasses]];
        }
    }
    return _factories;
}

@end
