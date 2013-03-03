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

@interface CASPlateSolvedObject ()
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

@end

@interface CASPlateSolveSolution ()
@property (nonatomic,strong) NSArray* wcsinfo;
@property (nonatomic,strong) NSArray* annotations;
@end

@implementation CASPlateSolveSolution {
    NSMutableArray* _objects;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.wcsinfo forKey:@"wcsinfo"];
    [aCoder encodeObject:self.annotations forKey:@"annotations"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self){
        self.wcsinfo = [aDecoder decodeObjectForKey:@"wcsinfo"];
        self.annotations = [aDecoder decodeObjectForKey:@"annotations"];
    }
    return self;
}

- (void)setAnnotations:(NSArray*)annotations
{
    if (_annotations != annotations){
        
        if (_objects){
            [[self mutableArrayValueForKey:@"objects"] removeAllObjects];
        }
        
        _annotations = annotations;
        
        for (NSDictionary* annotation in _annotations){
            
            CASPlateSolvedObject* object = [CASPlateSolvedObject new];
            object.enabled = [[annotation objectForKey:@"type"] isEqualToString:@"ngc"];
            object.annotation = annotation;
            if (!_objects){
                _objects = [NSMutableArray arrayWithCapacity:[annotations count]];
            }
            [[self mutableArrayValueForKey:@"objects"] addObject:object];
        }
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

@interface CASPlateSolver ()
@property (nonatomic,strong) CASCCDExposure* exposure;
@property (nonatomic,strong) CASTaskWrapper* solverTask;
@property (nonatomic,strong) NSMutableString* logOutput;
@end

@implementation CASPlateSolver

static NSString* const kSolutionArchiveName = @"solution.plist";
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

- (NSString*)cacheDirectoryForExposure:(CASCCDExposure*)exposure
{
    NSString* path = nil;
    
    if (exposure.io){
        path = [[exposure.io.url path] stringByAppendingPathComponent:@"plate-solve"];
    }
    else {
        path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    }
    
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

- (NSString*)cacheDirectory
{
    return [self cacheDirectoryForExposure:self.exposure];
}

- (NSError*)errorWithCode:(NSInteger)code reason:(NSString*)reason
{
    return [NSError errorWithDomain:NSStringFromClass([self class]) code:code userInfo:@{NSLocalizedFailureReasonErrorKey:reason}];
}

- (CASPlateSolveSolution*)cachedSolutionForExposure:(CASCCDExposure*)exposure
{
    CASPlateSolveSolution* result = nil;
    
    NSString* cacheDirectory = [self cacheDirectoryForExposure:exposure];
    if (cacheDirectory){
        
        NSData* data = [NSData dataWithContentsOfFile:[cacheDirectory stringByAppendingPathComponent:kSolutionArchiveName]];
        if (data){
            
            result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            if (![result isKindOfClass:[CASPlateSolveSolution class]]){
                result = nil;
            }
        }
    }
    
    return result;
}

- (BOOL)canSolveExposure:(CASCCDExposure*)exposure error:(NSError**)error
{
    if (!self.indexDirectoryURL || ![self.indexDirectoryURL checkResourceIsReachableAndReturnError:nil]){
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
                
                [self.solverTask setArguments:@[imagePath,@"--no-plots",@"-z",@"2",@"--overwrite",@"-d",@"500",@"-l",@"20",@"-r",@"-D",self.cacheDirectory,@"-b",configPath]];
                
                // run the solver task
                [self.solverTask launchWithOutputBlock:^(NSString* string) {
                    
                    // accumulate the log output
                    if (!self.logOutput){
                        self.logOutput = [NSMutableString stringWithCapacity:1024];
                    }
                    [self.logOutput appendString:string];
                    [self.logOutput appendString:@"\n"];
                    
                    NSLog(@"Plate solve output: %@",string);
                    
                } terminationBlock:^(int terminationStatus) {
                    
                    if (terminationStatus){
                        complete([self errorWithCode:3 reason:@"Plate solve failed"],nil);
                    }
                    else {
                        
                        // nasty hack to avoid as yet undiagnosed race between solve-field and wcsinfo resulting in empty solution results
                        double delayInSeconds = 0.5;
                        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                            
                            // get solution data by running the wcsinfo tool
                            self.solverTask = [[CASSyncTaskWrapper alloc] initWithTool:@"wcsinfo"];
                            if (!self.solverTask){
                                complete([self errorWithCode:4 reason:@"Can't find the embedded wcsinfo tool"],nil);
                            }
                            else {
                                
                                NSString* name = [[imagePath lastPathComponent] stringByDeletingPathExtension];
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
                                            
                                            // create a solution object
                                            CASPlateSolveSolution* solution = [CASPlateSolveSolution new];
                                            solution.wcsinfo = output;
                                            
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
                                                            solution.annotations = [report objectForKey:@"annotations"];
                                                            
                                                            NSData* solutionData = [NSKeyedArchiver archivedDataWithRootObject:solution];
                                                            if (solutionData){
                                                                NSString* solutionDataPath = [self.cacheDirectory stringByAppendingPathComponent:kSolutionArchiveName];
                                                                [solutionData writeToFile:solutionDataPath options:0 error:nil];
                                                            }
                                                            
                                                            NSString* solvedImagePath = [self.cacheDirectory stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@-ngc",name] stringByAppendingPathExtension:@"png"]];
                                                            
                                                            complete(nil,@{@"solution":solution,@"image":solvedImagePath});
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
