//
//  MKOAppDelegate.m
//  astrometry-test
//
//  Created by Simon Taylor on 12/24/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//
//  Inspired by http://stargazerslounge.com/topic/143540-star-hopping-with-on-the-fly-astrometry/
//

#import "MKOAppDelegate.h"
#import "CASImageView.h"
#import "CASEQMacClient.h"
#import <QuartzCore/QuartzCore.h>

/* example wcs output
 "crpix0 506.983792063",
 "crpix1 378.635784858",
 "crval0 10.6280698245",
 "crval1 41.1611877064",
 "ra_tangent 10.6280698245",
 "dec_tangent 41.1611877064",
 "pixx_tangent 506.983792063",
 "pixy_tangent 378.635784858",
 "imagew 1024",
 "imageh 681",
 "cd11 -0.0022474834073",
 "cd12 -0.00292001370413",
 "cd21 0.00291952260955",
 "cd22 -0.00224608703052",
 "det 1.35730893618e-05",
 "parity 1",
 "pixscale 13.2630026061",
 "orientation -127.57857",
 "ra_center 10.7577556576",
 "dec_center 41.261762611",
 "orientation_center -127.49322",
 "ra_center_h 0",
 "ra_center_m 43",
 "ra_center_s 1.86135782312",
 "dec_center_sign 1",
 "dec_center_d 41",
 "dec_center_m 15",
 "dec_center_s 42.3453995364",
 "ra_center_hms 00:43:01.861",
 "dec_center_dms +41:15:42.345",
 "ra_center_merc 0.029882655",
 "dec_center_merc 0.62603934",
 "fieldarea 9.46511",
 "fieldw 3.771",
 "fieldh 2.508",
 "fieldunits degrees",
 "decmin 39.0048",
 "decmax 43.5225",
 "ramin 7.87173",
 "ramax 13.5709",
 "ra_min_merc 0.037697",
 "ra_max_merc 0.0218659",
 "dec_min_merc 0.634544",
 "dec_max_merc 0.617838",
 "merc_diff 0.0167061",
 "merczoom 6",
 ""
*/

@interface CASTaskWrapper : NSObject
@property (nonatomic,readonly) NSString* taskOutput;
- (void)launchWithOutputBlock:(void(^)(NSString*))block terminationBlock:(void(^)(int))block2;
@end

@interface CASTaskWrapper ()
@property (nonatomic,copy) void(^taskOutputBlock)(NSString*);
@property (nonatomic,copy) void(^taskTerminationBlock)(int);
@end

@interface CASTaskWrapper ()
@property (nonatomic,strong) NSTask* task;
@property (nonatomic,strong) NSFileHandle* taskOutputHandle;
@end

@implementation CASTaskWrapper {
    NSTask* _task;
    NSString* _tool;
    NSMutableString* _output;
    NSFileHandle* _taskOutputHandle;
    NSInteger _iomask;
}

- (id)initWithTool:(NSString*)tool
{
    self = [super init];
    if (self) {
        _iomask = 3;
        _tool = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"astrometry/bin/%@",tool]];
        if (![[NSFileManager defaultManager] isExecutableFileAtPath:_tool]){
            NSLog(@"No tool at %@",_tool);
            self = nil;
        }
        else {
            self.task = [[NSTask alloc] init];
            [_task setLaunchPath:_tool];
        }
    }
    return self;
}

- (id)initWithTool:(NSString*)tool iomask:(NSInteger)iomask
{
    self = [self initWithTool:tool];
    if (self){
        _iomask = iomask;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)launchWithOutputBlock:(void(^)(NSString*))block terminationBlock:(void(^)(int))block2;
{
    self.taskOutputBlock = block;
    self.taskTerminationBlock = block2;

    _output = [NSMutableString stringWithCapacity:1024];
    
    NSString* supportPath = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"support"];

    [_task setEnvironment:@{
     @"PATH":[NSString stringWithFormat:@"/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:%@",supportPath],
     @"DYLD_LIBRARY_PATH":supportPath
     }];

    NSPipe* output = [NSPipe pipe];
    if (_iomask & 1){
        [_task setStandardOutput:output];
    }
    else {
        [_task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    }
    if (_iomask & 2){
        [_task setStandardError:output];
    }
    else {
        [_task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    }
    self.taskOutputHandle = [output fileHandleForReading];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminate:) name:NSTaskDidTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskOutputDataAvailable:) name:NSFileHandleReadCompletionNotification object:_taskOutputHandle];
    [_taskOutputHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];

//    NSLog(@"%@ %@",_task.launchPath,_task.arguments);
    
    [_task launch];
}

- (void)handleTaskOutputData:(NSData*)output
{
    if ([output length]){
        NSString* string = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        if (string){
            [_output appendString:string];
            if (self.taskOutputBlock){
                self.taskOutputBlock(string);
            }
        }
    }
}

