//
//  ControllerSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//
#import "ControllerSettings.h"

#define DESIRED_POINTS_PER_BLADE 4


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
    }
    return self;
}

-(SensorSettings*) sensor {
    if (!_sensor) _sensor = [SensorSettings LONG];
    return _sensor;
}

-(float) outOfRange {
    _outOfRange = 15.0;//_sensor.mr + _sensor.mv;
    return _outOfRange;
}

-(NSString*)calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter {
    
    NSString* errorMessage;
    float circumference = M_PI * tipDiameter;
    float inchesPerSecond = circumference * rpm / 60.0;
    
    self.acquisitionTime = 1.10 * circumference / inchesPerSecond;
    if (self.acquisitionTime <= 0)
        errorMessage = [NSString stringWithFormat:@"Error: Time Low %f", self.acquisitionTime];
    else if (self.acquisitionTime > 1800)
        errorMessage = [NSString stringWithFormat:@"Error: Time High %f", self.acquisitionTime];
    
    float samplesPerInch = DESIRED_POINTS_PER_BLADE / bladeWidth;
    // Round measurement rate to the next highest 100 Hz.
    float measRate = ceilf((inchesPerSecond * samplesPerInch) / 100.0) * 100.0;
    if (measRate > 6500.0) {
        measRate = 6500.0;
        if (!errorMessage) errorMessage = @"";
        errorMessage = [errorMessage stringByAppendingString:[NSString stringWithFormat:@"Error: Rate High %f pts/blade", samplesPerInch * bladeWidth]];
    } else if (measRate <= 100)
        measRate = 100;
    // Convert measurement rate to kHz. for output
    self.measurementRate = measRate / 1000.0;
        
    if (self.measurementRate <= 0.4)
        self.intensityThreshold = 320.0;
    else if ((self.measurementRate > 0.4) && (self.measurementRate < 1.9))
        self.intensityThreshold = 4.98 * expf(-1.141 * self.measurementRate);
    else if (self.measurementRate >= 1.9)
        self.intensityThreshold = 50.0;
    
    return errorMessage;
}

@end
