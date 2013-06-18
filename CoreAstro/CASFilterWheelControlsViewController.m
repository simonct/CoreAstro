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
    if (context == (__bridge void *)(self)) {
        if (object == [CASDeviceManager sharedManager]){
            if ([keyPath isEqualToString:@"filterWheelControllers"]){
                [self updateFilterWheelMenu];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateFilterWheelMenu
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
    
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"None" action:@selector(guiderMenuAction:) keyEquivalent:@""];
    [menu addItem:item];
    
    NSMenuItem* selectedItem = nil;
    if ([[CASDeviceManager sharedManager].filterWheelControllers count]){
        [menu addItem:[NSMenuItem separatorItem]];
        for (CASFilterWheelController* filterWheel in [CASDeviceManager sharedManager].filterWheelControllers){
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:filterWheel.filterWheel.deviceName action:@selector(filterWheelMenuAction:) keyEquivalent:@""];
            item.representedObject = filterWheel;
            [menu addItem:item];
            if (self.currentFilterWheel == filterWheel){
                selectedItem = item;
            }
        }
    }
    
    self.filterWheelMenu.menu = menu;
    if (!selectedItem){
        selectedItem = [[menu itemArray] objectAtIndex:0]; // None item
    }
    [self.filterWheelMenu selectItem:selectedItem];
    
}

- (IBAction)filterWheelMenuAction:(NSMenuItem*)sender
{
    NSLog(@"filterWheelMenuAction");
    
    self.currentFilterWheel = sender.representedObject;
}

- (void)setCurrentFilterWheel:(CASFilterWheelController *)currentFilterWheel
{
    _currentFilterWheel = currentFilterWheel;
}

@end