- (void)taskOutputDataAvailable:(NSNotification*)note
{
//    NSLog(@"taskOutputDataAvailable: %ld",[[[note userInfo] objectForKey:NSFileHandleNotificationDataItem] length]);
    
    if (note.object == _taskOutputHandle){
        
        NSData* data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
        if ([data length]){
            [self handleTaskOutputData:data];
            [_taskOutputHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];
        }
    }
}

- (void)taskDidTerminate:(NSNotification*)note
{
//    NSLog(@"taskDidTerminate: %d",_task.terminationStatus);

    if (note.object == _task){

        if (self.taskTerminationBlock){
            self.taskTerminationBlock(_task.terminationStatus);
        }
    }
}

- (NSString*) taskOutput
{
    return [_output copy];
}

- (void)setArguments:(NSArray *)arguments;
{
    [_task setArguments:arguments];
}

- (void)terminate
{
    [_task terminate];
}

@end

@interface CASSyncTaskWrapper : CASTaskWrapper
@end

@implementation CASSyncTaskWrapper

- (void)launchWithOutputBlock:(void(^)(NSString*))block terminationBlock:(void(^)(int))block2;
{
    [super launchWithOutputBlock:block terminationBlock:block2];
    [self.task waitUntilExit];
    if (self.taskTerminationBlock){
        self.taskTerminationBlock(self.task.terminationStatus);
    }
}

- (void)taskDidTerminate:(NSNotification*)note {}

@end

@class CASPlateSolvedObject;

@interface CASAnnotationLayer : CALayer
@property (nonatomic,weak) CATextLayer* textLayer;
@property (nonatomic,weak) CASPlateSolvedObject* object;
@end

@implementation CASAnnotationLayer
@end

@interface CASSolverModel : NSObject
@property (nonatomic,assign) float scaleLow;
@property (nonatomic,assign) float scaleHigh;
@end

@implementation CASSolverModel
@end

@interface CASPlateSolvedObject : NSObject
@property (nonatomic,assign) BOOL enabled;
@property (nonatomic,readonly) NSString* name;
@property (nonatomic,strong) NSDictionary* annotation;
@end

@implementation CASPlateSolvedObject

/*
 {
 names =         (
 "NGC 6526"
 );
 pixelx = "583.327";
 pixely = "381.319";
 radius = "418.425";
 type = ngc;
 },
*/

- (NSString*)name
{
    NSMutableString* result = [NSMutableString string];
    for (NSString* name in [self.annotation objectForKey:@"names"]){
        if ([result length]){
            [result appendString:@"/"];
        }
        [result appendString:name];
    }
    return [result copy];
}

- (CASAnnotationLayer*)createCircularLayerAtPosition:(CGPoint)position radius:(CGFloat)radius annotation:(NSString*)annotation inLayer:(CALayer*)annotationLayer withFont:(NSFont*)font andColour:(CGColorRef)colour
{
    CASAnnotationLayer* objectLayer = [CASAnnotationLayer layer];
    
    // flip y
    position.y = annotationLayer.bounds.size.height - position.y;
    
    objectLayer.borderColor = colour;
    objectLayer.borderWidth = 2.5;
    objectLayer.cornerRadius = radius;
    objectLayer.bounds = CGRectMake(0, 0, 2*radius, 2*radius);
    objectLayer.position = position;
    objectLayer.masksToBounds = NO;
    
    [annotationLayer addSublayer:objectLayer];
    
    if (annotation){
        
        CATextLayer* textLayer = [CATextLayer layer];
        textLayer.string = annotation;
        const CGSize size = [textLayer.string sizeWithAttributes:@{NSFontAttributeName:font}];
        textLayer.font = (__bridge CFTypeRef)(font);
        textLayer.fontSize = font.pointSize;
        textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
        textLayer.position = CGPointMake(CGRectGetMidX(objectLayer.frame) + size.width/2 + 10, CGRectGetMidY(objectLayer.frame) + size.height/2 + 10);
        textLayer.alignmentMode = @"center";
        textLayer.foregroundColor = colour;
        
        [annotationLayer addSublayer:textLayer];
        
        objectLayer.textLayer = textLayer;
        
        // want the inverse of the text bounding box as a clip mask for the circle layer
        CAShapeLayer* shape = [CAShapeLayer layer];
        CGPathRef path = CGPathCreateWithRect(objectLayer.bounds, nil);
        CGMutablePathRef mpath = CGPathCreateMutableCopy(path);
        CGPathAddRect(mpath, NULL, [annotationLayer convertRect:objectLayer.textLayer.frame toLayer:objectLayer]);
        shape.path = mpath;
        shape.fillRule = kCAFillRuleEvenOdd;
        objectLayer.mask = shape;
    }

    return objectLayer;
}

