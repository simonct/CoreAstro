//
//  CASGuideAlgorithm.m
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
//  Guiding algorithms by Craig Stark ( http://www.stark-labs.com )
//
//  ***************************************************************************
//  Please don't use this code as the basis of further development; it's still
//  a work in progress. The original, verified algorithm can be found at
//  http://code.google.com/p/open-phd-guiding/source/browse/branches/craig/guide_routines.cpp
//  ***************************************************************************
//

#import "CASAutoGuider.h"
#import <vector>
#import <ApplicationServices/ApplicationServices.h>

#define CROPXSIZE 100
#define CROPYSIZE 100

static float SIGN(double x) {
	if (x > 0.0) return 1.0;
	else if (x < 0.0) return -1.0;
	else return 0.0;
}

enum {
	DEC_OFF = 0,
	DEC_AUTO,
	DEC_NORTH,
	DEC_SOUTH
};

enum {
	STAR_OK = 0,
	STAR_SATURATED,
	STAR_LOWSNR,
	STAR_LOWMASS,
	STAR_MASSCHANGE,
	STAR_LARGEMOTION
};

enum {
    kGuidingModeNone = 0,
    kGuidingModeNeedsCalibrating,
    kGuidingModeCalibrating,
    kGuidingModeGuiding
};

@interface CASGuideAlgorithm ()
@property (nonatomic,copy) NSString* status;
@end

@implementation CASGuideAlgorithm {
    
    NSInteger SearchRegion;
//    NSInteger	CropX ;
//    NSInteger	CropY;
    bool FoundStar;
    double LastdX;
    double LastdY;
    double dX;
    double dY;
    double StarX, StarY;
    double LockX;
    double LockY;
    double StarMass;
    double StarSNR;
    double StarMassChangeRejectThreshold;
    bool Calibrated;
    double RA_rate, RA_angle, Dec_rate, Dec_angle, Dec_dist, Dec_dur, Dec_History, Curr_Dec_Side;
    std::vector<double> Dec_dist_list;
    int	Cal_duration;
    bool Dec_guide;
    
    NSInteger guidingMode;
    CASGuiderDirection calibrationDirection;
    
    double dist;
	bool still_going;
	int iterations;
	double dist_crit;
    bool in_backlash;
    
    double Max_RA_Dur, Max_Dec_Dur;
    double RA_aggr, RA_hysteresis;
    double last_guide;
    double MinMotion;
    NSInteger frame_index;
    NSTimeInterval start_time, elapsed_time;
    
    NSFileHandle* logFile;
}

@synthesize imageProcessor;

