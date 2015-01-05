//
//  SXIOSequenceEditorWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/5/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOSequenceEditorWindowController.h"

@interface SXIOSequenceStep : NSObject<NSCoding,NSCopying>
@property (nonatomic,assign) NSInteger count;
@property (nonatomic,assign) NSInteger duration;
@property (nonatomic,assign) NSInteger binningIndex;
@property (nonatomic,assign) NSInteger filterIndex;
@end

@implementation SXIOSequenceStep

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.filterIndex = NSNotFound;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        self.count = [coder decodeIntegerForKey:@"count"];
        self.duration = [coder decodeIntegerForKey:@"duration"]; // default seconds
        self.binningIndex = [coder decodeIntegerForKey:@"binningIndex"]; // or value ?
        self.filterIndex = [coder decodeIntegerForKey:@"filterIndex"]; // or name ?
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.count forKey:@"count"];
    [aCoder encodeInteger:self.duration forKey:@"duration"];
    [aCoder encodeInteger:self.binningIndex forKey:@"binningIndex"];
    [aCoder encodeInteger:self.filterIndex forKey:@"filterIndex"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SXIOSequenceStep* copy = [SXIOSequenceStep new];
    
    copy.count = self.count;
    copy.duration = self.duration;
    copy.binningIndex = self.binningIndex;
    copy.filterIndex = self.filterIndex;

    return copy;
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"count" isEqualToString:key]){
        self.count = 0;
    }
    else if ([@"duration" isEqualToString:key]){
        self.duration = 0;
    }
    else {
        [super setNilValueForKey:key];
    }
}

@end

@interface SXIOSequence : NSObject<NSCoding>
@property (nonatomic,strong) NSMutableArray* steps;
@property (nonatomic,copy) NSString* prefix;
@property (nonatomic,assign) NSInteger dither;
@property (nonatomic,assign) NSInteger temperature;
@end

@implementation SXIOSequence

- (id)init
{
    self = [super init];
    if (self) {
        self.steps = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        self.steps = [[coder decodeObjectOfClass:[NSArray class] forKey:@"steps"] mutableCopy];
        self.dither = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"dither"] integerValue];
        self.temperature = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"temperature"] integerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.steps forKey:@"steps"];
    [aCoder encodeInteger:self.dither forKey:@"dither"];
    [aCoder encodeInteger:self.temperature forKey:@"temperature"];
}

- (void)setNilValueForKey:(NSString *)key
{
    [super setNilValueForKey:key];
}

@end

@interface SXIOSequenceEditorWindowController ()
@property (nonatomic,strong) SXIOSequence* sequence;
@property (nonatomic,strong) IBOutlet NSArrayController* stepsController;
@end

@implementation SXIOSequenceEditorWindowController

+ (instancetype)loadSequenceEditor
{
    return [[[self class] alloc] initWithWindowNibName:@"SXIOSequenceEditorWindowController"];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.sequence = [SXIOSequence new];
}

- (void)setSequence:(SXIOSequence *)sequence
{
    if (_sequence != sequence){
        _sequence = sequence;
        self.stepsController.content = _sequence.steps;
    }
}

- (IBAction)start:(id)sender
{
    NSLog(@"start");
}

- (void)updateWindowRepresentedURL:(NSURL*)url
{
    self.window.representedURL = url; // need scoped bookmark data ?
    NSString* name = [url isFileURL] ? [[NSFileManager defaultManager] displayNameAtPath:url.path] : [url lastPathComponent];
    [self.window setTitleWithRepresentedFilename:name];
}

- (IBAction)save:(id)sender
{
    void (^archiveToURL)(NSURL*) = ^(NSURL* url){
        if ([[NSKeyedArchiver archivedDataWithRootObject:self.sequence] writeToURL:url options:NSDataWritingAtomic error:nil]){
            [self updateWindowRepresentedURL:url];
        }
    };
    
    if (self.window.representedURL){
        archiveToURL(self.window.representedURL);
    }
    else {
        NSSavePanel* save = [NSSavePanel savePanel];
        
        save.allowedFileTypes = @[@"caSequence"];
        save.canCreateDirectories = YES;
        
        [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton){
                archiveToURL(save.URL);
            }
        }];
    }
}

- (IBAction)open:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = @[@"caSequence"];
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton){
            SXIOSequence* sequence = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfURL:open.URL]];
            if ([sequence isKindOfClass:[SXIOSequence class]]){
                self.sequence = sequence;
                [self updateWindowRepresentedURL:open.URL];
            }
        }
    }];
}

@end
