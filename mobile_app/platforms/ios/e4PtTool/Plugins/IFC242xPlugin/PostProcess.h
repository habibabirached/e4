//
//  PostProcess.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//
#import "ClearanceData.h"
#import "MeasurementData.h"

@interface PostProcess : NSObject
@property (nonatomic) BOOL filterByDisplacementAndIntensity;
@property (nonatomic) float outOfRange;
@property (nonatomic) BOOL useMinimumClearance;
-(ClearanceData*)computeClearance:(MeasurementData*)measurementData bladeCount:(int)bladeCount;
-(ClearanceData*)computeClearance:(MeasurementData*)measurementData bladeCount:(int)bladeCount usingAdjustmentFactor:(float)offsetAdjustment;
@end
