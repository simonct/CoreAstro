//
//  CASHalfFluxDiameter.m
//  CoreAstro
//
//  Copyright (c) 2012, Wagner Truppel
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


// Uses the Half-Flux Diameter as a focus metric.

#import "CASHalfFluxDiameter.h"


NSString* const keyRadiusTolerance = @"radius tolerance";
NSString* const keyBrightnessTolerance = @"brightness tolerance";


// A vector from point A to point B, represented as a point from the origin.
NS_INLINE CGPoint vecfromAtoB(CGPoint pA, CGPoint pB)
{
    return CGPointMake(pB.x - pA.x, pB.y - pA.y);
}


// Dot product of two vectors represented as points from the origin.
NS_INLINE double dotProd(CGPoint pA, CGPoint pB)
{
    return pA.x * pB.x + pA.y * pB.y;
}


// The square of the length of the segment connecting points pA and pB.
NS_INLINE double segmSquaredLength(CGPoint pA, CGPoint pB)
{
    double dx = pA.x - pB.x;
    double dy = pA.y - pB.y;

    return dx * dx + dy * dy;
}


// The square of the length of a vector represented as a point P from the origin.
NS_INLINE double vecSquaredLength(CGPoint p)
{
    return p.x * p.x + p.y * p.y;
}


// Assumes that p is relative to the center of the circle of radius r.
NS_INLINE BOOL pointOutsideOrOnCircle(CGPoint p, double r)
{
    return vecSquaredLength(p) >= (r * r);
}


@interface CASHalfFluxDiameter ()

@property (readwrite, nonatomic) CGPoint brightnessCentroid;

@property (nonatomic) double pixelArea;         // Area of a pixel.
@property (nonatomic) double pixelTriangleArea; // Area of a pixel triangle.

@end


@implementation CASHalfFluxDiameter

// WTH is wrong with XCode that it's requiring this property to be synthesized,
// but not any others???
@synthesize brightnessCentroid = _brightnessCentroid;


- (NSDictionary*) resultsFromData: (NSDictionary*) dataD;
{
    id objInDataD = nil;
    NSMutableDictionary* mutDataD = [dataD mutableCopy];

    // === keyPixelW === //

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyPixelW
                       inDictionary: dataD
                   withDefaultValue: nil];
    if (!objInDataD) return nil;

    double pixelW = [(NSNumber*) objInDataD doubleValue];

    // === keyPixelH === //

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyPixelH
                       inDictionary: dataD
                   withDefaultValue: nil];
    if (!objInDataD) return nil;

    double pixelH = [(NSNumber*) objInDataD doubleValue];

    // === keyRadiusTolerance === //

    double rtol = DEFAULT_RADIUS_TOLERANCE_FACTOR * MIN(pixelW, pixelH);

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyRadiusTolerance
                       inDictionary: dataD
                   withDefaultValue: [NSNumber numberWithDouble: rtol]];
    if (!objInDataD) return nil;

    self.radiusTolerance = [(NSNumber*) objInDataD doubleValue];
    [mutDataD setObject: objInDataD forKey: keyRadiusTolerance];

    // === keyBrightnessTolerance === //

    double btol = DEFAULT_BRIGHTNESS_TOLERANCE;

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyBrightnessTolerance
                       inDictionary: dataD
                   withDefaultValue: [NSNumber numberWithDouble: btol]];
    if (!objInDataD) return nil;

    self.brightnessTolerance = [(NSNumber*) objInDataD doubleValue];
    [mutDataD setObject: objInDataD forKey: keyBrightnessTolerance];

    // ============================== //

    dataD = [NSDictionary dictionaryWithDictionary: mutDataD];
    return [super resultsFromData: dataD];
}


