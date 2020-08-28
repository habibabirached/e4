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

#define SENSOR_MEASUREMENT_RANGE "10.0"

// Hard coded values for RS232 serial cable
// 192 = 64 * 3.  Data seems to come in 64 byte packets and data from
// the IFC242x comes in 3-byte values.
#define BYTE_BUFFER_SIZE 192
#define RX_FORWARD_COUNT 64

// Some defines for the signal processing
#define KERNEL_SIZE 13
#define KERNEL_SIGMA 2.8
#define OUT_OF_RANGE 15.0
#define FILTER_EDGE_SIZE_START 1
#define FILTER_EDGE_SIZE_STOP 1
#define MASTER_VALUE 5.0

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
@property (strong, nonatomic) NSString* frame;
@property (strong, nonatomic) NSString* serial_number;
@property (strong, nonatomic) NSString* stage;
@property (strong, nonatomic) NSString* position;
@property (strong, nonatomic) NSString* casing_thickness;
@property (strong, nonatomic) NSString* spacer_thickness;
@property (strong, nonatomic) NSString* state;
@property (strong, nonatomic) NSString* customer;
@property (strong, nonatomic) NSString* site;
@property (strong, nonatomic) NSString* user;
@property (strong, nonatomic) NSString* units;
@property (strong, nonatomic) NSString* num_blades;
@property (strong, nonatomic) NSString* sensor_measurement_range;
@property (strong, nonatomic) NSString* master_fixture_height;
@property (strong, nonatomic) NSString* blade_width;
@property (strong, nonatomic) NSString* tip_diameter;
@property (strong, nonatomic) NSString* master_offset;
    

-(instancetype)init;

@end

@implementation ScanMetaData

@synthesize frame = _frame;
@synthesize serial_number = _serial_number;
@synthesize stage = _stage;
@synthesize position = _position;
@synthesize casing_thickness = _casing_thickness;
@synthesize spacer_thickness = _spacer_thickness;
@synthesize state = _state;
@synthesize customer = _customer;
@synthesize site = _site;
@synthesize user = _user;
@synthesize units = _units;
@synthesize num_blades = _num_blades;
@synthesize sensor_measurement_range = _sensor_measurement_range;
@synthesize blade_width = _blade_width;
@synthesize tip_diameter = _tip_diameter;
@synthesize master_offset = _master_offset;
@synthesize master_fixture_height = _master_fixture_height;
    

