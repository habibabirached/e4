//
//  PostProcess.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23
//  Copyright (c) General Electric Co.
//
//

#import "PostProcess.h"
#include "math.h"
#include <Accelerate/Accelerate.h>

// Take out the printf lines in release mode
#ifndef DEBUG
#define DBGcout if(0)printf
#else
#define DBGcout printf
#endif

// Some defines for the signal processing
#define KERNEL_SIZE 13
#define KERNEL_SIGMA 2.8
#define FILTER_EDGE_SIZE_START 1
#define FILTER_EDGE_SIZE_STOP 1
#define BIN_MULTIPLIER 4 // This multiplier will change the size & resolution of the histogram.

@implementation PostProcess {
    NSMutableArray* kernel;
    NSNumber* outOfRangeNumber;
}

@synthesize filterByDisplacementAndIntensity = _filterByDisplacementAndIntensity;
@synthesize outOfRange = _outOfRange;
@synthesize useMinimumClearance = _useMinimumClearance;

-(instancetype)init {
    if (self = [super init]) {
        [self computeKernel:KERNEL_SIGMA kernel_size:KERNEL_SIZE];
        [self resetOptions];
    }
    return self;
}

- (void)resetOptions {
    self.filterByDisplacementAndIntensity = YES;
    self.useMinimumClearance = NO;
    [self setOutOfRange:15];
}

-(void)setOutOfRange:(float)value {
    self->_outOfRange = value;
    self->outOfRangeNumber = [NSNumber numberWithFloat:self.outOfRange];
}

- (ClearanceData*)computeClearance:(MeasurementData*)measurementData bladeCount:(int)bladeCount {
    return [self computeClearance:measurementData bladeCount:bladeCount usingAdjustmentFactor:0.0];
}

