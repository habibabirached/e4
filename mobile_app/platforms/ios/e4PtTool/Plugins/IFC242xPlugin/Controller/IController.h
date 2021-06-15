//
//  IController.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Feb-02.
//
//

#import "../IFC242xManager.h"
#import "../MeasurementData.h"
#import "ControllerSettings.h"

@protocol IController

@property (readonly, strong, nonatomic) ControllerSettings* settings;
@property (readonly, strong, nonatomic) MeasurementData* measurementData;
@property (readonly, nonatomic) enum CONTROLLER_STATE state;

-(instancetype)initWithDelegate:(IFC242xManager*)delegate;
-(instancetype)initWithDelegate:(IFC242xManager*)delegate andSettings:(ControllerSettings*)settings;

- (void)abortDataCollection;
- (void)disconnectDevice;
- (void)doDarkReference;
- (void)doDataCollection;
- (void)initialize;
- (void)configureController;
- (void)readSensorParameters;
- (void)masterDevice:(NSString*)masteringValue;
- (void)queueDataCollection:(float)timeoutSecondsForPrep;
- (void)setIntensityThreshold:(float)threshold;
- (void)setIntensityThreshold:(float)threshold sendImmediately:(bool)send;
- (void)setMeasurementRate:(float)rate;
- (void)setMeasurementRate:(float)rate reportStatus:(bool)report;

@end
