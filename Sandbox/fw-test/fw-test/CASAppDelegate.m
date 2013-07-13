//
//  CASAppDelegate.m
//  fw-test
//
//  Created by Simon Taylor on 2/9/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASAppDelegate.h"
#import "CASHIDDeviceBrowser.h"
#import "SXCCDDeviceFactory.h"
#import "SXFWDevice.h"

@interface CASAppDelegate ()
@property (nonatomic,strong) CASHIDDeviceBrowser* browser;
@property (nonatomic,strong) SXCCDDeviceFactory* factory;
@property (nonatomic,strong) SXFWDevice* fw;
@end

@implementation CASAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.browser = [[CASHIDDeviceBrowser alloc] init];
    self.factory = [[SXCCDDeviceFactory alloc] init];
    
    __weak CASAppDelegate* weakSelf = self;
    self.browser.deviceRemoved = ^(void* dev,NSString* path,NSDictionary* props) {
        
        CASAppDelegate* strongSelf = weakSelf;
        if (strongSelf && [path isEqualToString:strongSelf.fw.path]){
            [strongSelf.fw removeObserver:strongSelf forKeyPath:@"filterCount" context:(__bridge void *)(strongSelf)];
            [strongSelf.fw removeObserver:strongSelf forKeyPath:@"currentFilter" context:(__bridge void *)(strongSelf)];
            [strongSelf.fw disconnect];
            strongSelf.fw = nil;
        }
        
        return (CASDevice*)nil;
    };

    [self.browser scan:^CASDevice *(void *dev, NSString *path, NSDictionary *props) {
        
        SXFWDevice* fw = (SXFWDevice*)[self.factory createDeviceWithDeviceRef:dev path:path properties:props];
        if ([fw isKindOfClass:[SXFWDevice class]]){
            
            fw.transport = [self.browser createTransportWithDevice:fw];
            
            [fw connect:^(NSError* error) {
                
                if (error){
                    NSLog(@"connect: %@",error);
                }
                else {
                    self.fw = fw;
                    [self.fw addObserver:self forKeyPath:@"filterCount" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
                    [self.fw addObserver:self forKeyPath:@"currentFilter" options:NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
                }
            }];
        }
        
        return NO;
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
//        NSLog(@"keyPath %@ -> %@",keyPath,[object valueForKeyPath:keyPath]);
        
        if ([@"filterCount" isEqualToString:keyPath]){
            
            while (self.filterSelectionMatrix.numberOfColumns > self.fw.filterCount) {
                [self.filterSelectionMatrix removeColumn:[self.filterSelectionMatrix numberOfColumns]-1];
            }
            [self.filterSelectionMatrix sizeToCells];
            [self.filterSelectionMatrix.superview layout];
        }
        else if ([@"currentFilter" isEqualToString:keyPath]) {
            
            if (self.fw.currentFilter != NSNotFound && !self.fw.moving){
                [self.filterSelectionMatrix selectCellAtRow:0 column:self.fw.currentFilter];
            }
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)setCurrentFilter:(NSMatrix*)sender
{
    [self.fw setCurrentFilter:[sender.cells indexOfObject:sender.selectedCell]];
}

@end
