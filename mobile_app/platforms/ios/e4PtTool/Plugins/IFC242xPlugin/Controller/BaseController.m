//
//  BaseController.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "BaseController.h"
#import "../IFC242xManager.h"

@interface BaseController ()
@property (strong, nonatomic) ControllerSettings* settings;
@property (nonatomic) enum CONTROLLER_STATE state;
@end

@implementation BaseController {
    NSTimeInterval startTime;
}

@synthesize measurementData = _measurementData;
@synthesize settings = _settings;
@synthesize state = _state;

-(instancetype)initWithDelegate:(IFC242xManager*)delegate {
    return [self initWithDelegate:delegate andSettings:[ControllerSettings new]];
}

-(instancetype)initWithDelegate:(IFC242xManager*)delegate andSettings:(ControllerSettings*)settings {
    
    if (self = [super init]) {
        self->telnetCmds = [NSMutableArray new];
        self.state = notReady;
        self->delegate = delegate;
        self.settings = settings;
        [self initialize];
    }
    return self;
}

- (ControllerSettings *) settings
{
    if (!_settings) _settings = [ControllerSettings new];
    return _settings;
}

- (MeasurementData *) measurementData
{
    if (!_measurementData) _measurementData = [MeasurementData new];
    return _measurementData;
}

- (NSMutableArray *) telnetCmds
{
    if (!telnetCmds) telnetCmds = [NSMutableArray new];
    return telnetCmds;
}

- (void)connectDevice:(NSString*)ip_address port:(int)port {

    dispatch_async(self->networkQueue, ^{
        NSLog(@"@connectDevice: %@:%d", ip_address, port);
        if (port == self->dataPort) self->dataStreamIsOpen = false;
        if (port == self->telnetPort) self->telnetStreamIsOpen = false;
        
        if (port == DATA_PORT) {
            if (self->inputDataStream != nil) {
                CFStreamStatus chkStream;
                CFReadStreamRef cfinputstream = (__bridge CFReadStreamRef )self->inputDataStream;
                chkStream = CFReadStreamGetStatus(cfinputstream);
                if(chkStream == (CFStreamStatus) kCFStreamStatusOpen){
                    NSLog(@"This device is already connected for data.");
                    return;
                }
            }
            if(self->outputDataStream != nil){
                NSLog(@"  Already Connected - Data");
                return;
            }
        }
        else if (port == TELNET_PORT) {
            if (self->inputTelnetStream != nil) {
                CFStreamStatus chkStream;
                CFReadStreamRef cfinputstream = (__bridge CFReadStreamRef )self->inputTelnetStream;
                chkStream = CFReadStreamGetStatus(cfinputstream);
                if(chkStream == (CFStreamStatus) kCFStreamStatusOpen){
                    NSLog(@"This device is already connected for telnet.");
                    return;
                }
            }
            if(self->outputTelnetStream != nil){
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
        [inputStream scheduleInRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
        //[inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        //[outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [inputStream open];
        [outputStream open];
        
        if (port == DATA_PORT) {
            self->outputDataStream = outputStream;
            self->inputDataStream = inputStream;
            [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(timeoutTimerDataStreamOpening:) userInfo:@(port) repeats:NO];
        } else if (port == TELNET_PORT) {
            self->outputTelnetStream = outputStream;
            self->inputTelnetStream = inputStream;
        }
    });
}

// This function sets up a timer that tries on an interval to send a command from a
// queue of commands over telnet.  The timer will keep firing until the queue runs
// out of command and the timer is invalidated in the callback.
- (void)sendTelnetCommand {
    
    NSLog(@"@sendTelnetCommand: number of queued commands: %lu", (unsigned long)self->telnetCmds.count);
    dispatch_async(dispatch_get_main_queue(), ^{
        self->timerSendTelnetCommand = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                        target:self
                                                                      selector:@selector(timeoutTelnetSendCommand:)
                                                                      userInfo:nil
                                                                       repeats:YES];
    });
}

- (void)timeoutTelnetSendCommand:(NSTimer*)timer {
    NSLog(@"@timeoutTelnetSendCommand: Timer expired. # commands = %lu", (unsigned long)self->telnetCmds.count);
    if (self->telnetCmds.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
            self.state = ready;
        });
        return;
    }
    NSString* command = [self->telnetCmds objectAtIndex:0];
    NSLog (@"  command: %@", command);
    if (self->telnetIsReady) {
        // send the command
        [self sendCommand:command];
        
        // Remove the command that was just sent
        [self->telnetCmds removeObjectAtIndex:0];
        
        // Disable the timer if we've run out of commands to send.
        if ([self->telnetCmds count] == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [timer invalidate];
            });
        }
        self->telnetIsReady = false;  // telnetIsReady is set to true as soon as the "->" comes back from the controller.
    } else {
        NSLog(@"  telnet is not ready yet...");
        [self sendEmptyCommand];
    }
}

