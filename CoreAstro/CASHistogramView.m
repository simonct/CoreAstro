//
//  CASHistogramView.m
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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

#import "CASHistogramView.h"
#import <CorePlot/CorePlot.h>
#import <CorePlot/_CPTDarkGradientTheme.h>

@interface CASHistogramTheme : _CPTDarkGradientTheme
@end

@implementation CASHistogramTheme

-(void)applyThemeToBackground:(CPTXYGraph *)graph
{
	graph.fill			= nil;
}

-(void)applyThemeToPlotArea:(CPTPlotAreaFrame *)plotAreaFrame
{
	CPTGradient *gradient = [CPTGradient gradientWithBeginningColor:[[CPTColor colorWithGenericGray:0.1] colorWithAlphaComponent:0.5] endingColor:[[CPTColor colorWithGenericGray:0.3] colorWithAlphaComponent:0.5]];
    
	gradient.angle	   = 90.0;
	plotAreaFrame.fill = [CPTFill fillWithGradient:gradient];
    
	CPTMutableLineStyle *borderLineStyle = [CPTMutableLineStyle lineStyle];
	borderLineStyle.lineColor = [CPTColor colorWithGenericGray:0.2];
	borderLineStyle.lineWidth = 2;
    
	plotAreaFrame.borderLineStyle = borderLineStyle;
	plotAreaFrame.cornerRadius	  = 10.0;
}

@end

@interface CASHistogramView ()
@property (nonatomic,copy) NSString* title;
@property (nonatomic,strong) NSMutableArray* graphs;
@property (nonatomic,strong) CPTGraphHostingView* hostingView;
@end

@implementation CASHistogramView

@synthesize hostingView;
@synthesize title, graphs;
@synthesize histogram = _histogram;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		self.graphs = [[NSMutableArray alloc] init];
        self.hostingView = [(CPTGraphHostingView *)[CPTGraphHostingView alloc] initWithFrame:self.bounds];
        [self addSubview:self.hostingView];
    }
    
    return self;
}

- (BOOL)wantsLayer
{
    return YES;
}

- (void)setBounds:(NSRect)aRect
{
    [super setBounds:aRect];
    [self.hostingView setFrame:aRect];
}

- (void)setHistogram:(NSArray *)histogram
{
    _histogram = histogram;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self renderInLayer:self.hostingView withTheme:[[CASHistogramTheme alloc] init]];
}

-(void)setTitleDefaultsForGraph:(CPTGraph *)graph withBounds:(CGRect)bounds
{
	graph.title = self.title;
	CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
	textStyle.color				   = [CPTColor grayColor];
	textStyle.fontName			   = @"Helvetica-Bold";
	textStyle.fontSize			   = round(bounds.size.height / (CGFloat)20.0);
	graph.titleTextStyle		   = textStyle;
	graph.titleDisplacement		   = CGPointMake( 0.0f, round(bounds.size.height / (CGFloat)18.0) ); // Ensure that title displacement falls on an integral pixel
	graph.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
}

-(void)setPaddingDefaultsForGraph:(CPTGraph *)graph withBounds:(CGRect)bounds
{
	CGFloat boundsPadding = round(bounds.size.width / (CGFloat)20.0); // Ensure that padding falls on an integral pixel
    
	graph.paddingLeft = boundsPadding;
    
	if ( graph.titleDisplacement.y > 0.0 ) {
		graph.paddingTop = graph.titleDisplacement.y * 2;
	}
	else {
		graph.paddingTop = boundsPadding;
	}
    
	graph.paddingRight	= boundsPadding;
	graph.paddingBottom = boundsPadding;
}

-(void)applyTheme:(CPTTheme *)theme toGraph:(CPTGraph *)graph withDefault:(CPTTheme *)defaultTheme
{
	if ( theme == nil ) {
		[graph applyTheme:defaultTheme];
	}
	else if ( ![theme isKindOfClass:[NSNull class]] ) {
		[graph applyTheme:theme];
	}
}

-(void)addGraph:(CPTGraph *)graph toHostingView:(CPTGraphHostingView *)layerHostingView
{
	[self.graphs addObject:graph];
        
	if ( layerHostingView ) {
		layerHostingView.hostedGraph = graph;
	}
}

-(void)renderInLayer:(CPTGraphHostingView *)layerHostingView withTheme:(CPTTheme *)theme
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
	CGRect bounds = layerHostingView.bounds;
#else
	CGRect bounds = NSRectToCGRect(layerHostingView.bounds);
#endif
    
	CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:bounds];
	[self addGraph:graph toHostingView:layerHostingView];
	[self applyTheme:theme toGraph:graph withDefault:[CPTTheme themeNamed:kCPTDarkGradientTheme]];
    
	[self setTitleDefaultsForGraph:graph withBounds:bounds];
	[self setPaddingDefaultsForGraph:graph withBounds:bounds];
    
	// Setup scatter plot space
	CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
	plotSpace.delegate				= (id)self;
    
	// Axes
	// Label x axis with a fixed interval policy
	CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
	CPTXYAxis *x		  = axisSet.xAxis;
    x.hidden = YES;
    x.labelingPolicy			  = CPTAxisLabelingPolicyNone;

	// Label y with an automatic label policy.
	CPTXYAxis *y = axisSet.yAxis;
    y.hidden = YES;
	y.labelingPolicy			  = CPTAxisLabelingPolicyNone;

	// Set axes
	//graph.axisSet.axes = [NSArray arrayWithObjects:x, y, y2, nil];
	graph.axisSet.axes = [NSArray arrayWithObjects:x, y, nil];
    
	// Create a plot that uses the data source method
	CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] init];
	dataSourceLinePlot.identifier = @"Data Source Plot";
    
	CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
	lineStyle.lineWidth				 = 1.5;
	lineStyle.lineColor				 = [CPTColor orangeColor];
	dataSourceLinePlot.dataLineStyle = lineStyle;
    
	dataSourceLinePlot.dataSource = (id)self;
	[graph addPlot:dataSourceLinePlot];
    
	// Auto scale the plot space to fit the plot data
	// Extend the ranges by 30% for neatness
	[plotSpace scaleToFitPlots:[NSArray arrayWithObjects:dataSourceLinePlot, nil]];
	CPTMutablePlotRange *xRange = [plotSpace.xRange mutableCopy];
	CPTMutablePlotRange *yRange = [plotSpace.yRange mutableCopy];
	[xRange expandRangeByFactor:CPTDecimalFromDouble(1.1)];
	[yRange expandRangeByFactor:CPTDecimalFromDouble(1.1)];
	plotSpace.xRange = xRange;
	plotSpace.yRange = yRange;

	// Set plot delegate, to know when symbols have been touched
	// We will display an annotation when a symbol is touched
	dataSourceLinePlot.delegate						   = self;
	dataSourceLinePlot.plotSymbolMarginForHitDetection = 5.0f;
}

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return [self.histogram count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
	NSNumber *num = nil;
    
	if ( fieldEnum == CPTScatterPlotFieldX ) {
		num = [NSNumber numberWithUnsignedInteger:index];
	}
    else if ( fieldEnum == CPTScatterPlotFieldY ) {
		num = [self.histogram objectAtIndex:index];
	}
    
	return num;
}

@end
