//
//  MeasurementData.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-25.
//
//

#import "MeasurementData.h"

@implementation MeasurementData

@synthesize displacements = _displacements;
@synthesize intensities = _intensities;
@synthesize timestamps = _timestamps;
@synthesize datasetIDs = _datasetIDs;
@synthesize pointCounts = _pointCounts;

- (NSMutableArray *) displacements
{
    if (!_displacements) _displacements = [NSMutableArray new];
    return _displacements;
}

- (NSMutableArray *) intensities
{
    if (!_intensities) _intensities = [NSMutableArray new];
    return _intensities;
}

- (NSMutableArray *) timestamps
{
    if (!_timestamps) _timestamps = [NSMutableArray new];
    return _timestamps;
}

- (NSMutableArray *) datasetIDs
{
    if (!_datasetIDs) _datasetIDs = [NSMutableArray new];
    return _datasetIDs;
}

- (NSMutableArray *) pointCounts
{
    if (!_pointCounts) _pointCounts = [NSMutableArray new];
    return _pointCounts;
}

-(void)clear {
    [self.displacements removeAllObjects];
    [self.intensities removeAllObjects];
    [self.timestamps removeAllObjects];
    [self.datasetIDs removeAllObjects];
    [self.pointCounts removeAllObjects];
}

@end
