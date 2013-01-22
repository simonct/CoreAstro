//
//  CASCenteringClipView.h
//  scrollview-test
//
//  derived from AGCenteringClipView at http://cocoadev.com/wiki/CenteringInsideNSScrollView
//

#import <Cocoa/Cocoa.h>


@interface CASCenteringClipView : NSClipView
- (void)resetClipView;
+ (void)replaceClipViewInScrollView:(NSScrollView*)scrollView;
@end