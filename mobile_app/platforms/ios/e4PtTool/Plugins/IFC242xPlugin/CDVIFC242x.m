//
//  CDVIFC242x.m
//  IFC242x
//
//  Created by Glen Brooksby - March 24, 2020
//  Copyright (c) General Electric Co.
//
//

#if !TARGET_IPHONE_SIMULATOR

#import "CDVIFC242x.h"
#import "Controller/ControllerSettings.h"
#import "PostProcess.h"
#import <AVFoundation/AVFoundation.h>
#include "math.h"
#include <Accelerate/Accelerate.h>
#import "redparkSerial.h"
#import "RscMgr.h"


// Take out the printf lines in release mode
#ifndef DEBUG
#define DBGcout if(0)printf
#else
#define DBGcout printf
#endif

// Hard coded address for the IFC-242x address, which should be static.
#define IFC_ADDR "192.168.168.150"
#define DATA_PORT 1024
#define TELNET_PORT 23

// Hard coded values for RS232 serial cable
// 192 = 64 * 3.  Data seems to come in 64 byte packets and data from
// the IFC242x comes in 3-byte values.
#define BYTE_BUFFER_SIZE 192
#define RX_FORWARD_COUNT 64

// Some defines for the signal processing
#define OUT_OF_RANGE 15.0

// Define SERIAL_SEND_TIMESTAMP if you want to have the timestamp
// sent over the serial cable.  This takes more bits over the
// limited serial cable bandwidth.
// Define SEND_DISPLACEMENT_ONLY if you want to send just the
// displacement value to maximize bandwidth.
//#define SERIAL_SEND_TIMESTAMP
//#define SEND_DISPLACEMENT_ONLY

// Number of desired points measured per blade.
#define DESIRED_POINTS_PER_BLADE 4.0

// This option, when defined causes the program to output
// the minimum clearance for each blade rather than the
// average across the tip.
//#define OUTPUT_MINIMUM

// For using simulated data
//#define SIMULATED_DATA

// For testing purposes define TEST_CODE
//#define TEST_CODE

enum pluginState {
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

enum ifc242xValue {
    IFCIntensity = 0,
    IFCDisplacement,
    IFCTimestamp
};


@interface ScanMetaData : NSObject
@property (strong, nonatomic) NSString* serial_number;
@property (strong, nonatomic) NSString* stage;
@property (strong, nonatomic) NSString* position;
@property (strong, nonatomic) NSString* casing_thickness;
@property (strong, nonatomic) NSString* spacer_thickness;
@property (strong, nonatomic) NSString* num_blades;
@property (strong, nonatomic) NSString* blade_width;
@property (strong, nonatomic) NSString* tip_diameter;
    

-(instancetype)init;

@end

@implementation ScanMetaData

@synthesize serial_number = _serial_number;
@synthesize stage = _stage;
@synthesize position = _position;
@synthesize casing_thickness = _casing_thickness;
@synthesize spacer_thickness = _spacer_thickness;
@synthesize num_blades = _num_blades;
@synthesize blade_width = _blade_width;
@synthesize tip_diameter = _tip_diameter;

-(instancetype)init {
    self = [super init];
    [self clear];
    return self;
}

- (void)clear {
    self.serial_number = @"";
    self.stage = @"";
    self.position = @"";
    self.spacer_thickness = @"";
    self.casing_thickness = @"";
    self.num_blades = @"";
    self.blade_width = @"";
    self.tip_diameter = @"";
}

@end

@interface IFCObjectiveCManager : NSObject <NSStreamDelegate>

+ (IFCObjectiveCManager*)staticManager;

@property (nonatomic,weak) UIWebView* webView;

- (void)setDeviceMode:(NSString*)mode;
- (void)connectDevice:(NSString*)ip_address port:(int)port;
- (void)disconnectDevice;
- (void)doDarkReference;
- (void)masterDevice;
- (void)masterDeviceWithValue:(NSString*)masteringValue;
- (void)setMeasurementRate:(NSString*)rate withAlert:(bool)tf;
- (void)setThreshold:(NSString*)threshold;
- (void)collectData:(int)num_sets casingThickness:(float)casing_thicknesss;
- (void)doDataCollection;

// IP Connection Commands
- (void)sendTelnetCommand;

// RS232 Connection Commands

@end

@interface IFCObjectiveCManager () {
    PostProcess* postProcess;
    ControllerSettings* controllerSettings;
}

// TCP/IP connection variables
@property (nonatomic) int dataPort;
@property (nonatomic) int telnetPort;
@property (nonatomic,retain) NSInputStream* inputDataStream;
@property (nonatomic,retain) NSOutputStream* outputDataStream;
@property (nonatomic,retain) NSInputStream* inputTelnetStream;
@property (nonatomic,retain) NSOutputStream* outputTelnetStream;
@property (nonatomic) BOOL dataStreamIsOpen;
@property (nonatomic) BOOL telnetStreamIsOpen;
@property (nonatomic) BOOL telnetIsReady;
@property (strong, nonatomic) NSString* ipAddress;
@property (nonatomic) uint8_t *totalBuffer;
@property (nonatomic) long int totalBufferIndex;
@property (nonatomic,retain) NSTimer * timerDataStreamOpening;
@property (nonatomic, retain) NSTimer* timerSendTelnetCommand;
@property (nonatomic, retain) NSTimer* timerDemoFunctions;
@property (nonatomic, retain) NSTimer* timerProgress;
@property (nonatomic, retain) NSTimer* timerWaiting;
@property (strong, nonatomic) NSRunLoop* networkRunLoop;
@property (strong, nonatomic) dispatch_queue_t networkQueue;

// Variables needed for data collection.
@property (nonatomic) int tmpCounter;
@property (nonatomic) int pState;
@property (strong, nonatomic) NSMutableArray* telnetCmds;
@property (strong, nonatomic) NSString* mode; // "ethernet" or "serial"
@property (strong, nonatomic) ScanMetaData* metaData;
@property (strong, nonatomic) NSString* last_saved_file;

@property (strong, nonatomic) NSMutableArray* datasetIds;
@property (strong, nonatomic) NSMutableArray* times;
@property (strong, nonatomic) NSMutableArray* displacements;
@property (strong, nonatomic) NSMutableArray* point_counts;
@property (strong, nonatomic) NSMutableArray* intensities;
@property (nonatomic) BOOL calibratedAcquire;

@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval testTime;


@property (nonatomic) int num_pts_max;
@property (nonatomic) int current_data_set_id;
@property (nonatomic) int previous_data_set_id;
@property (nonatomic) float set_count;
@property (nonatomic) int data_index;
@property (nonatomic) int num_sets;
@property (nonatomic) float progress;
@property (nonatomic) bool delayResponse;
@property (nonatomic) float overall_average;

@property (nonatomic) bool demoMode;
@property (strong, nonatomic) NSString* controllerType;

@property (strong, nonatomic) CDVIFC242x* plugin;

@property (strong, nonatomic) NSString* connectionMode;

//
// RS232 connection variables
//
@property (strong, nonatomic) NSThread *commThread;   // thread for communications tasks
@property (strong, nonatomic) RscMgr *rscMgr;         // Redpark serial communications
@property BOOL cableConnected;
@property DataSizeType dataSizeType;
@property ParityType parityType;
@property StopBitsType stopBitsType;
@property int baudRate;
@property int dataBits;
@property int parity;
@property int stopBits;
@property int rts;        // rx flow control
@property int cts;        // tx flow control
@property (nonatomic) uint8_t* byteBuffer;
@property (nonatomic) uint8_t* writePtr;
@property (nonatomic) uint8_t* readPtr;
@property (nonatomic) uint32_t* val1Ptr;
@property (nonatomic) int nextIFCValue;
@property (nonatomic) BOOL nSync; // Is the data stream synchronized? I couldn't resist this name.
@property (nonatomic) int leftoverBytes;


- (void)callBackErrorWithMethodName:(NSString*)methodName andWithError:(NSString*)errorMessage;

@end

@implementation IFCObjectiveCManager

@synthesize webView = _webView;
@synthesize metaData = _metaData;
@synthesize last_saved_file = _last_saved_file;

@synthesize dataStreamIsOpen = _dataStreamIsOpen;
@synthesize telnetStreamIsOpen = _telnetStreamIsOpen;
@synthesize ipAddress = _ipAddress;
@synthesize dataPort = _dataPort;
@synthesize telnetPort = _telnetPort;
@synthesize totalBuffer = _totalBuffer;
@synthesize totalBufferIndex = _totalBufferIndex;
@synthesize tmpCounter = _tmpCounter;
@synthesize telnetIsReady = _telnetIsReady;
@synthesize pState = _pState;
@synthesize telnetCmds = _telnetCmds;

@synthesize num_pts_max = _num_pts_max;
@synthesize current_data_set_id = _current_data_set_id;
@synthesize previous_data_set_id = _previous_data_set_id;
@synthesize set_count = _set_count;
@synthesize data_index = _data_index;
@synthesize num_sets = _num_sets;
@synthesize progress = _progress;
@synthesize plugin = _plugin;

@synthesize datasetIds = _datasetIds;
@synthesize times = _times;
@synthesize displacements = _displacements;
@synthesize point_counts = _point_counts;
@synthesize intensities = _intensities;
@synthesize demoMode = _demoMode;
@synthesize startTime = _startTime;
@synthesize testTime = _testTime;
@synthesize delayResponse = _delayResponse;
@synthesize overall_average = _overall_average;

@synthesize commThread = _commThread;
@synthesize rscMgr = _rscMgr;
@synthesize cableConnected = _cableConnected;
@synthesize dataSizeType = _dataSizeType;
@synthesize parityType = _parityType;
@synthesize stopBitsType = _stopBitsType;
@synthesize baudRate = _baudRate;
@synthesize dataBits = _dataBits;
@synthesize parity = _parity;
@synthesize stopBits = _stopBits;
@synthesize rts = _rts;
@synthesize cts = _cts;
@synthesize byteBuffer = _byteBuffer;
@synthesize readPtr = _readPtr;
@synthesize writePtr = _writePtr;
@synthesize val1Ptr = _val1Ptr;
@synthesize nextIFCValue = _nextIFCValue;
@synthesize leftoverBytes = _leftoverBytes;

@synthesize calibratedAcquire = _calibratedAcquire;

@synthesize connectionMode = _connectionMode;
@synthesize networkRunLoop = _networkRunLoop;
@synthesize networkQueue = _networkQueue;

+ (IFCObjectiveCManager*)staticManager {
    
    static IFCObjectiveCManager* _manager = nil;
    
    if (_manager==nil) {
        _manager = [[IFCObjectiveCManager alloc] init];
        _manager.connectionMode = @"serial"; // default connection mode.
        _manager.last_saved_file = @"";
        _manager.networkRunLoop = nil;
#ifdef SIMULATED_DATA
        _manager.demoMode = true;
#else
        _manager.demoMode = false;
#endif
        _manager->postProcess = [PostProcess new];
        _manager->controllerSettings = [ControllerSettings new];
        [_manager initializeSensor];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication* app = [UIApplication sharedApplication];
        if (![app isIdleTimerDisabled]) {
            [app setIdleTimerDisabled:true]; // This allows the app to keep the iPad from sleeping while the app is open.
        }
    });
    
    return _manager;
}

- (void)callBackWithCommandString:(NSString*)cmd {
    if ([[NSThread currentThread] isMainThread]) {
        [ self.webView stringByEvaluatingJavaScriptFromString:cmd ];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ self.webView stringByEvaluatingJavaScriptFromString:cmd ];
        });
    }
}

- (void)callBackErrorWithMethodName:(NSString*)methodName andWithError:(NSString*)errorMessage {
    NSString *cmd = [NSString stringWithFormat:@"window.plugins.IFC242x.OnError('%@','%@')", methodName, errorMessage];
    [ self callBackWithCommandString:cmd ];
}

- (void)returnPluginResponse:(NSDictionary*)jsonMessage keepOpen:(BOOL)keepOpen {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonMessage];
    result.keepCallback = [NSNumber numberWithBool:keepOpen];
    [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
}

