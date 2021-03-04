//
//  ControllerSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//
#import "SensorSettings.h"

#define DESIRED_POINTS_PER_BLADE 4

@interface ControllerSettings : NSObject
@property (strong, nonatomic) SensorSettings* sensor;
@property (readonly, nonatomic) float outOfRange;
@property (nonatomic) float acquisitionTime;
@property (nonatomic) float measurementRate;
@property (nonatomic) float intensityThreshold;
@property (nonatomic) BOOL overrideRateAndIntensity;

-(NSString*)calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter;
@end
