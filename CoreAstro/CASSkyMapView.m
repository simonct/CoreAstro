//
//  CASSkyMapViewSkyMapView.m
//  skymap
//
//  Created by Simon Taylor on 24/09/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import "CASSkyMapView.h"
#import <CoreAstro/CoreAstro.h>
#import <QuartzCore/QuartzCore.h>

@interface Star : NSObject
@property double ra, dec, alt, az, mag;
@property (strong) CALayer* layer;
@end

@implementation Star
@end

@interface CASSkyMapView ()
@property (strong) CALayer* scope;
@property (strong) CALayer* moon;
@property (strong) CALayer* sun;
@property (strong) CALayer* background;
@property (strong) NSMutableArray<CALayer*>* contours;
@property (strong) NSMutableArray<Star*>* stars;
@property (strong) CASNova* nova;
@property (strong) NSTimer* timer;
@property (nonatomic,assign) CGPoint scopePosition;
@end

@implementation CASSkyMapView

static const NSInteger numAz = 20;
static const NSInteger numAlt = 9;
static const CGFloat lineWidth = 0.5;
static const CGFloat maxStarSize = 10; // relate to size of display ?
static const CGFloat scopeSize = 10;
static const CGFloat scopeBorderSize = 2;

+ (double)limitMag
{
    return 6;
}

- (void)setup
{
    self.wantsLayer = YES;
    
    if (!self.background){
        self.background = [CALayer layer];
        self.background.backgroundColor = [self backgroundColour].CGColor;
        self.background.borderColor = [self lineColour].CGColor;
        self.background.borderWidth = lineWidth;
        self.background.masksToBounds = YES;
        [self.layer addSublayer:self.background];
    }
    
    if (!self.nova){
        NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
        NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
        if (latitude && longitude){
            self.nova = [[CASNova alloc] initWithObserverLatitude:[latitude doubleValue] longitude:[longitude doubleValue]]; // inject this ?
        }
        else {
            self.nova = [[CASNova alloc] initWithObserverLatitude:51 longitude:0]; // inject this ?
        }
    }
    
    if (!self.timer){
        // todo; init with fire date
        self.timer = [NSTimer scheduledTimerWithTimeInterval:15 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [self layoutAnimated:YES];
        }];
        self.timer.tolerance = 5;
    }
}

- (CGFloat)size
{
    return MIN(self.bounds.size.width, self.bounds.size.height);
}

- (NSColor*)lineColour
{
    return [NSColor lightGrayColor];
}

- (NSColor*)backgroundColour
{
    return [NSColor blackColor];
}

- (NSColor*)starColour
{
    return [NSColor whiteColor];
}

- (NSColor*)contourColour
{
    return [[NSColor orangeColor] colorWithAlphaComponent:0.75];
}

- (NSColor*)scopeColour
{
    return [NSColor redColor];
}

- (void)layout
{
    [super layout];
    
    [self layoutAnimated:NO];
}

- (void)layoutAnimated:(BOOL)animated
{
    if (!animated){
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
    }
    
    const CGFloat size = [self size];
    self.background.frame = CGRectMake(CGRectGetMidX(self.bounds)-size/2,
                                       CGRectGetMidY(self.bounds)-size/2,
                                       size,
                                       size);
    self.background.cornerRadius = size/2;
    
    [self layoutContours];
    
    [self layoutScope];
    
    [self.stars enumerateObjectsUsingBlock:^(Star * _Nonnull star, NSUInteger idx, BOOL * _Nonnull stop) {
        [self layoutStar:star];
    }];
    
    if (!self.sun){
        self.sun = [CALayer layer];
        self.sun.backgroundColor = [NSColor clearColor].CGColor;
        self.sun.borderColor = [NSColor yellowColor].CGColor;
        self.sun.borderWidth = 2;
        self.sun.bounds = CGRectMake(0, 0, 20, 20);
        self.sun.cornerRadius = 10;
        [self.background addSublayer:self.sun];
    }
    self.sun.position = CGPointMake(size/2, size/2);
    const CASRaDec solar = [self.nova solarPosition];
    const CASAltAz altaz = [self.nova objectAltAzFromRA:solar.ra dec:solar.dec];
    self.sun.transform = [self transformForAlt:altaz.alt az:altaz.az];

    if (!self.moon){
        self.moon = [CALayer layer];
        self.moon.backgroundColor = [NSColor clearColor].CGColor;
        self.moon.borderColor = [NSColor blueColor].CGColor;
        self.moon.borderWidth = 2;
        self.moon.bounds = CGRectMake(0, 0, 20, 20);
        self.moon.cornerRadius = 10;
        [self.background addSublayer:self.moon];
    }
    self.moon.position = CGPointMake(size/2, size/2);
    const CASRaDec lunar = [self.nova lunarPosition];
    const CASAltAz laltaz = [self.nova objectAltAzFromRA:lunar.ra dec:lunar.dec];
    self.moon.transform = [self transformForAlt:laltaz.alt az:laltaz.az];

    if (!animated){
        [CATransaction commit];
    }
}