- (void)connectDevice:(NSString*)ip_address port:(int)port {

    dispatch_async(self.networkQueue, ^{
        NSLog(@"@connectDevice: %@:%d", ip_address, port);
        if (port == self.dataPort) self.dataStreamIsOpen = false;
        if (port == self.telnetPort) self.telnetStreamIsOpen = false;
        
        if (port == DATA_PORT) {
            if (self.inputDataStream != nil) {
                CFStreamStatus chkStream;
                CFReadStreamRef cfinputstream = (__bridge CFReadStreamRef )self.inputDataStream;
                chkStream = CFReadStreamGetStatus(cfinputstream);
                if(chkStream == (CFStreamStatus) kCFStreamStatusOpen){
                    NSLog(@"This device is already connected for data.");
                    return;
                }
            }
            if(self.outputDataStream != nil){
                NSLog(@"  Already Connected - Data");
                return;
            }
        }
        else if (port == TELNET_PORT) {
            if (self.inputTelnetStream != nil) {
                CFStreamStatus chkStream;
                CFReadStreamRef cfinputstream = (__bridge CFReadStreamRef )self.inputTelnetStream;
                chkStream = CFReadStreamGetStatus(cfinputstream);
                if(chkStream == (CFStreamStatus) kCFStreamStatusOpen){
                    NSLog(@"This device is already connected for telnet.");
                    return;
                }
            }
            if(self.outputTelnetStream != nil){
                NSLog(@"  Already Connected - Telnet");
                return;
            }
        }
        
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)ip_address, port, &readStream, &writeStream);
        
        NSInputStream* inputStream = (__bridge NSInputStream *)readStream;
        NSOutputStream* outputStream = (__bridge NSOutputStream *)writeStream;
        [inputStream setDelegate:self];
        [outputStream setDelegate:self];
        [inputStream scheduleInRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
        //[inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        //[outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [inputStream open];
        [outputStream open];
        
        if (self.totalBuffer == nil) {
            self.totalBuffer = (uint8_t *) malloc(2048);
        }
        
        if (port == DATA_PORT) {
            self.outputDataStream = outputStream;
            self.inputDataStream = inputStream;
            self.timerDataStreamOpening = [ NSTimer scheduledTimerWithTimeInterval:0.75
                                                                            target:self
                                                                          selector:@selector(timeoutTimerDataStreamOpening:)
                                                                          userInfo:@(port)
                                                                           repeats:NO];
        }
        else if (port == TELNET_PORT) {
            self.outputTelnetStream = outputStream;
            self.inputTelnetStream = inputStream;
        }
    });
}

- (void)timeoutTimerDataStreamOpening:(NSTimer*)timer {
    NSLog(@"@timeoutDataStreamOpening: Timer expired (as expected)");
    int port = [timer.userInfo intValue];

    NSLog(@"    ipaddress = %@:%d",self.ipAddress,port);
    
    if(self.dataStreamIsOpen){
        NSLog(@"    OK - stream is open.");
    }
    else {
        NSLog(@"    stream not open.");
        [self.inputDataStream removeFromRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
        [self.outputDataStream removeFromRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
        //[self.inputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        //[self.outputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        // apple documentation also says to set delegate connection to nil (how?)
        
        if (port == DATA_PORT) {
            NSLog(@"    closing data port streams.");
            [self.inputDataStream close];
            self.inputDataStream = nil;
            [self.outputDataStream close];
            self.outputDataStream = nil;
        }
        else if (port == TELNET_PORT) {
            NSLog(@"    closing telnet port streams.");
            [self.inputTelnetStream close];
            self.inputTelnetStream = nil;
            [self.outputTelnetStream close];
            self.outputTelnetStream = nil;
        }
    }
}

- (void)timeoutProgressTimer:(NSTimer*)timer {
    if (self.progress >= 1.0) {
        [timer invalidate];
        self.progress = 1.0;
    }
    [self reportProgress];
}
    
- (void)reportProgress {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"Reporting progress: %f",self.progress);
        int intProgress = (int)roundf(self.progress*100); // Convert progress to a rounded whole %.
        NSString* progress = [NSString stringWithFormat:@"%d",intProgress];
        NSDictionary* jsonDict = @{@"type":@"progress",@"progress":progress};
        // Below are two ways to report progress back to the UI.  The later seems to cause a crash
        // when collecting data via ethernet. I'm leaving the code for now, but will use the more
        // direct method that does not crash.
        if (true) {
            NSError* error;
            NSData *jsonData=[NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingSortedKeys error:&error];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            [self.plugin.commandDelegate evalJs:[NSString stringWithFormat:@"pluginMessage(%@);",jsonString]];
        }
        else {
            [self returnPluginResponse:jsonDict keepOpen:YES];
        }
    });
}

- (void)timeoutWaitTimer:(NSTimer*)timer {
    NSDictionary* info = [timer userInfo];
    NSNumber* timeout = [info valueForKey:@"timeout"];
    NSString* nextProc = [info valueForKey:@"nextProcess"];
    NSTimeInterval dT = [[NSDate date] timeIntervalSince1970] - self.startTime;
    if (dT < [timeout doubleValue]) {
        if (self.pState == ready) {
            [timer invalidate];  // Everything is good. Turn off the timer and do the next thing.
            if ([nextProc containsString:@"doDataCollection"]) {
                NSLog(@"No timeout. Do data collection");
                [self doDataCollection];
            }
        }
        else if (self.pState == darkReferenceInProgress) {
            // update the progress bar.
            self.progress = dT / [timeout doubleValue];
        }
        else {
            // otherwise, keep waiting...
            [self returnPluginResponse:@{@"type":@"status",@"status":@"waiting"} keepOpen:YES];
        }
    }
    else {
        if (self.pState != ready) {
            // This is the timeout condition. The timeout has expired.
            // This could mean an error occured.
            NSString* msg = @"";
            if (self.pState == setMeasurementRateInProgress) {
                msg = @"Error setting measurement rate.\nTimeout.";
                
                NSLog(@"%@",msg);
                [self returnPluginResponse:@{@"type":@"alert",@"message":msg} keepOpen:NO];
                self.pState = ready;
            }
            else if (self.pState == darkReferenceInProgress) {
                // update then hide the progress bar.
                self.progress = 1.0;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    NSDictionary* jsonDict = @{@"type":@"alert",@"message":@"Dark referencing complete."};
                    if (true) {
                        NSError* error;
                        NSData *jsonData=[NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingSortedKeys error:&error];
                        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                        [self.plugin.commandDelegate evalJs:[NSString stringWithFormat:@"pluginMessage(%@);",jsonString]];
                    }
                    else {
                        [self returnPluginResponse:jsonDict keepOpen:YES];
                    }
                });
                if ([nextProc containsString:@"doDataCollection"]) {
                    NSLog(@"Dark reference complete. Do data collection. %fs", controllerSettings.acquisitionTime);
                    [self doDataCollection];
                }
            }
        }

        [timer invalidate];
    }
}

- (void)timeoutTimerDemoMode:(NSTimer*)timer {
    NSString* arg = timer.userInfo;
    if ([arg containsString:@"dark_reference"]) {
        [self processComplete:@"connected"];
    }
    if ([arg containsString:@"mastering"]) {
        [self processComplete:@"done_mastering"];
    }
    if ([arg containsString:@"measurement_rate"]) {
        [self processComplete:@"connected"];
    }
    if ([arg containsString:@"threshold"]) {
        [self processComplete:@"connected"];
    }
    if ([arg containsString:@"collect_data"]) {
        [self loadCSVFile:@""];
        [self returnPluginResponse:@{@"type":@"status",@"status":@"processing"} keepOpen:YES];
        [self returnData:[self computeClearance]];
        [self processComplete:@"connected"];
    }
}

- (void)timeoutTelnetSendCommand:(NSTimer*)timer {
    NSLog(@"@timeoutTelnetSendCommand: Timer expired. # commands = %lu", (unsigned long)self.telnetCmds.count);
    if (self.demoMode) {
        [self.timerSendTelnetCommand invalidate]; // Cancel the timer in demo mode.
        [self disconnectDevice];
        [self processComplete:@"connected"];
    }
    if (self.telnetCmds.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
            self.pState = ready;
        });
        return;
    }
    NSString* command = [self.telnetCmds objectAtIndex:0];
    NSLog (@"  command: %@", command);
    if (self.telnetIsReady) {
        // send the command
        if ([self.connectionMode containsString:@"ethernet"]) {
            NSData* cmdData = [[NSData alloc] initWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
            [self.outputTelnetStream write:(const unsigned char*)[cmdData bytes] maxLength:[cmdData length]];
        }
        if ([self.connectionMode containsString:@"serial"]) {
            [self sendSerialData:command];
        }
        
        // Remove the command that was just sent
        [self.telnetCmds removeObjectAtIndex:0];
        
        // Disable the timer if we've run out of commands to send.
        if ([self.telnetCmds count] == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [timer invalidate];
            });
        }
        self.telnetIsReady = false;  // telnetIsReady is set to true as soon as the "->" comes back from the controller.
    }
    else {
        NSLog(@"  telnet is not ready yet...");
        if ([self.connectionMode containsString:@"ethernet"]){
            if (self.outputTelnetStream != nil) {
                NSLog(@"outputTelnetStream is not nil.");
                NSString* command = @"\n";
                NSData* cmdData = [[NSData alloc] initWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
                [self.outputTelnetStream write:(const unsigned char*)[cmdData bytes] maxLength:[cmdData length]];
            }
            else {
                NSLog(@"outputTelnetStream is nil!");
            }
        }
        if ([self.connectionMode containsString:@"serial"]){
            NSLog(@"   coaxing it...");
            [self sendSerialData:@"OUTPUT NONE\n"];
        }
    }
}

// This function sets up a timer that tries on an interval to send a command from a
// queue of commands over telnet.  The timer will keep firing until the queue runs
// out of command and the timer is invalidated in the callback.
- (void)sendTelnetCommand {
    // The controller will automatically disconnect the telnet port after a period
    // of inactivity.  If this happens we have to reconnect the port before sending
    // commands.
    if ([self.connectionMode containsString:@"ethernet"]) {
        if (self.outputTelnetStream == nil) {
            // attempt reconnect
            NSLog(@"  Attempting to (re)connect to telnet port.");
            [self connectDevice:self.ipAddress port:self.telnetPort];
        }
    }
    
    NSLog(@"@sendTelnetCommand: number of queued commands: %lu", (unsigned long)self.telnetCmds.count);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timerSendTelnetCommand = [ NSTimer scheduledTimerWithTimeInterval:0.1
                                                                        target:self
                                                                      selector:@selector(timeoutTelnetSendCommand:)
                                                                      userInfo:nil
                                                                       repeats:YES];
    });
}

- (void)setDeviceMode:(NSString*)mode {
  self.mode = mode;
}

- (void)initializeSensor {
    NSLog(@"@initializeSensor");
    self.pState = initializationInProgress;
    self.ipAddress = @IFC_ADDR;
    self.dataPort = DATA_PORT;
    self.telnetPort = TELNET_PORT;
    self.telnetIsReady = false;
    if (self.datasetIds == nil) self.datasetIds = [[NSMutableArray alloc] init];
    if (self.times == nil) self.times = [[NSMutableArray alloc] init];
    if (self.displacements == nil) self.displacements = [[NSMutableArray alloc] init];
    if (self.point_counts == nil) self.point_counts = [[NSMutableArray alloc] init];
    if (self.intensities == nil) self.intensities = [[NSMutableArray alloc] init];
    if (self.telnetCmds == nil) self.telnetCmds = [[NSMutableArray alloc] init];
    if (self.metaData == nil) self.metaData = [[ScanMetaData alloc] init];
    [self.metaData clear];
    self.controllerType = @"";
    
#ifdef SEND_DISPLACEMENT_ONLY
    self.nextIFCValue = IFCDisplacement;
#else
    self.nextIFCValue = IFCIntensity;
#endif
    
    self.nSync = false;
    self.leftoverBytes = 0;
    self.startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
    self.progress = 0.0;
    self.delayResponse = false;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timerSendTelnetCommand invalidate];
    });
    [self.telnetCmds removeAllObjects];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"ETHERMODE ETHERNET\n"]];
    if ([self.connectionMode containsString:@"ethernet"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"OUTPUT ETHERNET\n"]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASTRANSFER SERVER/TCP 1024\n"]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"OUT_ETH 01INTENSITY 01DIST1 TIMESTAMP\n"]];
    }

    if ([self.connectionMode containsString:@"serial"]) {
        // ifdefs below are structured the way they are because elseif didn't seem to work.
#ifdef SERIAL_SEND_TIMESTAMP
        // Output TIMESTAMP when using serial connection. This requires more bandwidth.
        //[self.telnetCmds addObject:[NSString stringWithFormat:@"OUT_RS422 01INTENSITY 01DIST1 TIMESTAMP\n"]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"OUT_RS422 01INTENSITY 01DIST1 COUNTER\n"]];
#elif defined(SEND_DISPLACEMENT_ONLY)
        [self.telnetCmds addObject:[NSString stringWithFormat:@"OUT_RS422 01DIST1\n"]];
#else
        // Don't output TIMESTAMP when using serial connection. This should allow us to increase throughput.
        [self.telnetCmds addObject:[NSString stringWithFormat:@"OUT_RS422 01INTENSITY 01DIST1\n"]];
#endif
    }
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE 1.0\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"OUTPUT NONE\n"]]; // turns off output.
    [self.telnetCmds addObject:[NSString stringWithFormat:@"GETINFO\n"]];
    
    if ([self.connectionMode containsString:@"ethernet"]) {
        // No need to connect the device here since sendTelnetCommand will do it.
        // Doing it here risks doing it twice with unpredictable results.
        //if (self.inputTelnetStream == nil) {
        //    NSLog(@"connectingDevice from initializeSensor");
        //    [self connectDevice:self.ipAddress port:self.telnetPort];
        //}

        NSLog(@"Calling sendTelnetCommand from initializeSensor with ethernet connection");
        [self setupSerialCableAndCommThread];
        [self sendTelnetCommand];
    }
    else if ([self.connectionMode containsString:@"serial"]) {
        [self setupSerialCableAndCommThread];
        NSLog(@"Calling sendTelnetCommand from initializeSensor with serial connection");
        [self sendTelnetCommand];
    }

    // Remove notifications before adding them so they are not added multiple times.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