- (void)initialize {
    self->ipAddress = @IFC_ADDR;
    self->dataPort = DATA_PORT;
    self->telnetPort = TELNET_PORT;
    self->telnetIsReady = false;
    self->controllerType = @"";
    
#ifdef SEND_DISPLACEMENT_ONLY
    self->nextIFCValue = IFCDisplacement;
#else
    self->nextIFCValue = IFCIntensity;
#endif
    
    self->startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->timerSendTelnetCommand invalidate];
    });
    [self->telnetCmds removeAllObjects];
    [self->telnetCmds addObject:@"ETHERMODE ETHERNET\n"];
    [self configureOutputSettings];
    if (self.settings)
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %.3f\n", self.settings.measurementRate]];
    [self->telnetCmds addObject:@"OUTPUT NONE\n"]; // turns off output.
    [self->telnetCmds addObject:@"GETINFO\n"];
    
    NSLog(@"Calling sendTelnetCommand from initializeSensor");
    [self setupSerialCableAndCommThread];
    [self sendTelnetCommand];

    // Remove notifications before adding them so they are not added multiple times.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)masterDevice:(NSString*)masteringValue {
    if (![self checkReady]) return;
    NSLog(@"@masteringDevice");
    
    if (self->inputTelnetStream == nil) {
        [self connectDevice:self->ipAddress port:self->telnetPort];
    }
    self.state = masteringInProgress;
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"mastering_in_progress"} keepOpen:YES];

    // Mastering is a process internal to the controller.
    // However, it can't complete unless output is being generated (apparently).  This has been shown
    // by manually trying to master using a telnet window.
    // However, we don't want to contend with data pouring in while we are just mastering.  So instead,
    // we enable data on the OPPOSITE output from that to which we are connected.  That way mastering
    // can proceed and we are not inundated with data.
    [self selectOppositeOutput];

    if (!masteringValue)
        [self->telnetCmds addObject:@"MASTER 01DIST1 RESET\n"];
    else {
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 %@\n", masteringValue]];
        [self->telnetCmds addObject:@"MASTER 01DIST1 SET\n"];
    }
    [self->telnetCmds addObject:@"OUTPUT NONE\n"];
    [self sendTelnetCommand];
}

//TODO handle unknown controller model
- (void)doDarkReference {
    if (![self checkReady]) return;
    NSLog(@"@doDarkReference");
    self.state = darkReferenceInProgress;
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"acquiring"} keepOpen:YES];
    
    [self connectTelnetPortIfNecessary:self->inputTelnetStream];
    
    float processTime = 24.0; // Dark correction takes ~22s per channel on the IFC2422.
    if ([self->controllerType containsString:@"IFC2422"]) {
        [self->telnetCmds addObject:@"DARKCORR_CH01\n"];
        [self->telnetCmds addObject:@"DARKCORR_CH02\n"];
        processTime *= 2.0; // 2 channels = twice the time.
    } else if ([self->controllerType containsString:@"IFC2421"]) {
        [self->telnetCmds addObject:@"DARKCORR\n"];
    } else {
        self.state = ready;
        [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"complete"} keepOpen:YES];
        [self->delegate returnPluginResponse:@{@"type":@"alert",@"message":@"Unable to perform dark reference"} keepOpen:YES];
        return; // Shouldn't get here.
    }
    // This timer just updates progress information every second assuming each channel takes ~22s.
    // After the dark correction, it collects 3 seconds of data.
    self->delegate.progress = 0.0;
    self->startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithFloat:processTime], @"timeout",
                              @"doDataCollection", @"nextProcess",
                              @"3.0", @"acqTime",
                              nil];
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeoutWaitTimer:) userInfo:info repeats:YES];
    });
    [self->delegate startProgressReporting];
    [self sendTelnetCommand];
}

- (void)setMeasurementRate:(float)rate {
    [self setMeasurementRate:rate sendImmediately:YES];
}

