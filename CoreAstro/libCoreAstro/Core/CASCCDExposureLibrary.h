//
//  CASCCDExposureLibrary.h
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

#import "CASCCDExposure.h"

@interface CASCCDExposureLibraryProject : NSObject

@property (nonatomic,copy,readonly) NSString* uuid;

@property (nonatomic,weak) CASCCDExposureLibraryProject* parent;
@property (nonatomic,strong) NSMutableArray* children;

@property (nonatomic,strong) NSMutableArray* exposures; // or uuids - subset of library exposures in this project

@property (nonatomic,strong) CASCCDExposure* masterDark;
@property (nonatomic,strong) CASCCDExposure* masterBias;
@property (nonatomic,strong) CASCCDExposure* masterFlat;

@property (nonatomic,copy) NSString* name;

- (void)addExposures:(NSSet *)objects;
- (void)removeExposures:(NSSet *)objects;

@end

@interface CASCCDExposureLibrary : NSObject

+ (CASCCDExposureLibrary*)sharedLibrary;

@property (nonatomic,strong) NSArray* projects; // array of CASCCDExposureLibraryProject
@property (nonatomic,strong) NSArray* exposures;

- (void)addExposure:(CASCCDExposure*)exposure save:(BOOL)save block:(void (^)(NSError*,NSURL*))block;

- (NSArray*)darksMatchingExposure:(CASCCDExposure*)exposure;
- (NSArray*)flatsMatchingExposure:(CASCCDExposure*)exposure;

- (CASCCDExposure*)exposureWithUUID:(NSString*)uuid;

- (void)addProjects:(NSSet *)objects;
- (void)removeProjects:(NSSet *)objects;
- (void)moveProject:(CASCCDExposureLibraryProject*)project toIndex:(NSInteger)index;

- (CASCCDExposureLibraryProject*)projecteWithUUID:(NSString*)uuid;

- (void)projectWasUpdated:(CASCCDExposureLibraryProject*)project;

extern NSString* kCASCCDExposureLibraryExposureAddedNotification;

@end

