//
//  BaseController.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "IController.h"


enum CONTROLLER_STATE {
    ready = 0,
    initializationInProgress,
    masteringInProgress,
    darkReferenceInProgress,
    setMeasurementRateInProgress,
    setThresholdInProgress,
    collectingDataInProgress,
    clearanceComputationInProgress,
    notReady,
    halted,
    timeOut
};

enum MEASUREMENT_CATEGORY {
    IFCIntensity = 0,
    IFCDisplacement,
    IFCTimestamp
};

@interface BaseController : NSObject<IController> {
    @protected enum CONTROLLER_STATE _state;
    @protected IFC242xManager* delegate;
    @protected enum MEASUREMENT_CATEGORY nextIFCValue;
    @protected NSString* controllerType;
    @protected NSMutableArray* telnetCmds;
    @protected BOOL telnetIsReady;
    @protected int num_sets;
    @protected float set_count;
    @protected NSRunLoop* networkRunLoop;
    @protected dispatch_queue_t networkQueue;
    @protected NSTimer* timerSendTelnetCommand;
}

- (int)calculateNumberOfDatasetsToAcquireForTime:(float)acqTime atRateInHertz:(float)rate;
- (void)collectDataSets;
- (void)configureOutputSettings;
- (void)disconnectData;
- (void)disconnectTelnet;
- (double)getElapsedTime;
- (void)processResponse:(NSString*)rxData;
- (void)selectOppositeOutput;
- (void)sendCommand:(NSString*)command;
- (void)sendEmptyCommand;
- (void)sendTelnetCommand;
- (void)startCommThread;
- (void)timeoutTelnetSendCommand:(NSTimer*)timer;

@end