#ifdef TEST_CODE
    [self codeTest];
    NSLog(@"codeTest Complete.");
#endif

}

- (void)masterDevice {
    [self masterDeviceWithValue:[NSString stringWithFormat:@"%f", controllerSettings.sensor.mv]];
}

- (void)masterDeviceWithValue:(NSString*)masteringValue {
    NSLog(@"@masteringDevice");
    if (![self checkReady]) return;
    if (self.inputTelnetStream == nil) {
        [self connectDevice:self.ipAddress port:self.telnetPort];
    }
    self.pState = masteringInProgress;
    [self returnPluginResponse:@{@"type":@"status",@"status":@"mastering_in_progress"} keepOpen:YES];

    // These next few lines are not intuitive.  Mastering is a process internal to the controller.
    // However, it can't complete unless output is being generated (apparently).  This has been shown
    // by manually trying to master using a telnet window.
    // However, we don't want to contend with data pouring in while we are just mastering.  So instead,
    // we enable data on the OPPOSITE output from that to which we are connected.  That way mastering
    // can proceed and we are not inundated with data.
    if ([self.connectionMode containsString:@"serial"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"OUTPUT ETHERNET\n"]];
    }
    if ([self.connectionMode containsString:@"ethernet"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"OUTPUT RS422\n"]];
    }

    [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTER 01DIST1 RESET\n"]];
    if (masteringValue != nil) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 %@\n", masteringValue]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTER 01DIST1 SET\n"]];
    }
    [self.telnetCmds addObject:[NSString stringWithFormat:@"OUTPUT NONE\n"]];
    [self sendTelnetCommand];
}

- (void)doDarkReference {
    NSLog(@"@doDarkReference");
    if (![self checkReady]) return;
    self.pState = darkReferenceInProgress;
    [self returnPluginResponse:@{@"type":@"status",@"status":@"acquiring"} keepOpen:YES];
    if ([self.connectionMode containsString:@"ethernet"]) {
        if (self.inputTelnetStream == nil) {
            [self connectDevice:self.ipAddress port:self.telnetPort];
        }
    }
    float processTime = 24.0; // Dark correction takes ~22s per channel on the IFC2422.
    if ([self.controllerType containsString:@"IFC2422"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"DARKCORR_CH01\n"]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"DARKCORR_CH02\n"]];
        processTime *= 2.0; // 2 channels = twice the time.
    }
    else if ([self.controllerType containsString:@"IFC2421"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"DARKCORR\n"]];
    }
    else {
        return; // Shouldn't get here.
    }
    // This timer just updates progress information every second assuming each channel takes ~22s.
    // After the dark correction, it collects 3 seconds of data.
    controllerSettings.acquisitionTime = 3.0;
    self.progress = 0.0;
    self.startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithFloat:processTime], @"timeout",
                              @"doDataCollection", @"nextProcess", nil];
        self.timerWaiting = [ NSTimer scheduledTimerWithTimeInterval:1.0
                                                              target:self
                                                            selector:@selector(timeoutWaitTimer:)
                                                            userInfo:info
                                                             repeats:YES];
    });
    // This timer updates the progress bar.
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timerProgress = [ NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(timeoutProgressTimer:)
                                                             userInfo:nil
                                                              repeats:YES];
    });
    [self sendTelnetCommand];
}

- (void)setMeasurementRate:(NSString*)rate withAlert:(bool)tf {
    if (![self checkReady]) return;
    self.pState = setMeasurementRateInProgress;
    controllerSettings.measurementRate = [rate floatValue];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %.3f\n", controllerSettings.measurementRate]];
    [self sendTelnetCommand];
}

- (void)setMeasurementRateAndIntensityThreshold{
    NSLog(@"setMeasurementRateAndIntensityThreshold");
    if (![self checkReady]) return;
    if (self.demoMode) return;
    self.pState = setMeasurementRateInProgress;
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %.3f\n", controllerSettings.measurementRate]];
    if ([self.controllerType containsString:@"IFC2422"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH01 %.3f\n", controllerSettings.intensityThreshold]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH02 %.3f\n", controllerSettings.intensityThreshold]];
    }
    else if ([self.controllerType containsString:@"IFC2421"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD %.3f\n", controllerSettings.intensityThreshold]];
    }
    else {
        return; // Shouldn't get here.
    }
    [self sendTelnetCommand];
}

- (void)setThreshold:(NSString*)threshold {
    if (![self checkReady]) return;
    self.pState = setThresholdInProgress;
    controllerSettings.intensityThreshold = [threshold floatValue];
    if ([self.controllerType containsString:@"IFC2422"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH01 %.3f\n", controllerSettings.intensityThreshold]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH02 %.3f\n", controllerSettings.intensityThreshold]];
    }
    else if ([self.controllerType containsString:@"IFC2421"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD %.3f\n", controllerSettings.intensityThreshold]];
    }
    else {
        return; // Shouldn't get here.
    }
    [self sendTelnetCommand];

}

- (bool)checkReady {
    if (self.pState != ready) {
        [self returnPluginResponse:@{@"type":@"status",@"status":@"Error: Device not ready. Please wait."} keepOpen:YES];
        return false;
    }
    return true;
}

// disconnectDevice stops both data and telnet streams.
- (void)disconnectDevice {
    [self disconnectData];
    [self disconnectTelnet];
}

