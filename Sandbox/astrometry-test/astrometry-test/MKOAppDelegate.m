//
//  MKOAppDelegate.m
//  astrometry-test
//
//  Created by Simon Taylor on 12/24/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "MKOAppDelegate.h"
#import "CASImageView.h"
#import <QuartzCore/QuartzCore.h>

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

- (CALayer*)createCircularLayerAtPosition:(CGPoint)position radius:(CGFloat)radius annotation:(NSString*)annotation inLayer:(CALayer*)annotationLayer withFont:(NSFont*)font
{
    CALayer* layer = [CALayer layer];
    
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
    
    layer.borderColor = colour;
    layer.borderWidth = 2.5;
    layer.cornerRadius = radius;
    layer.bounds = CGRectMake(0, 0, 2*radius, 2*radius);
    layer.position = position;
    layer.masksToBounds = NO;
    
    [annotationLayer addSublayer:layer];
    
    if (annotation){
        
        CATextLayer* text = [CATextLayer layer];
        text.string = annotation;
        const CGSize size = [text.string sizeWithAttributes:@{NSFontAttributeName:font}];
        text.font = (__bridge CFTypeRef)(font);
        text.fontSize = font.pointSize;
        text.bounds = CGRectMake(0, 0, size.width, size.height);
        text.position = CGPointMake(CGRectGetMidX(layer.bounds) + size.width/2 + 10, CGRectGetMidY(layer.bounds) + size.height/2);
        text.alignmentMode = @"center";
        text.foregroundColor = colour;
        [annotationLayer addSublayer:text];
        
        // want the inverse of the text bounding box as a clip mask for the circle layer
        CAShapeLayer* shape = [CAShapeLayer layer];
        CGPathRef path = CGPathCreateWithRect(layer.bounds, nil);
        CGMutablePathRef mpath = CGPathCreateMutableCopy(path);
        CGPathAddRect(mpath, NULL, text.frame);
        shape.path = mpath;
        shape.fillRule = kCAFillRuleEvenOdd;
        layer.mask = shape;
        
        text.position = CGPointMake(CGRectGetMidX(layer.frame) + size.width/2 + 10, CGRectGetMidY(layer.frame) + size.height/2);
    }
    
    
    CFBridgingRelease(colour);
    
    return layer;
}

- (CALayer*)createLayerInLayer:(CALayer*)annotationLayer withFont:(NSFont*)font
{
    const CGFloat x = [[self.annotation objectForKey:@"pixelx"] doubleValue];
    const CGFloat y = [[self.annotation objectForKey:@"pixely"] doubleValue];
    const CGFloat radius = [[self.annotation objectForKey:@"radius"] doubleValue];

    return [self createCircularLayerAtPosition:CGPointMake(x, y) radius:radius annotation:self.name inLayer:annotationLayer withFont:font];
}

@end

@interface CASPlateSolveSolution : NSObject
@property (nonatomic,readonly) NSString* centreRA;
@property (nonatomic,readonly) NSString* centreDec;
@property (nonatomic,readonly) NSString* centreAngle;
@property (nonatomic,readonly) NSString* pixelScale;
@property (nonatomic,readonly) NSString* fieldWidth;
@property (nonatomic,readonly) NSString* fieldHeight;
@property (nonatomic,strong) NSArray* wcsinfo;
@property (nonatomic,strong) NSArray* annotations;
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

- (NSString*)centreDec
{
    return [NSString stringWithFormat:@"%02.0f° %02.0fm %02.2fs",
            [[self numberFromInfo:self.wcsinfo withKey:@"dec_center_d"] doubleValue],
            [[self numberFromInfo:self.wcsinfo withKey:@"dec_center_m"] doubleValue],
            [[self numberFromInfo:self.wcsinfo withKey:@"dec_center_s"] doubleValue]];
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
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor lightGrayColor] set];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
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
        self.url = [NSURL URLWithString:urlString];
        if (self.image){
            return YES;
        }
        else {
            [[NSAlert alertWithMessageText:@"Sorry" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Unrecognised image format"] runModal];
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
            [self drawAnnotations];
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
        [self drawAnnotations];
    }
}

- (void)drawAnnotations
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
    
    for (CASPlateSolvedObject* object in self.annotations){
        if (object.enabled){
            [object createLayerInLayer:self.annotationLayer withFont:self.annotationsFont];
        }
    }
    
    // flip y
    for (CALayer* sublayer in [self.annotationLayer sublayers]){
        CGPoint p = sublayer.position;
        p.y = self.annotationLayer.bounds.size.height - p.y;
        sublayer.position = p;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        [self drawAnnotations];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASTaskWrapper* solverTask;
@property (nonatomic,strong) CASSolverModel* solverModel;
@property (nonatomic,readonly) NSString* cacheDirectory;
@property (nonatomic,strong) CASPlateSolveSolution* solution;
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
    
    NSData* fontData = [[NSUserDefaults standardUserDefaults] objectForKey:@"CASAnnotationsFont"];
    if (fontData){
        self.imageView.annotationsFont = [NSUnarchiver unarchiveObjectWithData:fontData];
    }
    else {
        self.imageView.annotationsFont = [NSFont boldSystemFontOfSize:18];
    }

    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self.imageView forKeyPath:@"values.CASAnnotationsColour" options:0 context:(__bridge void *)(self.imageView)];
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

        [self.solverTask setArguments:@[self.imageView.url.path,@"-z",@"2",@"--overwrite",@"-d",@"500",@"-l",@"20",@"-r",@"-D",self.cacheDirectory,@"-b",configPath]];
                
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
                    
                    // get solution data
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

- (IBAction)changeFont:(id)sender
{
    self.imageView.annotationsFont = [sender convertFont:self.imageView.annotationsFont];
    [[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:self.imageView.annotationsFont] forKey:@"CASAnnotationsFont"];
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
            
            // set the annotations
            offscreenImageView.url = self.imageView.url;
            offscreenImageView.annotations = self.imageView.annotations;
            
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
    if (menuItem.action == @selector(saveDocument:)){
        return (self.solution != nil);
    }
    return YES;
}

@end