- (void)setMeasurementRate:(float)rate sendImmediately:(bool)send {
    if (![self checkReady]) return;
    self.state = setMeasurementRateInProgress;
    self.settings.measurementRate = rate;
    [self->telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %.3f\n", self.settings.measurementRate]];
    if (send) [self sendTelnetCommand];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithFloat:5.0], @"timeout", nil];
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeoutWaitTimer:) userInfo:info repeats:YES];
    });
}

- (void)setIntensityThreshold:(float)threshold {
    [self setIntensityThreshold:threshold sendImmediately:YES];
}

- (void)setIntensityThreshold:(float)threshold sendImmediately:(bool)send {
    if (![self checkReady]) return;
    self.state = setThresholdInProgress;
    self.settings.intensityThreshold = threshold;
    if ([self->controllerType containsString:@"IFC2422"]) {
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH01 %.3f\n", self.settings.intensityThreshold]];
         [self->telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH02 %.3f\n", self.settings.intensityThreshold]];
    } else if ([self->controllerType containsString:@"IFC2421"]) {
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD %.3f\n", self.settings.intensityThreshold]];
    } else {
        self.state = ready;
        [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"complete"} keepOpen:YES];
        [self->delegate returnPluginResponse:@{@"type":@"alert",@"message":@"Unable to set intensity threshold"} keepOpen:YES];
        return; // Shouldn't get here.
    }
    if (send) [self sendTelnetCommand];
}

- (bool)checkReady {
    if (self.state != ready) {
        [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"Error: Device not ready. Please wait."} keepOpen:YES];
    }
    return self.state == ready;
}

// disconnectDevice stops both data and telnet streams.
- (void)disconnectDevice {
    [self disconnectData];
    [self disconnectTelnet];
}

- (void)disconnectTelnet {
    NSLog(@"@disconnectTelnet.");
    if (self->inputTelnetStream != nil)
        [self->inputTelnetStream removeFromRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
    
    if (self->outputTelnetStream != nil)
        [self->outputTelnetStream removeFromRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
    
    if (self->inputTelnetStream != nil) {
        [self->inputTelnetStream close];
        self->inputTelnetStream = nil;
    }
    
    if (self->outputTelnetStream != nil) {
        [self->outputTelnetStream close];
        self->outputTelnetStream = nil;
    }
    
    self->telnetStreamIsOpen = false;
    [self->telnetCmds removeAllObjects];
}

- (void)doDataCollection {
    [self prepareDataForCollection];
    
    // Update the status in the HTML page.
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"acquiring"} keepOpen:YES];
    [self collectDataSets];
}

- (void)prepareDataForCollection {
    [self.measurementData clear];
    self->set_count = 0;
    self->num_sets = [self calculateNumberOfDatasetsToAcquireForTime:self.settings.acquisitionTime atRateInHertz:self.settings.measurementRate * 1000];
    NSLog(@"prepareDataForCollection: num_sets = %d", num_sets);

    self->delegate.progress = 0.0;
    self.state = collectingDataInProgress;
    self->startTime = [[NSDate date] timeIntervalSince1970]; // start time timestamp in whole seconds.
}

- (void)processResponse:(NSString*)rxData {
    NSLog(@"@processResponse");
    NSString* prompt = @"";
    if (rxData.length > 1) {
        prompt = [rxData substringFromIndex: [rxData length] - 2];
        NSLog(@"prompt: %@",prompt);
    } else {
        return;
    }
    
    if ([rxData containsString:@"Measurement range:"]) {
        NSString* measurementRange = [[rxData componentsSeparatedByString:@"\r\n"][3] substringFromIndex:18];
        self.settings.sensor.mr = [[measurementRange substringToIndex:[measurementRange length]-2] floatValue];
        NSLog(@"Sensor Measurement Range is %f", self.settings.sensor.mr);
    } else if ([rxData containsString:@"IFC2422"]) {
        NSLog(@"Controller is IFC2422");
        self->controllerType = @"IFC2422";
        [self->telnetCmds addObject:@"SENSORINFO_CH01\n"];
        [self sendTelnetCommand];
    } else if ([rxData containsString:@"IFC2421"]) {
        NSLog(@"Controller is IFC2421");
        self->controllerType = @"IFC2421";
        [self->telnetCmds addObject:@"SENSORINFO\n"];
        [self sendTelnetCommand];
    }
    
    if ([prompt containsString:@"->"]) {
        NSLog(@"Got telnet prompt: telnetCmds.count = %lu",(unsigned long)self->telnetCmds.count);
        self->telnetIsReady = true;
        switch (self.state) {
                
            case masteringInProgress:
                if (self->telnetCmds.count == 0) {
                    NSLog(@"Mastering Complete.");
                    [self->delegate processComplete:@"done_mastering"];
                    self.state = ready;
                }
                break;
                
            case darkReferenceInProgress:
                if (self->telnetCmds.count == 0) {
                    NSLog(@"Dark Correction Complete.");
                    [self->delegate processComplete:@"connected"];
                }
                break;
                
            case initializationInProgress:
            case setMeasurementRateInProgress:
                if (self->telnetCmds.count > 0) break;
                
            case setThresholdInProgress:
            case clearanceComputationInProgress:
                [self->delegate processComplete:@"connected"];
            
            default:
                self.state = ready;
                break;
        }
    }
    NSLog(@"Returning from processResponse");
}

