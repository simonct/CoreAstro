//
//  CASFilterWheelControlsViewController.m
//  CoreAstro
//
//  Created by Simon Taylor on 6/2/13.
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

#import "CASFilterWheelControlsViewController.h"
#import <CoreAstro/CoreAstro.h>

@interface CASFilterWheelControlsViewController ()
@property (nonatomic,weak) IBOutlet NSPopUpButton *filterWheelMenu;
@property (nonatomic,weak) IBOutlet NSPopUpButton *filterWheelFilterMenu;
@property (nonatomic,weak) CASFilterWheelController* currentFilterWheel;
@end

@implementation CASFilterWheelControlsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self){
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"filterWheelControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    }
    return self;
}

- (void)dealloc
{
    [[CASDeviceManager sharedManager] removeObserver:self forKeyPath:@"filterWheelControllers"];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self updateFilterWheelMenu];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSLog(@"observeValueForKeyPath: %@ (%@)",keyPath,change);
    
    if (context == (__bridge void *)(self)) {
        
        if (object == [CASDeviceManager sharedManager]){
            
            if ([keyPath isEqualToString:@"filterWheelControllers"]){
                
                // new fw? add observers
                // old one, remove them
                
                [self updateFilterWheelMenu];
            }
        }
        else if (object == self.currentFilterWheel){
            
            [self updateFilterWheelFilterMenu];
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateFilterWheelMenu
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
        
    NSMenuItem* selectedItem = nil;
    for (CASFilterWheelController* filterWheel in [CASDeviceManager sharedManager].filterWheelControllers){
        
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:filterWheel.filterWheel.deviceName action:@selector(filterWheelMenuAction:) keyEquivalent:@""];
        item.representedObject = filterWheel;
        item.target = self;
        [menu addItem:item];

        if (self.currentFilterWheel == filterWheel){
            selectedItem = item;
        }
    }
    
    self.filterWheelMenu.menu = menu;
    
    NSArray* items = [menu itemArray];
    if (![items count]){
        self.filterWheelMenu.enabled = NO;
    }
    else {
        self.filterWheelMenu.enabled = YES;
        if (!selectedItem){
            selectedItem = items[0];
        }
    }
    [self.filterWheelMenu selectItem:selectedItem];
    
    [self filterWheelMenuAction:selectedItem];
}

- (void)updateFilterWheelFilterMenu
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];

    if (!self.currentFilterWheel){
        self.filterWheelFilterMenu.enabled = NO;
    }
    else{
        
        self.filterWheelFilterMenu.enabled = YES;
        for (NSUInteger i = 0; i < self.currentFilterWheel.filterWheel.filterCount; ++i){
            NSString* filterName = [NSString stringWithFormat:@"%ld",i+1]; // tmp, just use index
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:filterName action:@selector(filterWheelFilterMenuAction:) keyEquivalent:@""];
            item.target = self;
            [menu addItem:item];
        }
    }
    
    self.filterWheelFilterMenu.menu = menu;
    
    if (self.currentFilterWheel.filterWheel.currentFilter != NSNotFound){
        [self.filterWheelFilterMenu selectItemAtIndex:self.currentFilterWheel.filterWheel.currentFilter];
    }
}

- (IBAction)filterWheelMenuAction:(NSMenuItem*)sender
{
    NSLog(@"filterWheelMenuAction");
    
    [self.currentFilterWheel removeObserver:self forKeyPath:@"currentFilter"];
    [self.currentFilterWheel removeObserver:self forKeyPath:@"filterCount"];
    
    self.currentFilterWheel = sender.representedObject;

    [self.currentFilterWheel addObserver:self forKeyPath:@"currentFilter" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    [self.currentFilterWheel addObserver:self forKeyPath:@"filterCount" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
}

- (IBAction)filterWheelFilterMenuAction:(NSMenuItem*)sender
{
    NSLog(@"filterWheelFilterMenuAction");
    
    self.currentFilterWheel.currentFilter = [[self.filterWheelFilterMenu.menu itemArray] indexOfObject:sender];
}

@end
