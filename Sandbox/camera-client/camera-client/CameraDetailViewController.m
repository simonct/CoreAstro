//
//  CameraViewController.m
//  camera-client
//
//  Created by Simon Taylor on 27/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CameraDetailViewController.h"
#import "SXIORemoteControl.h"

@interface ContrastStretchFilter : CIFilter
@end

@implementation ContrastStretchFilter {
    CIImage* inputImage;
    NSNumber* inputLower;
    NSNumber* inputUpper;
    NSNumber* inputGamma;
}

- (CIColorKernel*)colourKernel
{
    static CIColorKernel* kernel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
//        NSString* contrastStretch = @"kernel vec4 contrastStretch(__sample s, float minval, float maxval, float gamma){\
//        float range = maxval - minval;\
//        float scale = 1.0 / range;\
//        vec4 result = s;\
//        result.rgb = clamp(s.rgb - minval,vec3(0),vec3(1)) * scale;\
//        return result;\
//        }";

        //         result.rgb = s.r < minval ? vec3(0) : s.r > maxval ? vec3(1) : (s.rgb - minval) * scale;\
        //         result.rgb = s.r < minval ? vec3(0) : s.r > maxval ? vec3(1) : vec3(0.5);\

        NSString* contrastStretch = @"kernel vec4 contrastStretch(__sample s, float minval, float maxval, float gamma){\
        minval=0.017;\
        maxval=0.025;\
        float scale = 1.0/(maxval - minval);\
        vec4 result = s;\
        result.rgb = s.r < minval ? vec3(0) : s.r > maxval ? vec3(1) : (s.rgb - minval) * scale;\
        result.a = 1.0;\
        return result;\
        }";

        kernel = [CIColorKernel kernelWithString:contrastStretch];
    });
    return kernel;
}

- (CIImage *)outputImage
{
    if (!inputImage){
        return nil;
    }
    return [[self colourKernel] applyWithExtent:inputImage.extent arguments:@[inputImage,inputLower ?: @(0),inputUpper ?: @(1),inputGamma ?: @(1)]];
}

@end

@interface StatusView : UIView
@property (nonatomic,weak) UIVisualEffectView* effectsView;
@end

@implementation StatusView

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    
    if (self.superview){
        if (!self.effectsView && [UIVisualEffectView class]){
            UIVisualEffectView* effectsView = [[UIVisualEffectView alloc] initWithFrame:self.bounds];
            [self addSubview:effectsView];
            [self sendSubviewToBack:effectsView];
            effectsView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            self.effectsView = effectsView;
        }
        else {
            self.backgroundColor = [UIColor whiteColor];
        }
    }
}

@end

@interface CameraDetailViewController ()
@property (nonatomic,strong) NSMutableDictionary* completions;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (copy, nonatomic) NSString* lastExposureUUID;
@property (copy, nonatomic) id lastExposureUpper;
@property (copy, nonatomic) id lastExposureLower;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (strong, nonatomic) NSProgress* downloadProgress;
@end

@implementation CameraDetailViewController

static void* kvoContext;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.downloadProgress = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Camera";
    self.statusLabel.text = nil;
    self.progressBar.hidden = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusChanged:) name:kSXIORemoteControlCameraStatusChangedNotification object:nil];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Capture" style:UIBarButtonItemStylePlain target:self action:@selector(capture:)];
}

- (void)statusChanged:(NSNotification*)note
{
    NSAssert([NSThread isMainThread], @"statusChanged");
    
    NSDictionary* msg = [note userInfo];
    if ([[_camera[@"id"] description] isEqualToString:[msg[@"id"] description]]){
        [self processCameraStatus:msg];
    }
}

