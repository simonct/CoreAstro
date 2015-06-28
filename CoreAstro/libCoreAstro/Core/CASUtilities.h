//
//  CASUtilities.h
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
//  CoreAstro framework header file

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#define CAS_EXTERN extern "C"
#else
#define CAS_EXTERN extern
#endif

CAS_EXTERN NSString* CASCreateUUID();
CAS_EXTERN NSTimeInterval CASTimeBlock(void(^)(void));
CAS_EXTERN void CASWithSuddenTerminationDisabled(void(^)(void));
CAS_EXTERN void CASThrowException(Class klass,NSString* message);
CAS_EXTERN void CASThrowOOMException(Class klass);
CAS_EXTERN BOOL CASRunningInSandbox();
CAS_EXTERN BOOL CASSaveUrlToDefaults(NSURL* url,NSString* key);
CAS_EXTERN NSURL* CASUrlFromDefaults(NSString* key);
