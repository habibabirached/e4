//
//  ClearanceData.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

@interface ClearanceData : NSObject
@property (readonly, strong, nonatomic) NSMutableArray* filtered;
@property (readonly, strong, nonatomic) NSMutableArray* clearances;
@property (readonly, strong, nonatomic) NSMutableArray* bladeClearances;
@property (readonly, strong, nonatomic) NSMutableArray* locations;
@property (readonly, strong, nonatomic) NSMutableArray* quality;
@property (readonly) float clearance;
@property (readonly) float max;
@property (readonly) float min;
@property (readonly) float median;
@property (readonly) float std;
@property float averageDisplacement;
@property float shelfThreshold;

-(void)applyAdjustment:(float)adjustment threshold:(float)threshold;
-(void)calculateStatistics;
-(void)calculateStatisticsWithBladeCount:(int)bladeCount;
@end