// Assumes the points are relative to the center of the circle of radius r.
- (BOOL) segmentFromPoint: (CGPoint) ptA
                  toPoint: (CGPoint) ptB
 intersectsCircleOfRadius: (double) r
                  atPoint: (CGPoint*) ptP
                 andPoint: (CGPoint*) ptQ;
{
    // Coefficients of the quadratic equation as^2 + bs + c = 0.

    // OA = vector from origin to A = ptA, since we're assuming
    // that the points are already relative to the origin.

    // a = |AB|^2
    double a = segmSquaredLength(ptA, ptB);

    // b / 2 = (OA . AB)
    double bover2 = dotProd(ptA, vecfromAtoB(ptA, ptB));

    // c = |OA|^2 - r^2
    double c = vecSquaredLength(ptA) - r*r;

    // one-quarter of the discriminant
    // Delta/4 = (b/2)^2 - ac
    double dover4 = bover2 * bover2 - a * c;

    if (dover4 < 0.0)
    {
        // No real solutions, ie, no intersections.
        return NO;
    }
    else if (dover4 > 0.0)
    {
        // Two distinct real solutions.
        double s1 = 0.0;
        double s2 = 0.0;

        // Compute the solutions the numerically-stable way.

        if (bover2 > 0)
        {
            double z = - (bover2 + sqrt(dover4));

            s1 = z / a;
            s2 = c / z;
        }
        else if (bover2 < 0)
        {
            double z = - (bover2 - sqrt(dover4));

            s1 = z / a;
            s2 = c / z;
        }
        else // bover2 == 0
        {
            s1 = - sqrt(dover4);
            s2 = - s1;
        }

        // Sort the roots so that s1 <= s2.
        if (s1 > s2)
        {
            double t = s2;
            s2 = s1;
            s1 = t;
        }

        // Only solutions in the closed interval [0, 1] correspond
        // to segment intersections. Any other solutions are considered
        // invalid.
        BOOL foundValidSolutions = NO;

        if (s1 >= 0.0 && s1 <= 1.0)
        {
            foundValidSolutions = YES;
            assert(ptP);

            (*ptP).x = ptA.x + s1 * (ptB.x - ptA.x);
            (*ptP).y = ptA.y + s1 * (ptB.y - ptA.y);
        }

        if (s2 >= 0.0 && s2 <= 1.0)
        {
            // If found only one valid solution, assign it to ptP.

            if (!foundValidSolutions)
            {
                foundValidSolutions = YES;
                assert(ptP);

                (*ptP).x = ptA.x + s1 * (ptB.x - ptA.x);
                (*ptP).y = ptA.y + s1 * (ptB.y - ptA.y);
            }
            else
            {
                assert(ptQ);

                (*ptQ).x = ptA.x + s2 * (ptB.x - ptA.x);
                (*ptQ).y = ptA.y + s2 * (ptB.y - ptA.y);
            }
        }

        return foundValidSolutions;
    }
    else // dover4 == 0.0
    {
        // Only one solution.
        double s1 = - bover2 / a;

        // Only solutions in the closed interval [0, 1] correspond
        // to segment intersections. Any other solutions are considered
        // invalid.
        BOOL foundValidSolution = (s1 >= 0.0 && s1 <= 1.0);

        if (foundValidSolution)
        {
            CGPoint ptS = CGPointMake(0.0, 0.0);
            ptS.x = ptA.x + s1 * (ptB.x - ptA.x);
            ptS.y = ptA.y + s1 * (ptB.y - ptA.y);

            if(ptP)
            {
                (*ptP).x = ptS.x;
                (*ptP).y = ptS.y;
            }

            if(ptQ)
            {
                (*ptQ).x = ptS.x;
                (*ptQ).y = ptS.y;
            }
        }

        return foundValidSolution;
    }
}


// Assumes the points are relative to the center of the circle of radius r.
- (double) areaOfCircularSectorOfRadius: (double) r
                              fromPoint: (CGPoint) ptP
                                toPoint: (CGPoint) ptQ;
{
    double rsq = r * r;
    return 0.5 * rsq * acos(dotProd(ptP, ptQ) / rsq);
}