- (CASAnnotationLayer*)createLayerInLayer:(CALayer*)annotationLayer withFont:(NSFont*)font andColour:(CGColorRef)colour
{
    const CGFloat x = [[self.annotation objectForKey:@"pixelx"] doubleValue];
    const CGFloat y = [[self.annotation objectForKey:@"pixely"] doubleValue];
    const CGFloat radius = [[self.annotation objectForKey:@"radius"] doubleValue];

    CASAnnotationLayer* result = [self createCircularLayerAtPosition:CGPointMake(x, y) radius:radius annotation:self.name inLayer:annotationLayer withFont:font andColour:colour];
    
    result.object = self;
    
    return result;
}

@end

@interface CASPlateSolveSolution : NSObject
@property (nonatomic,readonly) NSString* centreRA;
@property (nonatomic,readonly) double centreRADouble;
@property (nonatomic,readonly) NSString* centreDec;
@property (nonatomic,readonly) double centreDecDouble;
@property (nonatomic,readonly) NSString* centreAngle;
@property (nonatomic,readonly) NSString* pixelScale;
@property (nonatomic,readonly) NSString* fieldWidth;
@property (nonatomic,readonly) NSString* fieldHeight;
@property (nonatomic,strong) NSArray* wcsinfo;
@property (nonatomic,strong) NSArray* annotations;
@property (nonatomic,copy) NSString* wcsPath;
@end

@implementation CASPlateSolveSolution

- (void)replaceAnnotations:(NSArray*)annotations
{
    if (_annotations){
        [[self mutableArrayValueForKey:@"annotations"] removeAllObjects];
    }
    
    for (NSDictionary* annotation in annotations){
        CASPlateSolvedObject* object = [CASPlateSolvedObject new];
        object.enabled = [[annotation objectForKey:@"type"] isEqualToString:@"ngc"];
        object.annotation = annotation;
        if (!_annotations){
            _annotations = [NSMutableArray arrayWithCapacity:[annotations count]];
        }
        [[self mutableArrayValueForKey:@"annotations"] addObject:object]; // this causes a call to -setAnnotations: each time
    }
}

- (NSNumber*)numberFromInfo:(NSArray*)values withKey:(NSString*)key
{
    for (NSString* string in values){
        if ([string hasPrefix:key]){
            NSScanner* scanner = [NSScanner scannerWithString:string];
            NSString* ignored;
            [scanner scanString:key intoString:&ignored];
            double d;
            if ([scanner scanDouble:&d]){
                return [NSNumber numberWithDouble:d];
            }
        }
    }
    return nil;
}

- (NSString*)centreRA
{
    return [NSString stringWithFormat:@"%02.0fh %02.0fm %02.2fs",
            [[self numberFromInfo:self.wcsinfo withKey:@"ra_center_h"] doubleValue],
            [[self numberFromInfo:self.wcsinfo withKey:@"ra_center_m"] doubleValue],
            [[self numberFromInfo:self.wcsinfo withKey:@"ra_center_s"] doubleValue]];
}

- (double) centreRADouble // ra_center ?
{
    return [[self numberFromInfo:self.wcsinfo withKey:@"ra_center"] doubleValue] +
    ([[self numberFromInfo:self.wcsinfo withKey:@"ra_center_m"] doubleValue]/60.0) +
    ([[self numberFromInfo:self.wcsinfo withKey:@"ra_center_s"] doubleValue]/3600.0);
}

- (NSString*)centreDec
{
    return [NSString stringWithFormat:@"%02.0f° %02.0fm %02.2fs",
            [[self numberFromInfo:self.wcsinfo withKey:@"dec_center_d"] doubleValue],
            [[self numberFromInfo:self.wcsinfo withKey:@"dec_center_m"] doubleValue],
            [[self numberFromInfo:self.wcsinfo withKey:@"dec_center_s"] doubleValue]];
}

- (double) centreDecDouble // dec_center ?
{
    return [[self numberFromInfo:self.wcsinfo withKey:@"dec_center_d"] doubleValue] +
    ([[self numberFromInfo:self.wcsinfo withKey:@"dec_center_m"] doubleValue]/60.0) +
    ([[self numberFromInfo:self.wcsinfo withKey:@"dec_center_s"] doubleValue]/3600.0);
}

- (NSString*)centreAngle
{
    return [NSString stringWithFormat:@"%02.0f°",
            [[self numberFromInfo:self.wcsinfo withKey:@"orientation"] doubleValue]];
}

- (NSString*)pixelScale
{
    return [NSString stringWithFormat:@"%.2f\u2033",
            [[self numberFromInfo:self.wcsinfo withKey:@"pixscale"] doubleValue]];
}

- (NSString*)fieldWidth
{
    return [NSString stringWithFormat:@"%.2f\u2032", // todo; check fieldunits == arcminutes
            [[self numberFromInfo:self.wcsinfo withKey:@"fieldw"] doubleValue]];
}

- (NSString*)fieldHeight
{
    return [NSString stringWithFormat:@"%.2f\u2032",
            [[self numberFromInfo:self.wcsinfo withKey:@"fieldh"] doubleValue]];
}

@end

