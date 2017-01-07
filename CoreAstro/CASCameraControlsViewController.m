//
//  CASCameraControlsViewController.m
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

#import "CASCameraControlsViewController.h"
#import <CoreAstro/CoreAstro.h>

static NSString* const kCASCameraControlsOtherCountDefaultsKey = @"CASCameraControlsOtherCount";

@interface CASCameraControlsViewController ()
@property (weak) IBOutlet NSTextField *sensorLabel;
@property (weak) IBOutlet NSTextField *sensorSizeField;
@property (weak) IBOutlet NSTextField *sensorPixelsField;
@property (weak) IBOutlet NSTextField *measuredTemperatureField;
@property (weak) IBOutlet NSTextField *measuredTemperatureLabel;
@property (weak) IBOutlet NSTextField *exposureField;
@property (weak) IBOutlet NSPopUpButton *exposureScalePopup;
@property (weak) IBOutlet NSMatrix *binningRadioButtons;
@property (weak) IBOutlet NSTextField *subframeDisplay;
@property (weak) IBOutlet NSPopUpButton *captureMenu;
@property (strong) IBOutlet NSViewController *otherCountViewController;
@property (strong) IBOutlet NSUserDefaultsController *sharedDefaultsController;
@property (nonatomic,assign) BOOL ditherInPHD;
@property (nonatomic,assign) NSInteger ditherInPHDAmount;
@property (nonatomic,assign) NSUInteger captureMenuSelectedIndex;
@property (nonatomic,assign) NSInteger otherExposureCount;
@property (weak) IBOutlet NSTextField *exposureCompletionLabel;
@property (weak) IBOutlet NSTextField *phdEventLabel;
@end

@implementation CASCameraControlsViewController

static void* kvoContext;

+ (void)initialize
{
    if (self == [CASCameraControlsViewController class]){
        // register temp converter
    }
}