- (void)disconnectData {
    NSLog(@"@disconnectData.");
    
    if ([self.connectionMode containsString:@"ethernet"]) {
        if (self.inputDataStream != nil)
            [self.inputDataStream removeFromRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
            //[self.inputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        if (self.outputDataStream != nil)
            [self.outputDataStream removeFromRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
            //[self.outputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        // apple documentation also says to set delegate connection to nil (how?)
        if (self.inputDataStream != nil) {
            [self.inputDataStream close];
            self.inputDataStream = nil;
        }
        if (self.outputDataStream != nil) {
            [self.outputDataStream close];
            self.outputDataStream = nil;
        }
        self.dataStreamIsOpen = false;
    }
    if ([self.connectionMode containsString:@"serial"]) {
         // Can't send this the telnet way because data is blasting through.
        [self sendSerialData:@"OUTPUT NONE\n"];
    }
}

- (void)disconnectTelnet {
    NSLog(@"@disconnectTelnet.");
    if (self.inputTelnetStream != nil)
        [self.inputTelnetStream removeFromRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
        //[self.inputTelnetStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    if (self.outputTelnetStream != nil)
        [self.outputTelnetStream removeFromRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
        //[self.outputTelnetStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    // apple documentation also says to set delegate connection to nil (how?)
    if (self.inputTelnetStream != nil) {
        [self.inputTelnetStream close];
        self.inputTelnetStream = nil;
    }
    if (self.outputTelnetStream != nil) {
        [self.outputTelnetStream close];
        self.outputTelnetStream = nil;
    }
    self.telnetStreamIsOpen = false;
    [self.telnetCmds removeAllObjects];
}

- (void)messageHandler:(NSString*)msg {
    
    NSLog(@"@messageHandler: pState = %d", self.pState);
    NSArray* msgArray = [msg componentsSeparatedByString:@";"]; // This results in an extra empty string.
    NSString* cmd = [msgArray objectAtIndex:0];
    
    if ([cmd containsString:@"ping"]) {
        NSLog(@"Got ping");
        return;
    }
    if ([cmd containsString:@"send_data"]) {
        NSLog(@"Got send_data");
        // If there's less than 5 arguments, this call is a generic
        // request for data so clear the meta-data. 5 or more args
        // is a request for specific frame/stage/position data.
        NSString* acqTime = @"";
        if (msgArray.count < 5) {
            // Call from JavaScript:
            // message = {"args":["send_data",acquisitionTime,"0.0"]};
            acqTime = [msgArray objectAtIndex:1];
            self.metaData.casing_thickness = [msgArray objectAtIndex:2];
            [self.metaData clear];
            self.calibratedAcquire = false;
        }
        if (msgArray.count > 4) {
            // Call from JavaScript:
            // ["send_data",acquisitionTime, frame, sn, stage, position, casing_thickness, spacer_thickness, master_offset, clearance_calc_method];
            acqTime = [msgArray objectAtIndex:1];
            //self.metaData.frame = [msgArray objectAtIndex:2];
            self.metaData.serial_number = [msgArray objectAtIndex:3];
            self.metaData.stage = [msgArray objectAtIndex:4];
            self.metaData.position = [msgArray objectAtIndex:5];
            self.metaData.casing_thickness = [msgArray objectAtIndex:6];
            self.metaData.spacer_thickness = [msgArray objectAtIndex:7];
            self.metaData.num_blades = [msgArray objectAtIndex:8];
            self.metaData.tip_diameter = [msgArray objectAtIndex:9];
            self.metaData.blade_width = [msgArray objectAtIndex:10];
            //self.metaData.master_offset = [msgArray objectAtIndex:11];
            controllerSettings.sensor.offsetSelector = [msgArray objectAtIndex:12];
            self.calibratedAcquire = true;
        }
        
        // Check if the value is specified in rpm.  If so, extract the rpm value.
        if ([[acqTime lowercaseString] hasSuffix:@"rpm"]) {
            float interval = 1.0;
            if (![controllerSettings overrideRateAndIntensity]) {
                // Set new measurement rate
                interval = 3.0; // Give it more time to set things up.
                NSString* err = [controllerSettings calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:[[acqTime substringToIndex:acqTime.length-3] floatValue] forBladeWidth:[self.metaData.blade_width floatValue] forTipDiameter:[self.metaData.tip_diameter floatValue]];
                if (err.length != 0) {
                    // Report errors.
                    [self returnPluginResponse:@{@"type":@"alert",@"message":err} keepOpen:YES];
                    return;
                }
                NSLog(@"Using auto-settings: Found measurement rate: %f; intensity threshold: %f", [controllerSettings measurementRate], [controllerSettings intensityThreshold]);
                [self setMeasurementRateAndIntensityThreshold];
            }
            else {
                NSLog(@"Overriding auto-settings.");
            }
            self.startTime = [[NSDate date] timeIntervalSince1970]; // start timeout timer
            // The timeoutWaitTimer callback will start data acquisition after the measurement
            // rate is set.  If the timeout expires, the user just gets an error message.
            if (!self.demoMode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                                          [NSNumber numberWithFloat:7.0], @"timeout",
                                          @"doDataCollection", @"nextProcess", nil];
                    self.timerWaiting = [ NSTimer scheduledTimerWithTimeInterval:interval
                                                                          target:self
                                                                        selector:@selector(timeoutWaitTimer:)
                                                                        userInfo:info
                                                                         repeats:YES];
                });
            }
            else {
                [self doDataCollection];
            }
        }
        else {
            controllerSettings.acquisitionTime = [acqTime floatValue];
            [self doDataCollection];
        }
        return;
    }
    if ([cmd containsString:@"get_data_file"]) {
        NSLog(@"Got get_data_file");
        [self returnPluginResponse:@{@"type":@"filename",@"fname":self.last_saved_file} keepOpen:NO];
        return;
    }
    if ([cmd containsString:@"do_dark_reference"]) {
        NSLog(@"Got do_dark_reference");
        if (!self.demoMode) {
            [self doDarkReference];
        }
        else {
            [self returnPluginResponse:@{@"type":@"status",@"status":@"acquiring"} keepOpen:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.timerDemoFunctions = [ NSTimer scheduledTimerWithTimeInterval:3.0
                                                                            target:self
                                                                          selector:@selector(timeoutTimerDemoMode:)
                                                                          userInfo:@"dark_reference"
                                                                           repeats:NO];
            });
        }
        return;
    }
    if ([cmd containsString:@"do_mastering"]) {
        NSLog(@"Got do_mastering");
        NSString* mv = [NSString stringWithFormat:@"%f", controllerSettings.sensor.mv];
        if (msgArray.count > 1 && [@"reset" caseInsensitiveCompare:msgArray[1]] == NSOrderedSame) {
            mv = nil;
        }
        if (!self.demoMode) {
            [self masterDeviceWithValue:mv];
        }
        else {
            [self returnPluginResponse:@{@"type":@"status",@"status":@"mastering_in_progress"} keepOpen:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.timerDemoFunctions = [ NSTimer scheduledTimerWithTimeInterval:3.0
                                                                            target:self
                                                                          selector:@selector(timeoutTimerDemoMode:)
                                                                          userInfo:@"mastering"
                                                                           repeats:NO];
            });
        }
        return;
    }
    if ([cmd containsString:@"set_measuring_rate"]) {
        NSLog(@"Got set_measuring_rate");
        if (!self.demoMode) {
            [self setMeasurementRate:[msgArray objectAtIndex:1] withAlert:true];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                                      [NSNumber numberWithFloat:5.0], @"timeout",
                                      @"nothing", @"nextProcess",nil];
                self.timerWaiting = [ NSTimer scheduledTimerWithTimeInterval:1.0
                                                                      target:self
                                                                    selector:@selector(timeoutWaitTimer:)
                                                                    userInfo:info
                                                                     repeats:YES];
            });
        }
        else {
            controllerSettings.measurementRate = [[msgArray objectAtIndex:1] floatValue];
            NSString* demoMsg = @"measurement_rate";
            dispatch_async(dispatch_get_main_queue(), ^{
                self.timerDemoFunctions = [ NSTimer scheduledTimerWithTimeInterval:3.0
                                                                            target:self
                                                                          selector:@selector(timeoutTimerDemoMode:)
                                                                          userInfo:demoMsg
                                                                           repeats:NO];
            });
        }
        return;
    }
    if ([cmd containsString:@"set_threshold"]) {
        NSLog(@"Got set_threshold");
        if (!self.demoMode) {
            [self setThreshold:[msgArray objectAtIndex:1]];
        }
        else {
            controllerSettings.intensityThreshold = [[msgArray objectAtIndex:1] floatValue];
            NSString* demoMsg = @"threshold";
            dispatch_async(dispatch_get_main_queue(), ^{
                self.timerDemoFunctions = [ NSTimer scheduledTimerWithTimeInterval:3.0
                                                                            target:self
                                                                          selector:@selector(timeoutTimerDemoMode:)
                                                                          userInfo:demoMsg
                                                                           repeats:NO];
            });
        }
        return;
    }
    if ([cmd containsString:@"set_manual_override"]) {
        controllerSettings.overrideRateAndIntensity = [[msgArray objectAtIndex:1] containsString:@"true"];
        NSLog(@"Got set_manual_override %@", controllerSettings.overrideRateAndIntensity ? @"YES" : @"NO");
        return;
    }
    if ([cmd containsString:@"set_demo_mode"]) {
        NSString* mode = [msgArray objectAtIndex:1];
        NSLog(@"Got set_demo_mode:%@", mode);
        NSString* msgStr;
        if ([mode containsString:@"true"]) {
            self.demoMode = true;
            msgStr = @"App is now in demo mode.";
        }
        else {
            self.demoMode = false;
            msgStr = @"App is now in production mode.";
        }
        [self returnPluginResponse:@{@"type":@"alert",@"message":msgStr} keepOpen:YES];
        if (!self.demoMode) {
            [self initializeSensor];
        }
        return;
    }
    if ([cmd containsString:@"set_connection_mode"]) {
        NSString* mode = [msgArray objectAtIndex:1];
        NSLog(@"Recieved set_connection_mode:%@",mode);
        NSString* msgStr;
        if ([mode containsString:@"serial"]) {
            self.connectionMode = @"serial";
            msgStr = @"App is now using serial connection.";
        }
        else {
            self.connectionMode = @"ethernet";
            msgStr = @"App is now using ethernet connection.";
        }
        [self initializeSensor];
        [self returnPluginResponse:@{@"type":@"alert",@"message":msgStr} keepOpen:YES];
        return;
    }
    if ([cmd containsString:@"shutdown"]) {
        exit(0);
    }
    if ([cmd containsString:@"get_version"]) {
        if (self.pState == notReady) {
            [self initializeSensor];
        }
        NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        [self returnPluginResponse:@{@"type":@"version",@"version":appVersion} keepOpen:YES];
        return;
    }
    if ([cmd containsString:@"get_sensor_parameters"]) {
        NSDictionary* jsonDict = @{@"type":@"sensor_params", @"master_fixture_height":[NSString stringWithFormat:@"%f", controllerSettings.sensor.hmf], @"mastering_value":[NSString stringWithFormat:@"%f", controllerSettings.sensor.mv], @"master_offset":[NSString stringWithFormat:@"%f", controllerSettings.sensor.mo], @"sensor_selection":controllerSettings.sensor.name, @"sensor_length":[NSString stringWithFormat:@"%f", controllerSettings.sensor.length], @"start_measurement_range":[NSString stringWithFormat:@"%f", controllerSettings.sensor.smr], @"sensor_measurement_range":[NSString stringWithFormat:@"%f", controllerSettings.sensor.mr]};
        [self returnPluginResponse:jsonDict keepOpen:NO];
        return;
    }
    if ([cmd containsString:@"set_sensor_parameters"]) {
        NSString* mfh = [msgArray objectAtIndex:1];
        NSString* mval = [msgArray objectAtIndex:2];
        NSString* mo = [msgArray objectAtIndex:3];
        NSString* sensor;
        NSString* sensorLength;
        NSString* smr;
        NSString* mr;
        if ([msgArray count] > 4) {
            sensor = [msgArray objectAtIndex:4];
            if ([msgArray count] > 5) {
                sensorLength = [msgArray objectAtIndex:5];
                if ([msgArray count] > 6) {
                    smr = [msgArray objectAtIndex:6];
                    if ([msgArray count] > 7) {
                        mr = [msgArray objectAtIndex:7];
                    }
                }
            }
        }
        //TODO must figure out how to safely set the MR
        //float sensor_mr = controllerSettings.sensor.mr;
        controllerSettings.sensor = [[SensorSettings alloc] initWithName:sensor lengthInches:[sensorLength floatValue] measurementRangeMM:[mr floatValue] startOfMeasurementRangeMM:[smr floatValue] masterFixtureHeightInches:[mfh floatValue] masteringValueMM:[mval floatValue] masteringOffsetInches:[mo floatValue]];
        
        [self returnPluginResponse:@{@"type":@"alert",@"message":@"Sensor Parameters are Set."} keepOpen:NO];
        return;
    }
    else {
        NSLog(@"Got %@",msg);
    }
}

- (void)doDataCollection {
    self.startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
    int num_sets = 0;
    float nSets = 0.0;
    float meas_rate = controllerSettings.measurementRate * 1000; // measurement_rate is in kHz.
    if ([self.connectionMode containsString:@"ethernet"]) {
        // 100 samples/frame, "* 1000" converts the measurement rate from kHz to Hz.
        nSets = meas_rate * controllerSettings.acquisitionTime / 100.0;
    }
    if ([self.connectionMode containsString:@"serial"]) {
        // "* 1000" converts the measurement rate from kHz to Hz.
#ifdef SERIAL_SEND_TIMESTAMP
        float bytesPerDataSet = 9.0;  // (3 bytes each, Inten., Disp., & Timestamp)
#elif defined(SEND_DISPLACEMENT_ONLY)
        float bytesPerDataSet = 3.0;  // (3 bytes for displacement)
#else
        float bytesPerDataSet = 6.0;  // (3 bytes each, Inten., Disp.)
#endif
        float dataSetsPerFrame = (float)RX_FORWARD_COUNT/bytesPerDataSet; // 64 bytes/Rx frame
        nSets = meas_rate * controllerSettings.acquisitionTime / dataSetsPerFrame;
    }
    num_sets = ceil(nSets); // Round up.
    self.progress = 0.0;
    
    if (!self.demoMode) {
        // now call collect data with the acquisition time.
        // Serial mode reports progress through a timer.
        if ([self.connectionMode containsString:@"serial"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Setting up progress timer. Main Thread = %d", [NSThread isMainThread]);
                self.timerProgress = [ NSTimer scheduledTimerWithTimeInterval:1.0
                                                                       target:self
                                                                     selector:@selector(timeoutProgressTimer:)
                                                                     userInfo:nil
                                                                      repeats:YES];
            });
        }
        [self collectData:num_sets casingThickness:[self.metaData.casing_thickness floatValue]];
    }
    else {
        [self returnPluginResponse:@{@"type":@"status",@"status":@"acquiring"} keepOpen:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.timerDemoFunctions = [ NSTimer scheduledTimerWithTimeInterval:3.0
                                                                        target:self
                                                                      selector:@selector(timeoutTimerDemoMode:)
                                                                      userInfo:@"collect_data"
                                                                       repeats:NO];
        });
    }
}

// Should be self-explanitory.
- (void)clearData {
    [self.datasetIds removeAllObjects];
    [self.times removeAllObjects];
    [self.displacements removeAllObjects];
    [self.point_counts removeAllObjects];
    [self.intensities removeAllObjects];
    if (self.byteBuffer != nil) {
        for (int i=0; i<BYTE_BUFFER_SIZE; i++) self.byteBuffer[i] = 0;
    }
}

// The collectData function is patterned after the e4PtTool python function
// named collect_data and tries to accomplish the same thing.
- (void)collectData:(int)num_sets casingThickness:(float)casing_thicknesss {
    NSLog(@"@collectData: num_sets = %d", num_sets);
    // Update the status in the HTML page.
    [self returnPluginResponse:@{@"type":@"status",@"status":@"acquiring"} keepOpen:YES];

    self.num_pts_max = 110;
    self.current_data_set_id = 0;
    self.previous_data_set_id = 0;
    self.set_count = 0;
    self.data_index = 0;
    self.num_sets = num_sets;
    NSString* tmpf = [NSString stringWithFormat:@"%.4f",casing_thicknesss];
    self.metaData.casing_thickness = tmpf;

    // Clear data arrays.
    if (self.displacements.count > 0) {
        [self clearData];
    }

    if ([self.connectionMode containsString:@"ethernet"]) {
        // Connect the device to collect the data.
        [self.telnetCmds addObject:@"OUTPUT ETHERNET\n"];
        [self sendTelnetCommand];
        [self connectDevice:self.ipAddress port:self.dataPort];
    }
    if ([self.connectionMode containsString:@"serial"]) {
        [self.telnetCmds addObject:@"OUTPUT RS422\n"];
        [self sendTelnetCommand];
    }
    self.pState = collectingDataInProgress;
    self.testTime = 0.0;
}

#pragma mark - TCPSocketDelegate