// Assumes the points are relative to the center of the circle of radius r.
// Uses a numerically-stable version of Heron's formula.
- (double) areaOfTriangularSectorOfRadius: (double) r
                                fromPoint: (CGPoint) ptP
                                  toPoint: (CGPoint) ptQ;
{
    double lenPQ = sqrt(segmSquaredLength(ptP, ptQ));

    if (r > lenPQ)
    {
        return (lenPQ / 4.0) * sqrt((r + (r + lenPQ)) * (r + (r - lenPQ)));
    }
    else
    {
        double d = 2.0 * r;
        return (lenPQ / 4.0) * sqrt((d + lenPQ) * (d - lenPQ));
    }
}


// Assumes the points are relative to the center of the circle of radius r.
- (double) intersectionAreaOfTriangleWithCircleOfRadius: (double) r
                                          intersectionP: (CGPoint) ptP
                                          intersectionQ: (CGPoint) ptQ
                                                  hasMN: (BOOL) hasMN
                                          intersectionM: (CGPoint) ptM
                                          intersectionN: (CGPoint) ptN
                                                 hasZin: (BOOL) hasZin
                                                  ptZin: (CGPoint) ptZin;
{
    // Area of circular sector POQ.
    double aSectorPOQ = [self areaOfCircularSectorOfRadius: r
                                                 fromPoint: ptP
                                                   toPoint: ptQ];

    // Area of isosceles triangle POQ.
    double aTrianglePOQ = [self areaOfTriangularSectorOfRadius: r
                                                     fromPoint: ptP
                                                       toPoint: ptQ];
    
    // Area of triangle PZQ.
    double aTrianglePZQ = 0.0;
    if (hasZin)
    {
        aTrianglePZQ = 0.5 * fabs(ptP.x - ptZin.x) * fabs(ptQ.y - ptZin.y);
    }

    double aSectorMON = 0.0;
    double aTriangleMON = 0.0;
    if (hasMN)
    {
        // Area of circular sector MON.
        aSectorMON = [self areaOfCircularSectorOfRadius: r
                                                     fromPoint: ptM
                                                       toPoint: ptN];

        // Area of isosceles triangle MON.
        aTriangleMON = [self areaOfTriangularSectorOfRadius: r
                                                         fromPoint: ptM
                                                           toPoint: ptN];
    }

    return aSectorPOQ + (aTrianglePZQ + (aTriangleMON - (aTrianglePOQ + aSectorMON)));
}


// Assumes the points are relative to the center of the circle of radius r.
- (double) intersectionAreaOfTriangleOfVertexA: (CGPoint) ptA
                                       vertexB: (CGPoint) ptB
                                       vertexC: (CGPoint) ptC
                            withCircleOfRadius: (double) r
                                 intersectionP: (CGPoint) ptP
                                 intersectionQ: (CGPoint) ptQ
                                        ptZout: (CGPoint) ptZout;
{
    // Area of triangle ABC.
    double aTriangleABC = self.pixelTriangleArea;

    // Area of triangle PZQ.
    double aTrianglePZQ = 0.5 * fabs(ptP.x - ptZout.x) * fabs(ptQ.y - ptZout.y);

    // Area of circular sector POQ.
    double aSectorPOQ = [self areaOfCircularSectorOfRadius: r
                                                 fromPoint: ptP
                                                   toPoint: ptQ];

    // Area of isosceles triangle POQ.
    double aTrianglePOQ = [self areaOfTriangularSectorOfRadius: r
                                                     fromPoint: ptP
                                                       toPoint: ptQ];

    return (aTriangleABC + (aSectorPOQ - (aTrianglePOQ + aTrianglePZQ)));
}


