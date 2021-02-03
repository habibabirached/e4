//
//  BaseController.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "IController.h"

// Hard coded address for the IFC-242x address, which should be static.
#define IFC_ADDR "192.168.168.150"
#define DATA_PORT 1024
#define TELNET_PORT 23

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

@interface BaseController : IController {
    @protected IFC242xManager* delegate;
    @protected enum MEASUREMENT_CATEGORY nextIFCValue;
    @protected NSString* controllerType, *ipAddress;
    @protected NSMutableArray* telnetCmds;
    @protected BOOL telnetIsReady, dataStreamIsOpen, telnetStreamIsOpen;
    @protected int dataPort, telnetPort, set_count, num_sets;
    @protected NSInputStream* inputDataStream, *inputTelnetStream;
    @protected NSOutputStream* outputDataStream, *outputTelnetStream;
    @protected NSRunLoop* networkRunLoop;
    @protected dispatch_queue_t networkQueue;
    @protected NSTimer* timerSendTelnetCommand;
}

- (int)calculateNumberOfDatasetsToAcquireForTime:(float)acqTime atRateInHertz:(float)rate;
- (void)collectDataSets;
- (void)configureOutputSettings;
- (void)connectDevice:(NSString*)ip_address port:(int)port;
- (void)connectTelnetPortIfNecessary:(NSStream*)streamToCheck;
- (void)disconnectData;
- (void)disconnectTelnet;
- (void)processResponse:(NSString*)rxData;
- (void)selectOppositeOutput;
- (void)sendCommand:(NSString*)command;
- (void)sendEmptyCommand;
- (void)sendTelnetCommand;
- (void)setupSerialCableAndCommThread;
- (void)timeoutTelnetSendCommand:(NSTimer*)timer;

@end