- (ClearanceData*)computeClearance:(MeasurementData*)measurementData bladeCount:(int)bladeCount usingAdjustmentFactor:(float)offsetAdjustment {
    
    ClearanceData* clearanceData = [ClearanceData new];
    
    // Displacement values will be between 0-15.
    // We create a coarse histogram to see how many peaks we find.
    // Should give 61 bins for BIN_MULTIPLIER = 4.0.
    int nbins = self.outOfRange * BIN_MULTIPLIER + 1;
    int* hBins = [self createHistogramForSegmentation:measurementData.displacements numberOfBins:nbins valueMultiplier:BIN_MULTIPLIER];
    
    // Use Otsu's method to get threshold
    clearanceData.shelfThreshold = [self otsuSegmentation:hBins nbins:nbins maxBin:self.outOfRange];
    free(hBins);
    
    // Perform edge detection with an LoG filter
    // (Kernel computation was handled during initialization.)
    //NSLog(@"Filtering");
    NSArray* filtered = [self fir_filter:self->kernel displacements:measurementData.displacements threshold:clearanceData.shelfThreshold];
    //NSLog(@"Filtering Done.");
    
    // Fill these buffers with indications for positive or
    // negative zero crossings.  These are the blade boundaries.
    // Blades tip go from a negative zc to a positiv zc.
    bool* pos_crossing = (bool*)malloc(filtered.count * sizeof(bool));
    bool* neg_crossing = (bool*)malloc(filtered.count * sizeof(bool));
    [self createBladeBoundaries:filtered pos_crossing:pos_crossing neg_crossing:neg_crossing];
    filtered = nil;
    
    // Traverse the data averaging the displacements between the neg.
    // and pos. zero-crossings IFF the intensity is greater than zero.
    // These averages are the per-blade clearances
    int overall_count = 0;

    int blades_count = 0;
    int blades_samples = 0;

    for (int i=0; i<measurementData.displacements.count; i++) {
        float rawDisplacement = [measurementData.displacements[i] floatValue];
        if (rawDisplacement < self.outOfRange) {
            clearanceData.averageDisplacement += rawDisplacement;
            overall_count++;
        }
        if (neg_crossing[i]) {
            // We've encountered a negative zero-crossing
            // so sum displacements to the next positive zero-crossing.
            int start = i;
            int stop = start;
            // This next loop determines the corresponding stopping point
            // point for this blade, if any.
            for (; stop < measurementData.displacements.count; stop++) {
                if (pos_crossing[stop]) {
                    //NSLog(@"Start: %d; Stop: %d", start, stop);
                    break;
                }
                else if (stop == measurementData.displacements.count -1) {
                    //NSLog(@"No stop found for start: %d", start);
                    // end of the data is encountered without a matching
                    // positive zero crossing.
                    for (int j=start; j<measurementData.displacements.count; j++) {
                        [clearanceData.filtered addObject:outOfRangeNumber];
                    }
                    stop = start;
                    break;
                }
            }
            //NSLog(@"Blade: %d - %d", start, stop);
            float clearance = 0;
            float min_clearance = self.outOfRange;
            float min_loc = 0;
            int count = 0;
            
            if (stop > start) {
                // FILTER_EDGE_SIZE_* allows us to shave down the number of points used
                for (int j=start + FILTER_EDGE_SIZE_START; j<=stop - FILTER_EDGE_SIZE_STOP; j++) {
                    rawDisplacement = [measurementData.displacements[j] floatValue];
                    BOOL intesityAboveThreshold = YES;
                    if (self.filterByDisplacementAndIntensity)
                        intesityAboveThreshold = [measurementData.intensities[j] floatValue] > 0;
                    
                    if ( intesityAboveThreshold && (rawDisplacement < clearanceData.shelfThreshold) ) {
                        //NSLog(@"Averaging: %f",[d floatValue]);
                        if (rawDisplacement < min_clearance) {
                            min_clearance = rawDisplacement;
                            min_loc = j;
                        }
                        clearance += rawDisplacement;
                        count++;
                    }
                }
                //NSLog(@"Sum: %f; count: %d", clearance, count);
                // Protect against divide-by-zero...
                if (count == 0) {
                    clearance = -9.996;
                } else {
                    clearance /= count; // Average clearance for this blade.
                    blades_count += 1;
                    blades_samples += count;
                }
                if (isnan(clearance)) {
                    clearance = -9.995;  // nan has happened before.
                }
                if (count > 1) {
                    if (self.useMinimumClearance)
                        [clearanceData.bladeClearances addObject:[NSNumber numberWithFloat:min_clearance]];
                    else {
                        [clearanceData.bladeClearances addObject:[NSNumber numberWithFloat:clearance]];
                    
                        float quality = [self computeQualityScore:0.0254 clearance:clearance minClearance:min_clearance numPoints:(float)count measurementData:measurementData start:start stop:stop];
                        [clearanceData.quality addObject:[NSNumber numberWithFloat:quality]];
                        min_loc = (start + stop) / 2.0;
                    }
                    [clearanceData.locations addObject:[NSNumber numberWithFloat:min_loc]];
                }
                //NSLog(@"Clearance: %f; Quality: %@", clearance, [clearanceData.quality lastObject]);
                for (int j=start; j<=stop; j++) {
                    if (count > 1 && [measurementData.displacements[j] floatValue] < self.outOfRange) {
                        [clearanceData.filtered addObject:[NSNumber numberWithFloat:clearance]];
                    } else {
                        [clearanceData.filtered addObject:outOfRangeNumber];
                    }
                }
            }
            i = stop; // Move the start point ahead to where we stopped.
        } else {
            [clearanceData.filtered addObject:outOfRangeNumber];
        }
    }
    free(neg_crossing);
    free(pos_crossing);
    
    // Finish computing the overall average.
    clearanceData.averageDisplacement /= (float)overall_count;
    [clearanceData applyAdjustment:offsetAdjustment threshold:self.outOfRange];
    [clearanceData calculateStatisticsWithBladeCount:bladeCount];

    clearanceData.blades = blades_count;
    if (blades_count == 0) {
        clearanceData.averageBladeSamples = 0;
    } else {
        clearanceData.averageBladeSamples = (float)blades_samples / (float)blades_count;
    }
        
    NSLog(@"computeClearance Done.");
    return clearanceData;
}
    