- (CASCameraController*)cameraController
{
    return self.representedObject;
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    [self.cameraController removeObserver:self forKeyPath:@"settings.subframe" context:&kvoContext];
    [self.cameraController removeObserver:self forKeyPath:@"settings.captureCount" context:&kvoContext];
    [self.cameraController removeObserver:self forKeyPath:@"settings.exposureDuration" context:&kvoContext];
    [self.cameraController removeObserver:self forKeyPath:@"settings.exposureUnits" context:&kvoContext];
    [self.cameraController removeObserver:self forKeyPath:@"settings.exposureInterval" context:&kvoContext];
    [self.cameraController removeObserver:self forKeyPath:@"capturing" context:&kvoContext];
    [self.cameraController.phd2Client removeObserver:self forKeyPath:@"lastEvent" context:&kvoContext];

    self.representedObject = cameraController;
    
    if (self.cameraController){
        [self.cameraController addObserver:self forKeyPath:@"settings.subframe" options:0 context:&kvoContext];
        [self.cameraController addObserver:self forKeyPath:@"settings.captureCount" options:0 context:&kvoContext];
        [self.cameraController addObserver:self forKeyPath:@"settings.exposureDuration" options:0 context:&kvoContext];
        [self.cameraController addObserver:self forKeyPath:@"settings.exposureUnits" options:0 context:&kvoContext];
        [self.cameraController addObserver:self forKeyPath:@"settings.exposureInterval" options:0 context:&kvoContext];
        [self.cameraController addObserver:self forKeyPath:@"capturing" options:0 context:&kvoContext];
        [self.cameraController.phd2Client addObserver:self forKeyPath:@"lastEvent" options:0 context:&kvoContext];
        [self configureForCameraController];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        if (object == self.cameraController.phd2Client) {
            [self.phdEventLabel setStringValue:self.cameraController.phd2Client.lastEvent ?: @""];
        }
        else {
            if ([keyPath isEqualToString:@"settings.subframe"]){
                
                const CGRect subframe = self.cameraController.settings.subframe;
                if (CGRectIsEmpty(subframe)){
                    [self.subframeDisplay setStringValue:@"Make a selection to define a subframe"];
                }
                else {
                    [self.subframeDisplay setStringValue:[NSString stringWithFormat:@"x=%.0f y=%.0f\nw=%.0f h=%.0f",subframe.origin.x,subframe.origin.y,subframe.size.width,subframe.size.height]];
                }
            }
            else if ([keyPath isEqualToString:@"capturing"]){
                [self configureBinningControls];
                [self configureExposureCountMenu];
                [self updateCompletionLabel];
            }
            else {
                [self updateCompletionLabel];
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateCompletionLabel
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];
    CASExposureSettings* settings = self.cameraController.settings;
    if (settings.exposureUnits != 0){
        self.exposureCompletionLabel.stringValue = @"";
    }
    else if (!self.cameraController.capturing) {
        const double duration = (settings.captureCount * settings.exposureDuration) + (settings.exposureInterval * (settings.captureCount - 1));
        NSDate* completionDate = [NSDate dateWithTimeIntervalSinceNow:duration];
        NSDateFormatter* formatter = [NSDateFormatter new];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        formatter.doesRelativeDateFormatting = YES;
        self.exposureCompletionLabel.stringValue = [NSString stringWithFormat:@"ends ~ %@",[formatter stringFromDate:completionDate]];
        [self performSelector:_cmd withObject:nil afterDelay:60]; // actually want to try an update on the minute...
    }
}

- (void)configureForCameraController
{
    CASCCDDevice* camera = self.cameraController.camera;
    
    if (!camera){
        [self.sensorSizeField setStringValue:@""];
        [self.sensorPixelsField setStringValue:@""];
    }
    else{
        [self.sensorSizeField setStringValue:[NSString stringWithFormat:@"%ld x %ld",camera.sensor.width,camera.sensor.height]];
        [self.sensorPixelsField setStringValue:[NSString stringWithFormat:@"%0.2fµm x %0.2fµm",camera.sensor.pixelSize.width,camera.sensor.pixelSize.height]];
    }
    
    [self configureBinningControls];
    [self configureExposureCountMenu];
    [self configureGuidingControls];
    [self updateCompletionLabel];
}

- (void)configureBinningControls
{
    NSArray* binningModes = self.cameraController.camera.binningModes;
    const BOOL capturing = self.cameraController.capturing;
    const BOOL hasCamera = (self.cameraController.camera != nil);
    const NSInteger n = [self.binningRadioButtons numberOfColumns];
    for (NSInteger i = 0; i < n; ++i){
        NSButtonCell* cell = [self.binningRadioButtons cellAtRow:0 column:i];
        const BOOL enabled = hasCamera && !capturing && ([binningModes containsObject:@(i+1)]);
        [cell setEnabled:enabled];
    }
    for (NSInteger i = 0; i < n; ++i){
        NSButtonCell* cell = [self.binningRadioButtons cellAtRow:0 column:i];
        const BOOL enabled = hasCamera && !capturing && ([binningModes containsObject:@(i+1)]);
        [cell setEnabled:enabled];
    }
}

- (void)configureExposureCountMenu
{
    [self willChangeValueForKey:@"captureMenuSelectedIndex"];
    
    const NSInteger captureCount = self.cameraController.settings.captureCount;
    switch (captureCount) {
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
            _captureMenuSelectedIndex = captureCount - 1;
            break;
        case 10:
            _captureMenuSelectedIndex = 5;
            break;
        case 25:
            _captureMenuSelectedIndex = 6;
            break;
        case 50:
            _captureMenuSelectedIndex = 7;
            break;
        case 75:
            _captureMenuSelectedIndex = 8;
            break;
        default:
            _captureMenuSelectedIndex = 10;
            self.otherExposureCount = captureCount;
            break;
    }
    
    [self didChangeValueForKey:@"captureMenuSelectedIndex"];
}

- (void)configureGuidingControls
{
    [self.phdEventLabel setStringValue:@""];
}

- (void)setExposure:(CASCCDExposure *)exposure
{
    if (exposure != _exposure){
        _exposure = exposure;
        [self configureForExposure];
    }
}

- (void)configureForExposure
{
    NSDictionary* params = [self.exposure.meta valueForKeyPath:@"device.params"];
    if (!params){
        self.exposureField.stringValue = self.sensorSizeField.stringValue = self.sensorPixelsField.stringValue = self.measuredTemperatureField.stringValue = @"";
    }
    else {
        
        // if the exposure doesn't match the current camera, change the Sensor heading to make that more obvious
        if ([self.exposure.deviceID isEqualToString:self.cameraController.device.uniqueID]){
            self.sensorLabel.stringValue = @"Sensor";
        }
        else {
            self.sensorLabel.stringValue = @"Exposure";
        }
        
        self.sensorSizeField.stringValue = [NSString stringWithFormat:@"%@ x %@",
                                            [params valueForKeyPath:@"width"],
                                            [params valueForKeyPath:@"height"]];
        
        const CGSize pixelSize = NSSizeFromString([params valueForKeyPath:@"pixelSize"]);
        self.sensorPixelsField.stringValue = [NSString stringWithFormat:@"%0.2fµm x %0.2fµm",pixelSize.width,pixelSize.height];
        
        NSUInteger ms = self.exposure.params.ms;
        if (!ms){
            self.exposureField.stringValue = @"";
            [self.exposureScalePopup selectItemAtIndex:0];
        }
        else {
            if (ms > 999){
                ms /= 1000;
                [self.exposureScalePopup selectItemAtIndex:0];
            }
            else {
                [self.exposureScalePopup selectItemAtIndex:1];
            }
            self.exposureField.stringValue = [NSString stringWithFormat:@"%ld",ms];
        }
        
        [self.binningRadioButtons selectCellAtRow:0 column:self.exposure.params.bin.width - 1];
        
        if (!self.exposure.isSubframe){
            self.subframeDisplay.stringValue = @"";
        }
        else {
            self.subframeDisplay.stringValue = [NSString stringWithFormat:@"x=%ld y=%ld\nw=%ld h=%ld",self.exposure.params.origin.x,self.exposure.params.origin.y,self.exposure.params.size.width,self.exposure.params.size.height];
        }
        
        // need to see how this interacts with a camera connected e.g. is this conflicting with bindings ?
        
        NSArray* temps = [self.exposure valueForKeyPath:@"meta.temperature.temperatures"];
        if ([temps count]){
            double avTemp = 0;
            for (NSNumber* temp in temps){
                avTemp += [temp doubleValue];
            }
            avTemp /= [temps count];
            self.measuredTemperatureLabel.hidden = self.measuredTemperatureField.hidden = NO;
            self.measuredTemperatureField.stringValue = [NSString stringWithFormat:@"%.1f",avTemp];
        }
        else {
            self.measuredTemperatureLabel.hidden = self.measuredTemperatureField.hidden = YES;
            self.measuredTemperatureField.stringValue = @"";
        }
    }
}

- (void)setCaptureMenuSelectedIndex:(NSUInteger)index
{
    if (_captureMenuSelectedIndex != index){
        _captureMenuSelectedIndex = index;
        if (self.cameraController.settings.continuous){
            self.cameraController.settings.captureCount = 0;
        }
        else {
            
            // tmp - probably replace with a different control style
            switch (_captureMenuSelectedIndex) {
                case 0:
                case 1:
                case 2:
                case 3:
                case 4:
                    self.cameraController.settings.captureCount = _captureMenuSelectedIndex + 1;
                    break;
                case 5:
                    self.cameraController.settings.captureCount = 10;
                    break;
                case 6:
                    self.cameraController.settings.captureCount = 25;
                    break;
                case 7:
                    self.cameraController.settings.captureCount = 50;
                    break;
                case 8:
                    self.cameraController.settings.captureCount = 75;
                    break;
                default:{
                    NSPopover* popover = [[NSPopover alloc] init];
                    popover.behavior = NSPopoverBehaviorTransient;
                    popover.contentViewController = self.otherCountViewController;
                    [popover showRelativeToRect:self.captureMenu.frame ofView:self.view preferredEdge:NSMaxXEdge];
                    const NSInteger count = self.otherExposureCount;
                    if (count > 0){
                        self.cameraController.settings.captureCount = count;
                    }
                }
                    break;
            }
        }
    }
}

- (NSString*)keyWithCameraID:(NSString*)key // todo; push into a base class/utility
{
    return self.cameraController ? [key stringByAppendingFormat:@"_%@",self.cameraController.camera.uniqueID] : key;
}

- (NSString*)otherExposureCountKey
{
    return [self keyWithCameraID:kCASCameraControlsOtherCountDefaultsKey];
}

- (NSInteger)otherExposureCount
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:[self otherExposureCountKey]];
}

- (void)setOtherExposureCount:(NSInteger)count
{
    count = MIN(MAX(0,count),10000);
    [[NSUserDefaults standardUserDefaults] setInteger:count forKey:[self otherExposureCountKey]];
    self.cameraController.settings.captureCount = count;
}

+ (NSSet*)keyPathsForValuesAffectingOtherExposureCount
{
    return [NSSet setWithObject:@"cameraController"];
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"otherExposureCount" isEqualToString:key]){
        self.otherExposureCount = 0;
    }
    else {
        [super setNilValueForKey:key];
    }
}

- (NSString*)otherMenuItemTitle
{
    const NSInteger count = self.otherExposureCount;
    return count > 0 ? [NSString stringWithFormat:@"%ld frames...",(long)count] : @"Other...";
}

+ (NSSet*)keyPathsForValuesAffectingOtherMenuItemTitle
{
    return [NSSet setWithObject:@"otherExposureCount"];
}

@end