- (void)stream:(NSStream *)inStream handleEvent:(NSStreamEvent)streamEvent {
    
    if (self.demoMode) return;  // Do nothing in demo mode.

    dispatch_async(self.networkQueue, ^{
        NSStream* theStream = inStream;
        
        NSLog(@"Processing stream, stream event %lu", (unsigned long)streamEvent);
        
        NSNumber* port = [theStream propertyForKey:(__bridge NSString*)kCFStreamPropertySocketRemotePortNumber];
        if ([port isKindOfClass:[NSNumber class]]) {
            NSLog(@"port: %d",[port intValue]);
        }
        
        // there may be parallel streams active
        // the stream may be a live data stream
        // or it may be a simple check connection (probe) stream
        // Determine which it is and process:
        
        // If the port is 1024, this is the data stream.
        // If the port is 23, this is the telnet stream.
        
        BOOL dataStreamFound = NO;
        BOOL telnetStreamFound = NO;
        
        //int i = 0;
        BOOL foundInputDataS = NO;
        BOOL foundOutputDataS = NO;
        BOOL foundInputTelnetS = NO;
        BOOL foundOutputTelnetS = NO;
        
        if([port intValue] == DATA_PORT){
            foundInputDataS = (self.inputDataStream == theStream);
            foundOutputDataS = (self.outputDataStream == theStream);
            dataStreamFound = foundOutputDataS || foundInputDataS;
        }
        else if ([port intValue] == TELNET_PORT) {
            foundInputTelnetS = (self.inputTelnetStream == theStream);
            foundOutputTelnetS = (self.outputTelnetStream == theStream);
            telnetStreamFound = foundOutputTelnetS || foundInputTelnetS;
        }
        NSLog(@"dataStreamFound = %d; telnetStreamFound = %d",dataStreamFound,telnetStreamFound);
        
        if(dataStreamFound || telnetStreamFound){
            // NSStreamEvents:
            // NSStreamEventNone = 0
            // NSStreamEventOpenCompleted = 1
            // NSStreamEventHasBytesAvailable = 2
            // NSStreamEventHasSpaceAvailable = 4
            // NSStreamEventErrorOccurred = 8
            // NSStreamEventEndEncountered = 16
            //NSLog(@"working with data stream, ip address = %@",self.ipAddress);
            
            switch (streamEvent) {
                case NSStreamEventHasSpaceAvailable:
                NSLog(@"NSStreamEventHasSpaceAvailable.");
                break;
                case NSStreamEventNone:
                NSLog(@"NSStreamEventNone.");
                break;
                case NSStreamEventOpenCompleted:
                {
                    NSLog(@"NSStreamEventOpenCompleted.");
                    NSLog(@"  foundInputDataS: %d; foundOutputDataS: %d", foundInputDataS, foundOutputDataS);
                    if(foundInputDataS) NSLog(@"  stream is an input data stream");
                    if(foundOutputDataS) NSLog(@"  stream is an output data stream");
                    if(foundInputTelnetS) NSLog(@"  stream is an input telnet stream");
                    if(foundOutputTelnetS) NSLog(@"  stream is an output telnet stream");
                    
                    if(dataStreamFound)  self.dataStreamIsOpen = YES;
                    if(telnetStreamFound) self.telnetStreamIsOpen = YES;
                    
                    break;
                }
                case NSStreamEventHasBytesAvailable:
                {
                    if ((self.dataStreamIsOpen == NO) && ([port intValue] == self.dataPort)) {
                        break;
                    }
                    if ((self.telnetStreamIsOpen == NO) && ([port intValue] == self.telnetPort)) {
                        break;
                    }
                    NSLog(@"NSStreamEventHasBytesAvailable");
                    NSThread* thrd = [NSThread currentThread];
                    NSLog(@"Thread: %@; isMainThread: %d",[thrd debugDescription], [NSThread isMainThread]);
                    if(foundInputDataS) NSLog(@"  stream is an input data stream");
                    if(foundOutputDataS) NSLog(@"  stream is an output data stream");
                    if(foundInputTelnetS) NSLog(@"  stream is an input telnet stream");
                    if(foundOutputTelnetS) NSLog(@"  stream is an output telnet stream");
                    NSLog(@"  TCP process data - %@; %d",[thrd debugDescription], [NSThread isMainThread]);
                    
                    long int len2;
                    uint32_t order_number;
                    uint32_t serial_number;
                    uint32_t video_length;
                    uint32_t len_meas_dat;
                    uint32_t num_frames;
                    uint32_t counter;
                    uint32_t timestamp;
                    uint8_t tmpBuf[2048];
                    
                    if ([self.inputDataStream hasBytesAvailable]) {
                        if (self.pState == masteringInProgress) {
                            return; // Don't do anything with incoming data while mastering.
                        }
                        while (self.set_count < self.num_sets) {
                            len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                            if ( strncmp((const char*)tmpBuf, "DATA", 4) == 0 ) {
                                NSLog(@"FOUND DATA! - %f", self.set_count);
                                
                                //for (int i=0; i<5; i++) self.totalBuffer[i] =0;
                                len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                order_number = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                serial_number = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                video_length = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                len_meas_dat = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                num_frames = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                counter = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                NSLog(@"%f: %d, %d, %d, %d, %d, %d", self.set_count, order_number, serial_number, video_length, len_meas_dat, num_frames, counter);
                                
                                for (int i=0; i<num_frames; i++) {
                                    // Read data from which to extract intensity.
                                    len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                    uint32_t intnsty = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                    | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                    float intensity = ((intnsty & 0x7FF) / 1024.0) * 100.00;
                                    
                                    // Read data from which to extract distance.
                                    len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                    uint32_t dVal = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                    | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                    float displacement = 0.0;
                                    NSString* error_msg = @"";
                                    if (dVal > 2147483392) {
                                        error_msg = @"Error ";
                                        if (dVal == 2147483396) {
                                            error_msg = [error_msg stringByAppendingString:@"No Peak"];
                                        }
                                        if (dVal == 2147483397) {
                                            error_msg = [error_msg stringByAppendingString:@"Peak in front of MR"];
                                        }
                                        if (dVal == 2147483398) {
                                            error_msg = [error_msg stringByAppendingString:@"Peak in back of MR"];
                                        }
                                        if (dVal == 2147483399) {
                                            error_msg = [error_msg stringByAppendingString:@"Measurement cannot be calculated"];
                                        }
                                        if (dVal == 2147483400) {
                                            error_msg = [error_msg stringByAppendingString:@"Measurement is outside representable area"];
                                        }
                                        displacement = OUT_OF_RANGE;
                                    }
                                    else {
                                        displacement = ((float)dVal) * 1e-6;
                                    }
                                    
                                    // Read data from which to extract timestamp.
                                    len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                                    timestamp = tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
                                    | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
                                    
                                    [self.displacements addObject:[NSNumber numberWithFloat:displacement]];
                                    [self.times addObject:[NSNumber numberWithUnsignedInteger:timestamp]];
                                    [self.intensities addObject:[NSNumber numberWithFloat:intensity]];
                                    [self.datasetIds addObject:[NSNumber numberWithInt:(int)self.set_count]];
                                    [self.point_counts addObject:[NSNumber numberWithInteger:num_frames]];
                                    
                                    NSLog(@"%@",[NSString stringWithFormat:@"\n%d: %u, %f, %f", i, timestamp, intensity, displacement]);
                                    
                                    self.data_index += 1;
                                }
                                
                                // num_sets was calculated assuming 100 samples per report.  This is not always correct,
                                // so we account for that here.
                                float set_inc = (float)num_frames / 100.0;
                                
                                self.set_count += set_inc;
                                float prog = (float)self.set_count / (float)self.num_sets;
                                prog = floorf(prog * 10) / 10;  // Round down to the nearest 10 percent
                                NSLog(@"num_sets: %d; set_count: %f; set_inc: %f; prog: %f; num_frames: %d",self.num_sets, self.set_count, set_inc, prog, num_frames);
                                if ( prog > self.progress ) {
                                    self.progress = prog;
                                    NSLog(@"Should report progress: %f", prog);
                                    [self reportProgress];
                                }
                                //NSLog(@"updating progress: %f", self.progress);
                            }
                            //else {
                            //    NSLog(@"  no data");
                            //}
                        }
                        [self disconnectData]; // Stop receiving data
                        self.progress = 1.0;
                        self.set_count = 0;
                        
                        // Load dummy data for testing without a rotor,
                        // but connected to a real sensor.
#ifdef SIMULATED_DATA
                        [self loadCSVFile:@""];
#endif

                        // At this point we should have all the data that was requested.
                        // We need to do any required processing/filtering, save to file,
                        // then bundle it up and send it back through to the javascript.
                        [self returnPluginResponse:@{@"type":@"status",@"status":@"processing"} keepOpen:YES];
                        
                        if (self.pState != clearanceComputationInProgress) {
                            [self returnData:[self computeClearance]];
                        }
                        [self.telnetCmds addObject:@"OUTPUT NONE\n"];
                        [self sendTelnetCommand];
                        
                    } // end of if ([self.inputDataStream hasBytesAvailable])
                    if ([self.inputTelnetStream hasBytesAvailable]) {
                        NSLog(@"Got data on telnet stream");
                        len2 = [self.inputTelnetStream read:tmpBuf maxLength:1024];
                        NSString* tmpStr = [[NSString alloc] initWithBytes:tmpBuf length:len2 encoding:NSUTF8StringEncoding];
                        if (len2 < 2) {
                            // not enough of a string to do anything with.
                            NSLog(@"  Short read: Only read %lu bytes", (unsigned long)tmpStr.length);
                            return;
                        }
                        [self processResponse:tmpStr];
                        
                    }
                    break;
                }
                case NSStreamEventErrorOccurred:
                {
                    NSLog(@"NSStreamEventErrorOccurred.");
                    NSError* error = [theStream streamError];
                    NSString* errorMessage = [NSString stringWithFormat:@"%@ (Code = %ld)",
                                              [error localizedDescription],
                                              (long)[error code]];
                    errorMessage = [NSString stringWithFormat:@"Error: %@",errorMessage];
                    NSLog(@"  %@",errorMessage);
                    if ([errorMessage containsString:@"Broken pipe"] && ([port intValue] ==  self.telnetPort)) {
                        [self disconnectTelnet]; // clean things up.
                        [self connectDevice:self.ipAddress port:self.telnetPort];
                    }
                    [self returnPluginResponse:@{@"type":@"status",@"status":errorMessage} keepOpen:NO];
                    break;
                }
                case NSStreamEventEndEncountered:
                {
                    NSLog(@"NSStreamEventEndEncountered for port = %@", port);
                    [theStream close];
                    [theStream removeFromRunLoop:self.networkRunLoop forMode:NSDefaultRunLoopMode];
                    theStream = nil;
                    
                    if ([port intValue] == TELNET_PORT) {
                        self.inputTelnetStream = nil;
                        self.outputTelnetStream = nil;
                    }
                    else if ([port intValue] == DATA_PORT) {
                        self.inputDataStream = nil;
                        self.outputDataStream = nil;
                    }
                    
                    break;
                }
                default:
                NSLog(@"Unknown event");
                break;
                
            } // switch
        } // if datastream found
    });
}

- (void)processResponse:(NSString*)rxData {
    NSLog(@"@processResponse");
    NSString* prompt = @"";
    if (rxData.length > 1) {
        prompt = [rxData substringFromIndex: [rxData length] - 2];
        NSLog(@"prompt: %@",prompt);
    }
    else {
        return;
    }
        
    if ([rxData containsString:@"IFC2422"]) {
        NSLog(@"Controller is IFC2422");
        self.controllerType = @"IFC2422";
        [self.telnetCmds addObject:@"SENSORINFO_CH01\n"];
        [self sendTelnetCommand];
    }
    if ([rxData containsString:@"IFC2421"]) {
        NSLog(@"Controller is IFC2421");
        self.controllerType = @"IFC2421";
        [self.telnetCmds addObject:@"SENSORINFO\n"];
        [self sendTelnetCommand];
    }
    if ([rxData containsString:@"Measurement range:"]) {
        NSString* measurementRange = [[rxData componentsSeparatedByString:@"\r\n"][3] substringFromIndex:18];
        controllerSettings.sensor.mr = [[measurementRange substringToIndex:[measurementRange length]-2] floatValue];
        NSLog(@"Sensor Measurement Range is %f", controllerSettings.sensor.mr);
    }
    if ([prompt containsString:@"->"]) {
        NSLog(@"Got telnet prompt: telnetCmds.count = %lu",(unsigned long)self.telnetCmds.count);
        self.telnetIsReady = true;
        if (self.pState == initializationInProgress) {
            if (self.telnetCmds.count == 0) {
                [self processComplete:@"connected"];
            }
        }
        if (self.pState == setMeasurementRateInProgress) {
            if (self.telnetCmds.count == 0) {
                NSLog(@"Set measurement rate complete");
                [self processComplete:@"connected"];
            }
        }
        if (self.pState == setThresholdInProgress) {
            NSLog(@"Set threshold complete");
            [self processComplete:@"connected"];
        }
        if (self.pState == darkReferenceInProgress) {
            if (self.telnetCmds.count == 0) {
                NSLog(@"Dark Correction Complete.");
                [self processComplete:@"connected"];
            }
        }
        if (self.pState == clearanceComputationInProgress) {
            NSLog(@"Clearance computation complete.");
            [self processComplete:@"connected"];
        }
        if (self.pState == masteringInProgress) {
            // Check for mastering commands still in the queue.  If there are none, then
            // mastering is complete.  If there are still mastering commands in the queue
            // then mastering is not complete.
            if (self.telnetCmds.count == 0) {
                NSLog(@"Mastering Complete.");
                [self processComplete:@"done_mastering"];  // This will set pState = ready.
            }
        }
    }
    NSLog(@"Returning from processResponse");
}

