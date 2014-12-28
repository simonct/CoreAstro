//
//  SXIOPlateSolveOptionsWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 2/21/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "SXIOPlateSolveOptionsWindowController.h"

@interface SXIOPlateSolveOptionsWindowController ()
@property (nonatomic,assign) float focalLength;
@property (nonatomic,assign) float pixelSize;
@property (nonatomic,assign) float sensorWidth;
@property (nonatomic,assign) float sensorHeight;
@property (nonatomic,assign) NSInteger binning;
@property (nonatomic,assign) CGSize fieldSizeDegrees;
@property (nonatomic,assign) float arcsecsPerPixel;
@property (nonatomic,assign) BOOL enableFieldSize;
@property (nonatomic,assign) BOOL enablePixelSize;
@end

@implementation SXIOPlateSolveOptionsWindowController {
    BOOL _observing:1;
}

static void* kvoContext;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self){
    }
    return self;
}

- (void)dealloc
{
    if (_observing){
        [self removeObserver:self forKeyPath:@"focalLength" context:&kvoContext];
        [self removeObserver:self forKeyPath:@"pixelSize" context:&kvoContext];
        [self removeObserver:self forKeyPath:@"sensorWidth" context:&kvoContext];
        [self removeObserver:self forKeyPath:@"sensorHeight" context:&kvoContext];
        [self removeObserver:self forKeyPath:@"binning" context:&kvoContext];
    }
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    if (!_observing){
        _observing = YES;
        [self addObserver:self forKeyPath:@"focalLength" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        [self addObserver:self forKeyPath:@"pixelSize" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        [self addObserver:self forKeyPath:@"sensorWidth" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        [self addObserver:self forKeyPath:@"sensorHeight" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        [self addObserver:self forKeyPath:@"binning" options:NSKeyValueObservingOptionInitial context:&kvoContext];
    }
    
    CASCCDProperties* sensor = self.cameraController.camera.sensor;
    if (sensor) {
        self.pixelSize = 7.4; // sensor.pixelSize.width;
        self.sensorWidth = 34; // sensor.sensorSize.width;
        self.sensorHeight = 22; // sensor.sensorSize.height;
        self.binning = self.cameraController.settings.binning ?: 1;
    }
    else {
        self.binning = 1;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        [self calculateFieldSize];
        [self calculateImageScale];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSString*)focalLengthKey
{
    NSString* const key = @"SXIOPlateSolverFocalLength";
    return [NSString stringWithFormat:@"%@%@",key,self.cameraController.camera.uniqueID];
}

- (float)focalLength
{
    return [[NSUserDefaults standardUserDefaults] floatForKey:[self focalLengthKey]];
}

- (void)setFocalLength:(float)focalLength
{
    [[NSUserDefaults standardUserDefaults] setFloat:focalLength forKey:[self focalLengthKey]];
}

- (BOOL)enableFieldSize
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOPlateSolverEnableFieldSize"];
}

- (void)setEnableFieldSize:(BOOL)enableFieldSize
{
    [[NSUserDefaults standardUserDefaults] setBool:enableFieldSize forKey:@"SXIOPlateSolverEnableFieldSize"];
}

- (BOOL)enablePixelSize
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOPlateSolverEnablePixelSize"];
}

- (void)setEnablePixelSize:(BOOL)enablePixelSize
{
    [[NSUserDefaults standardUserDefaults] setBool:enablePixelSize forKey:@"SXIOPlateSolverEnablePixelSize"];
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"focalLength" isEqualToString:key]){
        self.focalLength = 0;
    }
    else if ([@"pixelSize" isEqualToString:key]){
        self.pixelSize = 0;
    }
    else if ([@"sensorWidth" isEqualToString:key]){
        self.sensorWidth = 0;
    }
    else if ([@"sensorHeight" isEqualToString:key]){
        self.sensorHeight = 0;
    }
    else if ([@"binning" isEqualToString:key]){
        self.binning = 0;
    }
    else {
        [super setNilValueForKey:key];
    }
}

- (void)calculateImageScale
{
    if (self.focalLength == 0){
        self.arcsecsPerPixel = 0;
    }
    else {
        self.arcsecsPerPixel = self.binning*(206.3*self.pixelSize/self.focalLength);
    }
}

- (void)calculateFieldSize
{
    CGSize fieldSize;
    if (self.focalLength == 0){
        fieldSize.width = fieldSize.height = 0;
    }
    else {
        fieldSize.width = 3438*self.sensorWidth/self.focalLength/60.0;
        fieldSize.height = 3438*self.sensorHeight/self.focalLength/60.0;
    }
    self.fieldSizeDegrees = fieldSize;
}

- (NSString*)fieldSizeDisplay
{
    if (_fieldSizeDegrees.width == 0 && _fieldSizeDegrees.height == 0){
        return nil;
    }
    return [NSString stringWithFormat:@"%.2f\u2032x%.2f\u2032",_fieldSizeDegrees.width,_fieldSizeDegrees.height];
}

+ (NSSet*)keyPathsForValuesAffectingFieldSizeDisplay
{
    return [NSSet setWithObject:@"fieldSizeDegrees"];
}

- (IBAction)ok:(id)sender
{
//    if (self.completion){
//        self.completion(YES);
//    }
    [self endSheetWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
//    if (self.completion){
//        self.completion(NO);
//    }
    [self endSheetWithCode:NSCancelButton];
}

@end
