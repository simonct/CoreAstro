//
//  CASCameraController.h
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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

#import "CASDeviceController.h"
#import "CASCCDExposure.h"
#import "CASExposureSettings.h"

@class CASCCDDevice;
@class CASImageProcessor;
@class CASGuideAlgorithm;
@class CASGuiderController;
@class CASFilterWheelController;
@class CASCameraController;
@class CASPHD2Client; // tmp for flipping
@class CASMountController;

@protocol CASCameraControllerSink <NSObject>
- (void)cameraController:(CASCameraController*)controller didCompleteExposure:(CASCCDExposure*)exposure error:(NSError*)error;
@end

@interface CASCameraController : CASDeviceController

@property (nonatomic,readonly,strong) CASCCDDevice* camera;

typedef NS_ENUM(NSInteger, CASCameraControllerState) {
    CASCameraControllerStateNone,
    CASCameraControllerStateWaitingForTemperature,
    CASCameraControllerStateWaitingForGuider,
    CASCameraControllerStateExposing, // or downloading
    CASCameraControllerStateWaitingForNextExposure,
    CASCameraControllerStateDithering
};
@property (nonatomic,readonly) CASCameraControllerState state;
@property (nonatomic,readonly) float progress;

typedef NS_ENUM(NSInteger, CASCameraControllerRole) {
    CASCameraControllerRoleNone,
    CASCameraControllerRoleMaster,
    CASCameraControllerRoleSlave
};
@property (nonatomic,assign) CASCameraControllerRole role;

@property (nonatomic,readonly) BOOL capturing;

// tmp; moved to settings but kept for compatibility with bindings
@property (nonatomic,assign) BOOL temperatureLock;
@property (nonatomic,assign) CGFloat targetTemperature;

@property (nonatomic,readonly) CASExposureSettings* settings;

@property (nonatomic,strong) NSDate* exposureStart;

@property (nonatomic,strong) CASCCDExposure* lastExposure;

@property (strong) CASGuiderController* guider;
@property (weak) CASFilterWheelController* filterWheel;
@property (nonatomic,weak) CASMountController* mountController;

@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASGuideAlgorithm* guideAlgorithm;

@property (nonatomic,strong) id<CASCameraControllerSink> sink;

@property (nonatomic,strong,readonly) CASPHD2Client* phd2Client;
@property BOOL suppressDither;

@property (nonatomic,readonly) BOOL cancelled;

- (id)initWithCamera:(CASCCDDevice*)camera;

- (void)connect:(void(^)(NSError*))block;
- (void)disconnect;

- (void)resetCapture; // clears suspended flag, sets capture index back to 0

- (void)captureWithBlock:(void(^)(NSError*,CASCCDExposure*))block;
- (void)captureWithRole:(CASCameraControllerRole)role block:(void(^)(NSError*,CASCCDExposure*))block;

- (void)cancelCapture;
- (void)suspendCapture;

- (void)pushSettings:(CASExposureSettings*)settings;
- (void)popSettings;

- (CGSize)arcsecsPerPixelForFocalLength:(float)focalLength;
- (CGSize)fieldSizeForFocalLength:(float)focalLength;

@property (nonatomic) float focalLength;
+ (NSString*)focalLengthWithCameraKey:(CASCameraController*)cameraController;

@end

@interface CASCameraController (CASCCDExposure)
- (void)updateSettingsWithExposure:(CASCCDExposure*)exposure;
@end

extern NSString* const kCASCameraControllerExposureStartedNotification;
extern NSString* const kCASCameraControllerExposureCompletedNotification;

extern NSString* const kCASCameraControllerGuideErrorNotification;
extern NSString* const kCASCameraControllerGuideCommandNotification;
