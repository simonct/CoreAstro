//
//  iEQWindowController.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "iEQWindowController.h"
#import "iEQMount.h"
#import "CASLX200Commands.h"

@interface iEQRATransformer : NSValueTransformer

@end

@implementation iEQRATransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    return [CASLX200Commands highPrecisionRA:[value doubleValue]];
}

@end

@interface iEQDecTransformer : NSValueTransformer

@end

@implementation iEQDecTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    return [CASLX200Commands highPrecisionDec:[value doubleValue]];
}

@end

@interface iEQWindowController ()
@property (nonatomic,strong) iEQMount* mount;
@end

@implementation iEQWindowController

+ (void)initialize
{
    [NSValueTransformer setValueTransformer:[iEQRATransformer new] forName:@"iEQRATransformer"];
    [NSValueTransformer setValueTransformer:[iEQDecTransformer new] forName:@"iEQDecTransformer"];
}

- (void)connectToMount:(iEQMount*)mount
{
    self.mount = mount;
    
    [self.mount connectWithCompletion:^{
        if (self.mount.connected){
            [self.window makeKeyAndOrderFront:nil];
        }
        else {
            NSLog(@"Failed to connect");
        }
    }];
}

- (void)startMoving:(iEQMountDirection)direction
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving:) object:nil];
    [self performSelector:@selector(stopMoving:) withObject:nil afterDelay:0.25];
    [self.mount startMoving:direction];
}

- (IBAction)north:(id)sender
{
    [self startMoving:iEQMountDirectionNorth];
}

- (IBAction)soutgh:(id)sender
{
    [self startMoving:iEQMountDirectionSouth];
}

- (IBAction)west:(id)sender
{
    [self startMoving:iEQMountDirectionWest];
}

- (IBAction)east:(id)sender
{
    [self startMoving:iEQMountDirectionEast];
}

- (void)stopMoving:sender
{
    [self.mount stopMoving];
}

- (IBAction)dump:(id)sender
{
    [self.mount dumpInfo];
}

@end