@interface CASPlateSolveImageView : CASImageView
@property (nonatomic,assign) BOOL acceptDrop;
@property (nonatomic,strong) CALayer* annotationLayer;
@property (nonatomic,strong) NSArray* annotations;
@property (nonatomic,strong) NSFont* annotationsFont;
@property (nonatomic,strong) CATextLayer* draggingAnnotation;
@property (nonatomic,strong) CATextLayer* eqMacAnnotation;
@property (nonatomic,weak) CASEQMacClient* eqMacClient;
@end

@implementation CASPlateSolveImageView

- (void)dealloc
{
    self.annotations = nil;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self registerForDraggedTypes:@[(id)kUTTypeFileURL]];
    
    NSData* fontData = [[NSUserDefaults standardUserDefaults] objectForKey:@"CASAnnotationsFont"];
    if (fontData){
        self.annotationsFont = [NSUnarchiver unarchiveObjectWithData:fontData];
    }
    if (!self.annotationsFont){
        self.annotationsFont = [NSFont boldSystemFontOfSize:18];
    }
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CASAnnotationsColour" options:0 context:(__bridge void *)(self)];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor lightGrayColor] set];
    NSRectFill(dirtyRect);
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return self.acceptDrop ? NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    if (!self.acceptDrop){
        return NO;
    }
    
    NSString* urlString = [sender.draggingPasteboard stringForType:(id)kUTTypeFileURL];
    if ([urlString isKindOfClass:[NSString class]]){
#if DEBUG
        if ([[urlString pathExtension] isEqualToString:@"plist"]){
            
            NSDictionary* annotations = [NSDictionary dictionaryWithContentsOfFile:[[NSURL URLWithString:urlString] path]];
            if ([annotations isKindOfClass:[NSDictionary class]]){
                
                NSMutableArray* objects = nil;
                for (NSDictionary* annotation in [annotations objectForKey:@"annotations"]){
                    CASPlateSolvedObject* object = [CASPlateSolvedObject new];
                    object.enabled = [[annotation objectForKey:@"type"] isEqualToString:@"ngc"];
                    object.annotation = annotation;
                    if (!objects){
                        objects = [NSMutableArray arrayWithCapacity:[annotations count]];
                    }
                    [objects addObject:object];
                }

                self.annotations = objects;
                [self createAnnotations];
                return YES;
            }
        }
        else
#endif
        {
            self.url = [NSURL URLWithString:urlString]; // todo; deal with alias/bookmarks
            if (self.image){
                return YES;
            }
            else {
                [[NSAlert alertWithMessageText:@"Sorry" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Unrecognised image format"] runModal];
            }
        }
    }
    
    return NO;
}

- (void)setUrl:(NSURL *)url
{
    [super setUrl:url];
    self.annotations = nil;
}

- (void)setAnnotations:(NSArray *)annotations
{
    if (annotations != _annotations){
        
        if (_annotations){
            for (id object in self.annotations){
                [object removeObserver:self forKeyPath:@"enabled"];
            }
        }

        _annotations = annotations;
        
        for (id annotation in annotations){
            [annotation addObserver:self forKeyPath:@"enabled" options:0 context:(__bridge void *)(self)];
        }

        if (_annotations){
            [self createAnnotations];
        }
        else{
            [self.annotationLayer removeFromSuperlayer];
            self.annotationLayer = nil;
        }
    }
}

- (void)setAnnotationsFont:(NSFont *)annotationsFont
{
    if (_annotationsFont != annotationsFont){
        _annotationsFont = annotationsFont;
        [self updateAnnotations];
    }
}

- (CGColorRef)annotationsColour
{
    CGColorRef colour = nil;
    
    NSData* archivedColourData = [[NSUserDefaults standardUserDefaults] objectForKey:@"CASAnnotationsColour"];
    if (archivedColourData){
        NSColor* archivedColour = [NSUnarchiver unarchiveObjectWithData:archivedColourData];
        if (archivedColour){
            CGFloat red, green, blue, alpha;
            @try {
                [archivedColour getRed:&red green:&green blue:&blue alpha:&alpha];
                colour = CGColorCreateGenericRGB(red,green,blue,alpha);
            }
            @catch (NSException *exception) {
                NSLog(@"*** %@",exception);
            }
        }
    }
    
    if (!colour){
        colour = CGColorCreateGenericRGB(1,1,0,1);
    }
    
    return colour;
}

- (void)setEqMacClient:(CASEQMacClient *)eqMacClient
{
    if (eqMacClient != _eqMacClient){
        [_eqMacClient removeObserver:self forKeyPath:@"ra" context:(__bridge void *)(self)];
        [_eqMacClient removeObserver:self forKeyPath:@"dec" context:(__bridge void *)(self)];
        [_eqMacClient removeObserver:self forKeyPath:@"connected" context:(__bridge void *)(self)];
        _eqMacClient = eqMacClient;
        [_eqMacClient addObserver:self forKeyPath:@"ra" options:0 context:(__bridge void *)(self)];
        [_eqMacClient addObserver:self forKeyPath:@"dec" options:0 context:(__bridge void *)(self)];
        [_eqMacClient addObserver:self forKeyPath:@"connected" options:0 context:(__bridge void *)(self)];
    }
}

- (CASAnnotationLayer*)layerForObject:(CASPlateSolvedObject*)object
{
    // revisit this if we end up with lots of layers...
    for (CASAnnotationLayer* layer in self.annotationLayer.sublayers){
        if ([layer isKindOfClass:[CASAnnotationLayer class]]){
            if (layer.object == object){
                return layer;
            }
        }
    }
    return nil;
}

- (void)updateAnnotations
{
    NSFont* annotationsFont = self.annotationsFont;
    CGColorRef annotationsColour = self.annotationsColour;

    // hide/show annotations based on the enabled flag
    for (CASAnnotationLayer* layer in self.annotationLayer.sublayers){
        if ([layer isKindOfClass:[CASAnnotationLayer class]]){
            layer.hidden = layer.textLayer.hidden = !layer.object.enabled;
        }
    }

    // now update all the annotations in the layer with the current settings
    for (CALayer* layer in self.annotationLayer.sublayers){
        
        if ([layer isKindOfClass:[CATextLayer class]]){
            
            CATextLayer* textLayer = (CATextLayer*)layer;
            if (self.draggingAnnotation == textLayer){
                textLayer.foregroundColor = CGColorCreateCopyWithAlpha(annotationsColour, 0.75);
            }
            else {
                textLayer.foregroundColor = annotationsColour;
            }
            textLayer.font = (__bridge CFTypeRef)annotationsFont;
            textLayer.fontSize = annotationsFont.pointSize;
            const CGSize size = [textLayer.string sizeWithAttributes:@{NSFontAttributeName:annotationsFont}];
            textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
            // todo; pin to image rect
        }
    }
    
    for (CALayer* objectLayer in self.annotationLayer.sublayers){
        
        if ([objectLayer isKindOfClass:[CATextLayer class]]){
            continue;
        }

        objectLayer.borderColor = annotationsColour;
        
        // want the inverse of the text bounding box as a clip mask for the circle layer
        CAShapeLayer* shape = [CAShapeLayer layer];
        CGPathRef path = CGPathCreateWithRect(objectLayer.bounds, nil);
        CGMutablePathRef mpath = CGPathCreateMutableCopy(path);
        
        for (CALayer* textLayer in self.annotationLayer.sublayers){
            if (!textLayer.hidden && [textLayer isKindOfClass:[CATextLayer class]]){
                CGPathAddRect(mpath, NULL, [self.annotationLayer convertRect:textLayer.frame toLayer:objectLayer]);
            }
        }
        
        shape.path = mpath;
        shape.fillRule = kCAFillRuleEvenOdd;
        objectLayer.mask = shape;
    }
    
    if (!self.eqMacClient.connected){
        
        [self.eqMacAnnotation removeFromSuperlayer];
        self.eqMacAnnotation = nil;
    }
    else{
        
        if (!self.eqMacAnnotation){
            self.eqMacAnnotation = [CATextLayer layer];
            self.eqMacAnnotation.alignmentMode = @"center";
            [self.annotationLayer addSublayer:self.eqMacAnnotation];
        }
        
        self.eqMacAnnotation.font = (__bridge CFTypeRef)annotationsFont;
        self.eqMacAnnotation.fontSize = annotationsFont.pointSize;
        self.eqMacAnnotation.foregroundColor = annotationsColour;
        self.eqMacAnnotation.string = [NSString stringWithFormat:@"RA: %@ Dec: %@",self.eqMacClient.ra,self.eqMacClient.dec];
        const CGSize size = [self.eqMacAnnotation.string sizeWithAttributes:@{NSFontAttributeName:annotationsFont}];
        self.eqMacAnnotation.bounds = CGRectMake(0, 0, size.width + 10, size.height + 5);
        self.eqMacAnnotation.position = CGPointMake(CGRectGetMidX(self.annotationLayer.frame), CGRectGetMaxY(self.annotationLayer.frame) - self.eqMacAnnotation.bounds.size.height - 5);
    }
    
    CFBridgingRelease(annotationsColour);
}

- (void)createAnnotations
{
    if (!self.image){
        return;
    }
    
    if (!self.annotationLayer){
        self.annotationLayer = [CALayer layer];
        self.annotationLayer.bounds = CGRectMake(0, 0, self.image.extent.size.width, self.image.extent.size.height);
        self.annotationLayer.position = CGPointMake(self.image.extent.size.width/2, self.image.extent.size.height/2);
        [self.layer addSublayer:self.annotationLayer];
    }
    
    for (CALayer* layer in [[self.annotationLayer sublayers] copy]){
        [layer removeFromSuperlayer];
    }
    self.eqMacAnnotation = nil;
    
    NSFont* annotationsFont = self.annotationsFont;
    CGColorRef annotationsColour = self.annotationsColour;
    
    for (CASPlateSolvedObject* object in self.annotations){
        [object createLayerInLayer:self.annotationLayer withFont:annotationsFont andColour:annotationsColour];
    }
    
    [self updateAnnotations];
    
    CFBridgingRelease(annotationsColour);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        [self updateAnnotations];
        
        if (object == self.eqMacClient){
            // update scope position annotation
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    const CGPoint pointInLayer = [self.layer convertPoint:theEvent.locationInWindow fromLayer:nil];
    CALayer* layer = [self.annotationLayer hitTest:pointInLayer];
    
    if ([layer isKindOfClass:[CATextLayer class]] && layer != self.eqMacAnnotation){
        
        self.draggingAnnotation = (CATextLayer*)layer;
        self.draggingAnnotation.foregroundColor = CGColorCreateCopyWithAlpha(self.draggingAnnotation.foregroundColor, 0.75);

        CGPoint anchorPoint = [self.layer convertPoint:pointInLayer toLayer:self.draggingAnnotation];
        anchorPoint.x /= self.draggingAnnotation.bounds.size.width;
        anchorPoint.y /= self.draggingAnnotation.bounds.size.height;
        self.draggingAnnotation.anchorPoint = anchorPoint;
        
        self.draggingAnnotation.position = pointInLayer;
    }
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0;
        self.draggingAnnotation.position = [self.annotationLayer convertPoint:theEvent.locationInWindow fromLayer:nil];
        [self updateAnnotations];
    } completionHandler:0];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (self.draggingAnnotation){
        self.draggingAnnotation = nil;
        [self updateAnnotations];
    }
}

