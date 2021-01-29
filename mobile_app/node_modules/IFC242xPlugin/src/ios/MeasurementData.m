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

@end
