//
//  CASCenteringClipView.m
//  scrollview-test
//
//  derived from AGCenteringClipView at http://cocoadev.com/wiki/CenteringInsideNSScrollView
//

#import "CASCenteringClipView.h"

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
    [newClipView setBackgroundColor:[[scrollView contentView] backgroundColor]];
    [scrollView setContentView:(NSClipView* )newClipView];
    [scrollView setDocumentView:docView];
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
    mLookingAt.x = NSMidX(clipRect) / docRect.size.width;
    mLookingAt.y = NSMidY(clipRect) / docRect.size.height;

    return p;

    clipRect.origin = proposedNewOrigin; // shift origin to proposed location
    
// If the clip view is wider than the doc, we can't scroll horizontally
    if (docRect.size.width < clipRect.size.width) {
        clipRect.origin.x = round( maxX / 2.0 );
    } else {
        clipRect.origin.x = round( MAX(0,MIN(clipRect.origin.x,maxX)) );
    }
    
// If the clip view is taller than the doc, we can't scroll vertically
    if (docRect.size.height < clipRect.size.height) {
        clipRect.origin.y = round( maxY / 2.0 );
    } else {
        const float yo = clipRect.origin.y;
        clipRect.origin.y = round( MAX(0,MIN(yo,maxY)) );
        NSLog(@"%f %f -> %f",yo,maxY,clipRect.origin.y);
    }
    
// Save center of view as proportions so we can later tell where the user was focused.
    mLookingAt.x = NSMidX(clipRect) / docRect.size.width;
    mLookingAt.y = NSMidY(clipRect) / docRect.size.height;
    
// The docRect isn't necessarily at (0, 0) so when it isn't, this correctly creates the correct scroll point
    
    NSPoint result = NSMakePoint(docRect.origin.x + clipRect.origin.x, docRect.origin.y + clipRect.origin.y);
    
    NSLog(@"constrainScrollPoint 2: %@",NSStringFromPoint(result));

    return result;
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

// ----------------------------------------
// We have some redundancy in the fact that setFrame: appears to call/send setFrameOrigin:
// and setFrameSize: to do its work, but we need to override these individual methods in case
// either one gets called independently. Because none of them explicitly cause a screen update,
// it's ok to do a little extra work behind the scenes because it wastes very little time.
// It's probably the result of a single UI action anyway so it's not like it's slowing
// down a huge iteration by being called thousands of times.
- (void)setFrameOrigin:(NSPoint)newOrigin {
    if (!NSEqualPoints(self.frame.origin, newOrigin)) {
        [super setFrameOrigin:newOrigin];
        [self centerDocument];
    }
}

- (void)setFrameSize:(NSSize)newSize {
    if (!NSEqualSizes(self.frame.size, newSize)) {
        [super setFrameSize:newSize];
        [self centerDocument];
    }
}

- (void)setFrameRotation:(CGFloat)angle {
    [super setFrameRotation:angle];
    [self centerDocument];
}

- (void)centerDocument {
    
    NSRect docRect = [[self documentView] frame];
    NSRect clipRect = [self bounds];
    
    // The origin point should have integral values or drawing anomalies will occur.
    // We'll leave it to the constrainScrollPoint: method to do it for us.
    if (docRect.size.width < clipRect.size.width) {
        clipRect.origin.x = (docRect.size.width - clipRect.size.width) / 2.0;
    } else {
        clipRect.origin.x = mLookingAt.x; // ??
        docRect.size.width -= (clipRect.size.width / 2.0);
    }
    
    if (docRect.size.height < clipRect.size.height) {
        clipRect.origin.y = (docRect.size.height - clipRect.size.height) / 2.0;
    } else {
        clipRect.origin.y = mLookingAt.y; // ??
        docRect.size.height -= (clipRect.size.height / 2.0);
    }
    
    // Probably the best way to move the bounds origin.
    // Make sure that the scrollToPoint contains integer values
    // or the NSView will smear the drawing under certain circumstances.
    [self scrollToPoint:[self constrainScrollPoint:clipRect.origin]];
    [[self superview] reflectScrolledClipView:self];
}

@end