// Assumes the points are relative to the center of the circle of radius r.
- (double) intersectionAreaOfTriangleVertexA: (CGPoint) ptA
                                     vertexB: (CGPoint) ptB
                                     vertexC: (CGPoint) ptC
                          withCircleOfRadius: (double) r;
{
    CGPoint ptP = CGPointZero;
    CGPoint ptQ = CGPointZero;

    CGPoint ptM = CGPointZero;
    CGPoint ptN = CGPointZero;

    BOOL validSols = NO;

    if (pointOutsideOrOnCircle(ptA, r))
    {
        if (pointOutsideOrOnCircle(ptB, r))
        {
            if (pointOutsideOrOnCircle(ptC, r))
            {
                // All points outside or on the boundary.

                // Try segment AB
                validSols = [self segmentFromPoint: ptA
                                           toPoint: ptB
                          intersectsCircleOfRadius: r
                                           atPoint: &ptP
                                          andPoint: &ptQ];

                if (!validSols)
                {
                    // Try segment AC
                    validSols = [self segmentFromPoint: ptA
                                               toPoint: ptC
                              intersectsCircleOfRadius: r
                                               atPoint: &ptP
                                              andPoint: &ptQ];
                }

                if (!validSols)
                {
                    // Try segment BC
                    validSols = [self segmentFromPoint: ptB
                                               toPoint: ptC
                              intersectsCircleOfRadius: r
                                               atPoint: &ptP
                                              andPoint: &ptQ];
                }

                if (validSols)
                {
                    return [self intersectionAreaOfTriangleWithCircleOfRadius: r
                                                                intersectionP: ptP
                                                                intersectionQ: ptQ
                                                                        hasMN: NO
                                                                intersectionM: ptM
                                                                intersectionN: ptN
                                                                       hasZin: NO
                                                                        ptZin: CGPointZero];
                }
                else
                {
                    // Triangle has no intersection with the circle.
                    return 0.0;
                }
            }
            else // C strictly inside
            {
                // C is strictly inside, A and B outside or on boundary

                // Try segment CA - we should get a single valid intersection, point P
                validSols = [self segmentFromPoint: ptC
                                           toPoint: ptA
                          intersectsCircleOfRadius: r
                                           atPoint: &ptP
                                          andPoint: NULL];
                assert(validSols);

                // Try segment CB - we should get a single valid intersection, point Q
                validSols = [self segmentFromPoint: ptC
                                           toPoint: ptB
                          intersectsCircleOfRadius: r
                                           atPoint: &ptQ
                                          andPoint: NULL];
                assert(validSols);

                // Try segment AB - if we get any intersections, those are points M and N
                validSols = [self segmentFromPoint: ptA
                                           toPoint: ptB
                          intersectsCircleOfRadius: r
                                           atPoint: &ptM
                                          andPoint: &ptN];

                return [self intersectionAreaOfTriangleWithCircleOfRadius: r
                                                            intersectionP: ptP
                                                            intersectionQ: ptQ
                                                                    hasMN: validSols
                                                            intersectionM: ptM
                                                            intersectionN: ptN
                                                                   hasZin: YES
                                                                    ptZin: ptC];
            }
        }
        else // B strictly inside
        {
            if (pointOutsideOrOnCircle(ptC, r))
            {
                // B is strictly inside, A and C outside or on boundary

                // Try segment BA - we should get a single valid intersection, point P
                validSols = [self segmentFromPoint: ptB
                                           toPoint: ptA
                          intersectsCircleOfRadius: r
                                           atPoint: &ptP
                                          andPoint: NULL];
                assert(validSols);

                // Try segment BC - we should get a single valid intersection, point Q
                validSols = [self segmentFromPoint: ptB
                                           toPoint: ptC
                          intersectsCircleOfRadius: r
                                           atPoint: &ptQ
                                          andPoint: NULL];
                assert(validSols);

                // Try segment AC - if we get any intersections, those are points M and N
                validSols = [self segmentFromPoint: ptA
                                           toPoint: ptC
                          intersectsCircleOfRadius: r
                                           atPoint: &ptM
                                          andPoint: &ptN];

                return [self intersectionAreaOfTriangleWithCircleOfRadius: r
                                                            intersectionP: ptP
                                                            intersectionQ: ptQ
                                                                    hasMN: validSols
                                                            intersectionM: ptM
                                                            intersectionN: ptN
                                                                   hasZin: YES
                                                                    ptZin: ptB];
            }
            else // C strictly inside
            {
                // B and C strictly inside, A outside or on boundary

                // Try segment BA - we should get a single valid intersection, point P
                validSols = [self segmentFromPoint: ptB
                                           toPoint: ptA
                          intersectsCircleOfRadius: r
                                           atPoint: &ptP
                                          andPoint: NULL];
                assert(validSols);

                // Try segment CA - we should get a single valid intersection, point Q
                validSols = [self segmentFromPoint: ptC
                                           toPoint: ptA
                          intersectsCircleOfRadius: r
                                           atPoint: &ptQ
                                          andPoint: NULL];
                assert(validSols);

                return [self intersectionAreaOfTriangleOfVertexA: ptA
                                                         vertexB: ptB
                                                         vertexC: ptC
                                              withCircleOfRadius: r
                                                   intersectionP: ptP
                                                   intersectionQ: ptQ
                                                          ptZout: ptA];
            }
        }
    }
    else // A strictly inside
    {
        if (pointOutsideOrOnCircle(ptB, r))
        {
            if (pointOutsideOrOnCircle(ptC, r))
            {
                // A is strictly inside, B and C outside or on boundary

                // Try segment AB - we should get a single valid intersection, point P
                validSols = [self segmentFromPoint: ptA
                                           toPoint: ptB
                          intersectsCircleOfRadius: r
                                           atPoint: &ptP
                                          andPoint: NULL];
                assert(validSols);

                // Try segment AC - we should get a single valid intersection, point Q
                validSols = [self segmentFromPoint: ptA
                                           toPoint: ptC
                          intersectsCircleOfRadius: r
                                           atPoint: &ptQ
                                          andPoint: NULL];
                assert(validSols);

                // Try segment BC - if we get any intersections, those are points M and N
                validSols = [self segmentFromPoint: ptB
                                           toPoint: ptC
                          intersectsCircleOfRadius: r
                                           atPoint: &ptM
                                          andPoint: &ptN];

                return [self intersectionAreaOfTriangleWithCircleOfRadius: r
                                                            intersectionP: ptP
                                                            intersectionQ: ptQ
                                                                    hasMN: validSols
                                                            intersectionM: ptM
                                                            intersectionN: ptN
                                                                   hasZin: YES
                                                                    ptZin: ptA];
            }
            else // C strictly inside
            {
                // A and C strictly inside, B outside or on boundary

                // Try segment AB - we should get a single valid intersection, point P
                validSols = [self segmentFromPoint: ptA
                                           toPoint: ptB
                          intersectsCircleOfRadius: r
                                           atPoint: &ptP
                                          andPoint: NULL];
                assert(validSols);

                // Try segment CB - we should get a single valid intersection, point Q
                validSols = [self segmentFromPoint: ptC
                                           toPoint: ptB
                          intersectsCircleOfRadius: r
                                           atPoint: &ptQ
                                          andPoint: NULL];
                assert(validSols);

                return [self intersectionAreaOfTriangleOfVertexA: ptA
                                                         vertexB: ptB
                                                         vertexC: ptC
                                              withCircleOfRadius: r
                                                   intersectionP: ptP
                                                   intersectionQ: ptQ
                                                          ptZout: ptB];
            }
        }
        else // B strictly inside
        {
            if (pointOutsideOrOnCircle(ptC, r))
            {
                // A and B strictly inside, C outside or on boundary

                // Try segment AC - we should get a single valid intersection, point P
                validSols = [self segmentFromPoint: ptA
                                           toPoint: ptC
                          intersectsCircleOfRadius: r
                                           atPoint: &ptP
                                          andPoint: NULL];
                assert(validSols);

                // Try segment BC - we should get a single valid intersection, point Q
                validSols = [self segmentFromPoint: ptB
                                           toPoint: ptC
                          intersectsCircleOfRadius: r
                                           atPoint: &ptQ
                                          andPoint: NULL];
                assert(validSols);

                return [self intersectionAreaOfTriangleOfVertexA: ptA
                                                         vertexB: ptB
                                                         vertexC: ptC
                                              withCircleOfRadius: r
                                                   intersectionP: ptP
                                                   intersectionQ: ptQ
                                                          ptZout: ptC];
            }
            else // C strictly inside
            {
                // All points strictly inside.
                return self.pixelTriangleArea;
            }
        }
    }
}


