//
//  ClearanceData.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//
#import "ClearanceData.h"

@interface ClearanceData ()
@property (nonatomic) float clearance;
@property (nonatomic) float max;
@property (nonatomic) float min;
@property (nonatomic) float median;
@property (nonatomic) float std;
@property (nonatomic) float offsetAdjustmentFactor;
@end

@implementation ClearanceData

@synthesize filtered = _filtered;
@synthesize clearances = _clearances;
@synthesize bladeClearances = _bladeClearances;
@synthesize locations = _locations;
@synthesize quality = _quality;
@synthesize clearance = _clearance;
@synthesize max = _max;
@synthesize min = _min;
@synthesize median = _median;
@synthesize std = _std;
@synthesize offsetAdjustmentFactor = _offsetAdjustmentFactor;
@synthesize averageDisplacement = _averageDisplacement;
@synthesize shelfThreshold = _shelfThreshold;

-(instancetype)init {
    if (self = [super init]) {
        self.min = FLT_MAX;
    }
    return self;
}

- (NSMutableArray *) filtered
{
    if (!_filtered) {
        _filtered = [NSMutableArray new];
    }
    return _filtered;
}

- (NSMutableArray *) clearances
{
    if (!_clearances) {
        _clearances = [NSMutableArray new];
    }
    return _clearances;
}

- (NSMutableArray *) bladeClearances
{
    if (!_bladeClearances) {
        _bladeClearances = [NSMutableArray new];
    }
    return _bladeClearances;
}

- (NSMutableArray *) locations
{
    if (!_locations) {
        _locations = [NSMutableArray new];
    }
    return _locations;
}

- (NSMutableArray *) quality
{
    if (!_quality) {
        _quality = [NSMutableArray new];
    }
    return _quality;
}

-(void)applyAdjustment:(float)adjustment threshold:(float)threshold {
    if (adjustment != 0.0) {
        for (NSNumber* value in self.filtered) {
            if ([value floatValue] >= threshold) {
                [self.clearances addObject:value];
            } else {
                [self.clearances addObject:[NSNumber numberWithFloat:([value floatValue] + adjustment)]];
            }
        }
        
        NSMutableArray* tempArray = [NSMutableArray new];
        for (NSNumber* value in self.bladeClearances) {
            [tempArray addObject:[NSNumber numberWithFloat:([value floatValue] + adjustment)]];
        }
        [self.bladeClearances setArray:tempArray];
        tempArray = nil;
    } else {
        [self.clearances setArray:self.filtered];
    }
    self.offsetAdjustmentFactor = adjustment;
}

-(void)calculateStatistics {
    [self calculateStatisticsWithBladeCount:0];
}

-(void)calculateStatisticsWithBladeCount:(int)bladeCount {
    if (self.bladeClearances.count > 0 ) {
        NSMutableArray* statsBuff = [NSMutableArray new];
        NSUInteger upperIndex = (bladeCount == 0) ? self.bladeClearances.count : MIN(self.bladeClearances.count, bladeCount);
        int idx = 0;
        for (NSNumber* number in self.bladeClearances) {
            if (idx++ < upperIndex) {
                [self updateStatsWithClearanceValue:number statsBuffer:statsBuff];
            }
        }
        self.clearance /= (float)upperIndex;
        
        if (statsBuff.count > 1) {
            NSArray* sortedBuff = [statsBuff sortedArrayUsingSelector:@selector(compare:)];
            NSUInteger middle = [sortedBuff count] / 2;
            self.median = [sortedBuff[middle] floatValue];
            self.std = [self standardDeviationOf:statsBuff mean:self.clearance];
        }
    }
}

-(void)updateStatsWithClearanceValue:(NSNumber*)clearance statsBuffer:(NSMutableArray*)statsBuff {
    float value = [clearance floatValue];
    self.clearance += value;
    if (value > self.max) {
        self.max = value;
    }
    if (value < self.min) {
        self.min = value;
    }
    [statsBuff addObject:clearance];
}
    
-(float)standardDeviationOf:(NSArray *)array  mean:(double)mean {
    if(![array count]) {
        return 0.0;
    }
    
    double sumOfSquaredDifferences = 0.0;
    for(NSNumber *number in array) {
        sumOfSquaredDifferences += pow([number doubleValue] - mean,2);
    }
        
    return (float)sqrt(sumOfSquaredDifferences / [array count]);
}

@end