- (void)layoutContours
{
    const CGFloat size = [self size];

    [self.contours enumerateObjectsUsingBlock:^(CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperlayer];
    }];
    self.contours = [NSMutableArray arrayWithCapacity:100];
    
    if (self.showsAltAz){
        
        for (NSInteger i = 0; i < numAz; ++i){
            
            CALayer* layer = [CALayer layer];
            
            layer.backgroundColor = [self lineColour].CGColor;
            layer.bounds = CGRectMake(0, 0, lineWidth, size);
            layer.borderColor = [self lineColour].CGColor;
            layer.borderWidth = lineWidth;
            
            const CGFloat angle = i * (2*M_PI/numAz);
            CATransform3D translation = CATransform3DMakeTranslation(size/2, size/2, 0);
            CATransform3D rotation = CATransform3DMakeRotation(angle, 0, 0, 1);
            layer.transform = CATransform3DConcat(rotation,translation);
            
            [self.contours addObject:layer];
            [self.background addSublayer:layer];
        }
        
        for (NSInteger i = 0; i < numAlt; ++i){
            
            CALayer* layer = [CALayer layer];
            
            layer.backgroundColor = [NSColor clearColor].CGColor;
            layer.borderColor = [self lineColour].CGColor;
            layer.borderWidth = lineWidth;
            
            const CGFloat scaled = size * i/numAlt;
            layer.bounds = CGRectMake(0, 0, scaled, scaled);
            layer.cornerRadius = scaled/2;
            
            CATransform3D translation = CATransform3DMakeTranslation(size/2, size/2, 0);
            layer.transform = translation;
            
            [self.contours addObject:layer];
            [self.background addSublayer:layer];
        }
    }

    if (self.showsRaDec){
        
        for (double dec = -90; dec < 90; dec += 10){
            BOOL started = NO;
            CGMutablePathRef path = CGPathCreateMutable();
            for (double ra = 0; ra <= 360; ra += 5){
                started = [self addContourPointToPath:path ra:ra dec:dec started:started];
            }
            
            CAShapeLayer* shape = [self createContourLayerWithPath:path];
            [self.contours addObject:shape];
            [self.background addSublayer:shape];
        }
        
        for (double ra = 10; ra <= 360; ra += 10){
            BOOL started = NO;
            CGMutablePathRef path = CGPathCreateMutable();
            for (double dec = -90; dec <= 90; dec += 5){
                started = [self addContourPointToPath:path ra:ra dec:dec started:started];
            }
            
            CAShapeLayer* shape = [self createContourLayerWithPath:path];
            [self.contours addObject:shape];
            [self.background addSublayer:shape];
        }
    }
}

- (CAShapeLayer*)createContourLayerWithPath:(CGPathRef)path
{
    CAShapeLayer* shape = [CAShapeLayer layer];
    shape.strokeColor = [self contourColour].CGColor;
    shape.fillColor = [NSColor clearColor].CGColor;
    shape.lineWidth = lineWidth;
    shape.path = path;
    
    return shape;
}

- (BOOL)addContourPointToPath:(CGMutablePathRef)path ra:(double)ra dec:(double)dec started:(BOOL)started
{
    const CGFloat size = [self size];

    // get alt/az
    const CASAltAz altaz = [self.nova objectAltAzFromRA:ra dec:dec];
    
    // get transform
    const CATransform3D transform = [self transformForAlt:altaz.alt az:altaz.az];
    
    // use transform to calculate point
    const CGAffineTransform affine = CATransform3DGetAffineTransform(transform);
    
    const CGPoint point = CGPointApplyAffineTransform(CGPointZero,affine);
    
    if (!started){
        started = YES;
        CGPathMoveToPoint(path, nil, point.x + size/2, point.y + size/2);
    }
    else {
        CGPathAddLineToPoint(path, nil, point.x + size/2, point.y + size/2);
    }
    
    return started;
}

