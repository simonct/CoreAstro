//
//  CASExposuresController.h
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASCCDExposureLibraryProject;

@interface CASExposuresController : NSArrayController // make part of CASCCDExposures ?
@property (nonatomic,weak) CASCCDExposureLibraryProject* project;
- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index;
- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes;
- (void)promptToDeleteCurrentSelectionWithWindow:(NSWindow*)window;
@end

