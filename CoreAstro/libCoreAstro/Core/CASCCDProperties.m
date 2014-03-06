//
//  CASCCDProperties.m
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

#import "CASCCDProperties.h"
#import <objc/runtime.h>

@implementation CASCCDProperties
@end

@implementation NSObject (CASCCDProperties)

- (NSSet*)cas_properties {

    NSMutableSet* propertyNames = [NSMutableSet setWithCapacity:10];
    
    Class klass = [self class];
    while (klass && klass != [NSObject class]){
        unsigned int count = 0;
        objc_property_t * properties = class_copyPropertyList(klass,&count);
        for (unsigned int i = 0; i < count; ++i){
            const char* name = property_getName(properties[i]);
            if (name){
                [propertyNames addObject:[NSString stringWithUTF8String:name]];
            }
        }
        if (properties){
            free(properties);
        }
        klass = [klass superclass];
    }
    
    return [propertyNames copy];
}

- (NSDictionary*)cas_propertyValues {
    NSMutableDictionary* result = [[self dictionaryWithValuesForKeys:[[self cas_properties] allObjects]] mutableCopy];
    for (NSValue* value in [result allValues]){
        if ([value isKindOfClass:[NSValue class]]){
            const char* type = [value objCType];
            if (!strcmp(type, @encode(CGSize))){
                for (id key in [result allKeysForObject:value]){
                    result[key] = NSStringFromSize([value sizeValue]);
                }
            }
        }
    }
    return result;
}

@end
