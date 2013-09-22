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
@property (nonatomic,strong) NSDictionary* filterNames;
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
        
        NSString* name = filterWheelController.filterWheel.deviceName;
        self.window.title = name ?: @"Filter Wheel";
        
        [self.window setFrameAutosaveName:self.window.title];
        
        [self updateFilterNames];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        //        NSLog(@"keyPath %@ -> %@",keyPath,[object valueForKeyPath:keyPath]);
        
        if ([@"filterCount" isEqualToString:keyPath]){
            
            if (self.filterSelectionMatrix.numberOfRows > self.filterWheelController.filterCount){
                
                // remove excess radio buttons
                while (self.filterSelectionMatrix.numberOfRows > self.filterWheelController.filterCount) {
                    [self.filterSelectionMatrix removeRow:[self.filterSelectionMatrix numberOfRows]-1];
                }
                
                // remove excess text fields
                for (NSTextField* textField in ((NSView*)self.window.contentView).subviews){
                    if ([textField isKindOfClass:[NSTextField class]]){
                        [textField setHidden:(textField.tag > self.filterWheelController.filterCount)];
                    }
                }
                
                // resize window to fit
                NSRect frame = self.window.frame;
                const CGFloat height = 40 + (22+12)*self.filterWheelController.filterCount;
                frame.origin.y += frame.size.height - height;
                frame.size.height = height;
                [self.window setFrame:frame display:NO animate:YES];
            }
        }
        else if ([@"currentFilter" isEqualToString:keyPath]) {
            
            if (self.filterWheelController.currentFilter != NSNotFound && !self.filterWheelController.moving){
                [self.filterSelectionMatrix selectCellAtRow:self.filterWheelController.currentFilter column:0];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSDictionary*)filterNames
{
    NSDictionary* filterNames = self.filterWheelController.filterNames;
    return filterNames ?: [NSMutableDictionary dictionaryWithCapacity:7];
}

- (void)setFilterNames:(NSDictionary*)names
{
    self.filterWheelController.filterNames = names;
    [self updateFilterNames];
}

- (void)updateFilterNames
{
    NSDictionary* names = self.filterNames;
    for (NSTextField* textField in ((NSView*)self.window.contentView).subviews){
        if ([textField isKindOfClass:[NSTextField class]]){
            NSString* name = names[[@(textField.tag - 1) description]];
            if (!name){
                name = @"";
            }
            if (![name isEqualToString:textField.stringValue]){
                textField.stringValue = name;
            }
            textField.delegate = (id)self;
        }
    }
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    [self setFilterName:[obj object]];
}

- (IBAction)setFilterName:(NSTextField*)sender
{
    // use NSDictionaryController ?
    const NSInteger tag = sender.tag;
    if (tag > 0){
        const NSInteger index = tag - 1;
        NSString* name = sender.stringValue;
        NSMutableDictionary* names = [self.filterNames mutableCopy];
        if (name){
            names[[@(index) description]] = name;
        }
        else {
            [names removeObjectForKey:[@(index) description]];
        }
        self.filterNames = names;
    }
}

@end
