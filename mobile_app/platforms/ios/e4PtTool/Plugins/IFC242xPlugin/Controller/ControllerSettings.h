//
//  ControllerSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#import "IFC242xManager.h"
#import "SensorSettings.h"

// moved to app settings
//#define DESIRED_POINTS_PER_BLADE 16
#define MIN_RATE_HZ 100.0
#define MAX_RATE_HZ 6500.0

@interface ControllerSettings : NSObject {
    @protected IFC242xManager* delegate;
}

-(instancetype)initWithDelegate:(IFC242xManager*)delegate;

@property (strong, nonatomic) SensorSettings* sensor;
@property (readonly, nonatomic) float outOfRange;
@property (nonatomic) float acquisitionTime;
@property (nonatomic) float measurementRate;
@property (nonatomic) float intensityThreshold;
@property (nonatomic) BOOL overrideRateAndIntensity;
@property (nonatomic) BOOL sensorParamsProvided;
@property (nonatomic) int pointsPerBlade;

-(void)resetMeasurementRateAndIntensityThreshold;
-(NSString*)calculateAcquisitionTimeFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter;
-(NSString*)calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter;
-(float)calculateIntensityThresholdFromMeasurementRateKHz:(float)measurementRateKHz;
@end
