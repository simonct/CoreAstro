//
//  CASPlateSolveImageView.m
//  astrometry-test
//
//  Created by Simon Taylor on 6/9/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASPlateSolveImageView.h"
#import "CASEQMacClient.h"
#import "CASPlateSolvedObject+Drawing.h"
#import <CoreAstro/CoreAstro.h>

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
        self.url = [NSURL URLWithString:urlString]; // todo; deal with alias/bookmarks
        if (self.image){
            return YES;
        }
        else {
            [[NSAlert alertWithMessageText:@"Sorry" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Unrecognised image format"] runModal];
        }
    }
    
    return NO;
}

+ (NSData*)imageDataFromExposurePath:(NSString*)path error:(NSError**)error
{
    NSData* imageData = nil;
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
    if (io){
        CASCCDExposure* exp = [[CASCCDExposure alloc] init];
        if ([io readExposure:exp readPixels:YES error:error]){
            imageData = [[exp newImage] dataForUTType:@"public.png" options:nil];
        }
    }
    else {
        NSLog(@"no io");
    }
    return imageData;
}

- (void)setUrl:(NSURL *)url
{
    [self setImageWithURL:url];
}

- (BOOL)setImageWithURL:(NSURL*)url
{
    NSError* error;
    NSData* data = [[self class] imageDataFromExposurePath:url.path error:&error];
    if ([data length]){
        CGImageRef cgImage = [[[NSImage alloc] initWithData:data] CGImageForProposedRect:nil context:nil hints:nil]; // use ImageIO
        if (cgImage){
            [self setCGImage:cgImage];
        }
        else {
            url = nil;
        }
    }
    else if (error){
        url = nil;
    }
    if (url){
        [super setUrl:url];
        self.annotations = nil;
        [self zoomImageToFit:nil];
    }
    return (url != nil);
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

- (void)setMount:(CASMount *)mount
{
    if (mount != _mount){
        [_mount removeObserver:self forKeyPath:@"ra" context:(__bridge void *)(self)];
        [_mount removeObserver:self forKeyPath:@"dec" context:(__bridge void *)(self)];
        [_mount removeObserver:self forKeyPath:@"connected" context:(__bridge void *)(self)];
        _mount = mount;
        [_mount addObserver:self forKeyPath:@"ra" options:0 context:(__bridge void *)(self)];
        [_mount addObserver:self forKeyPath:@"dec" options:0 context:(__bridge void *)(self)];
        [_mount addObserver:self forKeyPath:@"connected" options:0 context:(__bridge void *)(self)];
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
    
    if (!self.mount.connected){
        
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
        self.eqMacAnnotation.string = [NSString stringWithFormat:@"RA: %@ Dec: %@",[CASLX200Commands highPrecisionRA:[self.mount.ra doubleValue]],[CASLX200Commands highPrecisionDec:[self.mount.dec doubleValue]]];
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
        [object createLayerInLayer:self.annotationLayer withFont:annotationsFont andColour:annotationsColour scaling:1];
    }
    
    [self updateAnnotations];
    
    CFBridgingRelease(annotationsColour);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        [self updateAnnotations];
        
        if (object == self.mount){
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
