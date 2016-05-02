//
//  CASClassDefaults.h
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

#import <Foundation/Foundation.h>
#import "CASDevice.h"

@interface CASClassDefaults : NSObject
@property (nonatomic,copy) NSString* name;
@property (nonatomic,readonly) NSString* domainName;
@property (nonatomic,strong) NSDictionary* domain;
- (void)registerKeys:(NSArray*)keys ofInstance:(id)instance;
- (void)unregisterKeys:(NSArray*)keys ofInstance:(id)instance;
+ (instancetype)defaultsForClassname:(NSString*)name;
@end

@interface CASDeviceDefaults : CASClassDefaults
@end

@interface CASDevice (CASDeviceDefaults)
- (id)defaultsObjectForKey:(id)key;
- (void)setDefaultsObject:(id)obj forKey:(id)key;
- (void)removeDefaultsObjectForKey:(id)key;
@end