- (void)timeoutWaitTimer:(NSTimer*)timer {
    NSDictionary* info = [timer userInfo];
    NSNumber* timeout = [info valueForKey:@"timeout"];
    NSString* nextProc = [info valueForKey:@"nextProcess"];
    NSTimeInterval dT = [[NSDate date] timeIntervalSince1970] - self->startTime;
    if (dT < [timeout doubleValue]) {
        if (self.state == ready) {
            [timer invalidate];  // Everything is good. Turn off the timer and do the next thing.
            if ([nextProc containsString:@"doDataCollection"]) {
                NSLog(@"No timeout. Do data collection");
                [self doDataCollection];
            }
        } else if (self.state == darkReferenceInProgress) {
            // update the progress bar.
            self->delegate.progress = dT / [timeout doubleValue];
        } else {
            // otherwise, keep waiting...
            [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"waiting"} keepOpen:YES];
        }
    } else {
        if (self.state != ready) {
            // This is the timeout condition. The timeout has expired.
            // This could mean an error occured.
            NSString* msg = @"";
            if (self.state == setMeasurementRateInProgress) {
                msg = @"Error setting measurement rate.\nTimeout.";
                
                NSLog(@"%@",msg);
                [self->delegate returnPluginResponse:@{@"type":@"alert",@"message":msg} keepOpen:NO];
                self.state = ready;
            } else if (self.state == darkReferenceInProgress) {
                // update then hide the progress bar.
                self->delegate.progress = 1.0;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    NSDictionary* jsonDict = @{@"type":@"alert",@"message":@"Dark referencing complete."};
                    if (/* DISABLES CODE */ (true)) {
                        NSError* error;
                        NSData *jsonData=[NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingSortedKeys error:&error];
                        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                        [self->delegate.commandDelegate evalJs:[NSString stringWithFormat:@"pluginMessage(%@);",jsonString]];
                    }
                    else {
                        [self->delegate returnPluginResponse:jsonDict keepOpen:YES];
                    }
                });
                if ([nextProc containsString:@"doDataCollection"]) {
                    NSLog(@"Dark reference complete. Do data collection. %fs", self.settings.acquisitionTime);
                    [self doDataCollection];
                }
            }
        }

        [timer invalidate];
    }
}

- (void)timeoutTimerDataStreamOpening:(NSTimer*)timer {
    NSLog(@"@timeoutDataStreamOpening: Timer expired (as expected)");
    int port = [timer.userInfo intValue];

    NSLog(@"    ipaddress = %@:%d",self->ipAddress,port);
    
    if(self->dataStreamIsOpen){
        NSLog(@"    OK - stream is open.");
    } else {
        NSLog(@"    stream not open.");
        [self->inputDataStream removeFromRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
        [self->outputDataStream removeFromRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
        //[self->inputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        //[self->outputDataStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        // apple documentation also says to set delegate connection to nil (how?)
        
        if (port == DATA_PORT) {
            NSLog(@"    closing data port streams.");
            [self->inputDataStream close];
            self->inputDataStream = nil;
            [self->outputDataStream close];
            self->outputDataStream = nil;
        }
        else if (port == TELNET_PORT) {
            NSLog(@"    closing telnet port streams.");
            [self->inputTelnetStream close];
            self->inputTelnetStream = nil;
            [self->outputTelnetStream close];
            self->outputTelnetStream = nil;
        }
    }
}

@end
