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
}

- (id)initWithTool:(NSString*)tool
{
    self = [super init];
    if (self) {
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
    [_task setStandardOutput:output];
    [_task setStandardError:output];
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
        
        [self handleTaskOutputData:[[note userInfo] objectForKey:NSFileHandleNotificationDataItem]];
        [_taskOutputHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];
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
    NSString* urlString = [sender.draggingPasteboard propertyListForType:(id)kUTTypeFileURL];
    if ([urlString isKindOfClass:[NSString class]]){
        NSURL* url = [NSURL URLWithString:urlString];
        self.imageURL = url;
        if (self.image){
            return YES;
        }
    }
    return NO;
}

@end

@interface MKOAppDelegate ()
@property (nonatomic,strong) CASTaskWrapper* solverTask;
@property (nonatomic,strong) CASSolverModel* solverModel;
@property (nonatomic,readonly) NSString* cacheDirectory;
@end

@implementation MKOAppDelegate

- (void)awakeFromNib
{
    self.spinner.hidden = YES;
    self.spinner.usesThreadedAnimation = YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
//    [[NSFileManager defaultManager] removeItemAtPath:self.cacheDirectory error:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (self.solverTask){
        [self.solverTask terminate];
    }
//    [[NSFileManager defaultManager] removeItemAtPath:self.cacheDirectory error:nil];
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
    __block NSNumber* result = nil;
    [values enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj hasPrefix:key]){
            NSScanner* scanner = [NSScanner scannerWithString:obj];
            NSString* ignored;
            [scanner scanString:key intoString:&ignored];
            double d;
            if ([scanner scanDouble:&d]){
                result = [NSNumber numberWithDouble:d];
                *stop = YES;
            }
        }
    }];
    return result;
}

- (IBAction)solve:(id)sender
{
    {
        self.solverTask = [[CASSyncTaskWrapper alloc] initWithTool:@"wcsinfo"];
        if (!self.solverTask){
            [self presentAlertWithMessage:@"Can't find the embedded wcsinfo tool"];
        }
        else {
            
            [self.solverTask setArguments:@[@"/var/folders/5y/ffhlwmqd08s7vxt39t5mrh2h0000gn/T/com.makotechnology.astrometry-test/m42.wcs"]];
            
            [self.solverTask launchWithOutputBlock:nil terminationBlock:^(int terminationStatus) {
                
                if (terminationStatus){
                    [self presentAlertWithMessage:@"Failed to get solution info"];
                }
                else {
                    
                    NSArray* output = [self.solverTask.taskOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    NSLog(@"RA %02.0f:%02.0f:%02.2f",
                          [[self numberFromInfo:output withKey:@"ra_center_h"] doubleValue],
                          [[self numberFromInfo:output withKey:@"ra_center_m"] doubleValue],
                          [[self numberFromInfo:output withKey:@"ra_center_s"] doubleValue]);
                    NSLog(@"Dec %@:%@:%@",
                          [self numberFromInfo:output withKey:@"dec_center_d"],
                          [self numberFromInfo:output withKey:@"dec_center_m"],
                          [self numberFromInfo:output withKey:@"dec_center_s"]);
                    NSLog(@"Angle %@",
                          [self numberFromInfo:output withKey:@"orientation"]);
                    
                }
                
                self.solverTask = nil;
            }];
        }
    }
    return;
    
    if (!self.imageView.image || self.solverTask){
        return;
    }

    self.solveButton.enabled = NO;
    self.imageView.alphaValue = 0.5;
    self.spinner.hidden = NO;
    [self.spinner startAnimation:nil];
    
    self.solverTask = [[CASTaskWrapper alloc] initWithTool:@"solve-field"];
    if (!self.solverTask){
        [self presentAlertWithMessage:@"Can't find the embedded solve-field tool"];
    }
    else {
        
        [self.solverTask setArguments:@[self.imageView.imageURL.path,@"-z",@"2",@"--overwrite",@"-d",@"500",@"-l",@"20",@"-r",@"-D",self.cacheDirectory]];
        
        // update config file with indexes
        
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
                            
//                            NSLog(@"taskOutput %@",[self.solverTask.taskOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
                            
                            NSLog(@"%@",[self numberFromInfo:[self.solverTask.taskOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] withKey:@"ra_center_h"]);
                        }
                        
                        self.solverTask = nil;
                    }];
                }
            }
        }];
    }
}

@end