@end

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASTaskWrapper* solverTask;
@property (nonatomic,strong) CASSolverModel* solverModel;
@property (nonatomic,readonly) NSString* cacheDirectory;
@property (nonatomic,strong) CASPlateSolveSolution* solution;
@property (nonatomic,strong) CASEQMacClient* eqMacClient;
@end

@implementation MKOAppDelegate

static NSString* const kCASAstrometryIndexDirectoryURLKey = @"CASAstrometryIndexDirectoryURL";

- (void)awakeFromNib
{
    self.spinner.hidden = YES;
    self.spinner.usesThreadedAnimation = YES;
        
    if (self.indexDirectoryURL){
        if (![[NSFileManager defaultManager] fileExistsAtPath:[self.indexDirectoryURL path] ]){
            self.indexDirectoryURL = nil;
        }
    }
    
    self.imageView.acceptDrop = YES;
    [self.imageView bind:@"annotations" toObject:self withKeyPath:@"solution.annotations" options:nil];
    
    [self.imageView addObserver:self forKeyPath:@"url" options:0 context:(__bridge void *)(self)];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [[NSColorPanel sharedColorPanel] orderOut:nil];
    [[NSColorPanel sharedColorPanel] setHidesOnDeactivate:YES];

    [[NSFileManager defaultManager] removeItemAtPath:self.cacheDirectory error:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (self.solverTask){
        [self.solverTask terminate];
    }
    [[NSFileManager defaultManager] removeItemAtPath:self.cacheDirectory error:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        if (object == self.imageView){
            self.solution = nil;
            NSString* title = [[NSFileManager defaultManager] displayNameAtPath:self.imageView.url.path];
            self.window.title = title ? title : @"";
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSURL*)indexDirectoryURL
{
    NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:kCASAstrometryIndexDirectoryURLKey];
    return s ? [NSURL fileURLWithPath:s] : nil;
}

- (void)setIndexDirectoryURL:(NSURL*)url
{
    [[NSUserDefaults standardUserDefaults] setValue:[url path] forKey:kCASAstrometryIndexDirectoryURLKey];
}

- (NSString*)cacheDirectory
{
    NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
}

- (IBAction)solve:(id)sender
{
    if (!self.imageView.image || self.solverTask){
        return;
    }
    
    if (!self.indexDirectoryURL){
        [self presentAlertWithMessage:@"You need to select the location of the astrometry.net indexes before solving"];
        return;
    }
    
    void (^completeWithError)(NSString*) = ^(NSString* error) {
        if (error){
            [self presentAlertWithMessage:error];
        }
        self.imageView.acceptDrop = YES;
        self.solveButton.enabled = YES;
        self.imageView.alphaValue = 1;
        self.spinner.hidden = YES;
        [self.spinner stopAnimation:nil];
        self.solverTask = nil;
    };

    self.imageView.acceptDrop = NO;
    self.imageView.annotations = nil;
    self.solution = nil;
    
    // bindings...
    self.solutionRALabel.stringValue = self.solutionDecLabel.stringValue = self.solutionAngleLabel.stringValue = @"";
    self.pixelScaleLabel.stringValue = self.fieldWidthLabel.stringValue = self.fieldHeightLabel.stringValue = @"";

    self.solveButton.enabled = NO;
    self.imageView.alphaValue = 0.5;
    self.spinner.hidden = NO;
    [self.spinner startAnimation:nil];
    
    self.solverTask = [[CASTaskWrapper alloc] initWithTool:@"solve-field"];
    if (!self.solverTask){
        completeWithError(@"Can't find the embedded solve-field tool");
    }
    else {
        
        // update the config with the index location
        NSMutableString* config = [NSMutableString string];
        [config appendFormat:@"add_path %@\n",[self.indexDirectoryURL path]];
        [config appendString:@"autoindex\n"];
        NSString* configPath = [self.cacheDirectory stringByAppendingPathComponent:@"backend.cfg"];
        [config writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        // --use-sextractor ? @"--kmz",@"google-sky.kmz"
        [self.solverTask setArguments:@[self.imageView.url.path,@"--no-plots",@"-z",@"2",@"--overwrite",@"-d",@"500",@"-l",@"20",@"-r",@"-D",self.cacheDirectory,@"-b",configPath]];
                
        [self.solverTask launchWithOutputBlock:^(NSString* string) {
            
            [self.outputLogTextView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:string]];
            [self.outputLogTextView scrollToEndOfDocument:nil];
            
        } terminationBlock:^(int terminationStatus) {
            
            if (terminationStatus){
                completeWithError(@"Solve failed");
            }
            else {

                // allow to switch between the detected object images, etc ?
                
                // nasty hack to avoid as yet undiagnosed race between solve-field and wcsinfo resulting in empty solution results
                double delayInSeconds = 0.5;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    
                    // show the solved image
                    NSString* name = [[self.imageView.url.path lastPathComponent] stringByDeletingPathExtension];
                    NSString* path = [self.cacheDirectory stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@-ngc",name] stringByAppendingPathExtension:@"png"]];
//                    self.imageView.url = [NSURL fileURLWithPath:path];
                    
                    // get solution data todo; move this into the solution class
                    self.solverTask = [[CASSyncTaskWrapper alloc] initWithTool:@"wcsinfo"];
                    if (!self.solverTask){
                        completeWithError(@"Can't find the embedded wcsinfo tool");
                    }
                    else {
                        
                        path = [[self.cacheDirectory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"wcs"];
                        [self.solverTask setArguments:@[path]];
                        
                        [self.solverTask launchWithOutputBlock:nil terminationBlock:^(int terminationStatus) {
                            
                            if (terminationStatus){
                                completeWithError(@"Failed to get solution info");
                            }
                            else {
                                                                
                                NSArray* output = [self.solverTask.taskOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                                if (![output count]){
                                    completeWithError(@"No output from wcsinfo");
                                }
                                else{
                                    
                                    self.solution = [CASPlateSolveSolution new];
                                    self.solution.wcsPath = path;
                                    self.solution.wcsinfo = output;
                                    
                                    // bindings...
                                    self.solutionRALabel.stringValue = self.solution.centreRA;
                                    self.solutionDecLabel.stringValue = self.solution.centreDec;
                                    self.solutionAngleLabel.stringValue = self.solution.centreAngle;
                                    self.pixelScaleLabel.stringValue = self.solution.pixelScale;
                                    self.fieldWidthLabel.stringValue = self.solution.fieldWidth;
                                    self.fieldHeightLabel.stringValue = self.solution.fieldHeight;

                                    // get annotations
                                    self.solverTask = [[CASSyncTaskWrapper alloc] initWithTool:@"plot-constellations" iomask:2];
                                    if (!self.solverTask){
                                        completeWithError(@"Can't find the embedded plot-constellations tool");
                                    }
                                    else {
                                        
                                        NSString* path = [[self.cacheDirectory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"wcs"];
                                        [self.solverTask setArguments:@[@"-w",path,@"-NCBJL"]];
                                        
                                        [self.solverTask launchWithOutputBlock:nil terminationBlock:^(int terminationStatus) {
                                            
                                            if (terminationStatus){
                                                completeWithError(@"Failed to get annotations");
                                            }
                                            else {
                                                
                                                NSDictionary* report = [NSJSONSerialization JSONObjectWithData:[self.solverTask.taskOutput dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
                                                if (![report isKindOfClass:[NSDictionary class]]){
                                                    completeWithError(@"Couldn't read annotation data");
                                                }
                                                else {
                                                    // check status=solved
                                                    [self.solution replaceAnnotations:[report objectForKey:@"annotations"]];
#if DEBUG
                                                    NSString* solutionPath = [self.imageView.url.path stringByDeletingLastPathComponent];
                                                    NSString* solutionName = [[[self.imageView.url.path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
                                                    [report writeToFile:[solutionPath stringByAppendingPathComponent:solutionName] atomically:YES];
#endif
                                                    completeWithError(nil);
                                                }
                                            }
                                        }];
                                    }
                                }
                            }
                        }];
                    }
                });
            }
        }];
    }
}

- (IBAction)showFontPanel:(id)sender
{
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager setDelegate:self];
    [fontManager orderFrontFontPanel:self];
}

- (IBAction)resetAnnotations:(id)sender
{
    [self.imageView createAnnotations];
}

- (IBAction)changeFont:(id)sender
{
    self.imageView.annotationsFont = [sender convertFont:self.imageView.annotationsFont];
    [[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:self.imageView.annotationsFont] forKey:@"CASAnnotationsFont"];
    [self.imageView updateAnnotations];
}

- (IBAction)openDocument:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = [NSImage imageFileTypes];
    open.allowsMultipleSelection = NO;
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            self.imageView.url = open.URL;
            if (self.imageView.url){
                // self.solution = nil;
            }
        }
    }];
}

- (IBAction)saveDocument:(id)sender
{
    if (!self.solution){
        return;
    }
    
    NSSavePanel* save = [NSSavePanel savePanel];
    
    save.allowedFileTypes = @[[self.imageView.url pathExtension]];
    save.canCreateDirectories = YES;
    save.nameFieldStringValue = [self.imageView.url lastPathComponent];
    
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){

            const CGSize size = self.imageView.image.extent.size;

            // create an offscreen view to render the image+annotations at full resolution
            NSWindow *offscreenWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-32000,-32000,size.width,size.height)
                                                                    styleMask:NSBorderlessWindowMask
                                                                      backing:NSBackingStoreNonretained
                                                                        defer:NO];
            CASPlateSolveImageView* offscreenImageView = [[CASPlateSolveImageView alloc] initWithFrame:NSMakeRect(0, 0, size.width,size.height)];
            offscreenImageView.wantsLayer = YES;
            offscreenImageView.layer.opacity = 1;
            [[offscreenWindow contentView] addSubview:offscreenImageView];
            
            // set the annotations and attributes
            offscreenImageView.url = self.imageView.url;
            offscreenImageView.annotationsFont = self.imageView.annotationsFont;
            offscreenImageView.annotations = self.imageView.annotations;
            
            // set annotation positions (assuming both arrays of annotations are in the same order)
            NSInteger i = 0;
            for (CALayer* layer in offscreenImageView.annotationLayer.sublayers){
                CALayer* layer2 = [self.imageView.annotationLayer.sublayers objectAtIndex:i++];
                layer.position = layer2.position;
                layer.anchorPoint = layer2.anchorPoint;
            }
            
            [[offscreenWindow contentView] addSubview:offscreenImageView];
            
            // create a bitmap to render the contents into
            CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
            CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, 8, (size.width) * 4, space, kCGImageAlphaPremultipliedLast);
            CFRelease(space);
            
            if (context){
                
                // render the view's layer
                [offscreenImageView.layer renderInContext:context];
                
                // grab the image and write to the destination url
                CGImageRef image = CGBitmapContextCreateImage(context);
                if (image){
                    
                    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)save.URL, CFSTR("public.png"), 1, nil);
                    if (!destination){
                        NSLog(@"Failed to create image destination for thumbnail at %@",save.URL);
                    }
                    else{
                        CGImageDestinationAddImage(destination,image,nil);
                        if (!CGImageDestinationFinalize(destination)){
                            NSLog(@"Failed to write thumbnail to %@",save.URL);
                        }
                        CFRelease(destination);
                    }
                    CGImageRelease(image);
                }
                CGContextRelease(context);
            }
        }
    }];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    if (menuItem.action == @selector(saveDocument:) || menuItem.action == @selector(goToInEQMac:)){
        return (self.solution != nil);
    }
    return YES;
}