-(int*)createHistogramForSegmentation:(NSArray*)displacements numberOfBins:(int)nbins valueMultiplier:(float)multiplier {
    
    int* hBins = (int*)malloc(nbins * sizeof(int));
    for (int i=0; i<nbins; i++) hBins[i] = 0;
    // Populate the histogram by converting displacements to histogram indices.
    // Round each displacement to get the bin index.
    //NSLog(@"Populating histogram...");
    float d=0.0;
    int bIdx = 0;
    for (NSNumber* n in displacements) {
        // exclude OUT_OF_RANGE points.
        if ([n floatValue] >= self.outOfRange) {
            continue;
        }
        d = multiplier * [n floatValue];  // multiply the value to get the index.
        bIdx = (int)floor(d); // Using floor makes bin edges integers. E.g. [0-1][+1-2][+2-3]...
        if (bIdx > nbins-1) {
            bIdx = nbins - 1; // Don't overflow
        }
        if (bIdx < 0) {
            bIdx = 0; // Don't underflow
        }
        hBins[bIdx]++; // Increment the histogram bin
    }
    //NSLog(@"Histogram:\n");
    //for (int i=0; i<nbins; i++) {
    //    NSLog(@" hBin[%d]: %d",i, hBins[i]);
    //}
    return hBins;
}

// otsuSegmentation performs a segmentation of the histogram into 2 classes
// using the Otsu method from image segmentation.
// See: https://en.wikipedia.org/wiki/Otsu%27s_method
// If the 2 classes are seen as too close to one another, then there is
// likely only a single class.
-(float)otsuSegmentation:(int*)hist nbins:(int)nbins maxBin:(float)maxBin {
    float sigmaSquared;
    float maxSigma = -1.0;
    int threshold_idx = 0;
    float binSize = maxBin / (float)nbins;
    // Glen Brooksby found iterating in opposite directions gives different answers.
    // Since the threshold seems to live on the edge of one of the classes,
    // I'll iterate both directions and take the average of the two thresholds.
    for (int k=nbins-1; k >= 0; k--) {
        sigmaSquared = [self calculateTwoClassDifference:hist segmentationIndex:k numberOfBins:nbins binSize:binSize];
        
        if (sigmaSquared > maxSigma) {
            maxSigma = sigmaSquared;
            threshold_idx = k;
        }
    }
    float threshold1 = (float)(threshold_idx+1) * binSize;
    
    maxSigma = -1.0;
    threshold_idx = 0;
    // Iterate the other direction.
    for (int k=0; k < nbins; k++) {
        sigmaSquared = [self calculateTwoClassDifference:hist segmentationIndex:k numberOfBins:nbins binSize:binSize];
        
        if (sigmaSquared > maxSigma) {
            maxSigma = sigmaSquared;
            threshold_idx = k;
        }
    }
    float threshold2 = ((float)(threshold_idx+1) * binSize);

    //TODO figure out how to do this if threshold idxs are different
    // Calculate the two cluster means based on the calculated threshold.
    float w0 = 0.0; float w1 = 0.0;
    float u0 = 0.0; float u1 = 0.0;
    for (int i=0; i<nbins; i++) {
        float p = ((float)(i+1) * binSize);
        if (i <= threshold_idx) {
            w0 += hist[i];
            u0 += hist[i] * p;
        } else {
            w1 += hist[i];
            u1 += hist[i] * p;
        }
    }
    // We need divide-by-zero protection.  If one of the w values is zero
    // this is probably a unimodal distribution.
    u0 = (w0 == 0) ? u1 : u0/w0;
    u1 = (w1 == 0) ? u0 : u1/w1;
    
    // Check to see if the two cluster means are too close to each other.
    // We use the criteria of 1mm separation as "too close".
    if (fabsf(u1-u0) < 1.0 ) {
        // These means are too close.  This is probably a unimodal distribution.
        // I.e. NOT squealer tips.  The threshold becomes the average of the
        // distance between the OUT_OF_RANGE value and the average of the two
        // "otsu" means.
        threshold1 = ((float)self.outOfRange + ((u0+u1)/2.0)) / 2.0;
    }
    else {
        // The means are adequately separated here so we probably have two classes.
        // However the Otsu threshold seems to live on the edge of one of the two classes
        // (depending on which way we traversed the historgram).  So the final threshold
        // is taken as the average of thresholds calculated going each direction.
        threshold1 = (threshold1+threshold2) / 2.0;
    }
    
    //NSLog(@"Shelf Threshold: %f", threshold1);
    return threshold1;
}
    
