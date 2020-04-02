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
@property (strong, nonatomic) NSString* operator;
@property (strong, nonatomic) NSString* units;
    

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
@synthesize operator = _operator;
@synthesize units = _units;
    

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
@property (strong, nonatomic) NSMutableArray* point_counts;
@property (strong, nonatomic) NSMutableArray* intensities;

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
@synthesize point_counts = _point_counts;
@synthesize intensities = _intensities;

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
        [self.outputTelnetStream write:[cmdData bytes] maxLength:[cmdData length]];
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
            [self.outputTelnetStream write:[cmdData bytes] maxLength:[cmdData length]];
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
    self.point_counts = [[NSMutableArray alloc] init];
    self.intensities = [[NSMutableArray alloc] init];
    self.measurement_rate = @"1.0";
    self.telnetCmds = [[NSMutableArray alloc] init];
    self.metaData = [[ScanMetaData alloc] init];
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
    NSDictionary* jsonDict = @{@"type":@"status",@"status":@"acquiring"};
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
        self.metaData.operator = [msgArray objectAtIndex:5];
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
    self.metaData.operator = @"";
    self.metaData.units = @"";
}

// Should be self-explanitory.
- (void)clearData {
    [self.datasetIds removeAllObjects];
    [self.times removeAllObjects];
    [self.displacements removeAllObjects];
    [self.point_counts removeAllObjects];
    [self.intensities removeAllObjects];
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
        [self.datasetIds removeAllObjects];
        [self.times removeAllObjects];
        [self.displacements removeAllObjects];
        [self.point_counts removeAllObjects];
        [self.intensities removeAllObjects];
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
                        

                        // At this point we should have all the data that was requested.
                        // We need to do any required processing/filtering, save to file,
                        // then bundle it up and send it back through to the javascript.
                        NSDictionary* jsonDict = @{@"type":@"status",@"status":@"processing"};
                        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonDict];// You can send data, String, int, array, dictionary, etc.
                        result.keepCallback = [NSNumber numberWithBool:YES];
                        [self.plugin.commandDelegate sendPluginResult:result callbackId:self.plugin.cmd.callbackId];
                        
                        NSError* error;
                        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:self.displacements options:NSJSONWritingSortedKeys error:&error];
                        NSString *dispJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        jsonData = [NSJSONSerialization dataWithJSONObject:self.intensities options:NSJSONWritingSortedKeys error:&error];
                        NSString *intensJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

                        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                        NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
                        
                        NSDictionary* jsonDataDict = @{@"type":@"data",
                                                       @"data":dispJSONString,
                                                       @"intensity":intensJSONString,
                                                       @"locs":@"",
                                                       @"gaps":@"",
                                                       @"clearance":@"",
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
    tmpManager.webView = self.webView;  // for bidirectional communication
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