- (void)returnData:(ClearanceData*)clearanceData {
    NSError* error;
    NSData* jsonData;
    // If we've done a calibrated acquisition we pass back the filtered, calibrated data.
    // If we've done an uncalibrated acquisition we pass back the raw, uncalibrated data.
    if (self.calibratedAcquire) {
        jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.filtered options:NSJSONWritingSortedKeys error:&error];
    }
    else {
        jsonData = [NSJSONSerialization dataWithJSONObject:self.displacements options:NSJSONWritingSortedKeys error:&error];
    }
    NSString *dispJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:self.intensities options:NSJSONWritingSortedKeys error:&error];
    NSString *intensJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.locations options:NSJSONWritingSortedKeys error:&error];
    NSString *minLocsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.bladeClearances options:NSJSONWritingSortedKeys error:&error];
    NSString *bladeClrsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.quality options:NSJSONWritingSortedKeys error:&error];
    NSString *clrQualityJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
    NSString* clearance = [NSString stringWithFormat:@"%f", clearanceData.clearance];
    NSString* stg_max_clr = [NSString stringWithFormat:@"%f", clearanceData.max];
    NSString* stg_min_clr = [NSString stringWithFormat:@"%f", clearanceData.min];
    NSString* stg_med_clr = [NSString stringWithFormat:@"%f", clearanceData.median];
    NSString* stg_clr_std = [NSString stringWithFormat:@"%f", clearanceData.std];
    NSString* overall_avg = [NSString stringWithFormat:@"%f", clearanceData.averageDisplacement];

    NSDictionary* jsonDataDict = @{@"type":@"data",
                                   @"data":dispJSONString,
                                   @"intensity":intensJSONString,
                                   @"locs":minLocsJSONString,
                                   @"gaps":bladeClrsJSONString,
                                   @"quality":clrQualityJSONString,
                                   @"clearance":clearance,
                                   @"casing_thickness":self.metaData.casing_thickness,
                                   @"spacer_thickness":self.metaData.spacer_thickness,
                                   @"max_clr":stg_max_clr,
                                   @"min_clr":stg_min_clr,
                                   @"med_clr":stg_med_clr,
                                   @"std_clr":stg_clr_std,
                                   @"overall_avg":overall_avg,
                                   @"date":dateStr,
                                   @"intensity_threshold":[NSString stringWithFormat:@"%f", controllerSettings.intensityThreshold],
                                   @"measurement_rate":[NSString stringWithFormat:@"%f", controllerSettings.measurementRate
                                   ]};
    [self returnPluginResponse:jsonDataDict keepOpen:NO];
    [self saveCSVFile:@"" clearanceData:clearanceData];
    [self clearData];
}

- (void)processComplete:(NSString*)statusMsg {
    if (self.pState == setMeasurementRateInProgress) {
        NSString* msgStr = [NSString stringWithFormat:@"Measurement rate set to %.3f kHz.", controllerSettings.measurementRate];
        [self returnPluginResponse:@{@"type":@"alert",@"message":msgStr} keepOpen:YES];
    }
    else if (self.pState == setThresholdInProgress) {
        NSString* msgStr = [NSString stringWithFormat:@"Threshold is set to %.3f.", controllerSettings.intensityThreshold];
        [self returnPluginResponse:@{@"type":@"alert",@"message":msgStr} keepOpen:NO];
    }
    else if (self.pState == darkReferenceInProgress) {
        return; // Dark referencing is followed by data collection
    }
    else {
        [self returnPluginResponse:@{@"type":@"status",@"status":statusMsg} keepOpen:NO];
    }
    
    self.pState = ready;
}

- (ClearanceData*)computeClearance {
    self.pState = clearanceComputationInProgress;
    
    MeasurementData* measurementData = [MeasurementData new];
    [measurementData.displacements setArray:self.displacements];
    [measurementData.intensities setArray:self.intensities];
    self->postProcess.outOfRange = OUT_OF_RANGE;
    
    float offsetAdjustment = 0.0;
    if (self.calibratedAcquire)
        offsetAdjustment = [controllerSettings.sensor calculateOffsetAdjustment:[self.metaData.spacer_thickness floatValue] casingThickness:[self.metaData.casing_thickness floatValue]];
    return [self->postProcess computeClearance:measurementData bladeCount:[self.metaData.num_blades intValue] usingAdjustmentFactor:offsetAdjustment];
}

// loadCSVFile should never be used in the field, but is here to allow
// for debugging when a rotor is not available.  It reads a CSV file
// and populates the data structures as though the data had come from
// the sensor.
- (bool)loadCSVFile:(NSString*)filePath {
    [self clearData]; // Clear everything out to re-write it from CSV file.
    NSString* fName = @"test_data"; // test data file
    NSString* csvPath = @"";
    if (filePath.length == 0) {
        csvPath = [[NSBundle mainBundle] pathForResource:fName ofType:@"csv"];
    }
    else {
        csvPath = filePath;
    }
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:csvPath]) {
        NSLog(@"Found CSV file.");
    }
    else {
        NSLog(@"CSV file not found.");
        return false;
    }
    NSString* fullFile = [NSString stringWithContentsOfFile:csvPath encoding:NSUTF8StringEncoding error:nil];
    NSArray* rows = [fullFile componentsSeparatedByString:@"\n"]; // this breaks up the file into rows
    int r = 0;
    //index,pt_count,dataset_id,timestamp,displacement,filtered,intensity,casing_thickness
    for (NSString* row in rows) {
        if (r ==0 ) {
            r++;
            continue; // skip the header row in the file
        }

        NSArray* lineArray = [row componentsSeparatedByString:@","]; // Split up the line
        if (lineArray.count < 8) {
            NSLog(@"Skipping line %d",r);
            r++;
            continue;
        }
        if (r == 1) {
            NSString* casingThickness = [lineArray objectAtIndex:7]; // Get casing thickness once.
            if ([casingThickness floatValue] > 0.0) self.metaData.casing_thickness = casingThickness;
            self.metaData.casing_thickness = [self.metaData.casing_thickness stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        }
        NSString* tmp = [lineArray objectAtIndex:4];
        [self.displacements addObject:[NSNumber numberWithFloat:[tmp floatValue]]];
        tmp = [lineArray objectAtIndex:2];
        [self.datasetIds addObject:[NSNumber numberWithInteger:[tmp intValue]]];
        tmp = [lineArray objectAtIndex:3];
        unsigned int t = (unsigned int)[tmp intValue];
        [self.times addObject:[NSNumber numberWithUnsignedInteger:t]];
        tmp = [lineArray objectAtIndex:1];
        [self.point_counts addObject:[NSNumber numberWithInteger:[tmp intValue]]];
        tmp = [lineArray objectAtIndex:6];
        [self.intensities addObject:[NSNumber numberWithFloat:[tmp floatValue]]];
        r++;
    }
    NSLog(@"Completed parsing CSV file.");
    return true;
}