-(float)calculateTwoClassDifference:(int*)hist segmentationIndex:(int)k numberOfBins:(int)nbins binSize:(float)binSize {
    // lower & upper bounds for classes
    float w0 = 0.0; float w1 = 0.0;
    float u0 = 0.0; float u1 = 0.0;
    for (int i=0; i < k; i++) {
        w0 += hist[i];
        u0 += hist[i] * ((float)(i+1) * binSize);
    }
    if (w0 > 0) u0 /= w0;
    // class 2 goes from k to nbins-1
    for (int i=k; i < nbins; i++) {
        w1 += hist[i];
        u1 += hist[i] * ((float)(i+1) * binSize);
    }
    if (w1 > 0) u1 /= w1;
    return w0*w1*pow(u0-u1,2);
}
    
-(void)createBladeBoundaries:(NSArray*)filtered pos_crossing:(bool*)pos_crossing neg_crossing:(bool*)neg_crossing {
    int i = 0;
    bool signalIsPositive, previousSignalIsPositive;
    for (NSNumber* number in filtered) {
        signalIsPositive = [number floatValue] >= 0;
        
        if (i==0) {
            // Skip first value
            pos_crossing[i] = false;
            neg_crossing[i++] = false;
        } else {
            pos_crossing[i] = signalIsPositive && !previousSignalIsPositive;
            neg_crossing[i++] = !signalIsPositive && previousSignalIsPositive;
        }
        
        previousSignalIsPositive = signalIsPositive;
    }
}
    
-(float)computeQualityScore:(double)threshold clearance:(float)clearance minClearance:(float)minClearance numPoints:(float)numPoints measurementData:(MeasurementData*)measurementData start:(int)start stop:(int)stop {
    
    // Check if minimum clearance is >0.001" (0.0254mm) from average clearance.  If so we consider it an outlier.
    // Quality is the fraction of points whose values are <= 0.001" from the mean.
    float quality = numPoints;
    if (fabs(clearance - minClearance) > threshold) {
        for (int j=start + FILTER_EDGE_SIZE_START; j<=stop - FILTER_EDGE_SIZE_STOP; j++) {
            if ((fabs(clearance - [measurementData.displacements[j] floatValue]) > threshold) && ([measurementData.intensities[j] floatValue] > 0)) {
                quality -= 1.0;
            }
        }
    }
    return quality / numPoints;
}

// computeKernel computes a normalized Laplacian-of-Gaussian kernel for
// edge detection.
- (void)computeKernel:(float)sigma kernel_size:(int)kernel_size {
    if (!self->kernel) self->kernel = [NSMutableArray new];
    [self->kernel removeAllObjects];
    double f1 = -(1.0 / (M_PI * pow(sigma, 4)));
    double twiceSigmaSquared = 2.0*pow(sigma,2);
    double hi = floor(kernel_size/2.0);
    double k_sum = 0;
    for (int x=-hi; x<0; x++) {
        double x2over2s2 = pow(x,2) / twiceSigmaSquared;
        double f2 = 1.0 - x2over2s2;
        double f3 = exp(-x2over2s2);
        double k = f1 * f2 * f3;
        k_sum += k;
        [self->kernel addObject:[NSNumber numberWithDouble:k]];
    }
    k_sum *= 2;
    if (kernel_size % 2 != 0) {
        k_sum += f1;
        [self->kernel addObject:[NSNumber numberWithFloat:(float)f1 / k_sum]];
    }
    // Now normalize the kernel
    for (int idx = hi-1; idx >= 0 ; idx--) {
        NSNumber* normalizedValue = [NSNumber numberWithFloat:(float)[kernel[idx] doubleValue] / k_sum];
        [self->kernel replaceObjectAtIndex:idx withObject:normalizedValue];
        [self->kernel addObject:normalizedValue];
    }
}

