//
//  CASStackingView.m
//  stack-test
//
//  Created by Simon Taylor on 11/23/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASStackingView.h"
#import "CASCCDExposure.h"
#import "CASAutoGuider.h"
#import "CASImageStacker.h"
#import "CASUtilities.h"

@interface CASStackingView ()
@property (nonatomic,assign) NSPoint currentPoint;
@property (nonatomic,strong) id<CASGuideAlgorithm> guider;
@property (nonatomic,strong) NSMutableDictionary* points;
@property (nonatomic,strong) NSMutableArray* exposuresToStack;
@end

@implementation CASStackingView

- (void)awakeFromNib
{
    _currentPoint = NSMakePoint(-1, -1);
}

- (CGFloat)searchRadius
{
    return 20;
}

- (CASGuideAlgorithm*)guider
{
    if (!_guider){
        _guider = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
    }
    return _guider;
}

- (NSMutableDictionary*)points
{
    if (!_points){
        _points = [NSMutableDictionary dictionaryWithCapacity:100];
    }
    return _points;
}

- (NSMutableArray*)exposuresToStack
{
    if (!_exposuresToStack){
        _exposuresToStack = [NSMutableArray arrayWithCapacity:100];
    }
    return _exposuresToStack;
}

- (void)setCurrentExposure:(CASCCDExposure *)currentExposure
{
    [super setCurrentExposure:currentExposure];
    
    NSValue* pointValue = [self.points objectForKey:self.currentExposure.uuid];
    if (pointValue){
        NSPoint point = [pointValue pointValue];
        self.starLocation = NSMakePoint(point.x, self.currentExposure.actualSize.height - point.y);
    }
    else {
        if (_currentPoint.x != -1 && _currentPoint.y != -1){
            [self updateStarLocationFromPoint:_currentPoint];
        }
    }
}

- (NSPoint)imagePointFromWindowPoint:(NSPoint)p
{
    if (!self.currentExposure){
        return NSZeroPoint; // invalid point ?
    }
    // todo; clip to image dimensions
    NSPoint point = [self convertViewPointToImagePoint:[self convertPoint:p fromView:nil]];
    point.y = self.currentExposure.actualSize.height - point.y;
    return point;
}

- (void)updateStarLocationFromPoint:(NSPoint)p
{
    if (!self.currentExposure){
        NSLog(@"No current exposure");
        return;
    }
    if (!NSPointInRect(p, CGRectMake(0, 0, self.currentExposure.actualSize.width, self.currentExposure.actualSize.height))){
        NSLog(@"Point outside of image");
        return;
    }
            
    p = [self.guider locateStar:self.currentExposure inArea:CGRectMake(p.x - self.searchRadius, p.y - self.searchRadius, 2 * self.searchRadius, 2 * self.searchRadius)];
    
    [self.points setObject:[NSValue valueWithPoint:p] forKey:self.currentExposure.uuid];
    self.currentPoint = p;

    p.y = self.currentExposure.actualSize.height - p.y;
    self.starLocation = p;
}

- (void)addCurrentExposure
{
    if (self.currentExposure && ![self.exposuresToStack containsObject:self.currentExposure]){
        [self.exposuresToStack addObject:self.currentExposure];
        NSLog(@"%ld images to stack",[self.exposuresToStack count]);
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    [self updateStarLocationFromPoint:[self imagePointFromWindowPoint:theEvent.locationInWindow]];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    [self updateStarLocationFromPoint:[self imagePointFromWindowPoint:theEvent.locationInWindow]];
}

- (void)keyDown:(NSEvent *)theEvent
{
    if ([theEvent keyCode] == 36){
        [self addCurrentExposure];
        if (self.currentExposure == [self.exposures lastObject]){
            [self stack:nil];
        }
        else {
            [self nextExposure:nil];
        }
    }
    else if ([theEvent keyCode] == 53){
        [super nextExposure:nil];
    }
}

- (IBAction)stack:(id)sender
{
    if ([self.exposuresToStack count] < 2){
        return;
    }
    
    const NSTimeInterval time = CASTimeBlock(^(){
        
        CASImageStacker* stacker = [[CASImageStacker alloc] init];
        
        const NSPoint reference = [[self.points objectForKey:((CASCCDExposure*)[self.exposuresToStack objectAtIndex:0]).uuid] pointValue];
        
        [stacker stackWithProvider:^(NSInteger index, CASCCDExposure **exposure, CASImageStackerInfo *info) {
            
            *exposure = [self.exposuresToStack objectAtIndex:index];
            
            const NSPoint p = [[self.points objectForKey:(*exposure).uuid] pointValue];
            info->offset = NSMakePoint(reference.x - p.x, p.y - reference.y);
            info->angle = 0;
            
        } count:[self.exposuresToStack count] block:^(CASCCDExposure *result) {
            
            [self setImage:[result createImage].CGImage imageProperties:nil];
        }];
    });
    
    NSLog(@"Stacked %ld images in %f seconds",[self.exposuresToStack count],time);
    
    self.statusText = [NSString stringWithFormat:@"Stack of %ld",[self.exposuresToStack count]];
}

@end
