//
//  ControllerSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#import "math.h"
#import "ControllerSettings.h"

@implementation ControllerSettings
@synthesize sensor = _sensor;
@synthesize outOfRange = _outOfRange;
@synthesize acquisitionTime = _acquisitionTime;
@synthesize measurementRate = _measurementRate;
@synthesize intensityThreshold = _intensityThreshold;
@synthesize overrideRateAndIntensity = _overrideRateAndIntensity;

-(instancetype)init {
    if (self = [super init]) {
        self.measurementRate = 1.0;
        self.intensityThreshold = [self calculateIntensityThresholdFromMeasurementRateKHz:self.measurementRate];
    }
    return self;
}

-(SensorSettings*) sensor {
    if (!_sensor) _sensor = [SensorSettings LONG];
    return _sensor;
}

-(float) outOfRange {
    _outOfRange = ceilf([self sensor].smr + [self sensor].mr/2.0);
    return _outOfRange;
}

-(NSString*)calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter {
    
    NSString* errorMessage = @"";
    float circumference = [self calculateCircumferenceFromTipDiameterInches:tipDiameter];
    if (circumference == 0) {
        errorMessage = @"Error: Circumference = 0, ";
    }
    float inchesPerSecond = [self calculateSpeedForCircumference:circumference withRPM:rpm];
    self.acquisitionTime = [self calculateAcquisitionTimeForCircumference:circumference atSpeed:inchesPerSecond];
    self.measurementRate = [self calculateKHzFrequencyForSamplesPerInch:(DESIRED_POINTS_PER_BLADE / bladeWidth) atSpeed:inchesPerSecond];
    self.intensityThreshold = [self calculateIntensityThresholdFromMeasurementRateKHz:self.measurementRate];
    
    // may not be a safe float comparison
    if (rpm == 0) {
        errorMessage = [errorMessage stringByAppendingString:@"Error: RPM = 0, "];
    }

    if (self.acquisitionTime <= 0) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: Time Low %f, ", self.acquisitionTime];
    } else if (self.acquisitionTime > 1800) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: Time High %f, ", self.acquisitionTime];
    }

    if (self.measurementRate >= 6.5) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: Rate High %d pts/blade", DESIRED_POINTS_PER_BLADE];
    }
    return errorMessage;
}

-(float)calculateCircumferenceFromTipDiameterInches:(float)tipDiameterInches {
    return M_PI * tipDiameterInches;
}

-(float)calculateSpeedForCircumference:(float)circumference withRPM:(float)rpm {
    return circumference * rpm / 60.0;
}

-(float)calculateAcquisitionTimeForCircumference:(float)circumference atSpeed:(float)inchesPerSecond {
    return 1.10 * circumference / inchesPerSecond;
}

-(float)calculateKHzFrequencyForSamplesPerInch:(float)samplesPerInch atSpeed:(float)inchesPerSecond {
    // Round measurement rate to the next highest 100 Hz and convert to kHz for output
    return MIN(MAX(ceilf((inchesPerSecond * samplesPerInch) / 100.0) * 100.0, 100.0), 6500.0) / 1000.0;
}

-(float)calculateIntensityThresholdFromMeasurementRateKHz:(float)measurementRateKHz {
    if (measurementRateKHz <= 0.4 || fabs(measurementRateKHz - 0.4) <= 0.0000001) {
        return 3.2;
    } else if (measurementRateKHz >= 1.9 || fabs(measurementRateKHz - 1.9) <= 0.0000001) {
        return 0.5;
    } else {
        return 4.98 * expf(-1.141 * measurementRateKHz);
    }
}

@end
