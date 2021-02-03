//
//  IController.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Feb-02.
//
//

#import "ControllerSettings.h"
#import "../MeasurementData.h"
@class IFC242xManager;

@interface IController : NSObject

@property (readonly, strong, nonatomic) ControllerSettings* settings;
@property (readonly, strong, nonatomic) MeasurementData* measurementData;
@property (readonly, nonatomic) enum CONTROLLER_STATE state;

-(instancetype)initWithDelegate:(IFC242xManager*)delegate;
-(instancetype)initWithDelegate:(IFC242xManager*)delegate andSettings:(ControllerSettings*)settings;

- (void)disconnectDevice;
- (void)doDarkReference;
- (void)doDataCollection;
- (void)initialize;
- (void)masterDevice:(NSString*)masteringValue;
- (void)setIntensityThreshold:(float)threshold;
- (void)setIntensityThreshold:(float)threshold sendImmediately:(bool)send;
- (void)setMeasurementRate:(float)rate;
- (void)setMeasurementRate:(float)rate sendImmediately:(bool)send;

@end
