//
//  MeasurementData.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-25.
//
//

@interface MeasurementData : NSObject
@property (readonly, strong, nonatomic) NSMutableArray* displacements;
@property (readonly, strong, nonatomic) NSMutableArray* intensities;
@property (readonly, strong, nonatomic) NSMutableArray* timestamps;
@end
