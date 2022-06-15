//
//  PostProcess.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#import "ClearanceData.h"
#import "IFC242xManager.h"
#import "MeasurementData.h"

@interface PostProcess : NSObject {
    @protected IFC242xManager* delegate;
}

-(instancetype)initWithDelegate:(IFC242xManager*)delegate;

@property (nonatomic) BOOL filterByDisplacementAndIntensity;
@property (nonatomic) float outOfRange;
@property (nonatomic) BOOL useMinimumClearance;
@property (nonatomic) int minBladeSamples;
-(ClearanceData*)computeClearance:(MeasurementData*)measurementData bladeCount:(int)bladeCount;
-(ClearanceData*)computeClearance:(MeasurementData*)measurementData bladeCount:(int)bladeCount usingAdjustmentFactor:(float)offsetAdjustment;
@end