- (double) focusMetricForExposureArray: (uint16_t*) values
                              ofLength: (NSUInteger) len
                               numRows: (NSUInteger) numRows
                               numCols: (NSUInteger) numCols
                                pixelW: (double) pixelW
                                pixelH: (double) pixelH
                    brightnessCentroid: (CGPoint*) brightnessCentroidPtr;
{
    // === Pre-compute some values. === //

    // Pixel width and height.
    double w = pixelW;
    double h = pixelH;

    // Area of a pixel.
    self.pixelArea = (w * h);

    // Area of a pixel triangle.
    self.pixelTriangleArea = 0.5 * self.pixelArea;

    // === Compute the total brightness and the exposure centroid === //

    double totalBrightness = 0.0;
    CGPoint centroid = CGPointZero;
    cas_alg_exp_centroid(values, len, numRows, numCols, w, h, &totalBrightness, &centroid);
    self.brightnessCentroid = centroid;
    *brightnessCentroidPtr = centroid;

    // === Binary search variables === //

    if (self.radiusTolerance == 0.0)
    {
        self.radiusTolerance = DEFAULT_RADIUS_TOLERANCE_FACTOR * MIN(w, h);
    }

    if (self.brightnessTolerance == 0.0)
    {
        self.brightnessTolerance = DEFAULT_BRIGHTNESS_TOLERANCE;
    }

    // Our brightness goal.
    double bgoal = 0.5 * totalBrightness;

    // Tolerance values.
    double rtol = self.radiusTolerance;
    double btol = self.brightnessTolerance;

    // Current minimum and maximum radii.
    // rmax is the maximum of the exposure width and the exposure height.
    // This guarantees that a circle of radius rmax contains the entire
    // exposure and, therefore, the total brightness.
    double rmin = 0.0;
    double rmax = MAX(numCols * w, numRows * h);

    // Current running value of the radius.
    double rcur = 0.0; // arbitrary initial value

    // === Start binary search === //

    BOOL done = NO;
    while (!done)
    {
        // Current running value of the brightness inside the
        // circle of radius rcur.
        double bcur = 0.0;

        // The binary search step.
        rcur = (rmin + rmax) / 2.0;

        // NSLog(@"rmin = %f", rmin);
        // NSLog(@"rcur = %f", rcur);
        // NSLog(@"rmax = %f\n\n", rmax);

        // For every pixel with a non-zero brightness value...
        for (NSUInteger p = 0; p < len; ++p)
        {
            uint16_t bpixel = values[p];
            if (bpixel == 0) continue;

            // Brightness per unit of area for the current pixel.
            double bpa = (bpixel / self.pixelArea);

            // Pixel indices.

            NSUInteger kx = cas_alg_kx(numRows, numCols, p);
            NSUInteger ky = cas_alg_ky(numRows, numCols, p);

            // Pixel corners, with coords relative to the
            // centroid, not with respect to the image coord system!

            CGPoint cornerBL; // bottom-left corner
            cornerBL.x = kx * w - centroid.x;
            cornerBL.y = ky * h - centroid.y;

            CGPoint cornerTR; // top-right corner
            cornerTR.x = cornerBL.x + w;
            cornerTR.y = cornerBL.y + h;

            CGPoint cornerTL; // top-left corner
            cornerTL.x = cornerBL.x;
            cornerTL.y = cornerTR.y;

            CGPoint cornerBR; // bottom-right corner
            cornerBR.x = cornerTR.x;
            cornerBR.y = cornerBL.y;

            // Triangle vertices, with coords relative to the centroid.

            // Top triangle.

            CGPoint topA = cornerTR;
            CGPoint topB = cornerTL;
            CGPoint topC = cornerBR;

            double area = [self intersectionAreaOfTriangleVertexA: topA
                                                          vertexB: topB
                                                          vertexC: topC
                                               withCircleOfRadius: rcur];
            if (area > 0.0)
            {
                if (bcur > bgoal + btol)
                {
                    break; // already above goal
                }
                else
                {
                    bcur += (area * bpa);
                }
            }

            // Bottom triangle.

            CGPoint botA = cornerBL;
            CGPoint botB = topC;
            CGPoint botC = topB;

            area = [self intersectionAreaOfTriangleVertexA: botA
                                                   vertexB: botB
                                                   vertexC: botC
                                        withCircleOfRadius: rcur];
            if (area > 0.0)
            {
                if (bcur > bgoal + btol)
                {
                    break; // already above goal
                }
                else
                {
                    bcur += (area * bpa);
                }
            }
        }

        // Have we closed in on the goal yet?
        done = (fabs(bcur - bgoal) <= btol);

        if (!done)
        {
            if (bcur > bgoal) // radius too large
            {
                rmax = rcur;
            }
            else if (bcur < bgoal) // radius too small
            {
                rmin = rcur;
            }
            
            // Have we converged to a radius within the tolerance?
            done = (rmax - rmin <= rtol);
        }
    }
    
    return (rmin + rmax); // HFD = 2*rcur = (rmin + rmax)
}


