//
//  CASGradientButtonCell.m
//  CoreAstro
//
//  Based on http://www.amateurinmotion.com/articles/2010/05/06/drawing-custom-nsbutton-in-cocoa.html
//

#import "CASGradientButton.h"

@implementation CASGradientButton

- (CGSize)intrinsicContentSize
{
    CGSize size = [self.attributedTitle size];
    size.width += 30;
    return size;
}

@end

@implementation CASGradientButtonCell

- (NSBezierPath*)pathWithFrame:(NSRect)frame radius:(CGFloat)radius
{
    NSBezierPath* path = [NSBezierPath bezierPath];
    
    const CGFloat corner = 0;
    const CGFloat depth = 10;

    [path moveToPoint:NSMakePoint(CGRectGetMinX(frame) + corner, CGRectGetMinY(frame) + CGRectGetHeight(frame)/2 + corner)];
    
    [path lineToPoint:NSMakePoint(CGRectGetMinX(frame) + depth, CGRectGetMaxY(frame))];
    [path lineToPoint:NSMakePoint(CGRectGetMaxX(frame), CGRectGetMaxY(frame))];
    [path lineToPoint:NSMakePoint(CGRectGetMaxX(frame), CGRectGetMinY(frame))];
    [path lineToPoint:NSMakePoint(CGRectGetMinX(frame) + depth, CGRectGetMinY(frame))];
    
    [path lineToPoint:NSMakePoint(CGRectGetMinX(frame) + corner, CGRectGetMinY(frame) + CGRectGetHeight(frame)/2 - corner)];
    
    return path;
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
    
    CGFloat roundedRadius = 3.0f;
    
    BOOL outer = 1;
    BOOL background = 1;
    BOOL stroke = 0;
    BOOL innerStroke = 0;
    
    if(outer) {
        [ctx saveGraphicsState];
        NSBezierPath *outerClip = [self pathWithFrame:frame radius:roundedRadius];
        [outerClip setClip];

        NSGradient *outerGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                     [NSColor colorWithDeviceWhite:0.20f alpha:1.0f], 0.0f, 
                                     [NSColor colorWithDeviceWhite:0.21f alpha:1.0f], 1.0f, 
                                     nil];
        
        [outerGradient drawInRect:[outerClip bounds] angle:90.0f];
        [ctx restoreGraphicsState];
    }
     
    if(background) {
        [ctx saveGraphicsState];
        NSBezierPath *backgroundPath = [self pathWithFrame:NSInsetRect(frame, 2.0f, 2.0f) radius:roundedRadius];
        [backgroundPath setClip];
        
        NSGradient *backgroundGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                          [NSColor colorWithDeviceWhite:0.17f alpha:1.0f], 0.0f, 
                                          [NSColor colorWithDeviceWhite:0.20f alpha:1.0f], 0.12f, 
                                          [NSColor colorWithDeviceWhite:0.27f alpha:1.0f], 0.5f, 
                                          [NSColor colorWithDeviceWhite:0.30f alpha:1.0f], 0.5f, 
                                          [NSColor colorWithDeviceWhite:0.42f alpha:1.0f], 0.98f, 
                                          [NSColor colorWithDeviceWhite:0.50f alpha:1.0f], 1.0f, 
                                          nil];
        
        [backgroundGradient drawInRect:[backgroundPath bounds] angle:270.0f];
        [ctx restoreGraphicsState];
    }
    
    if(stroke) {
        [ctx saveGraphicsState];
        [[NSColor colorWithDeviceWhite:0.12f alpha:1.0f] setStroke];
        [[self pathWithFrame:NSInsetRect(frame, 1.5f, 1.5f) radius:roundedRadius] stroke];
        [ctx restoreGraphicsState];
    }
    
    if(innerStroke) {
        [ctx saveGraphicsState];
        [[NSColor colorWithDeviceWhite:1.0f alpha:0.05f] setStroke];
        [[self pathWithFrame:NSInsetRect(frame, 2.5f, 2.5f) radius:roundedRadius] stroke];
        [ctx restoreGraphicsState];        
    }
    
    if([self isHighlighted]) {
        [ctx saveGraphicsState];
        [[self pathWithFrame:NSInsetRect(frame, 2.0f, 2.0f) radius:roundedRadius] setClip];
        [[NSColor colorWithCalibratedWhite:0.0f alpha:0.35] setFill];
        NSRectFillUsingOperation(frame, NSCompositeSourceOver);
        [ctx restoreGraphicsState];
    }
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView
{
    NSMutableAttributedString* mas = [[NSMutableAttributedString alloc] initWithAttributedString:title];
    [mas addAttributes:@{@"NSColor":[NSColor whiteColor]} range:NSMakeRange(0, [title length])];
    // shadow
    return [super drawTitle:mas withFrame:CGRectOffset(frame, 0, -2) inView:controlView];
}

- (NSRect)titleRectForBounds:(NSRect)theRect
{
    NSRect r = [super titleRectForBounds:theRect];
    r.origin.x += 10;
    r.size.width -= 10;
    return r;
}

@end
