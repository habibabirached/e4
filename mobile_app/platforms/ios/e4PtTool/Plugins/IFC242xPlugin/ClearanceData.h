//
//  ClearanceData.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#import "IFC242xManager.h"

@interface ClearanceData : NSObject {
    @protected IFC242xManager* delegate;
}

-(instancetype)initWithDelegate:(IFC242xManager*)delegate;

@property (readonly, strong, nonatomic) NSMutableArray* filtered;
@property (readonly, strong, nonatomic) NSMutableArray* clearances;
@property (readonly, strong, nonatomic) NSMutableArray* bladeClearances;
@property (readonly, strong, nonatomic) NSMutableArray* locations;
@property (readonly, strong, nonatomic) NSMutableArray* quality;
@property (readonly, nonatomic) float clearance;
@property (readonly, nonatomic) float max;
@property (readonly, nonatomic) float min;
@property (readonly, nonatomic) float median;
@property (readonly, nonatomic) float std;
@property (readonly, nonatomic) float offsetAdjustmentFactor;
@property (nonatomic) float averageDisplacement;
@property (nonatomic) float shelfThreshold;
@property (nonatomic) int blades;
@property (nonatomic) float averageBladeSamples;

-(void)applyAdjustment:(float)adjustment threshold:(float)threshold;
-(void)calculateStatistics;
-(void)calculateStatisticsWithBladeCount:(int)bladeCount;
@end