// Computes a faster but less accurate estimate of the HFD,
// using a spiral approach.
- (double) hfdForExposureArray: (uint16_t*) values
                      ofLength: (NSUInteger) len
                       numRows: (NSUInteger) numRows
                       numCols: (NSUInteger) numCols
                        pixelW: (double) pixelW
                        pixelH: (double) pixelH
            brightnessCentroid: (CGPoint*) brightnessCentroidPtr;
{
    // === Pre-compute some values. === //

    // Pixel width and height.
    double w = pixelW;
    double h = pixelH;

    NSUInteger numPixelsMinus1 = numRows * numCols - 1;

    // === Compute the total brightness and the exposure centroid === //

    double totalBrightness = 0.0;
    CGPoint centroid = CGPointZero;
    cas_alg_exp_centroid(values, len, numRows, numCols, w, h, &totalBrightness, &centroid);
    self.brightnessCentroid = centroid;
    *brightnessCentroidPtr = centroid;

    // === Run an outward-growing spiral around the pixel that contains  === //
    // === the centroid point, adding up the pixel brightness values as  === //
    // === we go along. Stop when we get above half the total brightness === //
    // === and return twice the distance of the center of that pixel to  === //
    // === the centroid as an estimate of the HFD.                       === //

    // The indices of the pixel that contains the centroid point.
    NSUInteger cx = floor(centroid.x / w);
    NSUInteger cy = floor(centroid.y / h);

    // NSUInteger p = cas_alg_p(numRows, numCols, cx, cy);
    // NSLog(@"centroid pixel = %ld : (%ld, %ld)", p, cx, cy);

    BOOL xturn = YES;
    NSUInteger sign = 1;
    NSUInteger step = 1;

    // Current running value of the brightness.
    double bcur = 0.0;

    BOOL done = NO;
    NSUInteger kx = cx;
    NSUInteger ky = cy;

    while (!done)
    {
        for (NSUInteger s = 0; s < 2*step && !done; ++s)
        {
            NSUInteger p = cas_alg_p(numRows, numCols, kx, ky);
            if (p == numPixelsMinus1)
            {
                done = YES;
                break;
            }

            // NSLog(@"pixel = %ld : (%ld, %ld) : %hd", p, kx, ky, values[p]);

            bcur += values[p];
            done = (bcur > 0.5 * totalBrightness);
            if (done) break;

            if (xturn)
            {
                if (kx == 0 && sign == -1)
                {
                    done = YES;
                    break;
                }

                kx += sign;
            }
            else
            {
                if (ky == 0 && sign == -1)
                {
                    done = YES;
                    break;
                }

                ky += sign;
            }

            if (!done && s == step - 1)
            {
                xturn = !xturn;
            }
        }
        
        if (!done && !xturn)
        {
            sign = -sign;
            xturn = YES;
        }
        
        if (!done && xturn)
        {
            step += 1;
        }
    }

    double x = (kx + 0.5) * w;
    double y = (ky + 0.5) * h;
    CGPoint ptP = CGPointMake(x, y);

    return 2.0 * sqrt(segmSquaredLength(centroid, ptP));
}


@end