- (void)saveCSVFile:(NSString*)fileName clearanceData:(ClearanceData*)clearanceData {
    // If called with no displacements, don't write a file, just return;
    if (self.displacements.count == 0) return;
    // Get the date & time for the filename.
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
    dateStr = [dateStr substringFromIndex:2]; // Remove char 0-1, to get a shortened 2-digit year.
    // Get path to documents directory
    NSString* docPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        docPath = [paths objectAtIndex:0];
    }
    // Create a sub-directory for this turbine's data if it doesn't exist.
    NSString* turbineDir = [NSString stringWithFormat:@"%@/%@",docPath,self.metaData.serial_number];
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError* error;
    if (![fm fileExistsAtPath:turbineDir]) {
        [fm createDirectoryAtPath:turbineDir withIntermediateDirectories:NO attributes:nil error:&error]; //Create folder
    }
    // Create a generic data sub-directory if it doesn't exist.
    NSString* dataDir = [NSString stringWithFormat:@"%@/data",docPath];
    if (![fm fileExistsAtPath:dataDir]) {
        [fm createDirectoryAtPath:dataDir withIntermediateDirectories:NO attributes:nil error:&error]; //Create folder
    }
    // Create a shortened position string: Top = T, Bottom = B, Right = R, Left = L, Top Left = TL, etc.
    NSString* pos = @"";
    if (self.metaData.position.length > 0) {
        NSArray* posArr = [self.metaData.position componentsSeparatedByString:@"_"];
        for (NSString* p in posArr) {
            pos = [NSString stringWithFormat:@"%@%@",pos,[p substringToIndex:1]]; // Use the first char from each word in the position string.
        }
    }
    // Create a file name as sn_stage_pos_state_datetime.csv.
    // If there is no serial number, just save to the data folder.
    NSString* csvFileName = [[NSString alloc] init];
    if (fileName.length == 0) {
        if (self.metaData.serial_number.length == 0) {
            csvFileName = [NSString stringWithFormat:@"%@/%@",
                           dataDir,
                           [NSString stringWithFormat:@"data_%@_mm.csv",dateStr]];
        }
        else {
            NSString* fName = [NSString stringWithFormat:@"%@_%@_%@_%@_mm.csv",
                               self.metaData.serial_number, self.metaData.stage,
                               pos, dateStr];
            csvFileName = [NSString stringWithFormat:@"%@/%@", turbineDir, fName];
        }
        // Change the data-time string format in the filename.
        csvFileName = [csvFileName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        csvFileName = [csvFileName stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    }
    else {
        csvFileName = [NSString stringWithFormat:@"%@/%@", docPath, fileName];
    }
    self.last_saved_file = csvFileName;
    // Now write the file...
    // Open the output file.
    NSFileHandle *handle;
    if ([fm fileExistsAtPath:csvFileName]) {
        NSLog(@"Deleting existing CSV file...");
        NSError* error;
        BOOL success = [fm removeItemAtPath:csvFileName error:&error];
        if (success) {
            NSLog(@"   Existing CSV file removed.");
        }
        else {
            NSLog(@"   Failed to remove existing CSV File.");
            NSLog(@"   Error message: %@", [error localizedDescription]);
        }
    }
    NSLog(@"Creating empty CSV file...");
    BOOL success = [fm createFileAtPath:csvFileName contents:nil attributes:nil];
    if (success) {
        NSLog(@"   Created CSV File %@.", csvFileName);
    }
    else {
        NSLog(@"   Failed to create CSV File %@.", csvFileName);
    }
    handle = [NSFileHandle fileHandleForWritingAtPath:csvFileName];
    [handle truncateFileAtOffset:[handle seekToEndOfFile]];
    // Write the header line
    NSString* dataStr = [NSString stringWithFormat:@"index,pt_count,dataset_id,timestamp,displacement,filtered,intensity,casing_thickness,avg_disp_over_blade,applied_offset\n"];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Write the individual data lines.
    float adjustmentFactor = self.calibratedAcquire ? [controllerSettings.sensor calculateOffsetAdjustment:[self.metaData.spacer_thickness floatValue] casingThickness:[self.metaData.casing_thickness floatValue]] : 0.0;
    for (int i=0; i<self.displacements.count; i++) {
        dataStr =  [NSString stringWithFormat:@"%d,%@,%@,%@,%@,%@,%@,%@,%@,%f\n",
                    i,[self.point_counts objectAtIndex:i],[self.datasetIds objectAtIndex:i],
                    [self.times objectAtIndex:i], [self.displacements objectAtIndex:i],
                    [clearanceData.clearances objectAtIndex:i], [self.intensities objectAtIndex:i],
                    self.metaData.casing_thickness, [clearanceData.filtered objectAtIndex:i], adjustmentFactor];
        [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    //  Write the sensor parameters and app version to the CSV file.
    dataStr = [NSString stringWithFormat:@"\n - Sensor Parameters,,,,,,,,,\nSensor Selection,Sensor Length (in),SMR (mm),Mastering Fixture Height (in),Mastering Value (mm),Master Offset (in),Spacer Thickness (in),Shelf Threshold (mm),Applied Offset Formula,\n%@,%f,%f,%f,%f,%f,%@,%f,%@,\n",
               controllerSettings.sensor.name,
               controllerSettings.sensor.length,
               controllerSettings.sensor.smr,
               controllerSettings.sensor.hmf,
               controllerSettings.sensor.mv,
               controllerSettings.sensor.mo,
               self.metaData.spacer_thickness,
               clearanceData.shelfThreshold,
               controllerSettings.sensor.offsetAdjustmentFormula];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];

    NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    dataStr = [NSString stringWithFormat:@"\n - Created by e4PtTool version %@,,,,,,,,,",appVersion];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];

    [handle closeFile];
}

//
// RS232 Serial Cable additions
//

// For IFC242x controller user 8N1 configuration.
- (void)setupSerialCableAndCommThread {
    NSLog(@"@setupSerialCableAndCommThread");
    
    if (self.byteBuffer == nil) {
        self.byteBuffer = (uint8_t *) malloc(BYTE_BUFFER_SIZE);
        self.readPtr = self.byteBuffer;
        self.writePtr = self.byteBuffer;
        self.val1Ptr = (uint32_t*)self.readPtr;
    }
    
    //[self.rscMgr enableExternalLogging:true];
    //[self.rscMgr enableTxRxExternalLogging:true];
    
    self.dataSizeType = SERIAL_DATABITS_8;
    self.parityType =     SERIAL_PARITY_NONE;
    self.stopBitsType = STOPBITS_1;
    self.rts = RXFLOW_NONE;
    self.cts = RXFLOW_NONE;

    self.baudRate = 460800; // Slower cables only do 115200

    // set baud rate, data bits, parity, and stop bits
    [self.rscMgr setBaud:self.baudRate];
    [self.rscMgr setDataSize:self.dataSizeType];
    [self.rscMgr setParity:self.parityType];
    [self.rscMgr setStopBits:self.stopBitsType];

    serialPortConfig portCfg;
    [self.rscMgr getPortConfig:&portCfg];
    portCfg.txAckSetting = 1;
    portCfg.rxFlowControl = self.rts;    // set flow control
    portCfg.txFlowControl = self.cts;
    portCfg.rxForwardCount = RX_FORWARD_COUNT;
    portCfg.rxForwardingTimeout = 50; // default = 100;
    [self.rscMgr setPortConfig:&portCfg requestStatus: NO];
        
    // Create and start the comm thread.  We'll use this thread to manage the rscMgr so
    // we don't tie up the UI thread.
    self.networkQueue = dispatch_queue_create("global_network_queue", DISPATCH_QUEUE_SERIAL); // Not DISPATCH_QUEUE_CONCURRENT
    dispatch_async(self.networkQueue, ^{
        [self startCommThread:nil];
    });
}

// start the communication thread
- (void) startCommThread:(id)object {
    NSLog(@"@startCommThread");

    // initialize RscMgr on this thread
    // so it schedules delegate callbacks for this thread
    if (self.rscMgr == nil) {
        self.rscMgr = [[RscMgr alloc] init];
        [self.rscMgr setDelegate:self];
    }
    
    // run the run loop
    if (self.networkRunLoop == nil) {
        NSLog(@"Setting up network runloop");
        self.networkRunLoop = [NSRunLoop currentRunLoop];
        [self.networkRunLoop run];
    }
    //[[NSRunLoop currentRunLoop] run];
}

- (void)sendSerialData:(NSString*)cmd {
    NSLog(@"@sendSerialData: %@",cmd);
    [self.rscMgr writeString:cmd];
}

// bytes are available to be read (user calls read:)
- (void) readBytesAvailable:(UInt32)length {
    //NSString *str = [rscMgr getStringFromBytesAvailable];
    NSData* rxBytes = [self.rscMgr getDataFromBytesAvailable];
    //NSString* str = [[NSString alloc] initWithData:rxBytes encoding:NSASCIIStringEncoding];
    NSString* str = @"";
    
    if ([str length] != 0) {       // avoid outputting empty strings
        //str = [str stringByAppendingString:@"  - Rx"];
        NSLog(@"Got string: %@",str);
    }
    if (rxBytes.length != 0) {
        NSLog(@"Got %lu bytes.", (unsigned long)rxBytes.length);
        [self parseSerialData:rxBytes];
    }
}

- (void)parseSerialData:(NSData*)data {
    NSLog(@"@parseSerialData: pState = %d", self.pState);
    
    if ((self.pState == masteringInProgress) ||
        (self.pState == darkReferenceInProgress) ||
        (self.pState == initializationInProgress) ||
        (self.pState == setMeasurementRateInProgress) ||
        (self.pState == setThresholdInProgress)) {
        NSString* response = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSLog(@"parseSerial: Got: %@",response);
        [self processResponse:response];
        return;
    }
    else {
        if (self.pState != collectingDataInProgress) {
            if (data.length >= 4) {
                NSString* response = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                if (response != nil) {
                    if ([response containsString:@"->"]) {
                        if ((self.pState == halted) || (self.pState == clearanceComputationInProgress)) {
                            self.delayResponse = true;
                        }
                        else {
                            [self processResponse:response];
                        }
                        return;
                    }
                }
            }
            return;  // if we're not collecting data, return.
        }
    }

    //
    // It has been seen that the number of bytes per read on the serial interface
    // is not consistent.  So we have to count data sets (nominally 64 bytes)
    // in fractional increments.
    //
    float set_inc = data.length/(float)RX_FORWARD_COUNT;
    
    // For receiving serial measurement data...
    if (self.testTime == 0.0) {
        self.testTime = ([[NSDate date] timeIntervalSince1970]) * 1000000;
        NSLog(@"Data collection start time: %f",self.testTime);
    }
    int pt_count = (int)floor((float)(data.length)/9.0); // 9 bytes per data point.
    if (self.set_count < self.num_sets) {
        
        // Copy the data to the buffer in a circular fashion.
        const uint8_t* dPtr = [data bytes];
        uint32_t mask = 0xC0C0C000; // mask of the upper 3 bytes with the expected pattern.
        uint8_t* endPtr = &self.byteBuffer[BYTE_BUFFER_SIZE-1];
        uint32_t v1;
        self.val1Ptr = &v1;
        for (int i=0; i<data.length; i++) {
            *self.writePtr = *dPtr++;
            //advance the write pointer 1 byte forward, wrapping as needed.
            (self.writePtr == endPtr) ? (self.writePtr = self.byteBuffer) : self.writePtr++;
        }
        
        // We shouldn't have to scan through more than 9 bytes to find the data.
        // "AND" the data with the mask and compare to the expected value to find the
        // pattern.  This is for initial synchronization only.
        
        // If we were in sync, check to see if we still are.  It has been known to get out of sync.
        // copy next 4 bytes into v1 to check them.
        uint8_t* fromPtr = self.readPtr;
        uint8_t* toPtr = (uint8_t*)self.val1Ptr;
        for (int i=0; i< 4; i++) {
            *toPtr = *fromPtr;
            (fromPtr == endPtr) ? (fromPtr = self.byteBuffer) : fromPtr++;
            toPtr++;
        }
        int offset = 0;
        if (self.nSync) {
            v1 = v1 & mask;
            bool syncFail = false;
#ifdef SEND_DISPLACEMENT_ONLY
            if (self.nextIFCValue == IFCDisplacement) {
                if (v1 != (uint32_t)0x00804000) {
                    syncFail = true;
                }
            }
#else
            if (self.nextIFCValue == IFCIntensity) {
                if (v1 != (uint32_t)0x00804000) {
                    syncFail = true;
                }
            }
            else if (self.nextIFCValue == IFCDisplacement) {
                if (v1 != (uint32_t)0x00C04000) {
                    syncFail = true;
                }
            }
            else if (self.nextIFCValue == IFCTimestamp) {
                if (v1 != (uint32_t)0x00C04000) {
                    syncFail = true;
                }
            }
#endif
            if (syncFail) {
                self.nSync = false;
                self.val1Ptr = (uint32_t*)self.readPtr;
            }
        }
        if (!self.nSync) {
            for (offset=0; offset<9; offset++) {
                v1 = v1 & mask;
                if (v1 == (uint32_t)0x00804000) {
                    NSLog(@"Found the pattern at offset %d!",offset);
                    // we found the pattern.
                    self.nSync = true;
                    break;
                }
                else {
                    //advance the read pointer 1 byte forward, wrapping as needed.
                    (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++;
                    // copy next 4 bytes into v1 to check them.
                    fromPtr = self.readPtr;
                    toPtr = (uint8_t*)self.val1Ptr;
                    for (int i=0; i< 4; i++) {
                        *toPtr = *fromPtr;
                        (fromPtr == endPtr) ? (fromPtr = self.byteBuffer) : fromPtr++;
                        toPtr++;
                    }
                }
            }
        }
        // readPtr should now be at the start of the data.
        /* Byte printing for debugging
         uint8_t* tmpPtr = self.readPtr;
         printf("Before: Next 8 bytes: ");
         for (int k=0; k<8; k++) {
         printf("%02X ", (0xff & *tmpPtr));
         (tmpPtr == endPtr) ? (tmpPtr = self.byteBuffer) : tmpPtr++;
         }
         printf("\n");
         */
        
        // Subtract the number of bytes we had to skip to get synced.  Add any leftover from previous frames.
        int numBytesLeft = (int)[data length] - offset + self.leftoverBytes;
        int numValues = (int)floor(numBytesLeft/3.0); // 3 bytes per value
        self.leftoverBytes = numBytesLeft - (numValues * 3);
        uint32_t ival = 0;
        uint32_t dval = 0;
        float displacement = 0;
        uint32_t tval = 0;
        NSTimeInterval unixTStamp;
        NSString* logStr = @"";
        for (int j=0; j<numValues; j++) {
            if (self.nextIFCValue == IFCIntensity) {
                ival = 0;
                ival = (uint32_t)(*self.readPtr & 0x3F);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++; // wrap pointer if needed.
                ival = ival | ((*self.readPtr & 0x3F) << 6);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++;
                ival = ival | ((*self.readPtr & 0x3F) << 12);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++;
                NSString* log = [NSString stringWithFormat:@"I:%d: ",ival];
                logStr = [logStr stringByAppendingString:log];
                if (self.pState == collectingDataInProgress) {
                    [self.intensities addObject:[NSNumber numberWithFloat:(float)ival]];
                }
                self.nextIFCValue = IFCDisplacement;
            }
            else if (self.nextIFCValue == IFCDisplacement) {
                dval = 0;
                dval = (uint32_t)(*self.readPtr & 0x3F);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++; // wrap pointer if needed.
                dval = dval | ((*self.readPtr & 0x3F) << 6);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++;
                dval = dval | ((*self.readPtr & 0x3F) << 12);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++;
                // Error checking
                NSString* error_msg = @"";
                if (dval > 262072) {
                    error_msg = @"Error ";
                    if (dval == 262073) {
                        error_msg = [error_msg stringByAppendingString:@"RS422 interface underflow"];
                    }
                    if (dval == 262074) {
                        error_msg = [error_msg stringByAppendingString:@"RS422 interface overflow"];
                    }
                    if (dval == 262075) {
                        error_msg = [error_msg stringByAppendingString:@"Too much data for baud rate"];
                    }
                    if (dval == 262076) {
                        error_msg = [error_msg stringByAppendingString:@"No peak present"];
                    }
                    if (dval == 262077) {
                        error_msg = [error_msg stringByAppendingString:@"Peak in front of measuring range"];
                    }
                    if (dval == 262078) {
                        error_msg = [error_msg stringByAppendingString:@"Peak is behind measuring range"];
                    }
                    if (dval == 262079) {
                        error_msg = [error_msg stringByAppendingString:@"Measuring value cannot be calculated"];
                    }
                    displacement = OUT_OF_RANGE;
                }
                else {
                    displacement = ((float)dval - 98232.0) * controllerSettings.sensor.mr / 65536.0;
                }
                NSString* log = [NSString stringWithFormat:@"D:%f: ", displacement];
                logStr = [logStr stringByAppendingString:log];
                if (self.pState == collectingDataInProgress) {
                    [self.displacements addObject:[NSNumber numberWithFloat:displacement]];
#ifdef SERIAL_SEND_TIMESTAMP
                    self.nextIFCValue = IFCTimestamp; // Next element is the timestamp.
#elif defined(SEND_DISPLACEMENT_ONLY)
                    self.nextIFCValue = IFCDisplacement; // Only do displacement.
                    // Create a timestamp and record it.
                    unixTStamp = ([[NSDate date] timeIntervalSince1970] - self.startTime) * 1000000; // microseconds since start.
                    tval = (uint32_t)floor(unixTStamp);
                    [self.times addObject:[NSNumber numberWithInt:(int)tval]];
                    [self.intensities addObject:[NSNumber numberWithFloat:1.0]];
                    [self.point_counts addObject:[NSNumber numberWithInt:pt_count]];
                    [self.datasetIds addObject:[NSNumber numberWithInt:(int)self.set_count]];
#else
                    self.nextIFCValue = IFCIntensity; // Skip timestamp to increase throughput.
                    // Create a timestamp and record it.
                    unixTStamp = ([[NSDate date] timeIntervalSince1970] - self.startTime) * 1000000; // microseconds since start.
                    tval = (uint32_t)floor(unixTStamp);
                    [self.times addObject:[NSNumber numberWithInt:(int)tval]];
                    [self.point_counts addObject:[NSNumber numberWithInt:pt_count]];
                    [self.datasetIds addObject:[NSNumber numberWithInt:(int)self.set_count]];
#endif
                }
            }
            else if (self.nextIFCValue == IFCTimestamp) {
                tval = 0;
                tval = (uint32_t)(*self.readPtr & 0x3F);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++; // wrap pointer if needed.
                tval = tval | ((*self.readPtr & 0x3F) << 6);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++;
                tval = tval | ((*self.readPtr & 0x3F) << 12);
                (self.readPtr == endPtr) ? (self.readPtr = self.byteBuffer) : self.readPtr++;
                NSString* log = [NSString stringWithFormat:@"T:%d: ",tval];
                logStr = [logStr stringByAppendingString:log];
                if (self.pState == collectingDataInProgress) {
                    [self.times addObject:[NSNumber numberWithInt:(int)tval]];
                    [self.point_counts addObject:[NSNumber numberWithInt:pt_count]];
                    [self.datasetIds addObject:[NSNumber numberWithInt:(int)self.set_count]];
                }
                self.nextIFCValue = IFCIntensity;
            }
        }
        NSLog(@"FrameData: %@",logStr);
        
        /* Byte printing for debugging
         tmpPtr = self.readPtr;
         (tmpPtr == self.byteBuffer) ? (tmpPtr = endPtr) : tmpPtr--; // back up pointer with wrap
         (tmpPtr == self.byteBuffer) ? (tmpPtr = endPtr) : tmpPtr--; // back up pointer with wrap
         (tmpPtr == self.byteBuffer) ? (tmpPtr = endPtr) : tmpPtr--; // back up pointer with wrap
         printf("After: Last 3 and Next 8 bytes: ");
         for (int k=0; k<11; k++) {
         printf("%02X ", (0xff & *tmpPtr));
         (tmpPtr == endPtr) ? (tmpPtr = self.byteBuffer) : tmpPtr++;
         }
         printf("\n");
         */
        
        self.set_count += set_inc;
        self.progress = (float)self.set_count / (float)self.num_sets;

    }
    if (self.set_count >= self.num_sets) {
        if ((self.pState == halted) || (self.pState == clearanceComputationInProgress)) return;
        self.pState = halted;
        self.set_count = 0;
        self.progress = 1.0;
        //
        // disconnectData shuts off the flow of data by sending "OUTPUT NONE"
        // to the RS422 port.  However, this triggers an asynchronous response
        // of "->" from the controller.  This is caught above.  Normally this
        // would call processResponse (setting telnetIsReady=true), which in
        // turn would call processComplete (setting pState=ready).
        // We want to delay all of this until after clearance calculation is
        // complete.
        //
        [self disconnectData];
        [self resetSerialParams];
        NSLog(@"set_count >= num_sets: pState = %d", self.pState);
        NSTimeInterval stop = ([[NSDate date] timeIntervalSince1970]) * 1000000;
        NSLog(@"Data collection stop time: %f",stop);
        NSLog(@"Elapsed Time: %f seconds.", (stop - self.testTime)/1000000.0);

        // Because data sets (Inten.,Disp.,Time) can be split across transmissions, we can end up
        // with different sized arrays here.  We need to trim the larger ones to the size of the
        // smallest.
        unsigned long minArrLen = LONG_MAX;
        if (self.displacements.count < minArrLen) minArrLen = self.displacements.count;
        if (self.intensities.count < minArrLen) minArrLen = self.intensities.count;
        if (self.times.count < minArrLen) minArrLen = self.times.count;
        while (self.displacements.count > minArrLen) [self.displacements removeLastObject];
        while (self.intensities.count > minArrLen) [self.intensities removeLastObject];
        while (self.times.count > minArrLen) [self.times removeLastObject];
        
        // At this point we should have all the data that was requested.
        // We need to do any required processing/filtering, save to file,
        // then bundle it up and send it back through to the javascript.
        [self returnPluginResponse:@{@"type":@"status",@"status":@"processing"} keepOpen:YES];
#ifdef SIMULATED_DATA
        [self loadCSVFile:@""];
#endif
        NSLog(@"Calling compute clearance...");
        [self returnData:[self computeClearance]];
        NSLog(@"Calling returnData");
        NSLog(@"Checking delayResponse");
        self.pState = ready;
        if (self.delayResponse) {
            NSLog(@"Calling delayed processResponse ->");
            [self processResponse:@"->"];
            self.delayResponse = false;
        }
    }
}

- (void)resetSerialParams {
    // Flush the cable Rx buffer to prepare for next acquisition.
    serialPortControl portCtl;
    portCtl.rxFlush = 1;
    portCtl.txFlush = 1;
    [self.rscMgr setPortControl:&portCtl requestStatus:false];
    // Reset all the parameters needed to start serial acquisition from scratch.
    self.nSync = false;
    self.nextIFCValue = IFCIntensity;
    self.readPtr = self.byteBuffer;
    self.writePtr = self.byteBuffer;
    self.set_count = 0;
    self.num_sets = 0;
    self.leftoverBytes = 0;
    if (self.byteBuffer != nil) {
        for (int i=0; i<BYTE_BUFFER_SIZE; i++) self.byteBuffer[i] = 0;
    }
}


// serial port status has changed
// user can call getModemStatus or getPortStatus to get current state
- (void) portStatusChanged {
    NSLog(@"@portStatusChanged");

    int modemStatus = [self.rscMgr getModemStatus];
    static serialPortStatus portStat;
    
    NSLog(@"PortStatus: msr:%02x", modemStatus);
    
    [self.rscMgr getPortStatus:&portStat];

}


// Redpark Serial Cable has been connected and/or application moved to foreground.
// protocol is the string which matched from the protocol list passed to initWithProtocol:
//
// NOTE:  Regardless of what the Redpark SDK document says, this function is NOT called
// when the app goes to the foreground.  To accomplish this I set up a notification in
// the NSNotificationCenter and call this function manually from that notification.
- (void) cableConnected:(NSString *)protocol {
    NSLog(@"@cableConnected");

    self.cableConnected = YES;
    
    // set baud rate, data bits, parity, and stop bits
    [self.rscMgr setBaud:self.baudRate];
    [self.rscMgr setDataSize:self.dataSizeType];
    [self.rscMgr setParity:self.parityType];
    [self.rscMgr setStopBits:self.stopBitsType];
    
    serialPortConfig portCfg;
    [self.rscMgr getPortConfig:&portCfg];
    portCfg.txAckSetting = 1;
    portCfg.rxFlowControl = self.rts;     // set flow control options
    portCfg.txFlowControl = self.cts;
    [self.rscMgr setPortConfig:&portCfg requestStatus: NO];
}

// Redpark Serial Cable was disconnected and/or application moved to background
//
// NOTE:  Regardless of what the Redpark SDK document says, this function is NOT called
// when the app goes to the background.  To accomplish this I set up a notification in
// the NSNotificationCenter and call this function manually from that notification.
- (void) cableDisconnected {
    NSLog(@"@cableDisconnected");
    self.cableConnected = NO;
    self.pState = notReady;
    NSDictionary* jsonDict = @{@"type":@"status",@"status":@"disconnected"};
    NSError* error;
    NSData *jsonData=[NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingSortedKeys error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    [self.plugin.commandDelegate evalJs:[NSString stringWithFormat:@"pluginMessage(%@);",jsonString]];

}

- (void)appMovedToBackground:(NSNotification*)note {
    NSLog(@"App moved to background.");
    // Some stuff to stop the serial cable & prepare it to be reconnected.
    CFRunLoopStop(CFRunLoopGetCurrent());
    self.networkRunLoop = nil;
    self.networkQueue = nil;
    self.rscMgr = nil;
    [self cableDisconnected];
}

- (void)appMovedToForeground:(NSNotification*)note {
    NSLog(@"App moved to foreground.");
}
    
- (void)registerDefaultsFromSettingsBundle {
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        NSLog(@"Could not find Settings.bundle");
        return;
    }
    
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];

    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for(NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        if(key && [[prefSpecification allKeys] containsObject:@"DefaultValue"]) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
}

@end

@interface CDVIFC242x ()

@property (readonly,nonatomic,weak) IFCObjectiveCManager* manager;

@end


@implementation CDVIFC242x

@synthesize manager = _manager;
@synthesize cmd = _cmd;


- (IFCObjectiveCManager*)manager {
    IFCObjectiveCManager* tmpManager = [ IFCObjectiveCManager staticManager ];
    tmpManager.webView = (UIWebView*)self.webView;  // for bidirectional communication
    tmpManager.plugin = self;
    return tmpManager;
}

/**
 * Error Handling
 *
 * All javascript calls into this plugin will initiate a method on a
 * separate thread and will return immediately.
 *
 * In the event of an error, the following callback is called:
 *
 *    function IFC242xErrorCallback( methodName, errorMessage )
 */

/**
 * connectDevice
 *
 * call this plugin method to initiate a device connection. 
 * The function takes two command line arguments:
 *   IP Address
 *   Port
 */
- (void)connectDevice:(CDVInvokedUrlCommand*)command {
  [self.commandDelegate runInBackground:^{
      NSString* ip_address = [command.arguments objectAtIndex:0];
      NSString* portStr = [command.arguments objectAtIndex:1];
      int port = [portStr intValue];
      [ self.manager connectDevice:ip_address port:port ];
   }];
}

/**
 * disconnectDevice
 *
 * call this plugin method to disconnect a specific device. 
 *
 */

- (void)disconnectDevice:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        //NSString* deviceIDString = [command.arguments objectAtIndex:0];
        [ self.manager disconnectDevice ];
    }];
}