//
// fir_filter is taken (almost) lock, stock and barrel from:
// http://hamiltonkibbe.com/finite-impulse-response-filters-using-apples-accelerate-framework-part-ii/
//
- (NSArray*)fir_filter:(NSArray*)kernel displacements:(NSArray*)displacements threshold:(float)threshold {

    // Get the kernal into a float array
    int h_length = (int)kernel.count;
    float* h = (float*)malloc(h_length * sizeof(float));
    int idx = 0;
    for (NSNumber* f in kernel) {
        h[idx++] = [f floatValue];
    }
    
    // Get the data into a float array, thresholding as we go.
    unsigned x_length = (unsigned)displacements.count;
    float* x = (float*)malloc(x_length * sizeof(float));
    idx = 0;
    for (NSNumber* f in displacements) {
        x[idx++] = fmin([f floatValue], threshold);
    }
    
    // Create buffer to store overflow across calls
    //static float overflow[KERNEL_SIZE - 1] = {0.0};
    
    // The length of the result from linear convolution is one less than the
    // sum of the lengths of the two inputs.
    unsigned result_length = x_length + h_length - 1;
    //unsigned overlap_length = result_length - x_length;
    
    // Create a temporary buffer to store the entire convolution result
    float* temp_buffer = (float*)malloc(result_length * sizeof(float));
    
    // Pointer to end of filter for use with vDSP_conv
    float    *h_end = h + (h_length - 1);
    
    // Length of signal passed to vDSP_conv
    unsigned signal_length = (h_length + result_length);
    
    // Create an array to store the signal passed to vDSP_conv, padded with zeros
    float* padded = (float*)malloc(signal_length * sizeof(float));
    
    // fill padded buffer with zeros
    float zero = 0.0;
    vDSP_vfill(&zero, padded, 1, signal_length);
    
    // Copy input into padded buffer
    cblas_scopy(x_length, x, 1, padded, 1);
    
    // use the Accelerate convolution function
    vDSP_conv(padded, 1, h_end, -1, temp_buffer, 1, result_length, h_length);
    
    //
    // In the GE Case we don't need to worry about adding results from
    // previous runs.  However, I'm leaving this code here in case I
    // ever want to refer to it for re-use.
    //
    // Add the overlap from the previous run
    // use vDSP_vadd instead of loop
    // vDSP_vadd(temp_buffer, overflow, buffer, overlap_length);
    //
    // Copy overlap into overlap buffer
    // use BLAS copy instead of loop
    // cblas_scopy(overlap_length, temp_buffer + x_length, 1, overflow, 1);
    //
    
    //
    // In the GE Case we want everything in a different array, so we just
    // put it there rather than doing the cblas copy to the output and
    // then having to copy it all again.  This saves time and memory.
    //s
    // write the final result to the output. use BLAS copy instead of loop
    // cblas_scopy(x_length, temp_buffer, 1, output, 1);
    
    // Filtered data here is offset by 1/2 of the kernel
    // length, so we offset the data when we write it back out.
    int offset = (int)round((float)kernel.count / 2.0);
    NSNumber* zeroNumber = [NSNumber numberWithFloat:0];
    NSMutableArray* filtered = [NSMutableArray new];
    for (int i=0; i<offset; i++)
        [filtered addObject:zeroNumber]; // offset
    for (int i=0; i<x_length; i++) {
        float tmpf = temp_buffer[i] - threshold;
        tmpf = roundf(tmpf * 1e5)/1e5;  // round to 5 decimal places
        tmpf = (tmpf == 0.0) ? 0.0 : tmpf; // This avoids problems that have happened where -0 is generated, causing a sign change.
        [filtered addObject:[NSNumber numberWithFloat:tmpf]];
    }
    
    free(padded);
    free(temp_buffer);
    free(x);
    free(h);
    
    return filtered;
}

@end