+ (id<CASGuideAlgorithm>)guideAlgorithmWithIdentifier:(NSString*)ident
{
    id result = nil;
    
    if (!ident){
        result = [[CASGuideAlgorithm alloc] init]; // CASGuideAlgorithm_OpenPHD
    }
    else {
        // consult plugin manager for a plugin of the appropriate type and identifier
    }
    
    return result;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (CGPoint)starLocation
{
    return CGPointMake(StarX, StarY);
}

- (CGPoint)lockLocation
{
    return CGPointMake(LockX, LockY);
}

- (CGFloat)searchRadius
{
    return SearchRegion;
}

- (void)reset
{
    SearchRegion = 30; // neccessary if guiding through the scope rather than the guider
    //    CropX = 0;
    //    CropY = 0;
    FoundStar = false;
    LastdX = 0.0;
    LastdY = 0.0;
    dX = 0.0;
    dY = 0.0;
    LockX = 0.0;
    LockY = 0.0;
    StarMass = 0.0;
    StarSNR = 0.0;
    StarMassChangeRejectThreshold = 0.5;
    Cal_duration = 750;
    MinMotion = 0.15;
    Max_Dec_Dur = 150;
    Max_RA_Dur = 1000;
    RA_hysteresis = 0.1;
    RA_aggr = 1.0;
    last_guide = 0;
    frame_index = 0;
    elapsed_time = 0;
    start_time = 0;
    Dec_guide = DEC_AUTO;
    Dec_History = 0;
    guidingMode = kGuidingModeNeedsCalibrating;
    Dec_dist_list.assign(10, 0);
}

- (void)logString:(NSString*)string
{
    if (!logFile){
        NSString* path = [@"~/Library/Logs/CoreAstro" stringByExpandingTildeInPath];
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        path = [path stringByAppendingPathComponent:@"PHD_log.txt"];
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        logFile = [NSFileHandle fileHandleForUpdatingAtPath:path];
        if (!logFile){
            NSLog(@"No guiding log file");
        }
    }
    NSLog(@"%@",string);
    [logFile writeData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSArray*)locateStars:(CASCCDExposure*)exposure
{
//    if (exposure.params.bps != 16){
//        NSLog(@"%@: only works with 16-bit images",NSStringFromSelector(_cmd));
//        return nil;
//    }
    
    float* exposurePixels = (float*)[exposure.floatPixels bytes];
    if (!exposurePixels){
        return nil;
    }

    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    double xpos = -1, ypos = -1;
    
    const CASSize size = exposure.params.size; // note, not actual size
    const NSInteger linesize = size.width;
    
    float A, B1, B2, C1, C2, C3, D1, D2, D3;
	double PSF[14] = { 0.906, 0.584, 0.365, .117, .049, -0.05, -.064, -.074, -.094 };
	double mean;
	double PSF_fit;
	double BestPSF_fit = 0.0;
    const int border = 40;
    
	for (NSInteger y=border; size.height > border && y<size.height-border; y++) {
        
		for (NSInteger x=border; linesize > border && x<linesize-border; x++) {
            
			A =  (float) *(exposurePixels + linesize * y + x);
            
            B1 = (float) *(exposurePixels + linesize * (y-1) + x) + (float) *(exposurePixels + linesize * (y+1) + x) + (float) *(exposurePixels + linesize * y + (x + 1)) + (float) *(exposurePixels + linesize * y + (x-1));
			
			B2 = (float) *(exposurePixels + linesize * (y-1) + (x-1)) + (float) *(exposurePixels + linesize * (y-1) + (x+1)) + (float) *(exposurePixels + linesize * (y+1) + (x + 1)) + (float) *(exposurePixels + linesize * (y+1) + (x-1));
			
            C1 = (float) *(exposurePixels + linesize * (y-2) + x) + (float) *(exposurePixels + linesize * (y+2) + x) + (float) *(exposurePixels + linesize * y + (x + 2)) + (float) *(exposurePixels + linesize * y + (x-2));
			
            C2 = (float) *(exposurePixels + linesize * (y-2) + (x-1)) + (float) *(exposurePixels + linesize * (y-2) + (x+1)) + (float) *(exposurePixels + linesize * (y+2) + (x + 1)) + (float) *(exposurePixels + linesize * (y+2) + (x-1)) +
            (float) *(exposurePixels + linesize * (y-1) + (x-2)) + (float) *(exposurePixels + linesize * (y-1) + (x+2)) + (float) *(exposurePixels + linesize * (y+1) + (x + 2)) + (float) *(exposurePixels + linesize * (y+1) + (x-2));
			
			C3 = (float) *(exposurePixels + linesize * (y-2) + (x-2)) + (float) *(exposurePixels + linesize * (y-2) + (x+2)) + (float) *(exposurePixels + linesize * (y+2) + (x + 2)) + (float) *(exposurePixels + linesize * (y+2) + (x-2));
			
            D1 = (float) *(exposurePixels + linesize * (y-3) + x) + (float) *(exposurePixels + linesize * (y+3) + x) + (float) *(exposurePixels + linesize * y + (x + 3)) + (float) *(exposurePixels + linesize * y + (x-3));
			
            D2 = (float) *(exposurePixels + linesize * (y-3) + (x-1)) + (float) *(exposurePixels + linesize * (y-3) + (x+1)) + (float) *(exposurePixels + linesize * (y+3) + (x + 1)) + (float) *(exposurePixels + linesize * (y+3) + (x-1)) +
            (float) *(exposurePixels + linesize * (y-1) + (x-3)) + (float) *(exposurePixels + linesize * (y-1) + (x+3)) + (float) *(exposurePixels + linesize * (y+1) + (x + 3)) + (float) *(exposurePixels + linesize * (y+1) + (x-3));
			
            D3 = 0.0;
            
            NSInteger i;
            float *uptr;
			uptr = exposurePixels + linesize * (y-4) + (x-4);
			for (i=0; i<9; i++, uptr++)
				D3 = D3 + *uptr;
            
			uptr = exposurePixels + linesize * (y-3) + (x-4);
			for (i=0; i<3; i++, uptr++)
				D3 = D3 + *uptr;
            
			uptr = uptr + 2;
			for (i=0; i<3; i++, uptr++)
				D3 = D3 + *uptr;
            
			D3 = D3 + (float) *(exposurePixels + linesize * (y-2) + (x-4)) + (float) *(exposurePixels + linesize * (y-2) + (x+4)) + (float) *(exposurePixels + linesize * (y-2) + (x-3)) + (float) *(exposurePixels + linesize * (y-2) + (x-3)) +
            (float) *(exposurePixels + linesize * (y+2) + (x-4)) + (float) *(exposurePixels + linesize * (y+2) + (x+4)) + (float) *(exposurePixels + linesize * (y+2) + (x - 3)) + (float) *(exposurePixels + linesize * (y+2) + (x-3)) +
            (float) *(exposurePixels + linesize * y + (x + 4)) + (float) *(exposurePixels + linesize * y + (x-4));
            
			uptr = exposurePixels + linesize * (y+4) + (x-4);
			for (i=0; i<9; i++, uptr++)
				D3 = D3 + *uptr;
            
			uptr = exposurePixels + linesize * (y+3) + (x-4);
			for (i=0; i<3; i++, uptr++)
				D3 = D3 + *uptr;
            
			uptr = uptr + 2;
			for (i=0; i<3; i++, uptr++)
				D3 = D3 + *uptr;
            
			mean = (A+B1+B2+C1+C2+C3+D1+D2+D3)/85.0;
            
			PSF_fit = PSF[0] * (A-mean) + PSF[1] * (B1 - 4.0*mean) + PSF[2] * (B2 - 4.0 * mean) +
            PSF[3] * (C1 - 4.0*mean) + PSF[4] * (C2 - 8.0*mean) + PSF[5] * (C3 - 4.0 * mean) +
            PSF[6] * (D1 - 4.0*mean) + PSF[7] * (D2 - 8.0*mean) + PSF[8] * (D3 - 48.0 * mean);
            
            
			if (PSF_fit > BestPSF_fit) {
				BestPSF_fit = PSF_fit;
				xpos = x;
				ypos = y;
			}
        }
    }
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
    
    return (xpos < 0 || ypos < 0) ? nil : [NSArray arrayWithObject:[NSValue valueWithPoint:NSMakePoint(xpos, ypos)]];
}

- (void)resetStarLocation:(CGPoint)star {

    [self reset];
    
    StarX = star.x;
    StarY = star.y;
}

typedef struct {
    double mx, my, mass, max, mean, snr, mass_ratio, nearmax1, nearmax2, maxlval, val;
} CASStarQuality;

- (CASStarQuality)_locateStar:(CASCCDExposure*)exposure inArea:(CGRect)area {
    
    NSInteger base_x, base_y;  // expected position in image (potentially cropped) coordinates
	NSInteger start_x, start_y, rowsize;
	NSInteger x, y, searchsize;
	float *dataptr;
	double lval, maxlval, mean;
	double max, nearmax1, nearmax2, sval, localmin;
	double mass, mx, my, val;

    const CASSize size = exposure.actualSize;
    float* exposurePixels = (float*)[exposure.floatPixels bytes];

    base_x = (int) CGRectGetMidX(area) ;
	base_y = (int) CGRectGetMidY(area);
    
	dataptr = exposurePixels;
	rowsize = size.width;
	searchsize = CGRectGetWidth(area) * 2 + 1;
	maxlval = nearmax1 = nearmax2 = max = 0;
	start_x = base_x - CGRectGetWidth(area); // u-left corner of local area
	start_y = base_y - CGRectGetWidth(area);
	mean=0;
    
	// figure the local offset
	localmin = 1.0;
    //	localmin = 0;
	if (start_y == 0) start_y = 1;
	double localmean = 0.0;
	for (y=0; y<searchsize; y++) {
		for (x=0; x<searchsize; x++) {
			if (*(dataptr + (start_x + x) + rowsize * (start_y + y-1)) < localmin)
				localmin = *(dataptr + (start_x + x) + rowsize * (start_y + y-1));
            //			localmin += *(dataptr + (start_x + x) + rowsize * (start_y + y-1));
			localmean = localmean + (double)  *(dataptr + (start_x + x) + rowsize * (start_y + y-1));
            
		}
	}
    //	localmin = localmin / (searchsize*searchsize);
	localmean = localmean / (double) (searchsize * searchsize);
	// get rough guess on star's location
	for (y=0; y<searchsize; y++) {
		for (x=0; x<searchsize; x++) {
			lval = *(dataptr + (start_x + x) + rowsize * (start_y + y)) +  // combine adjacent pixels to smooth image
            *(dataptr + (start_x + x+1) + rowsize * (start_y + y)) +		// find max of this smoothed area and set
            *(dataptr + (start_x + x-1) + rowsize * (start_y + y)) +		// base_x and y to be this spot
            *(dataptr + (start_x + x) + rowsize * (start_y + y+1)) +
            *(dataptr + (start_x + x) + rowsize * (start_y + y-1)) +
            *(dataptr + (start_x + x) + rowsize * (start_y + y));  // weigh current pixel by 2x
			if (lval >= maxlval) {
				base_x = start_x + x;
				base_y = start_y + y;
				maxlval = lval;
			}
			sval = *(dataptr + (start_x + x) + rowsize * (start_y + y)) -localmin;
			if ( sval >= max) {
				nearmax2 = nearmax1;
				nearmax1 = max;
				max = sval;
			}
			mean = mean + sval;
		}
	}
	mean = mean / (searchsize * searchsize);
    
//	frame->SetStatusText(_T(""),1);
	if (/*(frame->canvas->State == STATE_SELECTED) &&*/ (nearmax1 == nearmax2) && (nearmax1 == maxlval)) { // alert user that this is not the best star
        //		wxMessageBox(wxString::Format("This star appears to be saturated and will lead to sub-optimal\nguiding results.  You may wish to select another star, decrease\nexposure duration or decrease camera gain"));
		NSLog(@"SATURATED STAR");
	}
    
	// should be close now, hone in
	//start_x = base_x - 5; // u-left corner of local area
	//start_y = base_y - 5;
	int ft_range = 15; // must be odd
	int hft_range = ft_range / 2;
	mass = mx = my = 0.000001;
	//double threshold = localmean;
	double threshold = localmean + ((double) max + localmin - localmean) / 10.0;  // Note: max already has localmin pulled from it
	//double threshold = localmin + ((double) max - localmin) / 10.0;
	//frame->SetStatusText(wxString::Format("%f",threshold),1);
	for (y=0; y<ft_range; y++) {
		for (x=0; x<ft_range; x++) {
			val = (double) *(dataptr + (base_x + (x-hft_range)) + rowsize*(base_y + (y-hft_range))) - threshold;
			if (val < 0.0) val=0.0;
			mx = mx + (double) (base_x + x-hft_range) * val;
			my = my + (double) (base_y + y-hft_range) * val;
			mass = mass + val;
		}
	}
	if (mass < 10.0) { // We've over-subtracted here - try again
		mass = mx = my = 0.000001;
		threshold = localmean;
		for (y=0; y<ft_range; y++) {
			for (x=0; x<ft_range; x++) {
				val = (double) *(dataptr + (base_x + (x-hft_range)) + rowsize*(base_y + (y-hft_range))) - threshold;
				if (val < 0.0) val=0.0;
				mx = mx + (double) (base_x + x-hft_range) * val;
				my = my + (double) (base_y + y-hft_range) * val;
				mass = mass + val;
			}
		}
	}
	if (mass < 10.0) { // We've over-subtracted here yet again
		mass = mx = my = 0.000001;
		threshold = localmin;
		for (y=0; y<ft_range; y++) {
			for (x=0; x<ft_range; x++) {
				val = (double) *(dataptr + (base_x + (x-hft_range)) + rowsize*(base_y + (y-hft_range))) - threshold;
				if (val < 0.0) val=0.0;
				mx = mx + (double) (base_x + x-hft_range) * val;
				my = my + (double) (base_y + y-hft_range) * val;
				mass = mass + val;
			}
		}
	}
	
    /*	double AvgMass;
     if (LastMass2 < 1.0) LastMass2 = StarMass;
     if (LastMass1 < 1.0) LastMass1 = StarMass;
     AvgMass = (StarMass + LastMass1 + LastMass2) / 3.0;*/
	double MassRatio = StarMass ? mass / StarMass : INT_MAX;
	if (MassRatio > 1.0)
		MassRatio = 1.0/MassRatio;
	MassRatio = 1.0 - MassRatio;
	StarSNR = (double) max / (double) mean;

    CASStarQuality quality = {
        .max = max,
        .snr = StarSNR,
        .mass_ratio = MassRatio,
        .mass = mass,
        .nearmax1 = nearmax1,
        .nearmax2 = nearmax2,
        .mean = mean,
        .maxlval = maxlval,
        .mx = mx,
        .my = my,
        .val = val
    };
    return quality;
}

- (NSInteger)updateStarLocation:(CASCCDExposure*)exposure {
    
//	float *dataptr;
//	NSInteger x, y, searchsize;
	NSInteger base_x, base_y;  // expected position in image (potentially cropped) coordinates
//	double mass, mx, my, val = 0.0;
//	NSInteger start_x, start_y, rowsize;
//	float lval, maxlval, mean;
//	float max, nearmax1, nearmax2, sval, localmin;
	NSInteger retval = STAR_OK;
	static NSInteger BadMassCount = 0;
    
    const CASSize size = exposure.actualSize;
//    float* exposurePixels = (float*)[exposure.floatPixels bytes];

	if ((StarX <= SearchRegion) || (StarY <= SearchRegion) ||
		(StarX >= (size.width - SearchRegion)) || (StarY >= (size.height - SearchRegion))) {
		FoundStar = false;
		return STAR_LARGEMOTION;
	}
    
	LastdX = dX; // Save the previous motion
	LastdY = dY;
    
	base_x = (int) StarX ;
	base_y = (int) StarY;
    
    const CASStarQuality quality = [self _locateStar:exposure inArea:CGRectMake(base_x - SearchRegion, base_y - SearchRegion, 2*SearchRegion, 2*SearchRegion)];
        
	if (/*(frame->canvas->State > STATE_CALIBRATING) &&*/
		(quality.mass_ratio > StarMassChangeRejectThreshold) &&
		(StarMassChangeRejectThreshold < 0.99) && (BadMassCount < 2) ) {
        
		// we're guiding and big change in mass
		dX = 0.0;
		dY = 0.0;
		FoundStar=false;
        NSLog(@"Mass: %.0f vs %.0f",quality.mass,StarMass);
//		frame->SetStatusText(wxString::Format(_T("Mass: %.0f vs %.0f"),mass,StarMass),1);
		StarMass = quality.mass;
		retval = STAR_MASSCHANGE;
		BadMassCount++;
	}
	else if ((quality.mass < 10.0) || // so faint -- likely dropped frame§
             (StarSNR < 3.0) ) {
		dX = 0.0;
		dY = 0.0;
		FoundStar=false;
		StarMass = quality.mass;
		if (quality.mass < 10.0) {
            NSLog(@"NO STAR: %f",quality.mass);
//			frame->SetStatusText(wxString::Format(_T("NO STAR: %f"),mass),1);
			retval = STAR_LOWMASS;
		}
		else if (StarSNR < 3.0) {
            NSLog(@"LOW SNR: %f",StarSNR);
//			frame->SetStatusText(wxString::Format(_T("LOW SNR: %f"),StarSNR),1);
			retval = STAR_LOWSNR;
		}
	}
	else {
		BadMassCount = 0;
        //		LastMass1 = LastMass2;
        //s		LastMass2 = StarMass;
		StarMass = quality.mass;
		StarX = quality.mx / quality.mass;
		StarY = quality.my / quality.mass;
		dX = StarX - LockX;
		dY = StarY - LockY;
        NSLog(@"dX (%f) = StarX (%f) - LockX (%f)",dX,StarX,LockX);
        NSLog(@"dY (%f) = StarY (%f) - LockY (%f)",dY,StarY,LockY);
		FoundStar=true;
		if (quality.max == quality.nearmax2) {
            NSLog(@"Star saturated");
//			frame->SetStatusText(_T("Star saturated"));
			retval = STAR_SATURATED;
		}
		else{
//			frame->SetStatusText(_T(""),1);
        }
	}
    
    NSLog(@"%ldx%ld: %f, %f(%f), %f, %f",base_x,base_y,quality.mass,quality.mean,quality.val,quality.maxlval, quality.nearmax2);
    //	frame->SetStatusText(wxString::Format("%dx%d: %f, %ld(%f), %ld, %ld",base_x,base_y,mass,mean,val,maxlval, nearmax2),1);
//	CropX = StarX - (CROPXSIZE/2);
//	CropY = StarY - (CROPYSIZE/2);
//	if (CropX < 0) CropX = 0;
//	else if ((CropX + CROPXSIZE) >= fullFrameSize.width) CropX = fullFrameSize.width - (CROPXSIZE + 1);
//	if (CropY < 0) CropY = 0;
//	else if ((CropY + CROPYSIZE) >= fullFrameSize.height) CropY = fullFrameSize.height - (CROPYSIZE + 1);
    
	return retval;
}

- (NSPoint)locateStar:(CASCCDExposure*)exposure inArea:(CGRect)area {
    const CASStarQuality quality = [self _locateStar:exposure inArea:area];
    return quality.mass == 0 ? NSZeroPoint : NSMakePoint(quality.mx / quality.mass, quality.my / quality.mass);
}

- (CASCCDExposure*)processGuideFrame:(CASCCDExposure*)exposure error:(NSError**)errorPtr {
    
    // median filter (take a copy ?)
    [self.imageProcessor medianFilter:exposure];
    
    const NSInteger result = [self updateStarLocation:exposure];
    if (result != STAR_OK){
        if (errorPtr){
            *errorPtr = [NSError errorWithDomain:@"CASGuideAlgorithm"
                                            code:result
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedFailureReasonErrorKey,[NSString stringWithFormat:@"Updating guide frame failed with error %ld",result],nil]];
        }
        return nil;
    }
    
    return exposure;
}

- (void)pulse:(CASGuiderDirection)direction duration:(NSInteger)durationMS guideCallback:(void(^)(NSError*,CASGuiderDirection,NSInteger))guideCallback {
    
    if (guideCallback){
        guideCallback(nil,direction,durationMS);
    }
}

- (void)startCalibration:(CASCCDExposure*)exposure guideCallback:(void(^)(NSError*,CASGuiderDirection,NSInteger))guideCallback {

    self.status = @"Calibrating...";
    
    Calibrated = false;
    RA_rate = RA_angle = Dec_rate = Dec_angle = 0.0;
    
    NSError* error = nil;
    exposure = [self processGuideFrame:exposure error:&error];
    if (!exposure){
        if (guideCallback){
            guideCallback(error,kCASGuiderDirection_None,0);
        }
        return;
    }
    
    LockX = StarX;
    LockY = StarY;
    
    still_going = true;
    iterations = 0;
    dist_crit = exposure.params.frame.height * 0.05;
    if (dist_crit > 25.0) dist_crit = 25.0;
    
    // isn't there some relationship between dist_crit and searchregion ? e.g. search region should be at least large enough to capture the motion
    
    [self logString:@"Calibration begun"];
    [self logString:[NSString stringWithFormat:@"lock %f %f, star %f %f, dist_crit %f",LockX,LockY,StarX,StarY,dist_crit]];
    [self logString:@"Direction,Step,dx,dy,x,y"];
    
    calibrationDirection = kCASGuiderDirection_RAPlus;
    
    [self pulse:calibrationDirection duration:Cal_duration guideCallback:guideCallback];
    
    guidingMode = kGuidingModeCalibrating;
}

- (void)updateCalibration:(CASCCDExposure*)exposure guideCallback:(void(^)(NSError*,CASGuiderDirection,NSInteger))guideCallback {
    
    NSError* error = nil;
    exposure = [self processGuideFrame:exposure error:&error];
    if (!exposure){
        if (guideCallback){
            guideCallback(error,kCASGuiderDirection_None,0);
        }
        return;
    }
    
    dist = sqrt(dX*dX+dY*dY);
    NSLog(@"dist: %f",dist);
    
    if (calibrationDirection == kCASGuiderDirection_RAPlus) {
        
        self.status = @"Calibrating RA+...";

        iterations++;
        
        if (iterations > 60) {
            if (guideCallback){
                guideCallback([NSError errorWithDomain:@"CASGuideAlgorithm"
                                                  code:1
                                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedFailureReasonErrorKey,@"RA Calibration failed - star did not move enough",nil]],
                              kCASGuiderDirection_None,
                              0);
            }
            return;
        }
        
        [self logString:[NSString stringWithFormat:@"RA+ (west),%d,%f,%f,%f,%f",iterations, dX,dY,StarX,StarY]];
        
        if (dist > dist_crit) {
            
			RA_rate = dist / (double) (iterations * Cal_duration);
            
            NSLog(@"atany_x = %.2f, atan2= %.2f, dx= %f dy= %f",atan(dY / dX),atan2(dX,dY), dX, dY);

			if (dX == 0.0) dX = 0.00001;
			if (dX > 0.0) RA_angle = atan(dY/dX);
			else if (dY >= 0.0) RA_angle = atan(dY/dX) + M_PI;
			else RA_angle = atan(dY/dX) - M_PI;
            
            [self logString:[NSString stringWithFormat:@"RA+ (west) calibrated,%f,%f",RA_rate,RA_angle]];

            calibrationDirection = kCASGuiderDirection_RAMinus;
		}
        else {
            [self pulse:calibrationDirection duration:Cal_duration guideCallback:guideCallback];
        }
    }
    
    if (calibrationDirection == kCASGuiderDirection_DecPlus){
        
        self.status = @"Calibrating Dec+...";

        [self logString:[NSString stringWithFormat:@"Dec+ (north),%d,%f,%f,%f,%f",iterations, dX,dY,StarX,StarY]];

        if (in_backlash){
            
            if (abs(dist) >= 3.0) in_backlash = false;
            else if (iterations > 80) {
                
                still_going = false;
				in_backlash = false;
				Dec_guide = DEC_OFF;
                
                [self logString:@"Dec guiding failed during backlash removal - turned off"];
            }
            
            if (!in_backlash){
                
                LockX = StarX;  // re-sync star position
                LockY = StarY;
                
                iterations = 0;
            }
        }
        else {
         
            iterations++;
            
			if (iterations > 60) {
                
				still_going = false;
				Dec_guide = DEC_OFF;
                
                [self logString:@"Dec guiding failed during North cal - turned off"];
			}
            
			if (dist > dist_crit) {
                
				Dec_rate = dist / (double) (iterations * Cal_duration);
                
                NSLog(@"atany_x = %.2f, atan2= %.2f, dx= %f dy= %f",atan(dY / dX),atan2(dX,dY), dX, dY);
                
				if (dX == 0.0) dX = 0.00001;
				if (dX > 0.0) Dec_angle = atan(dY/dX);
				else if (dY >= 0.0) Dec_angle = atan(dY/dX) + M_PI;
				else Dec_angle = atan(dY/dX) - M_PI;
				still_going = false;
                
                [self logString:[NSString stringWithFormat:@"Dec+ (north) calibrated,%f,%f",Dec_rate,Dec_angle]];

                calibrationDirection = kCASGuiderDirection_DecMinus;
			}
            else {
                [self pulse:calibrationDirection duration:Cal_duration guideCallback:guideCallback];
            }
        }
    }
    
    if (calibrationDirection == kCASGuiderDirection_RAMinus || calibrationDirection == kCASGuiderDirection_DecMinus){
        
        self.status = (calibrationDirection == kCASGuiderDirection_RAMinus) ? @"Calibrating RA-..." : @"Calibrating Dec-...";
        
        if (iterations-- > 0){
            
            if (calibrationDirection == kCASGuiderDirection_RAMinus){
                [self logString:[NSString stringWithFormat:@"RA- (east),%d,%f,%f,%f,%f",iterations, dX,dY,StarX,StarY]];
            }
            else {
                [self logString:[NSString stringWithFormat:@"Dec- (south),%d,%f,%f,%f,%f",iterations, dX,dY,StarX,StarY]];
            }
            
            [self pulse:calibrationDirection duration:Cal_duration guideCallback:guideCallback];
        }
        else {
            
            LockX = StarX;  // re-sync star position
            LockY = StarY;
            iterations = 0;

            if (calibrationDirection == kCASGuiderDirection_RAMinus){
                calibrationDirection = kCASGuiderDirection_DecPlus;
                [self pulse:calibrationDirection duration:Cal_duration guideCallback:guideCallback];
            }
            else {
                self.status = @"Guiding";
                guidingMode = kGuidingModeGuiding;
                Calibrated = true;
            }
        }
    }
}

