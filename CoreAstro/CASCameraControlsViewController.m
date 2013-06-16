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

@interface CASCameraControlsViewController ()
@property (weak) IBOutlet NSTextField *sensorSizeField;
@property (weak) IBOutlet NSTextField *sensorPixelsField;
@property (weak) IBOutlet NSTextField *measuredTemperatureField;
@property (weak) IBOutlet NSTextField *measuredTemperatureLabel;
@property (weak) IBOutlet NSTextField *exposureField;
@property (weak) IBOutlet NSPopUpButton *exposureScalePopup;
@property (weak) IBOutlet NSMatrix *binningControl; // unused ? - same as binningRadioButtons
@property (weak) IBOutlet NSMatrix *binningRadioButtons;
@property (weak) IBOutlet NSTextField *subframeDisplay;
@property (weak) IBOutlet NSPopUpButton *captureMenu;
@property (nonatomic,assign) BOOL ditherInPHD;
@property (nonatomic,assign) NSInteger ditherInPHDAmount;
@property (nonatomic,assign) NSUInteger captureMenuSelectedIndex;
@end

@implementation CASCameraControlsViewController

+ (void)initialize
{
    if (self == [CASCameraControlsViewController class]){
        // register temp converter
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (CASCameraController*)cameraController
{
    return self.representedObject;
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    self.representedObject = cameraController;
    [self configureForCameraController];
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
        [self.sensorPixelsField setStringValue:[NSString stringWithFormat:@"%0.2fµm x %0.2fµm",camera.sensor.pixelWidth,camera.sensor.pixelHeight]];
    }
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
        
        self.sensorSizeField.stringValue = [NSString stringWithFormat:@"%@ x %@",
                                            [params valueForKeyPath:@"width"],
                                            [params valueForKeyPath:@"height"]];
        self.sensorPixelsField.stringValue = [NSString stringWithFormat:@"%0.2fµm x %0.2fµm",
                                              [[params valueForKeyPath:@"pixelWidth"] doubleValue],
                                              [[params valueForKeyPath:@"pixelHeight"] doubleValue]];
        
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
        if (self.cameraController.continuous){
            self.cameraController.captureCount = 0;
        }
        else {
            
            // tmp - probably replace with a different control style
            switch (_captureMenuSelectedIndex) {
                case 0:
                case 1:
                case 2:
                case 3:
                case 4:
                    self.cameraController.captureCount = _captureMenuSelectedIndex + 1;
                    break;
                case 5:
                    self.cameraController.captureCount = 10;
                    break;
                case 6:
                    self.cameraController.captureCount = 25;
                    break;
                case 7:
                    self.cameraController.captureCount = 50;
                    break;
                case 8:
                    self.cameraController.captureCount = 75;
                    break;
                default:
                    self.cameraController.captureCount = 1;
                    NSLog(@"Unknown exposure index: %ld",_captureMenuSelectedIndex);
                    break;
            }
        }
    }
}

@end
