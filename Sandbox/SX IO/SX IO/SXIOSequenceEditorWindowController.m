//
//  SXIOSequenceEditorWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/5/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOSequenceEditorWindowController.h"

@class SXIOSequenceStep;

@interface SXIOSequence : NSObject<NSCoding>
@property (nonatomic,strong) NSMutableArray* steps;
@end

@interface SXIOSequenceStep : NSObject<NSCoding,NSCopying>
@property (nonatomic,assign) NSInteger count;
@property (nonatomic,assign) NSInteger duration;
@property (nonatomic,assign) NSInteger binningIndex;
@property (nonatomic,assign) NSInteger filterIndex;
@property (nonatomic,copy) NSString* prefix;
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
        self.prefix = [coder decodeObjectOfClass:[NSString class] forKey:@"prefix"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.count forKey:@"count"];
    [aCoder encodeInteger:self.duration forKey:@"duration"];
    [aCoder encodeInteger:self.binningIndex forKey:@"binningIndex"];
    [aCoder encodeInteger:self.filterIndex forKey:@"filterIndex"];
    [aCoder encodeObject:self.prefix forKey:@"prefix"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SXIOSequenceStep* copy = [SXIOSequenceStep new];
    
    copy.count = self.count;
    copy.duration = self.duration;
    copy.binningIndex = self.binningIndex;
    copy.filterIndex = self.filterIndex;
    copy.prefix = self.prefix;

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

@interface SXIOSequence ()
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
@property (nonatomic,strong) IBOutlet NSArrayController* stepsController;
@end

@implementation SXIOSequenceEditorWindowController

+ (instancetype)loadSequenceEditor
{
    return [[[self class] alloc] initWithWindowNibName:@"SXIOSequenceEditorWindowController"];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.stepsController.content = [NSMutableArray arrayWithCapacity:10];
}

- (IBAction)start:(id)sender
{
    NSLog(@"start");
}

- (IBAction)save:(id)sender
{
    NSLog(@"save");
}

@end