- (void)capture:sender
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [[SXIORemoteControl sharedControl] startCaptureWithCamera:_camera[@"id"] completion:^(NSError *error, NSDictionary *response) {
        NSString* errorString = [error localizedDescription];
        if (!errorString){
            errorString = response[@"error"];
        }
        if (errorString){
            self.navigationItem.rightBarButtonItem.enabled = YES;
            [[[UIAlertView alloc] initWithTitle:@"Capture" message:errorString delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
}

- (void)getLastExposure
{
    if (!_camera[@"id"]){
        return;
    }
    
    [[SXIORemoteControl sharedControl] getLastExposureWithCamera:_camera[@"id"] completion:^(NSProgress* progress,NSError *error, NSData *data) {
        
        NSAssert([NSThread isMainThread], @"getLastExposure");

        if (error){
            self.progressBar.hidden = YES;
            [[[UIAlertView alloc] initWithTitle:@"Get Exposure" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
        else {
            if (progress){
                self.downloadProgress = progress;
                self.statusLabel.text = @"Downloading...";
            }
            else {
                self.downloadProgress = nil;
                if (error){
                    self.lastExposureUUID = nil;
                }
                else {
                    
                    if (/*self.lastExposureLower && self.lastExposureUpper && [CIColorKernel class]*/0){
                        
                        CIImage* input = [CIImage imageWithData:data];
                        
                        CIFilter* stretchFilter = [ContrastStretchFilter new];
                        [stretchFilter setValue:input forKey:@"inputImage"];
                        [stretchFilter setValue:@([self.lastExposureLower floatValue]) forKey:@"inputLower"];
                        [stretchFilter setValue:@([self.lastExposureUpper floatValue]) forKey:@"inputUpper"];
                        CIImage* output = [stretchFilter valueForKey:@"outputImage"];

//                        CIFilter* compFilter = [CIFilter filterWithName:@"CIMaximumComponent"];
//                        [compFilter setValue:output forKey:@"inputImage"];
//                        output = [compFilter valueForKey:@"outputImage"];
                        
                        CIContext *context = [CIContext contextWithOptions: nil];
                        CGImageRef cgImage = [context createCGImage:output fromRect: output.extent]; // slow...
                        UIImage *resultUIImage = [UIImage imageWithCGImage: cgImage]; // [UIImage imageWithCIImage:image]
                        self.imageView.image = resultUIImage;
                    }
                    else {
                        self.imageView.image = [UIImage imageWithData:data];
                    }
                }
                self.statusLabel.text = nil;
            }
        }
    }];
}

- (void)processCameraStatus:(NSDictionary*)status
{
    NSAssert([NSThread isMainThread], @"processCameraStatus");

    typedef NS_ENUM(NSInteger, CASCameraControllerState) {
        CASCameraControllerStateNone,
        CASCameraControllerStateWaitingForTemperature,
        CASCameraControllerStateExposing, // or downloading
        CASCameraControllerStateWaitingForNextExposure,
        CASCameraControllerStateDithering
    };
    _camera = status;
    switch ([_camera[@"state"] integerValue]) {
        case CASCameraControllerStateWaitingForTemperature:
            self.statusLabel.text = @"Waiting for temperature...";
            break;
        case CASCameraControllerStateExposing:
            self.statusLabel.text = @"Capturing...";
            break;
        case CASCameraControllerStateWaitingForNextExposure:
            self.statusLabel.text = @"Waiting for next exposure...";
            break;
        case CASCameraControllerStateDithering:
            self.statusLabel.text = @"Dithering...";
            break;
        default:
        case CASCameraControllerStateNone:
            self.statusLabel.text = nil;
            break;
    }
    if ([_camera[@"state"] integerValue] == 0 && ![_camera[@"last-exposure"] isEqualToString:self.lastExposureUUID]){
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.lastExposureUUID = _camera[@"last-exposure"];
        self.lastExposureLower = _camera[@"last-exposure-lower"];
        self.lastExposureUpper = _camera[@"last-exposure-upper"];
        [self getLastExposure];
    }
    const float progress = [_camera[@"progress"] floatValue];
    if (progress > 0){
        self.progressBar.hidden = NO;
        self.progressBar.progress = progress;
    }
    else {
        self.progressBar.hidden = YES;
    }
}

- (void)setCamera:(NSDictionary *)camera
{
    if (camera != _camera){
        _camera = camera;
        self.title = _camera[@"name"];
        if (_camera){
            [[SXIORemoteControl sharedControl] cameraStatusWithCamera:_camera[@"id"] completion:^(NSError *error, NSDictionary *response) {
                if (!error){
                    [self processCameraStatus:response[@"status"]];
                }
            }];
        }
    }
}

- (void)setDownloadProgress:(NSProgress *)downloadProgress
{
    if (_downloadProgress != downloadProgress){
        [_downloadProgress removeObserver:self forKeyPath:@"fractionCompleted" context:&kvoContext];
        _downloadProgress = downloadProgress;
        self.progressBar.hidden = (_downloadProgress == nil);
        [_downloadProgress addObserver:self forKeyPath:@"fractionCompleted" options:0 context:&kvoContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if (object == self.downloadProgress){
            self.progressBar.hidden = NO;
            self.progressBar.progress = self.downloadProgress.fractionCompleted;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