/**
 * setDeviceMode
 *
 * call this plugin method to set the acquisition mode of the connected
 * device.  Options are:
 *   Ethernet
 *   RS232
 */
- (void)setDeviceMode:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        NSLog(@"@CDVIFC242x.m::setDeviceMode");
        NSString* modeStr = [command.arguments objectAtIndex:0];
        [ self.manager setDeviceMode:modeStr ];
    }];
}

/**
 * doDarkReference
 */
- (void)doDarkReference:(CDVInvokedUrlCommand*)command {
  [self.commandDelegate runInBackground:^{
      NSLog(@"@CDVIFC242x.m::doDarkReference");
      [self.manager doDarkReference];
  }];
}

/**
 * masterSensor
 */
- (void)masterSensor:(CDVInvokedUrlCommand*)command {
  [self.commandDelegate runInBackground:^{  
      NSLog(@"@CDVIFC242x.m::masterSensor");
      [self.manager masterDevice];
  }];
}

/**
 * collectData
 */
- (void)collectData:(CDVInvokedUrlCommand*)command {
  [self.commandDelegate runInBackground:^{
      NSLog(@"@CDVIFC242x.m::collectData");
      NSString* acqTime = [command.arguments objectAtIndex:0];
      //TODO need to figure out how to do this properly
      //self.manager->controllerSettings.acquisitionTime = [acqTime floatValue];
      // 100 samples/frame, measurement rate is in kHz.
      self.manager.calibratedAcquire = false;
      //float nSets = self.manager->controllerSettings.measurementRate * 1000.0 * [acqTime floatValue] / 100.0;
      //int num_sets = ceil(nSets); // Round up.
      //NSString* csThckns = [command.arguments objectAtIndex:1];
      //[self.manager collectData:num_sets casingThickness:[csThckns floatValue]]; // num_sets, casing thickness.
      [self.manager doDataCollection];
  }];
}

/**
 * setMeasureRate
 */
- (void)setMeasureRate:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        NSLog(@"@CDVIFC242x.m::setMeasureRate");
        NSString* rateStr = [command.arguments objectAtIndex:0];
        [self.manager setMeasurementRate:rateStr withAlert:true];
    }];
}

- (void)messageHandler:(CDVInvokedUrlCommand*)command {
    self.cmd = command;
    NSLog(@"@CDVIFC242x::messageHandler: command.callbackId = %@", command.callbackId);
    [self.commandDelegate runInBackground:^{
        NSLog(@"@CDVIFC242x.m::messageHandler");
        NSString* msgStr = [command.arguments objectAtIndex:0];
        [self.manager messageHandler:msgStr];
    }];
}



@end

#endif