- (void)setTimeOffset:(double)timeOffset
{
    _timeOffset = timeOffset;
    self.nova.timeOffset = _timeOffset;
    [self setNeedsLayout:YES];
}

- (CATransform3D)transformForAlt:(double)alt az:(double)az
{
    const CGFloat size = [self size];
    const CGPoint center = CGPointMake(size/2, size/2);
    const CGPoint rotationPoint = CGPointMake(size/2, size/2);
    const CGFloat fraction = az/360.0;
    
    CATransform3D transform = CATransform3DIdentity;
    transform = CATransform3DTranslate(transform, rotationPoint.x-center.x, rotationPoint.y-center.y, 0.0);
    transform = CATransform3DRotate(transform, 2*M_PI * fraction + M_PI_2 + M_PI, 0.0, 0.0, 1.0);
    transform = CATransform3DTranslate(transform, center.x-rotationPoint.x, center.y-rotationPoint.y, 0.0);
    transform = CATransform3DTranslate(transform, ((90 - alt)/90.0) * size/2, 0, 0);
    
    return transform;
}

- (void)layoutStar:(Star*)star
{
    if (!self.nova){
        return;
    }
    
    const double max = [CASSkyMapView limitMag]+1.5;
    const CGFloat starSize = maxStarSize * (max-(star.mag + 1.5))/max; // set size related to mag
    const CGFloat size = [self size];

    // reset layer
    star.layer.bounds = CGRectMake(0, 0, starSize, starSize);
    star.layer.backgroundColor = [self starColour].CGColor;
    star.layer.cornerRadius = starSize/2;
    star.layer.position = CGPointMake(size/2, size/2);
    
    // apply transform
    const CASAltAz altaz = [self.nova objectAltAzFromRA:star.ra dec:star.dec];
    star.alt = altaz.alt;
    star.az = altaz.az;
    star.layer.transform = [self transformForAlt:star.alt az:star.az];
    
    star.layer.hidden = star.alt < 0;
}

- (void)layoutScope
{
    if (!self.showsScope){
        [self.scope removeFromSuperlayer];
        self.scope = nil;
        return;
    }
    
    const CGFloat size = [self size];
    self.scope.position = CGPointMake(size/2, size/2);
    const CASAltAz altaz = [self.nova objectAltAzFromRA:self.scopePosition.x dec:self.scopePosition.y];
    self.scope.transform = [self transformForAlt:altaz.alt az:altaz.az];
}

- (void)setScopePosition:(CGPoint)scopePosition
{
    [self setup];
    
    _scopePosition = scopePosition;
    
    if (!self.scope){
        self.scope = [CALayer layer];
        self.scope.backgroundColor = [NSColor clearColor].CGColor;
        self.scope.borderWidth = scopeBorderSize;
        self.scope.borderColor = [self scopeColour].CGColor;
        self.scope.bounds = CGRectMake(0, 0, scopeSize, scopeSize);
        self.scope.cornerRadius = scopeSize/2;
        [self.background addSublayer:self.scope];
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self layoutScope];
    [CATransaction commit];
}

- (void)setScopeRA:(double)ra dec:(double)dec
{
    self.showsScope = YES;
    self.scopePosition = CGPointMake(ra, dec);
}

- (void)setShowsRaDec:(BOOL)showsRaDec
{
    [self setup];
    
    _showsRaDec = showsRaDec;
    [self setNeedsLayout:YES];
}

- (void)setShowsAltAz:(BOOL)showsAltAz
{
    [self setup];
    
    _showsAltAz = showsAltAz;
    [self setNeedsLayout:YES];
}

- (void)setShowsScope:(BOOL)showsScope
{
    [self setup];

    _showsScope = showsScope;
    [self setNeedsLayout:YES];
}

- (void)addStarAtRA:(double)ra dec:(double)dec mag:(double)mag
{
    [self setup];
    
    if (!self.stars){
        self.stars = [NSMutableArray arrayWithCapacity:1000];
    }
    
    Star* star = [[Star alloc] init];
    star.ra = ra;
    star.dec = dec;
    star.mag = mag;
    star.layer = [CALayer layer];
    [self.stars addObject:star];
    
    [self.background addSublayer:star.layer];
    
    [self layoutStar:star];
}

@end
