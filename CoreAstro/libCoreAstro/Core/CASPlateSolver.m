//
//  CASPlateSolver.m
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
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

#import "CASPlateSolver.h"
#import "CASTaskWrapper.h"
#import "CASCCDExposureIO.h"

@interface CASPlateSolver ()
@property (nonatomic,strong) CASCCDExposure* exposure;
@property (nonatomic,strong) CASTaskWrapper* solverTask;
@property (nonatomic,strong) NSMutableString* logOutput;
@end

@implementation CASPlateSolver

static NSString* const kCASAstrometryIndexDirectoryURLKey = @"CASAstrometryIndexDirectoryURL";

+ (id<CASPlateSolver>)plateSolverWithIdentifier:(NSString*)ident
{
    CASPlateSolver* result = nil;
    
    if (!ident){
        result = [[CASPlateSolver alloc] init];
    }
    else {
        // consult plugin manager for a plugin of the appropriate type and identifier
    }
    
    return result;
}

+ (void)initialize
{
    if (self == [CASPlateSolver class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{kCASAstrometryIndexDirectoryURLKey:@"/Volumes/Media1TB/astrometry.net"}];
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
    NSString* path = nil;
    
    if (self.exposure.io){
        path = [[self.exposure.io.url path] stringByAppendingPathComponent:@"plate-solve"];
    }
    else {
        path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    }
    
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

- (NSError*)errorWithCode:(NSInteger)code reason:(NSString*)reason
{
    return [NSError errorWithDomain:NSStringFromClass([self class]) code:code userInfo:@{NSLocalizedFailureReasonErrorKey:reason}];
}

- (BOOL)canSolveExposure:(CASCCDExposure*)exposure error:(NSError**)error
{
    if (!self.indexDirectoryURL){
        if (error){
            *error = [self errorWithCode:1 reason:@"Plate solving index directory has not been set"];
        }
        return NO;
    }
    return YES;
}

- (void)solveExposure:(CASCCDExposure*)exposure completion:(void(^)(NSError*,NSDictionary*))block;
{
    void (^complete)(NSError*,NSDictionary*) = ^(NSError* error,NSDictionary* results){
        if (block){
            block(error,results);
        }
//        if ([imagePath length]){
//            [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
//        }
    };
    
    self.exposure = exposure;
    
    // check we're configured
    __block NSError* error = nil;
    if (![self canSolveExposure:exposure error:&error]){
        complete(error,nil);
        return;
    }
    
    // run image export async as it can take a while
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // export the exposure we want to solve to a png
        NSData* data = [[exposure newImage] dataForUTType:(id)kUTTypePNG options:nil];
        if (!data){
            complete([self errorWithCode:9 reason:@"Failed to export exposure to an image"],nil);
            return;
        }
        NSString* imagePath = [self.cacheDirectory stringByAppendingPathComponent:@"solve.png"];
        if (![data writeToFile:imagePath options:NSDataWritingAtomic error:&error]){
            complete(error,nil);
            return;
        }
        
        // create tasks on main queue otherwise we end up with no data being returned to the app (rings a bell but can't remember why this happens)
        dispatch_async(dispatch_get_main_queue(), ^{

            // create a solver task for the embedded tool
            self.solverTask = [[CASTaskWrapper alloc] initWithTool:@"solve-field"];
            if (!self.solverTask){
                complete([self errorWithCode:2 reason:@"Can't find the embedded solve-field tool"],nil);
            }
            else {
                
                // update the config with the index location
                NSMutableString* config = [NSMutableString string];
                [config appendFormat:@"add_path %@\n",[self.indexDirectoryURL path]];
                [config appendString:@"autoindex\n"];
                NSString* configPath = [self.cacheDirectory stringByAppendingPathComponent:@"backend.cfg"];
                [config writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                
                [self.solverTask setArguments:@[imagePath,@"-z",@"2",@"--overwrite",@"-d",@"500",@"-l",@"20",@"-r",@"-D",self.cacheDirectory,@"-b",configPath]];
                
                // run the solver task
                [self.solverTask launchWithOutputBlock:^(NSString* string) {
                    
                    // accumulate the log output
                    if (!self.logOutput){
                        self.logOutput = [NSMutableString stringWithCapacity:1024];
                    }
                    [self.logOutput appendString:string];
                    [self.logOutput appendString:@"\n"];
                    
                    NSLog(@"Plate Solve: %@",string);
                    
                } terminationBlock:^(int terminationStatus) {
                    
                    if (terminationStatus){
                        complete([self errorWithCode:3 reason:@"Plate solve failed"],nil);
                    }
                    else {
                        
                        // allow to switch between the detected object images, etc ?
                        
                        // nasty hack to avoid as yet undiagnosed race between solve-field and wcsinfo resulting in empty solution results
                        double delayInSeconds = 0.5;
                        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                            
                            // show the solved image
                            NSString* name = [[imagePath lastPathComponent] stringByDeletingPathExtension];
                            NSString* solvedImagePath = [self.cacheDirectory stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@-ngc",name] stringByAppendingPathExtension:@"png"]];
                            
                            // get solution data by running the wcsinfo tool
                            self.solverTask = [[CASSyncTaskWrapper alloc] initWithTool:@"wcsinfo"];
                            if (!self.solverTask){
                                complete([self errorWithCode:4 reason:@"Can't find the embedded wcsinfo tool"],nil);
                            }
                            else {
                                
                                [self.solverTask setArguments:@[[[self.cacheDirectory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"wcs"]]];
                                
                                [self.solverTask launchWithOutputBlock:nil terminationBlock:^(int terminationStatus) {
                                    
                                    if (terminationStatus){
                                        complete([self errorWithCode:5 reason:@"Failed to get solution info"],nil);
                                    }
                                    else {
                                        
                                        NSArray* output = [self.solverTask.taskOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                                        if (![output count]){
                                            NSLog(@"No output from wcsinfo");
                                        }
                                        else{
                                            
                                            // get annotations by running plot-constellations in json mode
                                            self.solverTask = [[CASSyncTaskWrapper alloc] initWithTool:@"plot-constellations" iomask:2];
                                            if (!self.solverTask){
                                                complete([self errorWithCode:6 reason:@"Can't find the embedded plot-constellations tool"],nil);
                                            }
                                            else {
                                                
                                                NSString* path = [[self.cacheDirectory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"wcs"];
                                                [self.solverTask setArguments:@[@"-w",path,@"-NCBJL"]];
                                                
                                                [self.solverTask launchWithOutputBlock:nil terminationBlock:^(int terminationStatus) {
                                                    
                                                    if (terminationStatus){
                                                        complete([self errorWithCode:7 reason:@"Failed to get annotations"],nil);
                                                    }
                                                    else {
                                                        
                                                        NSDictionary* report = [NSJSONSerialization JSONObjectWithData:[self.solverTask.taskOutput dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
                                                        if (![report isKindOfClass:[NSDictionary class]]){
                                                            complete([self errorWithCode:8 reason:@"Couldn't read annotation data"],nil);
                                                        }
                                                        else {
                                                            // check status=solved
                                                            NSArray* annotations = [[report objectForKey:@"annotations"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"type == 'ngc'"]];
                                                            complete(nil,@{@"annotations":annotations,@"wcs":output,@"image":solvedImagePath});
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
        });
    });
}

@end
