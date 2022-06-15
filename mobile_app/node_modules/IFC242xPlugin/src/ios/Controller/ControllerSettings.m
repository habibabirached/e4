//
//  ControllerSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#import "math.h"
#import "AppDelegate.h"
#import "ControllerSettings.h"

@implementation ControllerSettings
@synthesize sensor = _sensor;
@synthesize outOfRange = _outOfRange;
@synthesize acquisitionTime = _acquisitionTime;
@synthesize measurementRate = _measurementRate;
@synthesize intensityThreshold = _intensityThreshold;
@synthesize overrideRateAndIntensity = _overrideRateAndIntensity;
@synthesize sensorParamsProvided = _sensorParamsProvided;
@synthesize pointsPerBlade = _pointsPerBlade;

-(instancetype)initWithDelegate:(IFC242xManager*)delegate {
    if (self = [super init]) {
        self->delegate = delegate;
        self.measurementRate = 1.0;
        self.intensityThreshold = [self calculateIntensityThresholdFromMeasurementRateKHz:self.measurementRate];
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.pointsPerBlade = [((AppDelegate *)[UIApplication sharedApplication].delegate).pointsPerBlade intValue];
        });
        NSLog(@"@init: pointsPerBlade=%d", self.pointsPerBlade);
    }
    return self;
}

-(SensorSettings*) sensor {
    if (!_sensor) {
        // default to LONG sensor type
        _sensor = [SensorSettings LONG];
    }
    return _sensor;
}

-(float) outOfRange {
    _outOfRange = ceilf([self sensor].smr + [self sensor].mr/2.0);
    return _outOfRange;
}

-(void)resetMeasurementRateAndIntensityThreshold {
    NSLog(@"@resetMeasurementRateAndIntensityThreshold");
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"@ControllerSettings.resetMeasurementRateAndIntensityThreshold"} keepOpen:YES];
    self.measurementRate = 1.0;
    self.intensityThreshold = [self calculateIntensityThresholdFromMeasurementRateKHz:self.measurementRate];
}

-(NSString*)calculate:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter updateRateAndIntensity:(BOOL)rateAndIntensity {
    NSLog(@"@calculate: rpm=%f, bladeWidth=%f, tipDiameter=%f, rateAndIntensity=%s", rpm, bladeWidth, tipDiameter, rateAndIntensity ? "true" : "false");
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"ControllerSettings.calculate: rpm=%f, bladeWidth=%f, tipDiameter=%f, rateAndIntensity=%s", rpm, bladeWidth, tipDiameter, rateAndIntensity ? "TRUE" : "FALSE"]} keepOpen:YES];
    NSString* errorMessage = @"";
    
    if (rpm == 0) {
        errorMessage = [errorMessage stringByAppendingString:@"Error: RPM = 0, "];
    } else if (rpm < 0.5) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: RPM Low %f, ", rpm];
    } else if (rpm > 15.0) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: RPM High %f, ", rpm];
    }
    
    if (bladeWidth == 0) {
        errorMessage = [errorMessage stringByAppendingString:@"Error: Blade Width = 0, "];
    }

    if (tipDiameter == 0) {
        errorMessage = [errorMessage stringByAppendingString:@"Error: Tip Diameter = 0, "];
    }

    float circumference = [self calculateCircumferenceFromTipDiameterInches:tipDiameter];
    if (circumference == 0) {
        errorMessage = @"Error: Circumference = 0, ";
    }

    float inchesPerSecond = [self calculateSpeedForCircumference:circumference withRPM:rpm];
    if (inchesPerSecond == 0) {
        errorMessage = [errorMessage stringByAppendingString:@"Error: Inches Per Second = 0, "];
    }

    self.acquisitionTime = [self calculateAcquisitionTimeForCircumference:circumference atSpeed:inchesPerSecond];
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"ControllerSettings.calculate: acquisitionTime=%f", self.acquisitionTime]} keepOpen:YES];
    if (self.acquisitionTime <= 0) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: Time Low %f, ", self.acquisitionTime];
    } else if (self.acquisitionTime > 1800) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: Time High %f, ", self.acquisitionTime];
    }
    
    if (rateAndIntensity) {
        [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"ControllerSettings.calculate: pointsPerBlade=%d", self.pointsPerBlade]} keepOpen:YES];
        float samplesPerInch = self.pointsPerBlade / bladeWidth;
        self.measurementRate = [self calculateKHzFrequencyForSamplesPerInch:samplesPerInch atSpeed:inchesPerSecond];
        self.intensityThreshold = [self calculateIntensityThresholdFromMeasurementRateKHz:self.measurementRate];
    }
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"ControllerSettings.calculate: measurementRate=%f, intensityThreshold=%f", self.measurementRate, self.intensityThreshold]} keepOpen:YES];
    if (self.measurementRate < 0.1) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: Rate Low %f", self.measurementRate];
    } else if (self.measurementRate > 6.5) {
        errorMessage = [errorMessage stringByAppendingFormat:@"Error: Rate High %f", self.measurementRate];
    }

    return errorMessage;
}

-(NSString*)calculateAcquisitionTimeFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter {
    return [self calculate:rpm forBladeWidth:bladeWidth forTipDiameter:tipDiameter updateRateAndIntensity:FALSE];
}

-(NSString*)calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:(float)rpm forBladeWidth:(float)bladeWidth forTipDiameter:(float)tipDiameter {
    return [self calculate:rpm forBladeWidth:bladeWidth forTipDiameter:tipDiameter updateRateAndIntensity:TRUE];
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
    return MIN(MAX(ceilf((inchesPerSecond * samplesPerInch) / 100.0) * 100.0, MIN_RATE_HZ), MAX_RATE_HZ) / 1000.0;
}

-(float)calculateIntensityThresholdFromMeasurementRateKHz:(float)measurementRateKHz {
    if (measurementRateKHz <= 0.4 || fabs(measurementRateKHz - 0.4) <= 0.0000001) {
        return 3.2; // 3.1551
    } else if (measurementRateKHz >= 1.9 || fabs(measurementRateKHz - 1.9) <= 0.0000001) {
        return 0.5; // 0.5698
    } else {
        return 4.98 * expf(-1.141 * measurementRateKHz);
    }
}

@end
