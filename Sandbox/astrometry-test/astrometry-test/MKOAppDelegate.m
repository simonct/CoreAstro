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

@interface CASPlateSolveImageView : CASImageView
@property (nonatomic,assign) BOOL acceptDrop;
@end

@implementation CASPlateSolveImageView

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

- (CALayer*)createCircularLayerAtPosition:(CGPoint)position radius:(CGFloat)radius annotation:(NSString*)annotation inLayer:(CALayer*)annotationLayer
{
    CALayer* layer = [CALayer layer];
    
    CGColorRef colour = CGColorCreateGenericRGB(1,1,0,1);
    
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
        const CGFloat fontSize = 24;
        NSFont* font = [NSFont boldSystemFontOfSize:fontSize];
        const CGSize size = [text.string sizeWithAttributes:@{NSFontAttributeName:font}];
        text.font = (__bridge CFTypeRef)(font);
        text.fontSize = fontSize;
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

- (CALayer*)createLayerInLayer:(CALayer*)annotationLayer
{
    const CGFloat x = [[self.annotation objectForKey:@"pixelx"] doubleValue];
    const CGFloat y = [[self.annotation objectForKey:@"pixely"] doubleValue];
    const CGFloat radius = [[self.annotation objectForKey:@"radius"] doubleValue];

    return [self createCircularLayerAtPosition:CGPointMake(x, y) radius:radius annotation:self.name inLayer:annotationLayer];
}

@end

@interface CASPlateSolveSolution : NSObject
@property (nonatomic,copy) NSString* centreRA;
@property (nonatomic,copy) NSString* centreDec;
@property (nonatomic,copy) NSString* centreAngle;
@property (nonatomic,copy) NSString* pixelScale;
@property (nonatomic,copy) NSString* fieldWidth;
@property (nonatomic,copy) NSString* fieldHeight;
@property (nonatomic,strong) NSArray* objects;
@end

@implementation CASPlateSolveSolution
@end

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASTaskWrapper* solverTask;
@property (nonatomic,strong) CASSolverModel* solverModel;
@property (nonatomic,strong) NSMutableArray* annotations;
@property (nonatomic,readonly) NSString* cacheDirectory;
@property (nonatomic,strong) CALayer* annotationLayer;
@property (nonatomic,assign) BOOL solved;
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
    [self.imageView addObserver:self forKeyPath:@"url" options:0 context:(__bridge void *)(self)];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
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

- (void)updateAnnotations:(NSArray*)annotations // move to image view
{
    if (_annotations){
        for (id object in self.annotations){
            [object removeObserver:self forKeyPath:@"enabled"];
        }
        [[self mutableArrayValueForKey:@"annotations"] removeAllObjects];
    }
    
    if (!annotations){
        [self.annotationLayer removeFromSuperlayer];
        self.annotationLayer = nil;
    }
    else {
        
        for (NSDictionary* annotation in annotations){
            CASPlateSolvedObject* object = [CASPlateSolvedObject new];
            object.enabled = [[annotation objectForKey:@"type"] isEqualToString:@"ngc"];
            object.annotation = annotation;
            [object addObserver:self forKeyPath:@"enabled" options:0 context:(__bridge void *)(self)];
            if (!_annotations){
                _annotations = [NSMutableArray arrayWithCapacity:[annotations count]];
            }
            [[self mutableArrayValueForKey:@"annotations"] addObject:object];
        }
        
        [self drawAnnotations];
    }
}

- (void)drawAnnotations // move to image view
{
    if (!self.imageView.image){
        return;
    }
    
    if (!self.annotationLayer){
        self.annotationLayer = [CALayer layer];
        self.annotationLayer.bounds = CGRectMake(0, 0, self.imageView.image.extent.size.width, self.imageView.image.extent.size.height);
        self.annotationLayer.position = CGPointMake(self.imageView.image.extent.size.width/2, self.imageView.image.extent.size.height/2);
        [self.imageView.layer addSublayer:self.annotationLayer];
    }
    
    for (CALayer* layer in [[self.annotationLayer sublayers] copy]){
        [layer removeFromSuperlayer];
    }
    
    for (CASPlateSolvedObject* object in self.annotations){
        if (object.enabled){
            [object createLayerInLayer:self.annotationLayer];
        }
    }
    
    // flip y
    for (CALayer* sublayer in [self.annotationLayer sublayers]){
        CGPoint p = sublayer.position;
        p.y = self.annotationLayer.bounds.size.height - p.y;
        sublayer.position = p;
    }
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

    self.solved = NO;
    self.imageView.acceptDrop = NO;
    [self updateAnnotations:nil]; // yuk
    
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
                                    
                                    self.solved = YES;
                                    
                                    self.solutionRALabel.stringValue = [NSString stringWithFormat:@"%02.0fh %02.0fm %02.2fs",
                                                                        [[self numberFromInfo:output withKey:@"ra_center_h"] doubleValue],
                                                                        [[self numberFromInfo:output withKey:@"ra_center_m"] doubleValue],
                                                                        [[self numberFromInfo:output withKey:@"ra_center_s"] doubleValue]];
                                    
                                    self.solutionDecLabel.stringValue = [NSString stringWithFormat:@"%02.0f° %02.0fm %02.2fs",
                                                                         [[self numberFromInfo:output withKey:@"dec_center_d"] doubleValue],
                                                                         [[self numberFromInfo:output withKey:@"dec_center_m"] doubleValue],
                                                                         [[self numberFromInfo:output withKey:@"dec_center_s"] doubleValue]];
                                    
                                    self.solutionAngleLabel.stringValue = [NSString stringWithFormat:@"%02.0f°",
                                                                           [[self numberFromInfo:output withKey:@"orientation"] doubleValue]];
                                    
                                    self.pixelScaleLabel.stringValue = [NSString stringWithFormat:@"%.2f\u2033",
                                                                           [[self numberFromInfo:output withKey:@"pixscale"] doubleValue]];

                                    self.fieldWidthLabel.stringValue = [NSString stringWithFormat:@"%.2f\u2032", // todo; check fieldunits == arcminutes
                                                                        [[self numberFromInfo:output withKey:@"fieldw"] doubleValue]];
                                    
                                    self.fieldHeightLabel.stringValue = [NSString stringWithFormat:@"%.2f\u2032",
                                                                        [[self numberFromInfo:output withKey:@"fieldh"] doubleValue]];

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
                                                    [self updateAnnotations:[report objectForKey:@"annotations"]];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        if (object == self.imageView){
            [self updateAnnotations:nil]; // reset annotations layer
        }
        [self drawAnnotations];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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
    if (!self.solved){
        return;
    }
    
    NSSavePanel* save = [NSSavePanel savePanel];
    
    save.allowedFileTypes = @[[self.imageView.url pathExtension]];
    save.canCreateDirectories = YES;
    save.nameFieldStringValue = [self.imageView.url lastPathComponent];
    
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            NSError* error;
            if (![[NSFileManager defaultManager] copyItemAtURL:self.imageView.url toURL:save.URL error:&error]){
                [NSApp presentError:error];
            }
        }
    }];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    if (menuItem.action == @selector(saveDocument:)){
        return self.solved;
    }
    return YES;
}

@end
