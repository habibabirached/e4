//
//  ControllerSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#import "SensorSettings.h"

#define DESIRED_POINTS_PER_BLADE 16

@interface ControllerSettings : NSObject
@property (strong, nonatomic) SensorSettings* sensor;
@property (readonly, nonatomic) float outOfRange;
@property (nonatomic) float acquisitionTime;
@property (nonatomic) float measurementRate;
@property (nonatomic) float intensityThreshold;
@property (nonatomic) BOOL overrideRateAndIntensity;
@property (nonatomic) BOOL sensorParamsProvided;

-(NSString*)calculateAcquisitionTimeFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter;
-(NSString*)calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter;
-(float)calculateIntensityThresholdFromMeasurementRateKHz:(float)measurementRateKHz;
@end
