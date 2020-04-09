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

// Some defines for the signal processing
#define KERNEL_SIZE 13
#define KERNEL_SIGMA 2.8
#define OUT_OF_RANGE 15.0
#define FILTER_EDGE_SIZE_START 1
#define FILTER_EDGE_SIZE_STOP 1

// This option, when defined causes the program to output
// the minimum clearance for each blade rather than the
// average across the tip.
//#define OUTPUT_MINIMUM

// For using simulated data
#define SIMULATED_DATA 0

enum pluginState {
    ready = 0,
    initializationInProgress,
    masteringInProgress,
    darkReferenceInProgress,
    setMeasurementRateInProgress,
    notReady
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
    

-(instancetype)init {
    self = [super init];
    self.frame = @"";
    self.serial_number = @"";
    self.stage = @"";
    self.position = @"";
    self.casing_thickness = @"";
    self.spacer_thickness = @"";
    self.state = @"";
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
- (void)setMeasurementRate:(NSString*)rate;
- (void)collectData:(int)num_sets casingThickness:(float)casing_thicknesss;

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
@property (strong, nonatomic) NSMutableArray* kernel;

// Variables needed for data collection.
@property (nonatomic) int tmpCounter;
@property (nonatomic) enum pluginState pState;
@property (strong, nonatomic) NSMutableArray* telnetCmds;
@property (strong, nonatomic) NSString* mode; // "ethernet" or "serial"
@property (strong, nonatomic) ScanMetaData* metaData;
@property (strong, nonatomic) NSString* last_saved_file;
@property (strong, nonatomic) NSString* measurement_rate;

@property (strong, nonatomic) NSMutableArray* datasetIds;
@property (strong, nonatomic) NSMutableArray* times;
@property (strong, nonatomic) NSMutableArray* displacements;
@property (strong, nonatomic) NSMutableArray* filtered;
@property (strong, nonatomic) NSMutableArray* blade_clearances;
@property (strong, nonatomic) NSMutableArray* point_counts;
@property (strong, nonatomic) NSMutableArray* intensities;
@property (strong, nonatomic) NSMutableArray* min_locs;
@property (nonatomic) float stage_clearance;

@property (nonatomic) int num_pts_max;
@property (nonatomic) int current_data_set_id;
@property (nonatomic) int previous_data_set_id;
@property (nonatomic) int set_count;
@property (nonatomic) int data_index;
@property (nonatomic) int num_sets;

@property (strong, nonatomic) CDVIFC242x* plugin;

// RS232 connection variables
//
// TBD
//


- (void)callBackErrorWithMethodName:(NSString*)methodName andWithError:(NSString*)errorMessage;

@end

@implementation IFCObjectiveCManager

@synthesize webView = _webView;
//@synthesize interfaceHandle = _interfaceHandle;
@synthesize metaData = _metaData;
@synthesize last_saved_file = _last_saved_file;
@synthesize measurement_rate = _measurement_rate;

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
@synthesize plugin = _plugin;

@synthesize datasetIds = _datasetIds;
@synthesize times = _times;
@synthesize displacements = _displacements;
@synthesize filtered = _filtered;
@synthesize blade_clearances = _blade_clearances;
@synthesize stage_clearance = _stage_clearance;
@synthesize point_counts = _point_counts;
@synthesize intensities = _intensities;
@synthesize min_locs = _min_locs;
    
@synthesize kernel = _kernel;

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
        _manager.measurement_rate = @"1.0";
        _manager.last_saved_file = @"";
        [_manager initializeSensor];
    }
    
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
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
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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
        [self.inputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
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

- (void)timeoutTelnetSendCommand:(NSTimer*)timer {
    NSLog(@"@timeoutTelnetSendCommand: Timer expired");
    if (self.telnetCmds.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.timerSendTelnetCommand invalidate];
            self.pState = ready;
        });
        return;
    }
    NSString* command = [self.telnetCmds objectAtIndex:0];
    NSLog (@"  command: %@", command);
    if (self.telnetIsReady) {
        // send the command
        NSData* cmdData = [[NSData alloc] initWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
        [self.outputTelnetStream write:(const unsigned char*)[cmdData bytes] maxLength:[cmdData length]];
        [self.telnetCmds removeObjectAtIndex:0];
        // disable the timer
        if ([self.telnetCmds count] == 0) {
            // Turn off the timer if there are no more commands to send.
            dispatch_async(dispatch_get_main_queue(), ^{
                [timer invalidate];
            });
        }
        self.telnetIsReady = false;  // telnetIsReady is set to true as soon as the "->" comes back from the controller.
    }
    else {
        NSLog(@"  telnet is not ready yet...");
        if (self.outputTelnetStream != nil) {
            NSString* command = @"\n";
            NSData* cmdData = [[NSData alloc] initWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
            [self.outputTelnetStream write:(const unsigned char*)[cmdData bytes] maxLength:[cmdData length]];
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
    if (self.outputTelnetStream == nil) {
        // attempt reconnect
        NSLog(@"  Attempting to (re)connect to telnet port.");
        [self connectDevice:self.ipAddress port:self.telnetPort];
    }
    
    NSLog(@"@sendTelnetCommand: number of queued commands: %lu", (unsigned long)self.telnetCmds.count);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timerSendTelnetCommand = [ NSTimer scheduledTimerWithTimeInterval:0.75
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
    self.datasetIds = [[NSMutableArray alloc] init];
    self.times = [[NSMutableArray alloc] init];
    self.displacements = [[NSMutableArray alloc] init];
    self.filtered = [[NSMutableArray alloc] init];
    self.blade_clearances = [[NSMutableArray alloc] init];
    self.point_counts = [[NSMutableArray alloc] init];
    self.intensities = [[NSMutableArray alloc] init];
    self.min_locs = [[NSMutableArray alloc] init];
    self.measurement_rate = @"1.0";
    self.telnetCmds = [[NSMutableArray alloc] init];
    self.metaData = [[ScanMetaData alloc] init];
    [self computeKernel:KERNEL_SIGMA kernel_size:KERNEL_SIZE]; // Compute the LoG filter kernel.
    self.stage_clearance = 0;
    if (self.inputTelnetStream == nil) {
        [self connectDevice:self.ipAddress port:self.telnetPort];
    }
    [self.telnetCmds addObject:[NSString stringWithFormat:@"ETHERMODE ETHERNET\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"OUTPUT ETHERNET\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASTRANSFER SERVER/TCP 1024\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"OUT_ETH 01INTENSITY 01DIST1 TIMESTAMP\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE 1.0\n"]];
    [self sendTelnetCommand];
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
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 NONE\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 5.0\n"]];
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 SET\n"]];
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
    if (self.inputTelnetStream == nil) {
        [self connectDevice:self.ipAddress port:self.telnetPort];
    }
    [self.telnetCmds addObject:[NSString stringWithFormat:@"DARKCORR\n"]];
    [self sendTelnetCommand];
}

- (void)setMeasurementRate:(NSString*)rate {
    if (![self checkReady]) return;
    self.pState = setMeasurementRateInProgress;
    self.measurement_rate = rate;
    [self.telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %@\n", rate]];
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
    if (self.inputDataStream != nil)
        [self.inputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    if (self.outputDataStream != nil)
        [self.outputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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

- (void)disconnectTelnet {
    NSLog(@"@disconnectTelnet.");
    if (self.inputTelnetStream != nil)
        [self.inputTelnetStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    if (self.outputTelnetStream != nil)
        [self.outputTelnetStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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
}

- (void)messageHandler:(NSString*)msg {
    
    NSArray* msgArray = [msg componentsSeparatedByString:@";"]; // This results in an extra empty string.
    NSString* cmd = [msgArray objectAtIndex:0];

    if ([cmd containsString:@"ping"]) {
        NSLog(@"Got ping");
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
        }
        // 100 samples/frame, measurement rate is in kHz.
        float nSets = [self.measurement_rate floatValue] * 1000.0 * [acqTime floatValue] / 100.0;
        int num_sets = ceil(nSets); // Round up.
        // now call collect data with the acquisition time.
        [self collectData:num_sets casingThickness:[self.metaData.casing_thickness floatValue]];
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
        self.metaData.state = [msgArray objectAtIndex:7];
    }
    if ([cmd containsString:@"clear_meta_data"]) {
        NSLog(@"Got clear_meta_data");
        [self clearMetaData];
    }
    if ([cmd containsString:@"get_data_file"]) {
        NSLog(@"Got get_data_file");
        NSDictionary* jsonDict = @{@"type":@"filename",@"fname":self.last_saved_file};
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
    }
    if ([cmd containsString:@"do_dark_reference"]) {
        NSLog(@"Got do_dark_reference");
        [self doDarkReference];
    }
    if ([cmd containsString:@"do_mastering"]) {
        NSLog(@"Got do_mastering");
        [self masterDevice];
    }
    if ([cmd containsString:@"set_measuring_rate"]) {
        NSLog(@"Got set_measuring_rate");
        [self setMeasurementRate:[msgArray objectAtIndex:1]];
    }
    else {
        NSLog(@"Got %@",msg);
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
}

// Should be self-explanitory.
- (void)clearData {
    [self.datasetIds removeAllObjects];
    [self.times removeAllObjects];
    [self.displacements removeAllObjects];
    [self.filtered removeAllObjects];
    [self.blade_clearances removeAllObjects];
    [self.point_counts removeAllObjects];
    [self.intensities removeAllObjects];
    [self.min_locs removeAllObjects];
}

// The collectData function is patterned after the e4PtTool python function
// named collect_data and tries to accomplish the same thing.
- (void)collectData:(int)num_sets casingThickness:(float)casing_thicknesss {
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

    // Connect the device to collect the data.
    [self connectDevice:self.ipAddress port:self.dataPort];
    
}

#pragma mark - TCPSocketDelegate

- (void)stream:(NSStream *)inStream handleEvent:(NSStreamEvent)streamEvent {
    
    __block NSStream* theStream = inStream;
    dispatch_async(dispatch_get_main_queue(), ^{
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
                    if(foundInputDataS) NSLog(@"  stream is an input data stream");
                    if(foundOutputDataS) NSLog(@"  stream is an output data stream");
                    if(foundInputTelnetS) NSLog(@"  stream is an input telnet stream");
                    if(foundOutputTelnetS) NSLog(@"  stream is an output telnet stream");
                    NSLog(@"  TCP process data");
                    
                    long int len2;
                    //__block int set_count = 0;
                    uint32_t order_number;
                    uint32_t serial_number;
                    uint32_t video_length;
                    uint32_t len_meas_dat;
                    uint32_t num_frames;
                    uint32_t counter;
                    uint32_t timestamp;
                    uint8_t tmpBuf[2048];
                    
                    if ([self.inputDataStream hasBytesAvailable]) {
                        
                        while (self.set_count < self.num_sets) {
                            len2 = [self.inputDataStream read:tmpBuf maxLength:4];
                            if ( strncmp((const char*)tmpBuf, "DATA", 4) == 0 ) {
                                NSLog(@"FOUND DATA! - %d", self.set_count);
                                
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
                                NSLog(@"%d: %d, %d, %d, %d, %d, %d", self.set_count, order_number, serial_number, video_length, len_meas_dat, num_frames, counter);
                                
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
                                    [self.datasetIds addObject:[NSNumber numberWithInt:self.set_count]];
                                    [self.point_counts addObject:[NSNumber numberWithInteger:num_frames]];
                                    
                                    NSLog(@"%@",[NSString stringWithFormat:@"\n%d: %u, %f, %f", i, timestamp, intensity, displacement]);
                                    
                                    self.data_index += 1;
                                }
                                
                                self.set_count += 1;
                                
                            }
                            //else {
                            //    NSLog(@"  no data");
                            //}
                        }
                        [self disconnectData]; // Stop receiving data
                        self.set_count = 0;
                        
                        // Load dummy data for testing without a rotor.
                        if (SIMULATED_DATA == 1) {
                            [self loadCSVFile];
                        }
                        [self computeClearance];

                        // At this point we should have all the data that was requested.
                        // We need to do any required processing/filtering, save to file,
                        // then bundle it up and send it back through to the javascript.
                        NSDictionary* jsonDict = @{@"type":@"status",@"status":@"processing"};
                        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
                        result.keepCallback = [NSNumber numberWithBool:YES];
                        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
                        
                        NSError* error;
                        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:self.displacements options:NSJSONWritingSortedKeys error:&error];
                        //NSData* jsonData = [NSJSONSerialization dataWithJSONObject:self.filtered options:NSJSONWritingSortedKeys error:&error];
                        NSString *dispJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        jsonData = [NSJSONSerialization dataWithJSONObject:self.intensities options:NSJSONWritingSortedKeys error:&error];
                        NSString *intensJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        jsonData = [NSJSONSerialization dataWithJSONObject:self.min_locs options:NSJSONWritingSortedKeys error:&error];
                        NSString *minLocsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        jsonData = [NSJSONSerialization dataWithJSONObject:self.blade_clearances options:NSJSONWritingSortedKeys error:&error];
                        NSString *bladeClrsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

                        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                        NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
                        NSString* clearance = [NSString stringWithFormat:@"%f",self.stage_clearance];
                        
                        NSDictionary* jsonDataDict = @{@"type":@"data",
                                                       @"data":dispJSONString,
                                                       @"intensity":intensJSONString,
                                                       @"locs":minLocsJSONString,
                                                       @"gaps":bladeClrsJSONString,
                                                       @"clearance":clearance,
                                                       @"casing_thickness":self.metaData.casing_thickness,
                                                       @"spacer_thickness":self.metaData.spacer_thickness,
                                                       @"date":dateStr
                                                       };
                        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDataDict];// You can send data, String, int, array, dictionary, etc.
                        result.keepCallback = [NSNumber numberWithBool:NO];
                        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
                        [self saveCSVFile];
                        [self clearData];
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
                        NSString* prompt = [tmpStr substringFromIndex: [tmpStr length] - 2];
                        if ([prompt containsString:@"->"]) {
                            NSLog(@"Got telnet prompt");
                            self.telnetIsReady = true;
                            if (self.pState == initializationInProgress) {
                                if (self.telnetCmds.count == 0) {
                                    [self processComplete:@"connected"];
                                }
                            }
                            if (self.pState == setMeasurementRateInProgress) {
                                NSLog(@"Set measurement rate complete");
                                [self processComplete:@"connected"];
                            }
                            if (self.pState == darkReferenceInProgress) {
                                NSLog(@"Dark Correction Complete.");
                                [self processComplete:@"connected"];
                            }
                            if (self.pState == masteringInProgress) {
                                // Check for mastering commands still in the queue.  If there are none, then
                                // mastering is complete.  If there are still mastering commands in the queue
                                // then mastering is not complete.
                                bool foundMasterCommand = false;
                                for (NSString* cmd in self.telnetCmds) {
                                    if ([cmd containsString:@"MASTER"]) {
                                        foundMasterCommand = true;
                                    }
                                }
                                if (!foundMasterCommand) {
                                    NSLog(@"Mastering Complete.");
                                    [self processComplete:@"done_mastering"];
                                }
                            }
                        }
                        else {
                            NSLog(@"TN: %@",tmpStr);
                        }
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
                    [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                    //          [theStream release];
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

- (void)processComplete:(NSString*)statusMsg {
    NSDictionary* jsonDict = @{@"type":@"status",@"status":statusMsg};
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
    [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
    self.pState = ready;
}

- (void)computeClearance {
    // Displacement values will be between 0-15.
    // We create a coarse histogram to see how many peaks we find.
    int nbins = OUT_OF_RANGE + 1;
    int hBins[nbins];
    float data[self.displacements.count];
    for (int i=0; i<nbins; i++) hBins[i] = 0;
    // Populate the histogram by converting displacements to histogram indices.
    // Round each displacement to get the bin index.
    NSLog(@"Populating histogram...");
    int idx = 0;
    for (NSNumber* n in self.displacements) {
        float d = [n floatValue];
        data[idx++] = d; // poplulate a temporary data array.
        int bIdx = (int)floor(d); // Using floor makes bin edges integers. E.g. [0-1][+1-2][+2-3]...
        if (bIdx > nbins-1) bIdx = nbins - 1; // Don't overflow
        if (bIdx < 0) bIdx = 0; // Don't underflow
        hBins[bIdx]++; // Increment the histogram bin
    }
    NSLog(@"Histogram:\n");
    for (int i=0; i<nbins; i++) {
        NSLog(@" hBin[%d]: %d",i, hBins[i]);
    }
    // Find the top 3 peaks. One should be at 15. There should be one or two
    // others.  Two if measuring squealer tips; One if not.
    NSLog(@"Finding peaks...");
    int max1, max2, max3, i, peak1, peak2, peak3;
    max1 = max2 = max3 = i = peak1 = peak2 = peak3 = 0;
    for (i=0; i<nbins; i++) {
        if (hBins[i] > max1) {
            max1 = hBins[i];
            peak1 = i;
        }
    }
    for (i=0; i<nbins; i++) {
        if ((hBins[i] > max2) && (hBins[i] < max1)) {
            max2 = hBins[i];
            peak2 = i;
        }
    }
    for (i=0; i<nbins; i++) {
        if ((hBins[i] > max3) && (hBins[i] < max2)) {
            max3 = hBins[i];
            peak3 = i;
        }
    }
    NSLog(@"Peaks: %d, %d, %d", peak1, peak2, peak3);
    // Look at the difference between peaks to see if we're dealing with squealers or not.
    NSLog(@"Finding threshold...");
    float peakDiff = 1.0; // peak separation of 1mm
    float d12 = fabs((float)peak2 - (float)peak1);
    float d23 = fabs((float)peak3 - (float)peak2);
    float threshold = 0.0;
    if ((d12 >= peakDiff) && (d23 >= peakDiff)) {
        // Looks like squealer tips.
        NSLog(@"Looks like squealer tips.");
        threshold = ((float)peak2 + (float)peak3)/2.0;
    }
    else {
        // Looks like this is not a squealer tip.
        NSLog(@"Looks like not squealer tips.");
        threshold = ((float)peak1 + (float)peak3)/2.0;
    }
    NSLog(@"Found Threshold: %f\nThresholding data...",threshold);
    
    // Perform edge detection with an LoG filter
    // (Kernel computation was handled during initialization.)
    NSLog(@"Filtering...");
    [self fir_filter:self.kernel threshold:threshold];
    NSLog(@"Done.");
    
    //return; // Stop so we can just see the results of filtering
    
    // Fill sig_sign buffer with just 1 or -1 indicating the sign
    // of the filtered signal.
    int sig_sign[self.filtered.count];
    i=0;
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
    bool pos_crossing[self.filtered.count];
    bool neg_crossing[self.filtered.count];
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
                    NSNumber* intnst = [self.intensities objectAtIndex:j];
                    NSNumber* d = [self.displacements objectAtIndex:j];
                    if ( ([intnst floatValue] > 0) && ([d floatValue] < threshold) ) {
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
                clearance = clearance / count; // Average clearance for this blade.
#ifdef OUTPUT_MINIMUM
                [self.blade_clearances addObject:[NSNumber numberWithFloat:min_clearance]];
#else
                [self.blade_clearances addObject:[NSNumber numberWithFloat:clearance]];
                min_loc = ((float)start + (float)stop) / 2.0;
#endif
                [self.min_locs addObject:[NSNumber numberWithFloat:min_loc]];
                NSLog(@"Clearance: %f", clearance);
                for (int j=start; j<=stop; j++) {
                    [self.filtered addObject:[NSNumber numberWithFloat:clearance]];
                }
            }
            i = stop; // Move the start point ahead to where we stopped.
        }
        else {
            [self.filtered addObject:[NSNumber numberWithFloat:OUT_OF_RANGE]];
        }
    }
    self.stage_clearance = 0.0;
    int stage_num_blades = (int)[self.metaData.num_blades integerValue];
    if (stage_num_blades > 0) {
        for (i=0; i<stage_num_blades; i++) {
            NSNumber* c = [self.blade_clearances objectAtIndex:i];
            self.stage_clearance += [c floatValue];
        }
        self.stage_clearance /= (float)stage_num_blades;
    }
    
    NSLog(@"Done.");
}

// computeKernel computes a normalized Laplacian-of-Gaussian kernel for
// edge detection.
// kernel_size should be an odd number.  This is a quick & dirty
// implementation and there is no check for this.
- (void)computeKernel:(float)sigma kernel_size:(int)kernel_size {
    if (self.kernel == nil) self.kernel = [[NSMutableArray alloc] init];
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
    float h[h_length];
    int idx = 0;
    for (NSNumber* f in kernel) {
        h[idx] = [f floatValue];
        idx++;
    }
    
    // Get the data into a float array, thresholding as we go.
    unsigned x_length = (unsigned)self.displacements.count;
    float x[x_length];
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
    float temp_buffer[result_length];
    
    // Pointer to end of filter for use with vDSP_conv
    float    *h_end = h + (h_length - 1);
    
    // Length of signal passed to vDSP_conv
    unsigned signal_length = (h_length + result_length);
    
    // Create an array to store the signal passed to vDSP_conv, padded with zeros
    float padded[signal_length];
    
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
        [self.filtered addObject:[NSNumber numberWithFloat:tmpf]];
    }
    
}

// loadCSVFile should never be used in the field, but is here to allow
// for debugging when a rotor is not available.  It reads a CSV file
// and populates the data structures as though the data had come from
// the sensor.
- (void)loadCSVFile {
    [self clearData]; // Clear everything out to re-write it from CSV file.
    NSString* fName = @"test_data"; // test data file
    NSString* csvPath = [[NSBundle mainBundle] pathForResource:fName ofType:@"csv"];
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:csvPath]) {
        NSLog(@"Found CSV file.");
    }
    else {
        NSLog(@"CSV file not found.");
        return;
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
            self.metaData.casing_thickness = [lineArray objectAtIndex:7]; // Get casing thickness once.
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
}

- (void)saveCSVFile {
    // Get the date & time for the filename.
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
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
    // Create a file name as sn_stage_pos_state_datetime.csv.
    // If there is no serial number, just save to the data folder.
    NSString* csvFileName = [[NSString alloc] init];
    if (self.metaData.serial_number.length == 0) {
        csvFileName = [NSString stringWithFormat:@"%@/%@",
                       dataDir,
                       [NSString stringWithFormat:@"data_%@.csv",dateStr]];
    }
    else {
        NSString* fName = [NSString stringWithFormat:@"%@_%@_%@_%@.csv",
                           self.metaData.serial_number, self.metaData.stage,
                           self.metaData.position, dateStr];
        csvFileName = [NSString stringWithFormat:@"%@/%@", turbineDir, fName];
    }
    // Change the data-time string format in the filename.
    csvFileName = [csvFileName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    csvFileName = [csvFileName stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    self.last_saved_file = csvFileName;
    // Now write the file...
    // Open the output file.
    NSFileHandle *handle;
    if ([fm fileExistsAtPath:csvFileName]) {
        NSLog(@"Deleting existing dispositions CSV file...");
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
        NSLog(@"   Created CSV File.");
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
                    [self.displacements objectAtIndex:i], [self.intensities objectAtIndex:i],
                    self.metaData.casing_thickness];
        [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    //  Write the app version to the CSV file.
    NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    dataStr = [NSString stringWithFormat:@"\n\n\n - Created by e4PtTool version %@",appVersion];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];

    [handle closeFile];
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
        [self.manager setMeasurementRate:rateStr];
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
