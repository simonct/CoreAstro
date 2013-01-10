//
//  MKOAppDelegate.m
//  astrometry-test
//
//  Created by Simon Taylor on 12/24/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "MKOAppDelegate.h"

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

@interface CASDraggableImageView : NSImageView
@property (nonatomic,copy) NSURL* imageURL;
@end

@implementation CASDraggableImageView

- (void)awakeFromNib
{
    [self registerForDraggedTypes:@[(id)kUTTypeFileURL]];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor lightGrayColor] set];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

- (void)setImageURL:(NSURL *)imageURL
{
    if (imageURL != _imageURL){
        _imageURL = [imageURL copy];
        [self setImage:[[NSImage alloc] initWithContentsOfURL:_imageURL]];
    }
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    NSString* urlString = [sender.draggingPasteboard stringForType:(id)kUTTypeFileURL];
    if ([urlString isKindOfClass:[NSString class]]){
        NSURL* url = [NSURL URLWithString:urlString];
        self.imageURL = url;
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

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASTaskWrapper* solverTask;
@property (nonatomic,strong) CASSolverModel* solverModel;
@property (nonatomic,readonly) NSString* cacheDirectory;
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

- (IBAction)solve:(id)sender
{
    if (!self.imageView.image || self.solverTask){
        return;
    }
    
    if (!self.indexDirectoryURL){
        [self presentAlertWithMessage:@"You need to select the location of the astrometry.net indexes before solving"];
        return;
    }

    self.solved = NO;
    
    // bindings...
    self.solutionRALabel.stringValue = self.solutionDecLabel.stringValue = self.solutionAngleLabel.stringValue = @"";
    self.pixelScaleLabel.stringValue = self.fieldWidthLabel.stringValue = self.fieldHeightLabel.stringValue = @"";

    self.solveButton.enabled = NO;
    self.imageView.alphaValue = 0.5;
    self.spinner.hidden = NO;
    [self.spinner startAnimation:nil];
    
    self.solverTask = [[CASTaskWrapper alloc] initWithTool:@"solve-field"];
    if (!self.solverTask){
        [self presentAlertWithMessage:@"Can't find the embedded solve-field tool"];
    }
    else {
        
        // update the config with the index location
        NSMutableString* config = [NSMutableString string];
        [config appendFormat:@"add_path %@\n",[self.indexDirectoryURL path]];
        [config appendString:@"autoindex\n"];
        NSString* configPath = [self.cacheDirectory stringByAppendingPathComponent:@"backend.cfg"];
        [config writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        [self.solverTask setArguments:@[self.imageView.imageURL.path,@"-z",@"2",@"--overwrite",@"-d",@"500",@"-l",@"20",@"-r",@"-D",self.cacheDirectory,@"-b",configPath]];
                
        [self.solverTask launchWithOutputBlock:^(NSString* string) {
            
            [self.outputLogTextView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:string]];
            [self.outputLogTextView scrollToEndOfDocument:nil];
            
        } terminationBlock:^(int terminationStatus) {
            
            self.solveButton.enabled = YES;
            self.imageView.alphaValue = 1;
            self.spinner.hidden = YES;
            [self.spinner stopAnimation:nil];
            
            if (terminationStatus){
                [self presentAlertWithMessage:@"Solve failed"];
            }
            else {

                // allow to switch between the detected object images, etc ?
                
                // nasty hack to avoid as yet undiagnosed race between solve-field and wcsinfo resulting in empty solution results
                double delayInSeconds = 0.5;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    
                    // show the solved image
                    NSString* name = [[self.imageView.imageURL.path lastPathComponent] stringByDeletingPathExtension];
                    NSString* path = [self.cacheDirectory stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@-ngc",name] stringByAppendingPathExtension:@"png"]];
                    self.imageView.imageURL = [NSURL fileURLWithPath:path];
                    
                    // get solution data
                    self.solverTask = [[CASSyncTaskWrapper alloc] initWithTool:@"wcsinfo"];
                    if (!self.solverTask){
                        [self presentAlertWithMessage:@"Can't find the embedded wcsinfo tool"];
                    }
                    else {
                        
                        path = [[self.cacheDirectory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"wcs"];
                        [self.solverTask setArguments:@[path]];
                        
                        [self.solverTask launchWithOutputBlock:nil terminationBlock:^(int terminationStatus) {
                            
                            if (terminationStatus){
                                [self presentAlertWithMessage:@"Failed to get solution info"];
                            }
                            else {
                                                                
                                NSArray* output = [self.solverTask.taskOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                                if (![output count]){
                                    NSLog(@"No output from wcsinfo");
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
                                        [self presentAlertWithMessage:@"Can't find the embedded plot-constellations tool"];
                                    }
                                    else {
                                        
                                        NSString* path = [[self.cacheDirectory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"wcs"];
                                        [self.solverTask setArguments:@[@"-w",path,@"-NCBJL"]];
                                        
                                        [self.solverTask launchWithOutputBlock:nil terminationBlock:^(int terminationStatus) {
                                            
                                            if (terminationStatus){
                                                [self presentAlertWithMessage:@"Failed to get annotations"];
                                            }
                                            else {
                                                
                                                NSDictionary* report = [NSJSONSerialization JSONObjectWithData:[self.solverTask.taskOutput dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
                                                if (![report isKindOfClass:[NSDictionary class]]){
                                                    [self presentAlertWithMessage:@"Couldn't read annotation data"];
                                                }
                                                else {
                                                    // check status=solved
                                                    NSArray* annotations = [[report objectForKey:@"annotations"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"type == 'ngc'"]];
                                                    NSLog(@"%@",annotations);
                                                }
                                            }
                                        }];
                                    }
                                }
                            }
                            
                            self.solverTask = nil;
                        }];
                    }
                });
            }
        }];
    }
}

- (IBAction)openDocument:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = [NSImage imageFileTypes];
    open.allowsMultipleSelection = NO;
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            self.imageView.imageURL = open.URL;
            if (self.imageView.imageURL){
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
    
    save.allowedFileTypes = @[[self.imageView.imageURL pathExtension]];
    save.canCreateDirectories = YES;
    save.nameFieldStringValue = [self.imageView.imageURL lastPathComponent];
    
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            NSError* error;
            if (![[NSFileManager defaultManager] copyItemAtURL:self.imageView.imageURL toURL:save.URL error:&error]){
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