-(instancetype)init {
    self = [super init];
    self.frame = @"";
    self.serial_number = @"";
    self.stage = @"";
    self.position = @"";
    self.casing_thickness = @"";
    self.spacer_thickness = @"";
    self.state = @"";
    self.master_offset = @"";
    return self;
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
- (void)setMeasurementRate:(NSString*)rate withAlert:(bool)tf;
- (void)setThreshold:(NSString*)threshold;
- (void)collectData:(int)num_sets casingThickness:(float)casing_thicknesss;
- (void)doDataCollection:(NSString*)acqTime;

// IP Connection Commands
- (void)sendTelnetCommand;

// RS232 Connection Commands

@end

@interface IFCObjectiveCManager ()

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
@property (strong, nonatomic) NSMutableArray* kernel;
@property (strong, nonatomic) NSRunLoop* networkRunLoop;
@property (strong, nonatomic) dispatch_queue_t networkQueue;

// Variables needed for data collection.
@property (nonatomic) int tmpCounter;
//@property (nonatomic) enum pluginState pState;
@property (nonatomic) int pState;
@property (strong, nonatomic) NSMutableArray* telnetCmds;
@property (strong, nonatomic) NSString* mode; // "ethernet" or "serial"
@property (strong, nonatomic) ScanMetaData* metaData;
@property (strong, nonatomic) NSString* last_saved_file;
@property (strong, nonatomic) NSString* measurement_rate;
@property (strong, nonatomic) NSString* intensityThreshold;

@property (strong, nonatomic) NSMutableArray* datasetIds;
@property (strong, nonatomic) NSMutableArray* times;
@property (strong, nonatomic) NSMutableArray* displacements;
@property (strong, nonatomic) NSMutableArray* filtered;
@property (strong, nonatomic) NSMutableArray* blade_clearances;
@property (strong, nonatomic) NSMutableArray* clearance_quality;
@property (strong, nonatomic) NSMutableArray* point_counts;
@property (strong, nonatomic) NSMutableArray* intensities;
@property (strong, nonatomic) NSMutableArray* min_locs;
@property (nonatomic) float stage_clearance;
@property (nonatomic) float stage_max_clearance;
@property (nonatomic) float stage_min_clearance;
@property (nonatomic) float stage_median_clearance;
@property (nonatomic) float stage_clearance_std;
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

@property (nonatomic) bool demoMode;
@property (nonatomic) bool overrideAutoSettings;
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
//@synthesize interfaceHandle = _interfaceHandle;
@synthesize metaData = _metaData;
@synthesize last_saved_file = _last_saved_file;
@synthesize measurement_rate = _measurement_rate;
@synthesize intensityThreshold = _intensityThreshold;

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
@synthesize filtered = _filtered;
@synthesize blade_clearances = _blade_clearances;
@synthesize stage_clearance = _stage_clearance;
@synthesize clearance_quality = _clearance_quality;
@synthesize point_counts = _point_counts;
@synthesize intensities = _intensities;
@synthesize min_locs = _min_locs;
@synthesize demoMode = _demoMode;
@synthesize overrideAutoSettings = _overrideAutoSettings;
@synthesize startTime = _startTime;
@synthesize testTime = _testTime;
@synthesize delayResponse = _delayResponse;
    
@synthesize kernel = _kernel;

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

@synthesize stage_max_clearance = _stage_max_clearance;
@synthesize stage_min_clearance = _stage_min_clearance;
@synthesize stage_median_clearance = _stage_median_clearance;
@synthesize stage_clearance_std = _stage_clearance_std;
@synthesize calibratedAcquire = _calibratedAcquire;

@synthesize connectionMode = _connectionMode;
@synthesize networkRunLoop = _networkRunLoop;
@synthesize networkQueue = _networkQueue;

- (int)interfaceHandle {
    static int handle = 0;
    
    if (handle == 0) {
      // Create the handle if one doesn't exist.
    }

    return handle;
}

+ (IFCObjectiveCManager*)staticManager {
    
    static IFCObjectiveCManager* _manager = nil;
    
    if (_manager==nil) {
        _manager = [[IFCObjectiveCManager alloc] init];
        _manager.connectionMode = @"serial"; // default connection mode.
        _manager.measurement_rate = @"1.0";
        _manager.last_saved_file = @"";
        _manager.networkRunLoop = nil;
        _manager.overrideAutoSettings = false;
#ifdef SIMULATED_DATA
        _manager.demoMode = true;
#else
        _manager.demoMode = false;
#endif
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
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
            result.keepCallback = [NSNumber numberWithBool:YES];
            [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
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
                NSString* acqTime = [info valueForKey:@"acqTime"];
                [self doDataCollection:acqTime];
            }
        }
        else if (self.pState == darkReferenceInProgress) {
            // update the progress bar.
            self.progress = dT / [timeout doubleValue];
        }
        else {
            // otherwise, keep waiting...
            NSDictionary* jsonDict = @{@"type":@"status",@"status":@"waiting"};
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
            result.keepCallback = [NSNumber numberWithBool:YES];
            [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
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
                NSDictionary* jsonDict = @{@"type":@"alert",@"message":msg};
                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
                result.keepCallback = [NSNumber numberWithBool:NO];
                [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
                self.pState = ready;
            }
            else if (self.pState == darkReferenceInProgress) {
                // update then hide the progress bar.
                self.progress = 1.0;
                msg = @"Dark referencing complete.";
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    NSDictionary* jsonDict = @{@"type":@"alert",@"message":msg};
                    if (true) {
                        NSError* error;
                        NSData *jsonData=[NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingSortedKeys error:&error];
                        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                        [self.plugin.commandDelegate evalJs:[NSString stringWithFormat:@"pluginMessage(%@);",jsonString]];
                    }
                    else {
                        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
                        result.keepCallback = [NSNumber numberWithBool:YES];
                        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
                    }
                });
                if ([nextProc containsString:@"doDataCollection"]) {
                    NSString* acqTime = [info valueForKey:@"acqTime"];
                    NSLog(@"Dark reference complete. Do data collection. %@s",acqTime);
                    [self doDataCollection:acqTime];
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
        NSDictionary* jsonDict = @{@"type":@"status",@"status":@"processing"};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
        result.keepCallback = [NSNumber numberWithBool:YES];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
        [self computeClearance];
        [self returnData];
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
    if (self.filtered == nil) self.filtered = [[NSMutableArray alloc] init];
    if (self.blade_clearances == nil) self.blade_clearances = [[NSMutableArray alloc] init];
    if (self.clearance_quality == nil) self.clearance_quality = [[NSMutableArray alloc] init];
    if (self.point_counts == nil) self.point_counts = [[NSMutableArray alloc] init];
    if (self.intensities == nil) self.intensities = [[NSMutableArray alloc] init];
    if (self.min_locs == nil) self.min_locs = [[NSMutableArray alloc] init];
    self.measurement_rate = @"1.0";
    if (self.telnetCmds == nil) self.telnetCmds = [[NSMutableArray alloc] init];
    if (self.metaData == nil) self.metaData = [[ScanMetaData alloc] init];
    [self clearMetaData];
    [self computeKernel:KERNEL_SIGMA kernel_size:KERNEL_SIZE]; // Compute the LoG filter kernel.
    self.stage_clearance = 0;
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
    NSLog(@"@masteringDevice");
    if (![self checkReady]) return;
    if (self.inputTelnetStream == nil) {
        [self connectDevice:self.ipAddress port:self.telnetPort];
    }
    self.pState = masteringInProgress;
    NSDictionary* jsonDict = @{@"type":@"status",@"status":@"mastering_in_progress"};
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
    result.keepCallback = [NSNumber numberWithBool:YES]; // This is the magic option that lets you call a callback AGAIN!
    [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];

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

    [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 NONE\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 %f\n", MASTER_VALUE]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTER 01DIST1 SET\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"OUTPUT NONE\n"]];
    [self sendTelnetCommand];
}

- (void)doDarkReference {
    NSLog(@"@doDarkReference");
    if (![self checkReady]) return;
    self.pState = darkReferenceInProgress;
    NSDictionary* jsonDict = @{@"type":@"status",@"status":@"acquiring"};
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
    result.keepCallback = [NSNumber numberWithBool:YES]; // This is the magic option that lets you call a callback AGAIN!
    [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
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
    self.progress = 0.0;
    self.startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithFloat:processTime], @"timeout",
                              @"doDataCollection", @"nextProcess",
                              @"3.0", @"acqTime",
                              nil];
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
    self.measurement_rate = rate;
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %@\n", rate]];
    [self sendTelnetCommand];
}

- (void)setMeasurementRateAndIntensityThreshold:(NSString*)rate threshold:(NSString*)threshold {
    NSLog(@"setMeasurementRateAndIntensityThreshold");
    if (![self checkReady]) return;
    if (self.demoMode) return;
    self.pState = setMeasurementRateInProgress;
    self.measurement_rate = rate;
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %@\n", rate]];
    self.intensityThreshold = threshold;
    if ([self.controllerType containsString:@"IFC2422"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH01 %@\n", threshold]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH02 %@\n", threshold]];
    }
    else if ([self.controllerType containsString:@"IFC2421"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD %@\n", threshold]];
    }
    else {
        return; // Shouldn't get here.
    }
    [self sendTelnetCommand];
}

- (void)setThreshold:(NSString*)threshold {
    if (![self checkReady]) return;
    self.pState = setThresholdInProgress;
    self.intensityThreshold = threshold;
    if ([self.controllerType containsString:@"IFC2422"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH01 %@\n", threshold]];
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH02 %@\n", threshold]];
    }
    else if ([self.controllerType containsString:@"IFC2421"]) {
        [self.telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD %@\n", threshold]];
    }
    else {
        return; // Shouldn't get here.
    }
    [self sendTelnetCommand];

}

- (bool)checkReady {
    if (self.pState != ready) {
        NSString* errMsg = @"Error: Device not ready. Please wait.";
        NSDictionary* jsonDict = @{@"type":@"status",@"status":errMsg};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
        result.keepCallback = [NSNumber numberWithBool:YES]; // This is the magic option that lets you call a callback AGAIN!
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
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
            [self clearMetaData];
            self.calibratedAcquire = false;
        }
        if (msgArray.count > 4) {
            // Call from JavaScript:
            // ["send_data",acquisitionTime, frame, sn, stage, position, casing_thickness, spacer_thickness];
            acqTime = [msgArray objectAtIndex:1];
            self.metaData.frame = [msgArray objectAtIndex:2];
            self.metaData.serial_number = [msgArray objectAtIndex:3];
            self.metaData.stage = [msgArray objectAtIndex:4];
            self.metaData.position = [msgArray objectAtIndex:5];
            self.metaData.casing_thickness = [msgArray objectAtIndex:6];
            self.metaData.spacer_thickness = [msgArray objectAtIndex:7];
            self.metaData.num_blades = [msgArray objectAtIndex:8];
            self.metaData.tip_diameter = [msgArray objectAtIndex:9];
            self.metaData.blade_width = [msgArray objectAtIndex:10];
            self.metaData.master_offset = [msgArray objectAtIndex:11];
            self.calibratedAcquire = true;
        }
        
        // Check if the value is specified in rpm.  If so, extract the rpm value.
        bool isRPM = false;
        float rpm = 0.0;
        if ([acqTime containsString:@"rpm"] || [acqTime containsString:@"RPM"]) {
            isRPM = true;
            acqTime = [acqTime substringToIndex:acqTime.length-3]; // crop off the "rpm"
            rpm = [acqTime floatValue];
            NSArray* timeAndRate = [self acquisitionTimeAndRate:rpm];
            // timeAndRate: (0) acquisitionTime; (1) measurementRate; (2) intensityThreshold; (3) Errors.
            NSString* err = [timeAndRate objectAtIndex:3];
            if (err.length != 0) {
                // Report errors.
                NSDictionary* jsonDict = @{@"type":@"alert",@"message":err};
                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
                result.keepCallback = [NSNumber numberWithBool:YES];
                [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
                return;
            }
            else {
                acqTime = [NSString stringWithFormat:@"%@",[timeAndRate objectAtIndex:0]];
                // Set new measurement rate
                self.startTime = [[NSDate date] timeIntervalSince1970]; // start timeout timer
                NSNumber* tmpNum = [timeAndRate objectAtIndex:1];
                NSString* mRate = [NSString stringWithFormat:@"%.3f", [tmpNum floatValue]];
                tmpNum = [timeAndRate objectAtIndex:2];
                NSString* intThresh = [NSString stringWithFormat:@"%.3f", [tmpNum floatValue]];
                float interval = 1.0;
                if (!self.overrideAutoSettings) {
                    interval = 3.0; // Give it more time to set things up.
                    NSLog(@"Using auto-settings: Found measurement rate: %@; intensity threshold: %@", mRate, intThresh);
                    [self setMeasurementRateAndIntensityThreshold:mRate threshold:intThresh];
                }
                else {
                    NSLog(@"Overriding auto-settings.");
                }
                // The timeoutWaitTimer callback will start data acquisition after the measurement
                // rate is set.  If the timeout expires, the user just gets an error message.
                if (!self.demoMode) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                                              [NSNumber numberWithFloat:7.0], @"timeout",
                                              @"doDataCollection", @"nextProcess",
                                              acqTime, @"acqTime", nil];
                        self.timerWaiting = [ NSTimer scheduledTimerWithTimeInterval:interval
                                                                              target:self
                                                                            selector:@selector(timeoutWaitTimer:)
                                                                            userInfo:info
                                                                             repeats:YES];
                    });
                }
                else {
                    [self doDataCollection:acqTime];
                }
            }
        }
        else {
            [self doDataCollection:acqTime];
        }
        return;
    }
    if ([cmd containsString:@"scan_meta_data"]) {
        NSLog(@"Got scan_meta_data");
        // Call from JavaScript:
        //{"args":["scan_meta_data", E4PTdata.frame, E4PTdata.serial_number, E4PTdata.customer, E4PTdata.site_name, E4PTdata.operator, E4PTdata.units, E4PTdata.state]};
        self.metaData.frame = [msgArray objectAtIndex:1];
        self.metaData.serial_number = [msgArray objectAtIndex:2];
        self.metaData.customer = [msgArray objectAtIndex:3];
        self.metaData.site = [msgArray objectAtIndex:4];
        self.metaData.user = [msgArray objectAtIndex:5];
        self.metaData.units = [msgArray objectAtIndex:6];
        self.metaData.units = [self.metaData.units uppercaseString]; // We want units to be consistently in upper case.
        self.metaData.state = [msgArray objectAtIndex:7];
        return;
    }
    if ([cmd containsString:@"clear_meta_data"]) {
        NSLog(@"Got clear_meta_data");
        [self clearMetaData];
        return;
    }
    if ([cmd containsString:@"get_data_file"]) {
        NSLog(@"Got get_data_file");
        NSDictionary* jsonDict = @{@"type":@"filename",@"fname":self.last_saved_file};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
        return;
    }
    if ([cmd containsString:@"do_dark_reference"]) {
        NSLog(@"Got do_dark_reference");
        if (!self.demoMode) {
            [self doDarkReference];
        }
        else {
            NSDictionary* jsonDict = @{@"type":@"status",@"status":@"acquiring"};
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
            result.keepCallback = [NSNumber numberWithBool:YES]; // This is the magic option that lets you call a callback AGAIN!
            [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
            NSString* demoMsg = @"dark_reference";
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
    if ([cmd containsString:@"do_mastering"]) {
        NSLog(@"Got do_mastering");
        if (!self.demoMode) {
            [self masterDevice];
        }
        else {
            NSDictionary* jsonDict = @{@"type":@"status",@"status":@"mastering_in_progress"};
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
            result.keepCallback = [NSNumber numberWithBool:YES]; // This is the magic option that lets you call a callback AGAIN!
            [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
            NSString* demoMsg = @"mastering";
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
        NSLog(@"Got set_manual_override");
        NSString* mode = [msgArray objectAtIndex:1];
        if ([mode containsString:@"true"]) {
            self.overrideAutoSettings = true;
        }
        else if ([mode containsString:@"false"]) {
            self.overrideAutoSettings = false;
        }
        return;
    }
    if ([cmd containsString:@"set_demo_mode"]) {
        NSLog(@"Got set_demo_mode");
        NSString* mode = [msgArray objectAtIndex:1];
        NSString* msgStr;
        if ([mode containsString:@"true"]) {
            self.demoMode = true;
            msgStr = @"App is now in demo mode.";
        }
        else {
            self.demoMode = false;
            msgStr = @"App is now in production mode.";
        }
        NSDictionary* jsonDict = @{@"type":@"alert",@"message":msgStr};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
        result.keepCallback = [NSNumber numberWithBool:YES];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
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
        NSDictionary* jsonDict = @{@"type":@"alert",@"message":msgStr};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
        result.keepCallback = [NSNumber numberWithBool:YES];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
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
        NSDictionary* jsonDict = @{@"type":@"version",@"version":appVersion};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
        result.keepCallback = [NSNumber numberWithBool:YES];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
        return;
    }
    if ([cmd containsString:@"get_sensor_parameters"]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *mfh = [defaults stringForKey:@"masterFixtureHeight"];
        NSString *mo = [defaults stringForKey:@"masterOffset"];
        if ((mfh == nil) || (mo == nil)) {
            [self registerDefaultsFromSettingsBundle];
            mfh = [defaults stringForKey:@"masterFixtureHeight"];
            mo = [defaults stringForKey:@"masterOffset"];
        }
        self.metaData.master_fixture_height = mfh;
        self.metaData.master_offset = mo;
        NSDictionary* jsonDict = @{@"type":@"sensor_params", @"master_fixture_height":mfh, @"master_offset":mo};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
        return;
    }
    if ([cmd containsString:@"set_sensor_parameters"]) {
        NSString* mfh = [msgArray objectAtIndex:1];
        NSString* mo = [msgArray objectAtIndex:2];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setValue:mfh forKey:@"masterFixtureHeight"];
        [defaults setValue:mo forKey:@"masterOffset"];
        self.metaData.master_fixture_height = mfh;
        self.metaData.master_offset = mo;
        NSString* msgStr = [NSString stringWithFormat:@"Sensor Parameters are Set."];
        NSDictionary* jsonDict = @{@"type":@"alert",@"message":msgStr};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
        return;
    }
    else {
        NSLog(@"Got %@",msg);
    }
}

// acquisitionTimeAndRate calculates the needed acquisition time and measurement rate
// to get 1.05 rotations with ~5 pts/blade tip.  This function returns an array with
// 3 elements. (1) acquisition time; (2) measurement rate; (3) error messages, if any.
- (NSArray*)acquisitionTimeAndRate:(float)RPM {
    float bladeWidth = [self.metaData.blade_width floatValue];
    float circumference = M_PI * [self.metaData.tip_diameter floatValue];
    float inchesPerSecond = circumference * RPM / 60.0;
    float acquisitionTime =  1.10 * (circumference)/ inchesPerSecond;
    float samplesPerInch = DESIRED_POINTS_PER_BLADE / bladeWidth;
    float measRate = inchesPerSecond * samplesPerInch; // measRate in Hz.
    // Round measurement rate to the next highest 100 Hz.
    measRate /= 100.0;
    measRate = ceilf(measRate);
    measRate *= 100.0;
    
    NSString* errorMessage = @"";
    if (measRate > 6500.0) {
        measRate = 6500.0;
        samplesPerInch = measRate / inchesPerSecond;
        float ptsPerBlade = samplesPerInch * bladeWidth;
        errorMessage = [NSString stringWithFormat:@"ErrorRateHigh\n%f pts/blade. ",ptsPerBlade];
    }
    if (measRate <= 0.1) {
        measRate = 0.1; // Limit measurement rate on the low end.
        //errorMessage = [errorMessage stringByAppendingString:@"ErrorRateLow "];
    }
    if (acquisitionTime <= 0) {
        errorMessage = [errorMessage stringByAppendingString:@"ErrorTimeHigh "];
    }
    if (acquisitionTime > 1800) {
        errorMessage = [errorMessage stringByAppendingString:@"ErrorTimeLow "];
    }
    // Convert measurement rate to kHz. for output
    measRate /= 1000.0;
    
    // Get Intensity threshold for this sampling rate.
    // This formula was calculated from empirical tests run by Carlos Alfonso-Diaz.
    float intensityThreshold = 0;
    if (measRate <= 0.4) intensityThreshold = 3.2;
    if ((measRate > 0.4) && (measRate < 1.9)) intensityThreshold = 0.0498 * expf(-1.141 * measRate);
    if (measRate >= 1.9) intensityThreshold = 0.5;
    intensityThreshold *= 100.0;
    
    return [NSArray arrayWithObjects:
            [NSNumber numberWithFloat:acquisitionTime],
            [NSNumber numberWithFloat:measRate],
            [NSNumber numberWithFloat:intensityThreshold],
            errorMessage, nil];
}

- (void)doDataCollection:(NSString*)acqTime {
    self.startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
    int num_sets = 0;
    float nSets = 0.0;
    float meas_rate = [self.measurement_rate floatValue] * 1000; // measurement_rate is in kHz.
    if ([self.connectionMode containsString:@"ethernet"]) {
        // 100 samples/frame, "* 1000" converts the measurement rate from kHz to Hz.
        nSets = meas_rate * [acqTime floatValue] / 100.0;
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
        nSets = meas_rate * [acqTime floatValue] / dataSetsPerFrame;
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
        NSDictionary* jsonDict = @{@"type":@"status",@"status":@"acquiring"};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
        result.keepCallback = [NSNumber numberWithBool:YES];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
        NSString* demoMsg = @"collect_data";
        dispatch_async(dispatch_get_main_queue(), ^{
            self.timerDemoFunctions = [ NSTimer scheduledTimerWithTimeInterval:3.0
                                                                        target:self
                                                                      selector:@selector(timeoutTimerDemoMode:)
                                                                      userInfo:demoMsg
                                                                       repeats:NO];
        });
    }
}

// Should be self-explanitory.
- (void)clearMetaData {
    self.metaData.frame = @"";
    self.metaData.serial_number = @"";
    self.metaData.stage = @"";
    self.metaData.position = @"";
    self.metaData.spacer_thickness = @"";
    self.metaData.casing_thickness = @"";
    self.metaData.state = @"";
    self.metaData.customer = @"";
    self.metaData.site = @"";
    self.metaData.user = @"";
    self.metaData.units = @"";
    self.metaData.num_blades = @"";
    self.metaData.sensor_measurement_range = @SENSOR_MEASUREMENT_RANGE;
}

// Should be self-explanitory.
- (void)clearData {
    [self.datasetIds removeAllObjects];
    [self.times removeAllObjects];
    [self.displacements removeAllObjects];
    [self.filtered removeAllObjects];
    [self.blade_clearances removeAllObjects];
    [self.clearance_quality removeAllObjects];
    [self.point_counts removeAllObjects];
    [self.intensities removeAllObjects];
    [self.min_locs removeAllObjects];
    if (self.byteBuffer != nil) {
        for (int i=0; i<BYTE_BUFFER_SIZE; i++) self.byteBuffer[i] = 0;
    }
    self.stage_max_clearance = 0.0;
    self.stage_min_clearance = FLT_MAX;
    self.stage_median_clearance = 0.0;
    self.stage_clearance_std = 0.0;
}

// The collectData function is patterned after the e4PtTool python function
// named collect_data and tries to accomplish the same thing.
- (void)collectData:(int)num_sets casingThickness:(float)casing_thicknesss {
    NSLog(@"@collectData: num_sets = %d", num_sets);
    // Update the status in the HTML page.
    NSDictionary* jsonDict = @{@"type":@"status",@"status":@"acquiring"};
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
    result.keepCallback = [NSNumber numberWithBool:YES];
    [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];

    self.num_pts_max = 110;
    self.current_data_set_id = 0;
    self.previous_data_set_id = 0;
    self.set_count = 0;
    self.data_index = 0;
    self.num_sets = num_sets;
    NSString* tmpf = [NSString stringWithFormat:@"%.2f",casing_thicknesss];
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
                                        if (dVal == 214743396) {
                                            error_msg = [error_msg stringByAppendingString:@"No Peak"];
                                        }
                                        if (dVal == 214743397) {
                                            error_msg = [error_msg stringByAppendingString:@"Peak in front of MR"];
                                        }
                                        if (dVal == 214743398) {
                                            error_msg = [error_msg stringByAppendingString:@"Peak in back of MR"];
                                        }
                                        if (dVal == 214743399) {
                                            error_msg = [error_msg stringByAppendingString:@"Measurement cannot be calculated"];
                                        }
                                        if (dVal == 214743400) {
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
                        NSDictionary* jsonDict = @{@"type":@"status",@"status":@"processing"};
                        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
                        result.keepCallback = [NSNumber numberWithBool:YES];
                        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
                        
                        if (self.pState != clearanceComputationInProgress) {
                            [self computeClearance];
                            [self returnData];
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
                    NSDictionary* jsonDict = @{@"type":@"status",@"status":errorMessage};
                    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
                    [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
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
    }
    if ([rxData containsString:@"IFC2421"]) {
        NSLog(@"Controller is IFC2421");
        self.controllerType = @"IFC2421";
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

- (void)returnData {
    NSError* error;
    NSData* jsonData;
    // If we've done a calibrated acquisition we pass back the filtered, calibrated data.
    // If we've done an uncalibrated acquisition we pass back the raw, uncalibrated data.
    if (self.calibratedAcquire) {
        jsonData = [NSJSONSerialization dataWithJSONObject:self.filtered options:NSJSONWritingSortedKeys error:&error];
    }
    else {
        jsonData = [NSJSONSerialization dataWithJSONObject:self.displacements options:NSJSONWritingSortedKeys error:&error];
    }
    NSString *dispJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:self.intensities options:NSJSONWritingSortedKeys error:&error];
    NSString *intensJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:self.min_locs options:NSJSONWritingSortedKeys error:&error];
    NSString *minLocsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:self.blade_clearances options:NSJSONWritingSortedKeys error:&error];
    NSString *bladeClrsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:self.clearance_quality options:NSJSONWritingSortedKeys error:&error];
    NSString *clrQualityJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
    NSString* clearance = [NSString stringWithFormat:@"%f",self.stage_clearance];
    NSString* stg_max_clr = [NSString stringWithFormat:@"%f", self.stage_max_clearance];
    NSString* stg_min_clr = [NSString stringWithFormat:@"%f", self.stage_min_clearance];
    NSString* stg_med_clr = [NSString stringWithFormat:@"%f", self.stage_median_clearance];
    NSString* stg_clr_std = [NSString stringWithFormat:@"%f", self.stage_clearance_std];

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
                                   @"date":dateStr
                                   };
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDataDict];// You can send data, String, int, array, dictionary, etc.
    result.keepCallback = [NSNumber numberWithBool:NO];
    [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
    [self saveCSVFile:@""];
    [self clearData];
}

- (void)processComplete:(NSString*)statusMsg {
    if (self.pState == setMeasurementRateInProgress) {
        NSString* msgStr = [NSString stringWithFormat:@"Measurement rate set to %@ kHz.", self.measurement_rate];
        NSDictionary* jsonDict = @{@"type":@"alert",@"message":msgStr};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
        result.keepCallback = [NSNumber numberWithBool:YES];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
    }
    else if (self.pState == setThresholdInProgress) {
        NSString* msgStr = [NSString stringWithFormat:@"Threshold is set to %@.", self.intensityThreshold];
        NSDictionary* jsonDict = @{@"type":@"alert",@"message":msgStr};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
    }
    else if (self.pState == darkReferenceInProgress) {
        return; // Dark referencing is followed by data collection
    }
    else {
        NSDictionary* jsonDict = @{@"type":@"status",@"status":statusMsg};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
    }
    
    self.pState = ready;
}

- (void)computeClearance {
    self.pState = clearanceComputationInProgress;
    // Displacement values will be between 0-15.
    // We create a coarse histogram to see how many peaks we find.
    float hMult = 4.0;  // This multiplier will change the size & resolution of the histogram.
    int nbins = (OUT_OF_RANGE*hMult) + 1;  // Should give 61 bins for hMult = 4.0.
    int* hBins = (int*)malloc(nbins * sizeof(int));
    for (int i=0; i<nbins; i++) hBins[i] = 0;
    // Populate the histogram by converting displacements to histogram indices.
    // Round each displacement to get the bin index.
    NSLog(@"Populating histogram...");
    float d=0.0;
    int bIdx = 0;
    for (NSNumber* n in self.displacements) {
        // exclude OUT_OF_RANGE points.
        if ([n floatValue] == (float)OUT_OF_RANGE) continue;
        d = hMult * [n floatValue];  // multiply the value by hMult to get the index.
        bIdx = (int)floor(d); // Using floor makes bin edges integers. E.g. [0-1][+1-2][+2-3]...
        if (bIdx > nbins-1) bIdx = nbins - 1; // Don't overflow
        if (bIdx < 0) bIdx = 0; // Don't underflow
        hBins[bIdx]++; // Increment the histogram bin
    }
    NSLog(@"Histogram:\n");
    for (int i=0; i<nbins; i++) {
        NSLog(@" hBin[%d]: %d",i, hBins[i]);
    }
    // Use Otsu's method to get threshold
    float threshold = [self otsuSegmentation:hBins nbins:nbins maxBin:((float)OUT_OF_RANGE)];
    
    // Force threshold here.
    // threshold = 4.5;  // FYI, the threshold of 4.5 had some problems on some positions in the test rig.
    
    NSLog(@"Found Threshold: %f\nThresholding data...",threshold);
    
    // Perform edge detection with an LoG filter
    // (Kernel computation was handled during initialization.)
    NSLog(@"Filtering...");
    [self fir_filter:self.kernel threshold:threshold];
    NSLog(@"Done.");
    
    //return; // Stop so we can just see the results of filtering
    
    // Fill sig_sign buffer with just 1 or -1 indicating the sign
    // of the filtered signal.
    int* sig_sign = (int*)malloc(self.filtered.count * sizeof(int));
    int i=0;
    for (NSNumber* n in self.filtered) {
        if ([n floatValue] >= 0) {
            sig_sign[i] = 1;
        }
        else {
            sig_sign[i] = -1;
        }
        i++;
    }
    
    // Fill these buffers with indications for positive or
    // negative zero crossings.  These are the blade boundaries.
    // Blades tip go from a negative zc to a positiv zc.
    bool* pos_crossing = (bool*)malloc(self.filtered.count * sizeof(bool));
    bool* neg_crossing = (bool*)malloc(self.filtered.count * sizeof(bool));
    for (i=0; i<self.filtered.count; i++) {
        if (i==0) {
            // Skip first value
            pos_crossing[i] = false;
            neg_crossing[i] = false;
            continue;
        }
        if ( (sig_sign[i] - sig_sign[i-1]) < 0 ) {
            // Negative zero-crossing
            pos_crossing[i] = false;
            neg_crossing[i] = true;
        }
        else if ( (sig_sign[i] - sig_sign[i-1]) > 0 ) {
            // Positive zero-crossing
            pos_crossing[i] = true;
            neg_crossing[i] = false;
        }
        else {
            pos_crossing[i] = false;
            neg_crossing[i] = false;
        }
    }

// This debug stanza allows one to see where the zero-crossings occur.
#if 0
    [self.filtered removeAllObjects];
    float f = 1.0;
    for (i=0; i<self.displacements.count; i++) {
        if (neg_crossing[i]) f = 0.0;
        if (pos_crossing[i]) f = 1.0;
        [self.filtered addObject:[NSNumber numberWithFloat:f]];
    }
    return;
#endif
    
    // Traverse the data averaging the displacements between the neg.
    // and pos. zero-crossings IFF the intensity is greater than zero.
    // These averages are the per-blade clearances
    [self.filtered removeAllObjects];
    [self.blade_clearances removeAllObjects];
    [self.clearance_quality removeAllObjects];
    for (i=0; i<self.displacements.count; i++) {
        if (neg_crossing[i]) {
            // We've encountered a negative zero-crossing
            // so sum displacements to the next positive zero-crossing.
            int start = i;
            int stop = start;
            // This next loop determines the corresponding stoping point
            // point for this blade, if any.
            for (; stop < self.displacements.count; stop++) {
                if (pos_crossing[stop]) {
                    //NSLog(@"Start: %d; Stop: %d", start, stop);
                    break;
                }
                else if (stop == self.displacements.count -1) {
                    //NSLog(@"No stop found for start: %d", start);
                    // end of the data is encountered without a matching
                    // positive zero crossing.
                    for (int j=start; j<self.displacements.count; j++) {
                        [self.filtered addObject:[NSNumber numberWithFloat:OUT_OF_RANGE]];
                    }
                    stop = start;
                    break;
                }
            }
            //NSLog(@"Blade: %d - %d", start, stop);
            float clearance = 0;
            float min_clearance = OUT_OF_RANGE;
            float min_loc = 0;
            int count = 0;
// This debug stanza puts a dot on the start and stop points.
#if 0
            [self.min_locs addObject:[NSNumber numberWithInt:start]];
            [self.blade_clearances addObject:[self.displacements objectAtIndex:start]];
            [self.min_locs addObject:[NSNumber numberWithInt:stop]];
            [self.blade_clearances addObject:[self.displacements objectAtIndex:stop]];
#endif
            if (stop > start) {
                // FILTER_EDGE_SIZE_* allows us to shave down the number of points used
                for (int j=start + FILTER_EDGE_SIZE_START; j<=stop - FILTER_EDGE_SIZE_STOP; j++) {
                    NSNumber* d = [self.displacements objectAtIndex:j];
#ifdef SEND_DISPLACEMENT_ONLY
                    if ( [d floatValue] < threshold ) {
#else
                    NSNumber* intnst = [self.intensities objectAtIndex:j];
                    if ( ([intnst floatValue] > 0) && ([d floatValue] < threshold) ) {
#endif
                        //NSLog(@"Averaging: %f",[d floatValue]);
                        if ([d floatValue] < min_clearance) {
                            min_clearance = [d floatValue];
                            min_loc = j;
                        }
                        clearance += [d floatValue];
                        count++;
                    }
                }
                //NSLog(@"Sum: %f; count: %d", clearance, count);
                // Protect against divide-by-zero...
                if (count == 0) {
                    clearance = -9.996;
                }
                else {
                    clearance = clearance / count; // Average clearance for this blade.
                }
                if (isnan(clearance)) {
                    clearance = -9.995;  // nan has happened before.
                }
                if (count > 0) {
#ifdef OUTPUT_MINIMUM
                    [self.blade_clearances addObject:[NSNumber numberWithFloat:min_clearance]];
#else
                    [self.blade_clearances addObject:[NSNumber numberWithFloat:clearance]];
                    // Check if minimum clearance is >0.001" (0.0254mm) from average clearance.  If so we consider it an outlier.
                    // Quality is the fraction of points whose values are <= 0.001" from the mean.
                    float quality = (float)count;
                    if (fabs(clearance - min_clearance) > 0.0254) {
                        for (int j=start + FILTER_EDGE_SIZE_START; j<=stop - FILTER_EDGE_SIZE_STOP; j++) {
                            NSNumber* d = [self.displacements objectAtIndex:j];
                            NSNumber* intnst = [self.intensities objectAtIndex:j];
                            if ((fabs(clearance - [d floatValue]) > 0.0254) && ([intnst floatValue] > 0)) {
                                quality -= 1.0;
                            }
                            if (quality <= 0.0) {
                                NSLog(@"Bad Quality: q = %f at index %d; displacement = %f; clearance = %f; int = %f", quality, j, [d floatValue], clearance, [intnst floatValue]);
                            }
                        }
                    }
                    quality = quality / (float)count;
                    [self.clearance_quality addObject:[NSNumber numberWithFloat:quality]];
                    min_loc = ((float)start + (float)stop) / 2.0;
#endif
                    [self.min_locs addObject:[NSNumber numberWithFloat:min_loc]];
                }
                NSLog(@"Clearance: %f; Quality: %@", clearance, [self.clearance_quality lastObject]);
                for (int j=start; j<=stop; j++) {
                    NSNumber* d = [self.displacements objectAtIndex:j];
                    if (([d floatValue] != OUT_OF_RANGE) && (count > 0)) {
                        [self.filtered addObject:[NSNumber numberWithFloat:clearance]];
                    }
                    else {
                        [self.filtered addObject:[NSNumber numberWithFloat:OUT_OF_RANGE]];
                    }
                }
            }
            i = stop; // Move the start point ahead to where we stopped.
        }
        else {
            [self.filtered addObject:[NSNumber numberWithFloat:OUT_OF_RANGE]];
        }
    }
    // Now iterate over the filtered values and calibrate them to arrive at actual clearance values.
    // Old method: clearance_f = clearance_f + (SMR + SL) - spacer - casing_thickness + MO;
    // New method: clearance_f = clearance_f + (MFH - 5.0) - spacer - casing_thickness + MO;
    // Filtered clearances are in mm.
    // Sensor parameters (Mastering fixture height, Spacer thickness & casing thickness) are in inches.
    //
    // Get values into consistent units of mm. Perform calculations in mm
    float inToMM = 25.4;
    float mfh = [self.metaData.master_fixture_height floatValue] * inToMM;
    float mo = [self.metaData.master_offset floatValue] * inToMM;
    float ct = [self.metaData.casing_thickness floatValue] * inToMM;
    float st = [self.metaData.spacer_thickness floatValue] * inToMM;
    // Calibrate the filtered values
    if (self.calibratedAcquire) {
        for (unsigned int i = 0; i< self.filtered.count; i++) {
            if ([[self.filtered objectAtIndex:i] floatValue] == OUT_OF_RANGE) continue;  // no need to calibrate out-of-range values.
            float clearance_f = [[self.filtered objectAtIndex:i] floatValue] + mfh - st - ct + mo - MASTER_VALUE;
            [self.filtered replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:clearance_f]];
        }
            // Calibrate the blade clearances
        for (unsigned int i = 0; i< self.blade_clearances.count; i++) {
            float clearance_f = [[self.blade_clearances objectAtIndex:i] floatValue] + mfh - st - ct + mo - MASTER_VALUE;
            [self.blade_clearances replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:clearance_f]];
        }
    }
        
    // Now iterate over the blade_clearances to get the average clearance for the stage,
    // as well as max, min, median, and stdev.
    self.stage_clearance = 0.0;
    self.stage_max_clearance = 0.0;
    self.stage_min_clearance = FLT_MAX;
    self.stage_median_clearance = 0.0;
    self.stage_clearance_std = 0;
    NSMutableArray* statsBuff = [[NSMutableArray alloc] init];
    int stage_num_blades = (int)[self.metaData.num_blades integerValue];
    if (stage_num_blades > 0) {
        // This clause is used when the number of blades has been specified.
        // Use only the number of specified blades so that no blades are counted twice.
        for (i=0; i<stage_num_blades; i++) {
            // Make sure we don't try to go beyond the bounds of the array of clearances.
            if (i < self.blade_clearances.count) {
                NSNumber* c = [self.blade_clearances objectAtIndex:i];
                if ([c floatValue] > self.stage_max_clearance) self.stage_max_clearance = [c floatValue];
                if ([c floatValue] < self.stage_min_clearance) self.stage_min_clearance = [c floatValue];
                [statsBuff addObject:c];
                self.stage_clearance += [c floatValue];
            }
        }
        int divisor = (self.blade_clearances.count < stage_num_blades) ? (int)self.blade_clearances.count : stage_num_blades;
        if (divisor != 0) {
            self.stage_clearance /= (float)divisor;
        }
        else {
            self.stage_clearance = -9.994; // divide-by-zero protection.
        }
    }
    else {
        // This clause is used when no number of blades has been specified.
        if (self.blade_clearances.count > 0 ) {
            for (i=0; i<self.blade_clearances.count; i++) {
                NSNumber* c = [self.blade_clearances objectAtIndex:i];
                self.stage_clearance += [c floatValue];
                if ([c floatValue] > self.stage_max_clearance) self.stage_max_clearance = [c floatValue];
                if ([c floatValue] < self.stage_min_clearance) self.stage_min_clearance = [c floatValue];
                [statsBuff addObject:c];
            }
            int divisor = (int)self.blade_clearances.count;
            if (divisor != 0) {
                self.stage_clearance /= (float)divisor;
            }
            else {
                self.stage_clearance = -9.994; // divide-by-zero protection.
            }
        }
    }
    // Now find the median clearance value for this stage...
    if (statsBuff.count > 1) {
        NSArray* sortedBuff = [statsBuff sortedArrayUsingSelector:@selector(compare:)];
        NSUInteger middle = [sortedBuff count] / 2;
        self.stage_median_clearance = [[sortedBuff objectAtIndex:middle] floatValue];
        self.stage_clearance_std = [[self standardDeviationOf:statsBuff] floatValue];
    }

    free(neg_crossing);
    free(pos_crossing);
    free(sig_sign);
    free(hBins);

    NSLog(@"computeClearance Done.");
}
    
// otsuSegmentation performs a segmentation of the histogram into 2 classes
// using the Otsu method from image segmentation.
// See: https://en.wikipedia.org/wiki/Otsu%27s_method
// If the 2 classes are seen as too close to one another, then there is
// likely only a single class.
-(float)otsuSegmentation:(int*)hist nbins:(int)nbins maxBin:(float)maxBin {
    float w0, w1;
    float u0, u1;
    float sigma2;
    float maxSigma = 0.0;
    float threshold1 = 0.0;
    int threshold_idx = 0;
    // I found that iterating in different directions gives different answers.
    // Since the threshold seems to live on the edge of one of the classes,
    // I'll iterate both directions and take the average of the two thresholds.
    for (int k=nbins-1; k >= 0; k--) {
        // lower & upper bounds for classes
        w0 = 0.0; w1 = 0.0;
        u0 = 0.0; u1 = 0.0;
        // class 1 goes from 0 to k-1
        for (int i=0; i < k; i++) {
            w0 += hist[i];
            u0 += hist[i] * ((float)(i+1) * (float)maxBin / nbins);
        }
        u0 = u0 / w0;
        // class 2 goes from k to nbins-1
        for (int i=k; i < nbins; i++) {
            w1 += hist[i];
            u1 += hist[i] * ((float)(i+1) * (float)maxBin / nbins);
        }
        u1 = u1 / w1;
        sigma2 = w0*w1*(u0-u1)*(u0-u1);
        
        // Get the threshold by finding the max sigma2
        if (sigma2 > maxSigma) {
            maxSigma = sigma2;
            threshold_idx = k;
            threshold1 = ((float)(k+1) * (float)maxBin / nbins);
        }
    }
    maxSigma = 0.0;
    float threshold2 = 0.0;
    threshold_idx = 0;
    // Iterate the other direction.
    for (int k=0; k < nbins; k++) {
        // lower & upper bounds for classes
        w0 = 0.0; w1 = 0.0;
        u0 = 0.0; u1 = 0.0;
        // class 1 goes from 0 to k-1
        for (int i=0; i < k; i++) {
            w0 += hist[i];
            u0 += hist[i] * ((float)(i+1) * (float)maxBin / nbins);
        }
        u0 = u0 / w0;
        // class 2 goes from k to nbins-1
        for (int i=k; i < nbins; i++) {
            w1 += hist[i];
            u1 += hist[i] * ((float)(i+1) * (float)maxBin / nbins);
        }
        u1 = u1 / w1;
        sigma2 = w0*w1*(u0-u1)*(u0-u1);
        
        // Get the threshold by finding the max sigma2
        if (sigma2 > maxSigma) {
            maxSigma = sigma2;
            threshold_idx = k;
            threshold2 = ((float)(k+1) * (float)maxBin / nbins);
        }
    }

    // Calculate the two cluster means based on the calculated threshold.
    w0 = 0.0; w1 = 0.0;
    u0 = 0.0; u1 = 0.0;
    for (int i=0; i<nbins; i++) {
        float p = ((float)(i+1) * (float)maxBin / nbins);
        if (i <= threshold_idx) {
            w0 += hist[i];
            u0 += hist[i] * p;
        }
        if (i >  threshold_idx) {
            w1 += hist[i];
            u1 += hist[i] * p;
        }
    }
    // We need divide-by-zero protection.  If one of the w values is zero
    // this is probably a unimodal distribution.
    if (w0 == 0) {
        u1 = u1 / w1;
        u0 = u1;
    }
    else if (w1 == 0) {
        u0 = u0 / w0;
        u1 = u0;
    }
    else {
        u0 = u0 / w0;
        u1 = u1 / w1;
    }
    
    // Check to see if the two cluster means are too close to each other.
    // We use the criteria of 1mm separation as "too close".
    if (fabsf(u1-u0) < 1.0 ) {
        // These means are too close.  This is probably a unimodal distribution.
        // I.e. NOT squealer tips.  The threshold becomes the average of the
        // distance between the OUT_OF_RANGE value and the average of the two
        // "otsu" means.
        threshold1 = ((float)OUT_OF_RANGE + ((u0+u1)/2.0)) / 2.0;
    }
    else {
        // The means are adequately separated here so we probably have two classes.
        // However the Otsu threshold seems to live on the edge of one of the two classes
        // (depending on which way we traversed the historgram).  So the final threshold
        // is taken as the average of thresholds calculated going each direction.
        threshold1 = (threshold1+threshold2) / 2.0;
    }

    return threshold1;
}

- (NSNumber *)meanOf:(NSArray *)array {
    double runningTotal = 0.0;
    for(NSNumber *number in array) {
        runningTotal += [number doubleValue];
    }
    return [NSNumber numberWithDouble:(runningTotal / [array count])];
}
    
- (NSNumber *)standardDeviationOf:(NSArray *)array  {
    if(![array count]) return nil;
        
    double mean = [[self meanOf:array] doubleValue];
    double sumOfSquaredDifferences = 0.0;
        
    for(NSNumber *number in array) {
        double valueOfNumber = [number doubleValue];
        double difference = valueOfNumber - mean;
        sumOfSquaredDifferences += difference * difference;
    }
        
    return [NSNumber numberWithDouble:sqrt(sumOfSquaredDifferences / [array count])];
}

// convertToInches converts all the output values to inches prior to output.
// Currently this function is not used.
- (void)convertToInches {
    //[self.kernel replaceObjectAtIndex:idx withObject:[NSNumber numberWithFloat:k_val]];
    NSNumber* tmp = [NSNumber numberWithInt:0];
    for (unsigned int i=0; i< self.displacements.count; i++) {
        tmp = [NSNumber numberWithFloat:([[self.displacements objectAtIndex:i] floatValue] / 25.4)];
        [self.displacements replaceObjectAtIndex:i withObject:tmp];
    }
    for (unsigned int i=0; i< self.filtered.count; i++) {
        tmp = [NSNumber numberWithFloat:([[self.filtered objectAtIndex:i] floatValue] / 25.4)];
        [self.filtered replaceObjectAtIndex:i withObject:tmp];
    }
    for (unsigned int i=0; i< self.blade_clearances.count; i++) {
        tmp = [NSNumber numberWithFloat:([[self.blade_clearances objectAtIndex:i] floatValue] / 25.4)];
        [self.blade_clearances replaceObjectAtIndex:i withObject:tmp];
    }
    self.stage_max_clearance /= 25.4;
    self.stage_min_clearance /= 25.4;
    self.stage_median_clearance /= 25.4;
    self.stage_clearance_std /= 25.4;
}

// computeKernel computes a normalized Laplacian-of-Gaussian kernel for
// edge detection.
// kernel_size should be an odd number.  This is a quick & dirty
// implementation and there is no check for this.
- (void)computeKernel:(float)sigma kernel_size:(int)kernel_size {
    if (self.kernel == nil) self.kernel = [[NSMutableArray alloc] init];
    [self.kernel removeAllObjects];
    double f1 = -(1.0 / (M_PI * pow(sigma, 4)));
    double hi = floor(kernel_size/2.0);
    double lo = -hi;
    double k_sum = 0;
    for (int x=lo; x<hi+1; x++) {
        double f2 = 1.0 - (pow(x,2)/(2.0*pow(sigma,2)));
        double f3 = exp(-(pow(x,2)/(2.0*pow(sigma,2))));
        double k = f1 * f2 * f3;
        k_sum += k;
        [self.kernel addObject:[NSNumber numberWithDouble:k]];
    }
    // Now normalize the kernel
    for (int idx=0; idx<self.kernel.count; idx++) {
        NSNumber* num = [self.kernel objectAtIndex:idx];
        float k_val = (float)[num doubleValue] / k_sum;
        [self.kernel replaceObjectAtIndex:idx withObject:[NSNumber numberWithFloat:k_val]];
    }
}

//
// fir_filter is taken (almost) lock, stock and barrel from:
// http://hamiltonkibbe.com/finite-impulse-response-filters-using-apples-accelerate-framework-part-ii/
//
- (void)fir_filter:(NSMutableArray*)kernel threshold:(float)threshold {

    // Get the kernal into a float array
    int h_length = (int)kernel.count;
    float* h = (float*)malloc(h_length * sizeof(float));
    int idx = 0;
    for (NSNumber* f in kernel) {
        h[idx] = [f floatValue];
        idx++;
    }
    
    // Get the data into a float array, thresholding as we go.
    unsigned x_length = (unsigned)self.displacements.count;
    float* x = (float*)malloc(x_length * sizeof(float));
    idx = 0;
    for (NSNumber* f in self.displacements) {
        x[idx] = [f floatValue] < threshold ? [f floatValue] : threshold;
        idx++;
    }
    
    // Create buffer to store overflow across calls
    //static float overflow[KERNEL_SIZE - 1] = {0.0};
    
    // The length of the result from linear convolution is one less than the
    // sum of the lengths of the two inputs.
    unsigned result_length = x_length + h_length - 1;
    //unsigned overlap_length = result_length - x_length;
    
    // Create a temporary buffer to store the entire convolution result
    float* temp_buffer = (float*)malloc(result_length * sizeof(float));
    
    // Pointer to end of filter for use with vDSP_conv
    float    *h_end = h + (h_length - 1);
    
    // Length of signal passed to vDSP_conv
    unsigned signal_length = (h_length + result_length);
    
    // Create an array to store the signal passed to vDSP_conv, padded with zeros
    float* padded = (float*)malloc(signal_length * sizeof(float));
    
    // fill padded buffer with zeros
    float zero = 0.0;
    vDSP_vfill(&zero, padded, 1, signal_length);
    
    // Copy input into padded buffer
    cblas_scopy(x_length, x, 1, padded, 1);
    
    // use the Accelerate convolution function
    vDSP_conv(padded, 1, h_end, -1, temp_buffer, 1, result_length, h_length);
    
    //
    // In the GE Case we don't need to worry about adding results from
    // previous runs.  However, I'm leaving this code here in case I
    // ever want to refer to it for re-use.
    //
    // Add the overlap from the previous run
    // use vDSP_vadd instead of loop
    // vDSP_vadd(temp_buffer, overflow, buffer, overlap_length);
    //
    // Copy overlap into overlap buffer
    // use BLAS copy instead of loop
    // cblas_scopy(overlap_length, temp_buffer + x_length, 1, overflow, 1);
    //
    
    //
    // In the GE Case we want everything in a different array, so we just
    // put it there rather than doing the cblas copy to the output and
    // then having to copy it all again.  This saves time and memory.
    //s
    // write the final result to the output. use BLAS copy instead of loop
    // cblas_scopy(x_length, temp_buffer, 1, output, 1);
    
    // Filtered data here is offset by 1/2 of the kernel
    // length, so we offset the data when we write it back out.
    int offset = (int)round((float)kernel.count / 2.0);
    [self.filtered removeAllObjects];
    for (int i=0; i<offset; i++) [self.filtered addObject:[NSNumber numberWithFloat:0]]; // offset
    for (int i=0; i<x_length; i++) {
        float tmpf = temp_buffer[i] - threshold;
        tmpf = roundf(tmpf * 1e5)/1e5;  // round to 5 decimal places
        tmpf = (tmpf == 0.0) ? 0.0 : tmpf; // This avoids problems that have happened where -0 is generated, causing a sign change.
        [self.filtered addObject:[NSNumber numberWithFloat:tmpf]];
    }
    
    free(padded);
    free(temp_buffer);
    free(x);
    free(h);
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
        tmp = [lineArray objectAtIndex:5];
        [self.filtered addObject:[NSNumber numberWithFloat:[tmp floatValue]]];
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

- (void)saveCSVFile:(NSString*)fileName {
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
    NSString* dataStr = [NSString stringWithFormat:@"index,pt_count,dataset_id,timestamp,displacement,filtered,intensity, casing_thickness\n"];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Write the individual data lines.
    int i=0;
    for (i=0; i<self.displacements.count; i++) {
        dataStr =  [NSString stringWithFormat:@"%d,%@,%@,%@,%@,%@,%@,%@\n",
                    i,[self.point_counts objectAtIndex:i],[self.datasetIds objectAtIndex:i],
                    [self.times objectAtIndex:i], [self.displacements objectAtIndex:i],
                    [self.filtered objectAtIndex:i], [self.intensities objectAtIndex:i],
                    self.metaData.casing_thickness];
        [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    //  Write the app version to the CSV file.
    NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    dataStr = [NSString stringWithFormat:@"\n\n\n - Created by e4PtTool version %@",appVersion];
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
                    displacement = ((float)dval - 98232.0) * [self.metaData.sensor_measurement_range floatValue] / 65536.0;
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
        NSDictionary* jsonDict = @{@"type":@"status",@"status":@"processing"};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
        result.keepCallback = [NSNumber numberWithBool:YES];
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
#ifdef SIMULATED_DATA
        [self loadCSVFile:@""];
#endif
        NSLog(@"Calling compute clearance...");
        [self computeClearance]; // computeClearance changes pState to clearanceComputationInProgress
        NSLog(@"Calling returnData");
        [self returnData];
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
    
- (void)codeTest {
    // test files
    NSArray* files = @[@"299662_10_BOTTOM_2020-07-11_14-20-51.csv", @"299662_10_LEFT_2020-07-11_14-24-07.csv", @"299662_10_RIGHT_2020-07-11_14-44-10.csv", @"299662_10_TOP_2020-07-11_14-39-49.csv", @"299662_14_BOTTOM_2020-07-11_15-09-58.csv", @"299662_14_LEFT_2020-07-11_15-06-10.csv", @"299662_14_RIGHT_2020-07-11_14-48-37.csv", @"299662_14_TOP_2020-07-11_15-01-49.csv", @"299662_1_BOTTOM_2020-07-11_15-34-38.csv", @"299662_1_LEFT_2020-07-11_15-15-17.csv", @"299662_1_RIGHT_2020-07-11_15-30-18.csv", @"299662_1_TOP_2020-07-11_15-17-02.csv", @"299662_6_BOTTOM_2020-07-11_14-17-14.csv", @"299662_6_LEFT_2020-07-11_15-37-08.csv", @"299662_6_RIGHT_2020-07-11_14-06-09.csv", @"299662_6_TOP_2020-07-11_14-03-02.csv"];
    //NSArray* files = @[@"299662_10_LEFT_2020-07-11_14-24-07.csv"];
    NSString* docPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        docPath = [paths objectAtIndex:0];
    }
    // The files should all be loaded in a folder named "test" in the documents folder.
    for (NSString* file in files) {
        NSLog(@"Now testing %@",file);
        NSString* filePath = [NSString stringWithFormat:@"%@/%@",docPath,file];
        if (![self loadCSVFile:filePath]) {
            continue;
        }
        if ([file containsString:@"R10"]) self.metaData.num_blades = @"85";
        if ([file containsString:@"R14"]) self.metaData.num_blades = @"92";
        if ([file containsString:@"R1_"]) self.metaData.num_blades = @"24";
        if ([file containsString:@"R6"]) self.metaData.num_blades = @"72";
        [self computeClearance];
        NSString* outFile = [file stringByReplacingOccurrencesOfString:@".csv" withString:@"-test-out.csv"];
        [self saveCSVFile:outFile];
    }
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
      // 100 samples/frame, measurement rate is in kHz.
      float nSets = [self.manager.measurement_rate floatValue] * 1000.0 * [acqTime floatValue] / 100.0;
      int num_sets = ceil(nSets); // Round up.
      NSString* csThckns = [command.arguments objectAtIndex:1];
      [self.manager collectData:num_sets casingThickness:[csThckns floatValue]]; // num_sets, casing thickness.
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
