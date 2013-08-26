//
//  SXIOFilterWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 8/18/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOFilterWindowController.h"

@interface SXIOFilterWindowController ()
@property (weak) IBOutlet NSMatrix *filterSelectionMatrix;
- (IBAction)setCurrentFilter:(NSMatrix*)sender;
@end

@implementation SXIOFilterWindowController

static void* kvoContext;

- (void)dealloc
{
    if (_filterWheelController){
        [_filterWheelController removeObserver:self forKeyPath:@"filterCount" context:&kvoContext];
        [_filterWheelController removeObserver:self forKeyPath:@"currentFilter" context:&kvoContext];
    }
}

- (void)setFilterWheelController:(CASFilterWheelController *)filterWheelController
{
    if (filterWheelController != _filterWheelController){
        if (_filterWheelController){
            [_filterWheelController removeObserver:self forKeyPath:@"filterCount" context:&kvoContext];
            [_filterWheelController removeObserver:self forKeyPath:@"currentFilter" context:&kvoContext];
        }
        _filterWheelController = filterWheelController;
        if (_filterWheelController){
            [_filterWheelController addObserver:self forKeyPath:@"filterCount" options:NSKeyValueObservingOptionInitial context:&kvoContext];
            [_filterWheelController addObserver:self forKeyPath:@"currentFilter" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        //        NSLog(@"keyPath %@ -> %@",keyPath,[object valueForKeyPath:keyPath]);
        
        if ([@"filterCount" isEqualToString:keyPath]){
            
            while (self.filterSelectionMatrix.numberOfColumns > self.filterWheelController.filterCount) {
                [self.filterSelectionMatrix removeColumn:[self.filterSelectionMatrix numberOfColumns]-1];
            }
            [self.filterSelectionMatrix sizeToCells];
            [self.filterSelectionMatrix.superview layout];
        }
        else if ([@"currentFilter" isEqualToString:keyPath]) {
            
            if (self.filterWheelController.currentFilter != NSNotFound && !self.filterWheelController.moving){
                [self.filterSelectionMatrix selectCellAtRow:0 column:self.filterWheelController.currentFilter];
            }
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)setCurrentFilter:(NSMatrix*)sender
{
    [self.filterWheelController setCurrentFilter:[sender.cells indexOfObject:sender.selectedCell]];
}

@end
