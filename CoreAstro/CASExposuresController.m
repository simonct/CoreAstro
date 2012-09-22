//
//  CASExposuresController.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASExposuresController.h"
#import <CoreAstro/CoreAstro.h>

@implementation CASExposuresController

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index
{
    if (index != NSNotFound){
        [[[self arrangedObjects] objectAtIndex:index] deleteExposure];
        [super removeObjectAtArrangedObjectIndex:index];
    }
}

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
    if ([indexes count]){
        if ([indexes count] == 1){
            [self removeObjectAtArrangedObjectIndex:[indexes firstIndex]];
        }
        else {
            [[[self arrangedObjects] objectsAtIndexes:indexes] makeObjectsPerformSelector:@selector(deleteExposure)];
            [super removeObjectsAtArrangedObjectIndexes:indexes];
        }
    }
}

@end

