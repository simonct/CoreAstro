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

static NSString* const kCASPluginManagerPluginExtension = @"casPlugin";
static NSString* const kCASPluginManagerPluginClassesKey = @"CASClasses";
static NSString* const kCASPluginManagerPluginFactoryClassKey = @"CASFactoryClass";
static NSString* const kCASPluginManagerExternalSDKClassKey = @"CASExternalSDK";

@implementation CASPluginManager {
    NSMutableArray* _factoryClasses;
    NSMutableArray* _externalSDKClasses;
}

@synthesize browsers = _browsers;
@synthesize factories = _factories;
@synthesize externalSDKs = _externalSDKs;

- (id)init {
    self = [super init];
    if (self) {
        [self loadBundles];
    }
    return self;
}

- (void)loadBundleAtPath:(NSString*)path {
    
    NSLog(@"Attempting to load bundle at %@",path);
    
    NSBundle* pluginBundle = [NSBundle bundleWithPath:path];
    if (pluginBundle){
        
        NSDictionary* pluginInfo = [pluginBundle infoDictionary];
        
        NSDictionary* pluginClasses = [pluginInfo objectForKey:kCASPluginManagerPluginClassesKey];
        if (![pluginClasses isKindOfClass:[NSDictionary class]] || ![pluginClasses count]){
            NSLog(@"Entry for %@ is either not a dictionary or empty",kCASPluginManagerPluginClassesKey);
        }
        else{
        
            // handle factories (other class types to follow)
            NSArray* pluginFactories = [pluginClasses objectForKey:kCASPluginManagerPluginFactoryClassKey];
            if (pluginFactories){
                
                if (![pluginFactories isKindOfClass:[NSArray class]] || ![pluginFactories count]){
                    NSLog(@"Entry for %@ is either not an array or empty",kCASPluginManagerPluginFactoryClassKey);
                }
                else{
                    
                    // filter out bundles containing duplicate classes
                    BOOL foundClass = NO;
                    for (NSString* factoryName in pluginFactories){
                        if ([_factoryClasses containsObject:factoryName]){
                            NSLog(@"Already loaded %@, ignoring this bundle",factoryName); // todo: add 'from <bundle>', keep track of bundles where classes come from
                            foundClass = YES;
                        }
                    }
                    
                    if (!foundClass){
                        
                        // todo: lazy load plugins
                        NSError* error = nil;
                        if (![pluginBundle isLoaded] && ![pluginBundle loadAndReturnError:&error]){
                            NSLog(@"Failed to load %@ (%@)",[[pluginBundle bundlePath] lastPathComponent],error);
                        }
                        else {
                            [_factoryClasses addObjectsFromArray:pluginFactories];
                            NSLog(@"Bundle loaded, factory classes are %@",_factoryClasses);
                        }
                    }
                }
            }
            
            // handle external SDKs
            NSArray* externalSDKs = [pluginClasses objectForKey:kCASPluginManagerExternalSDKClassKey];
            if (externalSDKs){
                
                if (![externalSDKs isKindOfClass:[NSArray class]] || ![externalSDKs count]){
                    NSLog(@"Entry for %@ is either not a array or empty",kCASPluginManagerExternalSDKClassKey);
                }
                else{
                    
                    // filter out bundles containing duplicate classes
                    BOOL foundClass = NO;
                    for (NSString* sdkName in externalSDKs){
                        if ([_externalSDKClasses containsObject:sdkName]){
                            NSLog(@"Already loaded %@, ignoring this bundle",sdkName); // todo: add 'from <bundle>', keep track of bundles where classes come from
                            foundClass = YES;
                        }
                    }
                    
                    if (!foundClass){
                        
                        // todo: lazy load plugins
                        NSError* error = nil;
                        if (![pluginBundle isLoaded] && ![pluginBundle loadAndReturnError:&error]){
                            NSLog(@"Failed to load %@ (%@)",[[pluginBundle bundlePath] lastPathComponent],error);
                        }
                        else {
                            [_externalSDKClasses addObjectsFromArray:externalSDKs];
                            NSLog(@"Bundle loaded, SDK classes are %@",_externalSDKClasses);
                        }
                    }
                }
            }
        }
    }
}

- (void)loadBundles {
    
    _factoryClasses = [NSMutableArray arrayWithCapacity:5];
    _externalSDKClasses = [NSMutableArray arrayWithCapacity:5];
    
    // currently just search the framework plugins folder, in future use NSSearchDirectories to locate external plugin folders as well
    // (will need to deal with plugin versions e.g. scan all and pick the highest one before picking one to load)
    NSArray* paths = [NSArray arrayWithObjects:
                      [[NSBundle bundleForClass:[self class]] builtInPlugInsPath], // search framework PlugIns folder
#if DEBUG
                      [[NSBundle bundleWithPath:[[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"CoreAstro.framework"]] builtInPlugInsPath],
#endif
                      nil];
    for (NSString* path in paths){
        
        for (NSString* pluginPath in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil]){
           
            if ([pluginPath hasPrefix:@"."]){
                continue;
            }
            if ([[pluginPath pathExtension] isEqualToString:kCASPluginManagerPluginExtension]){
                [self loadBundleAtPath:[path stringByAppendingPathComponent:pluginPath]];
            }
        }
    }
}

- (NSArray*)browserClasses {
    return @[@"CASUSBDeviceBrowser",@"CASHIDDeviceBrowser"]; // todo: get these from loadable bundles in future from the frameworks Plugins directory and NSSearchDirectories
}

- (NSArray*)factoryClasses {
    return [_factoryClasses copy];
}

- (NSArray*)externalSDKClasses {
    return [_externalSDKClasses copy];
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

- (NSArray*)externalSDKs {
    @synchronized(self){
        if (!_externalSDKs){
            _externalSDKs = [self createInstancesFromClasses:[self externalSDKClasses]];
        }
    }
    return _externalSDKs;
}

@end