- (void)updateGuiding:(CASCCDExposure*)exposure guideCallback:(void(^)(NSError*,CASGuiderDirection,NSInteger))guideCallback {
    
    if (!start_time){
        start_time = [NSDate timeIntervalSinceReferenceDate];
    }
    elapsed_time = [NSDate timeIntervalSinceReferenceDate] - start_time;
    
    NSError* error = nil;
    exposure = [self processGuideFrame:exposure error:&error];
    if (!exposure){
        if (guideCallback){
            guideCallback(error,kCASGuiderDirection_None,0);
        }
        return;
    }
    
    if ( ((fabs(dX) > SearchRegion) || (fabs(dY)>SearchRegion))) { // likely lost lock -- stay here
        StarX = LockX;
        StarY = LockY;
        dX = 0.0;
        dY = 0.0;
        FoundStar = false;
        // StarErrorCode = STAR_LARGEMOTION;
        // sound the alarm and wait here
        NSBeep();
        return;
    }
    
    double theta, hyp;

    if (dX == 0.0) dX = 0.000001;
    if (dX > 0.0) theta = atan(dY/dX);		// theta = angle star is at
    else if (dY >= 0.0) theta = atan(dY/dX) + M_PI;
    else theta = atan(dY/dX) - M_PI;
    
    hyp = sqrt(dX*dX+dY*dY);	// dist b/n lock and star
    NSLog(@"hyp: %f",hyp);
    
    // Do RA guide
    double RA_dist = cos(RA_angle - theta)*hyp;	// dist in RA star needs to move
    RA_dist = (1.0 - RA_hysteresis) * RA_dist + RA_hysteresis * last_guide;	// add in hysteresis
    double RA_dur = (fabs(RA_dist)/RA_rate)*RA_aggr;	// duration of pulse

    if (RA_dur > (double) Max_RA_Dur) RA_dur = (double) Max_RA_Dur;  // cap pulse length
    
    if ((fabs(RA_dist) > MinMotion) && FoundStar){ // not worth <0.25 pixel moves
        
        NSLog(@"- Guiding RA ");
        
        if (RA_dist > 0.0) {
            
            NSLog(@"E dur=%f dist=%.2f",RA_dur,RA_dist);
            
            [self pulse:kCASGuiderDirection_RAMinus duration:RA_dur guideCallback:guideCallback]; // So, guide in the RA- direction;

            NSLog(@"%ld,%.3f,%.2f,%.2f,%f,%f,%.2f",frame_index,elapsed_time,dX,dY,theta,RA_dur,RA_dist);
        }
        else {
            
            NSLog(@"W dur=%f dist=%.2f",RA_dur,RA_dist);
            
            [self pulse:kCASGuiderDirection_RAPlus duration:RA_dur guideCallback:guideCallback]; // So, guide in the RA+ direction;

            NSLog(@"%ld,%.3f,%.2f,%.2f,%f,%f,%.2f",frame_index,elapsed_time,dX,dY,theta,RA_dur,RA_dist);
        }
    }
    else {
        
        NSLog(@"%ld,%.3f,%.2f,%.2f,%f,0.0,%.2f",frame_index,elapsed_time,dX,dY,theta,RA_dist);
        
    
        Dec_dist = cos(Dec_angle - theta)*hyp;	// dist in Dec star needs to move
        Dec_dur = fabs(Dec_dist)/Dec_rate;
        //				if (fabs(Dec_dist) < 0.5)   // if drift is small, assume noisy and don't include in history - set to 0
        //					Dec_dist_list.Add(0.0);
        //				else

        Dec_dist_list.push_back(Dec_dist);
        //					Dec_dist_list.Add(SIGN(Dec_dist));
        Dec_dist_list.erase(Dec_dist_list.begin());
        

        bool Allow_Dec_Move;
        if (fabs(Dec_dist) < MinMotion)
            Allow_Dec_Move = false;
        else
            Allow_Dec_Move = true; // so far, assume we'll allow the movement
        Dec_History = 0.0;
        for (int i=0; i<10; i++) {
            if (fabs(Dec_dist_list[i]) > MinMotion) // only count decent-size errors
                Dec_History += SIGN(Dec_dist_list[i]);
        }
        

        //					Dec_History += Dec_dist_list.Item(i);
        NSLog(@"%f %f %f %d %f",Curr_Dec_Side,Dec_dist,Dec_dur,Allow_Dec_Move,Dec_History);
        
        // see if on same side of Dec and if we have enough evidence to switch
        if ( ((Curr_Dec_Side == 0) || (Curr_Dec_Side == (-1.0 * SIGN(Dec_History)))) &&
            Allow_Dec_Move && (Dec_guide == DEC_AUTO)) { // think about switching
            
//            wxString HistString = _T("Thinking of switching - Hist: ");
//            for (int i=0; i<10; i++)
//                HistString += wxString::Format(_T("%.2f "),Dec_dist_list.Item(i));
//            HistString += wxString::Format(_T("(%.2f)\n"),Dec_History);
//            Debug << HistString;
            
            if (fabs(Dec_History) < 3.0) { // not worth of switch
                Allow_Dec_Move = false;
                NSLog(@"..Not compelling enough");
            }
            else { // Think some more
                if (fabs(Dec_dist_list[0] + Dec_dist_list[1] + Dec_dist_list[2]) <
                    fabs(Dec_dist_list[9] + Dec_dist_list[8] + Dec_dist_list[7])) {
                    
                    NSLog(@".. !!!! Getting worse - Switching %f to %f",Curr_Dec_Side,SIGN(Dec_History));
                    
                    Curr_Dec_Side = SIGN(Dec_History);
                    Allow_Dec_Move = true;
                }
                else {
                    Allow_Dec_Move = false;
                    NSLog(@"..Current error less than prior error -- not switching");
                }
            }
        }
        

        if (Allow_Dec_Move && (Dec_guide == DEC_AUTO)) {
            if (Curr_Dec_Side != SIGN(Dec_dist)) {
                Allow_Dec_Move = false;
                NSLog(@".. Dec move VETO .. must have overshot");
            }
        }
        
        if (Allow_Dec_Move) {
            NSLog(@"Dec move %f %f",Dec_dur,Dec_dist);
            if (Dec_dur > (float) Max_Dec_Dur) {
                Dec_dur = (float) Max_Dec_Dur;
                NSLog(@"... Dec move clipped to  %f",Dec_dur);
            }
            if ((Dec_dist > 0.0) && ((Dec_guide == DEC_AUTO) || (Dec_guide == DEC_SOUTH))) {
                
                self.status = [NSString stringWithFormat:@"S dur=%f dist=%f",Dec_dur,Dec_dist];
                
                [self logString:[NSString stringWithFormat:@"%f,%f",Dec_dur,Dec_dist]];
               
                [self pulse:kCASGuiderDirection_DecMinus duration:Dec_dur guideCallback:guideCallback];
            }
            else if ((Dec_dist < 0.0) && ((Dec_guide == DEC_AUTO) || (Dec_guide == DEC_NORTH))){
                
                self.status = [NSString stringWithFormat:@"N dur=%f dist=%f",Dec_dur,Dec_dist];
                
                [self logString:[NSString stringWithFormat:@"%f,%f",Dec_dur,Dec_dist]];
                
                [self pulse:kCASGuiderDirection_DecPlus duration:Dec_dur guideCallback:guideCallback];
            }
            else { // will hit this if in north or south only mode and the direction is the opposite
                
                [self logString:[NSString stringWithFormat:@",0.0,%.2f",Dec_dist]];

                NSLog(@"In N or S only mode and dir is opposite");

            }
        }
        else { // not enough motion
            
            [self logString:[NSString stringWithFormat:@",0.0,%.2f",Dec_dist]];

            NSLog(@"not enough motion");

        }
        NSLog(@"Done");
    }

    last_guide  = RA_dist;
    frame_index++;
}

- (void)updateWithExposure:(CASCCDExposure*)exposure guideCallback:(void(^)(NSError*,CASGuiderDirection,NSInteger))guideCallback {
    
    switch (guidingMode) {
            
        case kGuidingModeNeedsCalibrating:
            [self startCalibration:exposure guideCallback:guideCallback];
            break;
            
        case kGuidingModeCalibrating:
            [self updateCalibration:exposure guideCallback:guideCallback];
            break;
            
        case kGuidingModeGuiding:
            [self updateGuiding:exposure guideCallback:guideCallback];
            break;
            
        default:
            break;
    }
}

@end
