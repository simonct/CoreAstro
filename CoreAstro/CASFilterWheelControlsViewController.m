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
@property (nonatomic,copy) NSString* filterName;
@property (nonatomic,weak) IBOutlet NSTextField *filterTextField;
@property (nonatomic,weak) IBOutlet NSPopUpButton *filterWheelMenu;
@property (nonatomic,weak) IBOutlet NSPopUpButton *filterWheelFilterMenu;
@property (nonatomic,weak) CASFilterWheelController* currentFilterWheel;
@end

static NSString* const kCASFilterWheelControlsViewControllerFilterNameDefaultsKey = @"CASFilterWheelControlsViewControllerFilterName";

@implementation CASFilterWheelControlsViewController

static void* kvoContext;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self){
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"filterWheelControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];
    }
    return self;
}

- (void)dealloc
{
    self.currentFilterWheel = nil; // unobserves the current filter wheel
    [[CASDeviceManager sharedManager] removeObserver:self forKeyPath:@"filterWheelControllers"];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self updateFilterWheelMenu];
}

- (NSString*)filterName
{
    return self.currentFilterWheel ? nil: [[NSUserDefaults standardUserDefaults] stringForKey:kCASFilterWheelControlsViewControllerFilterNameDefaultsKey];
}

- (void)setFilterName:(NSString *)filterName
{
    filterName = [CASFilterWheelController sanitizeFilterName:filterName]; // limit to ascii
    if (!filterName){
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCASFilterWheelControlsViewControllerFilterNameDefaultsKey];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setObject:filterName forKey:kCASFilterWheelControlsViewControllerFilterNameDefaultsKey];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField* textField = [obj object];
    NSString* stringValue = textField.stringValue;
    NSString* sanitized = [CASFilterWheelController sanitizeFilterName:textField.stringValue];
    if (![sanitized isEqualToString:stringValue]){
        textField.stringValue = sanitized;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
//    NSLog(@"observeValueForKeyPath: %@ (%@)",keyPath,change);
    
    if (context == &kvoContext) {
        
        if (object == [CASDeviceManager sharedManager]){
            if ([keyPath isEqualToString:@"filterWheelControllers"]){
                [self updateFilterWheelMenu];
            }
        }
        [self updateFilterWheelFilterMenu];
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateFilterWheelMenu
{
    NSMenuItem* selectedItem = nil;
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];

    NSArray* filterWheelControllers = [CASDeviceManager sharedManager].filterWheelControllers;
    if (![filterWheelControllers count]){
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"None" action:nil keyEquivalent:@""]];
    }
    else {
        
        for (CASFilterWheelController* filterWheel in filterWheelControllers){
            
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:filterWheel.filterWheel.deviceName action:@selector(filterWheelMenuAction:) keyEquivalent:@""];
            item.representedObject = filterWheel;
            item.target = self;
            [menu addItem:item];
            
            if (self.currentFilterWheel == filterWheel){
                selectedItem = item;
            }
        }
    }
    
    self.filterWheelMenu.menu = menu;
    
    NSArray* items = [menu itemArray];
    if ([items count]){
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

    const NSInteger filterCount = self.currentFilterWheel.filterWheel.filterCount;
    if (!filterCount){
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"None" action:nil keyEquivalent:@""]];
    }
    else{
    
        for (NSUInteger i = 0; i < filterCount; ++i){
            NSString* filterName = self.currentFilterWheel.filterNames[[@(i) description]] ?: [NSString stringWithFormat:@"Filter %ld",i+1];
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
    self.currentFilterWheel = sender.representedObject;
}

- (IBAction)filterWheelFilterMenuAction:(NSMenuItem*)sender
{
    self.currentFilterWheel.currentFilter = [[self.filterWheelFilterMenu.menu itemArray] indexOfObject:sender];
}

- (void)setCurrentFilterWheel:(CASFilterWheelController *)currentFilterWheel
{
    if (_currentFilterWheel){
        [_currentFilterWheel removeObserver:self forKeyPath:@"currentFilter" context:&kvoContext];
        [_currentFilterWheel removeObserver:self forKeyPath:@"filterCount" context:&kvoContext];
        [_currentFilterWheel removeObserver:self forKeyPath:@"filterNames" context:&kvoContext];
    }
    
    _currentFilterWheel = currentFilterWheel;
    
    if (_currentFilterWheel){
        [_currentFilterWheel addObserver:self forKeyPath:@"currentFilter" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        [_currentFilterWheel addObserver:self forKeyPath:@"filterCount" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        [_currentFilterWheel addObserver:self forKeyPath:@"filterNames" options:NSKeyValueObservingOptionInitial context:&kvoContext];
    }
    
    self.cameraController.filterWheel = _currentFilterWheel;
}

@end
