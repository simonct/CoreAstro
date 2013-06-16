//
//  CASGuiderControlsViewController.m
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

#import "CASGuiderControlsViewController.h"
#import <CoreAstro/CoreAstro.h>

@interface CASGuiderControlsViewController ()
@property (nonatomic,weak) IBOutlet NSPopUpButton *guiderMenu;
@property (nonatomic,assign) NSInteger guidePulseDuration;
@end

@implementation CASGuiderControlsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self){
        self.guidePulseDuration = 250;
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"guiderControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    }
    return self;
}

- (void)dealloc
{
    [[CASDeviceManager sharedManager] removeObserver:self forKeyPath:@"guiderControllers"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        if (object == [CASDeviceManager sharedManager]){
            if ([keyPath isEqualToString:@"guiderControllers"]){
                [self updateGuiderMenu];
                // guider came or went
                //                NSLog(@"%@: %@ -> %@",object,keyPath,[object valueForKeyPath:keyPath]);
                //                NSLog(@"%@: %@",object,change);
                // add, kind == 2 (NSKeyValueChangeInsertion)
                // remove, kind == 3 (NSKeyValueChangeRemoval)
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

// todo; implement click and hold behaviour for pulse buttons
- (IBAction)pulseNorth:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_DecPlus duration:self.guidePulseDuration block:nil];
}

- (IBAction)pulseSouth:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_DecMinus duration:self.guidePulseDuration block:nil];
}

- (IBAction)pulseEast:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_RAMinus duration:self.guidePulseDuration block:nil];
}

- (IBAction)pulseWest:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_RAPlus duration:self.guidePulseDuration block:nil];
    
}

- (void)updateGuiderMenu
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
    
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"None" action:@selector(guiderMenuAction:) keyEquivalent:@""];
    [menu addItem:item];
    
    NSMenuItem* selectedItem = nil;
    if ([[CASDeviceManager sharedManager].guiderControllers count]){
        [menu addItem:[NSMenuItem separatorItem]];
        for (CASGuiderController* guider in [CASDeviceManager sharedManager].guiderControllers){
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:guider.guider.deviceName action:@selector(guiderMenuAction:) keyEquivalent:@""];
            item.representedObject = guider;
            [menu addItem:item];
            if (self.cameraController.guider == guider){
                selectedItem = item;
            }
        }
    }
    
    self.guiderMenu.menu = menu;
    if (!selectedItem){
        selectedItem = [[menu itemArray] objectAtIndex:0]; // None item
    }
    [self.guiderMenu selectItem:selectedItem];
    
    if (self.cameraController.guider && !selectedItem){
        self.cameraController.guider = nil;
        // hide guider UI
    }
}

- (IBAction)guiderMenuAction:(NSMenuItem*)sender
{
    return; // tmp
    
    if (!sender.representedObject){
        self.cameraController.guider = nil;
//        self.guideControlsContainer.hidden = YES;
    }
    else {
        self.cameraController.guider = sender.representedObject;
//        self.guideControlsContainer.hidden = NO;
//        self.imageView.showStarProfile = YES;
    }
}

@end
