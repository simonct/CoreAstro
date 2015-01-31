//
//  CASCenteringClipView.m
//  scrollview-test
//
//  derived from AGCenteringClipView at http://cocoadev.com/wiki/CenteringInsideNSScrollView
//

#import "CASCenteringClipView.h"

@interface CASScrollView : NSScrollView
@end

@implementation CASScrollView

@end

@interface CASCenteringClipView ()
- (void)centerDocument;
@end

@implementation CASCenteringClipView {
    NSPoint mLookingAt; // the proportion up and across the view, not coordinates.
}

+ (void)replaceClipViewInScrollView:(NSScrollView*)scrollView {
    NSView* docView = [scrollView documentView];
    CASCenteringClipView* newClipView = nil;
    newClipView = [[[self class] alloc] initWithFrame:[[scrollView contentView] frame]];
    newClipView.autoresizingMask = NSViewNotSizable;
    [newClipView setBackgroundColor:[[scrollView contentView] backgroundColor]];
    [scrollView setContentView:(NSClipView* )newClipView];
    [scrollView setDocumentView:docView];
    scrollView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    docView.autoresizingMask = NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin|NSViewMaxYMargin;
}

- (void)resetClipView {
    mLookingAt = CGPointZero;
    [self centerDocument];
}

// ----------------------------------------
// We need to override this so that the superclass doesn't override our new origin point.
- (NSPoint)constrainScrollPoint:(NSPoint)proposedNewOrigin {
    
    //NSLog(@"constrainScrollPoint 1: %@",NSStringFromPoint(proposedNewOrigin));
    
    NSPoint p = [super constrainScrollPoint:proposedNewOrigin];
    
    NSRect docRect = [[self documentView] frame];
    NSRect clipRect = [self bounds];
    CGFloat maxX = docRect.size.width - clipRect.size.width;
    CGFloat maxY = docRect.size.height - clipRect.size.height;

    if (docRect.size.width < clipRect.size.width) {
        p.x = docRect.origin.x + round( maxX / 2.0 );
    }
    
    if (docRect.size.height < clipRect.size.height) {
        p.y = docRect.origin.y + round( maxY / 2.0 );
    }

    // Save center of view as proportions so we can later tell where the user was focused.
    mLookingAt.x = docRect.size.width ? NSMidX(clipRect) / docRect.size.width : 0;
    mLookingAt.y = docRect.size.height ? NSMidY(clipRect) / docRect.size.height : 0;

    return p;
}

// ----------------------------------------
// These two methods get called whenever the NSClipView's subview changes.
// We save the old center of interest, call the superclass to let it do its work,
// then move the scroll point to try and put the old center of interest
// back in the center of the view if possible.
- (void)viewBoundsChanged:(NSNotification*)notification {
    NSPoint savedPoint = mLookingAt;
    [super viewBoundsChanged:notification];
    mLookingAt = savedPoint;
    [self centerDocument];
}

- (void)viewFrameChanged:(NSNotification*)notification {
    NSPoint savedPoint = mLookingAt;
    [super viewFrameChanged:notification];
    mLookingAt = savedPoint;
    [self centerDocument];
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    [self centerDocument];
}

- (void)setFrameRotation:(CGFloat)angle {
    [super setFrameRotation:angle];
    [self centerDocument];
}

- (void)centerDocument {
    
    NSRect docRect = [[self documentView] frame];
    NSRect clipRect = [self bounds];
    
    NSPoint origin = NSZeroPoint;
    const CGSize docSize = docRect.size;
    const CGSize clipSize = clipRect.size;
    
    // The origin point should have integral values or drawing anomalies will occur.
    // We'll leave it to the constrainScrollPoint: method to do it for us.
    if (docSize.width < clipSize.width) {
        origin.x = (docSize.width - clipSize.width) / 2.0;
    } else {
        origin.x = (docSize.width * (mLookingAt.x - 0.5)) + (docSize.width - clipSize.width) / 2.0;
    }
    
    if (docSize.height < clipSize.height) {
        origin.y = (docSize.height - clipSize.height) / 2.0;
    } else {
        origin.y = (docSize.height * (mLookingAt.y - 0.5)) + (docSize.height - clipSize.height) / 2.0;
    }
    
    // Probably the best way to move the bounds origin.
    // Make sure that the scrollToPoint contains integer values
    // or the NSView will smear the drawing under certain circumstances.
    const NSPoint p = [self constrainScrollPoint:origin];
    [self scrollToPoint:p];
    [[self superview] reflectScrolledClipView:self];
}

@end