@end

@implementation MKOAppDelegate (EQMacSupport)

- (void)slewToSolutionCentre
{
    [self.eqMacClient startSlewToRA:self.solution.centreRADouble dec:self.solution.centreDecDouble completion:^(BOOL ok) {
        
        if (!ok){
            [self presentAlertWithMessage:@"Failed to slew to the target"];
            // hide current ra/dec
        }
        else {
            // show current ra/dec
        }
    }];
}

- (IBAction)goToInEQMac:(id)sender
{
    if (!self.solution){
        return;
    }
    
    if (!self.eqMacClient){
        self.eqMacClient = [CASEQMacClient standardClient];
        self.imageView.eqMacClient = self.eqMacClient;
    }
    
    if (![[NSRunningApplication runningApplicationsWithBundleIdentifier:@"au.id.hulse.Mount"] count]){
        [self presentAlertWithMessage:@"EQMac is not running. Please start it, connect to your mount and try again"]; // todo; offer to launch it
    }
    else {
        
        if (self.eqMacClient.connected){
            [self slewToSolutionCentre];
        }
        else {
            
            [self.eqMacClient connectWithCompletion:^{
                if (self.eqMacClient.connected){
                    [self slewToSolutionCentre];
                }
                else {
                    [self presentAlertWithMessage:@"Failed to connect to EQMac. Please ensure it's running and connected to your mount"];
                }
            }];
        }
    }
}

@end
