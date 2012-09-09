//
//  CASScriptableObject.m
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

#import "CASScriptableObject.h"

@implementation CASScriptableObject {
    long _id;
}

- (id) init {
	self = [super init];
	if (self != nil) {
        static long gNextID = 0;
		_id = ++gNextID;
	}
	return self;
}

- (NSString*)containerAccessor
{
	return nil;
}

- (NSScriptClassDescription*)containerDescription
{
	return (NSScriptClassDescription *)[NSApp classDescription];
}

- (NSScriptObjectSpecifier*)containerSpecifier
{
	return nil;
}

- (id)uniqueID
{
	return [NSString stringWithFormat:@"%ld",_id];
}

- (NSScriptObjectSpecifier*)objectSpecifier
{
    return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:[self containerDescription]
                                                       containerSpecifier:[self containerSpecifier] 
                                                                      key:[self containerAccessor]
                                                                 uniqueID:[self uniqueID]];
}

- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier
{
	// NSLog(@"[%s indicesOfObjectsByEvaluatingObjectSpecifier]: %@",object_getClassName(self),specifier);

	return nil;
}

@end
