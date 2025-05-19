//
//  BaseController.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "AppDelegate.h"
#import "BaseController.h"
#import "SensorSettings.h"

@interface BaseController ()
@property (strong, nonatomic) ControllerSettings* settings;
@end

@implementation BaseController {
    NSTimeInterval startTime;
    NSRegularExpression *promptRegex;
    NSRegularExpression *mrRegex;
    NSRegularExpression *sensorNameRegex;
    NSRegularExpression *sensorParamRegex;
    BOOL useSerialBuffer;
    BOOL useSensorParams;
}

@synthesize measurementData = _measurementData;
@synthesize settings = _settings;
@dynamic state;

-(instancetype)initWithDelegate:(IFC242xManager*)delegate {
    return [self initWithDelegate:delegate andSettings:[[ControllerSettings alloc] initWithDelegate:delegate]];
}

-(instancetype)initWithDelegate:(IFC242xManager*)delegate andSettings:(ControllerSettings*)settings {

    if (self = [super init]) {
        self->delegate = delegate;
        self.settings = settings;
        self.state = notReady;
        self->telnetCmds = [NSMutableArray new];
        self->promptRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\-\\>)$" options:NSRegularExpressionCaseInsensitive error:nil];
        self->mrRegex = [NSRegularExpression regularExpressionWithPattern:@"\\s(\\d+\\.\\d+)mm" options:NSRegularExpressionCaseInsensitive error:nil];
        self->sensorNameRegex = [NSRegularExpression regularExpressionWithPattern:@"Name:\\s+(.*?)(?:$|\\n)" options:NSRegularExpressionCaseInsensitive error:nil];
        self->sensorParamRegex = [NSRegularExpression regularExpressionWithPattern:@":\\s+(\\d{8})(?:$|\\r\\n)" options:NSRegularExpressionAnchorsMatchLines error:nil];
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

- (enum CONTROLLER_STATE) state
{
    return _state;
}

- (void) setState:(enum CONTROLLER_STATE)state
{
    _state = state;
}

- (void) recordStartTime {
    self->startTime = [[NSDate date] timeIntervalSince1970];
}

- (double) getElapsedTime {
    return [[NSDate date] timeIntervalSince1970] - self->startTime;
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
    NSString* command = self->telnetCmds[0];
    NSLog (@"  command: %@", command);
    if (self->telnetIsReady) {
        [self->telnetCmds removeObjectAtIndex:0];
        [self sendCommand:command];

        // Disable the timer if we've run out of commands to send.
        if ([self->telnetCmds count] == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [timer invalidate];
            });
        }
        self->telnetIsReady = NO;  // telnetIsReady is set to true as soon as the "->" comes back from the controller.
    } else {
        NSLog(@"  telnet is not ready yet...");
        [self sendEmptyCommand];
    }
}

- (void)initialize {
    NSLog(@"@BaseController::initialize");
    //[self->delegate dispatchMessage:@{@"type":@"log",@"message":@"BaseController.initialize"}];
    self.state = initializationInProgress;
    self->telnetIsReady = NO;
    self->controllerType = @"";
    self->buffer = [[NSMutableString alloc] initWithString:@""];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        self->useSerialBuffer = ((AppDelegate *)[UIApplication sharedApplication].delegate).useSerialBuffer;
        self->useSensorParams = ((AppDelegate *)[UIApplication sharedApplication].delegate).useSensorParams;
    });

#ifdef SEND_DISPLACEMENT_ONLY
    self->nextIFCValue = IFCDisplacement;
#else
    self->nextIFCValue = IFCIntensity;
#endif

    [self recordStartTime]; // start time timestamp in whole seconds.

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->timerSendTelnetCommand invalidate];
    });
    [self->telnetCmds removeAllObjects];
    [self->telnetCmds addObject:@"ETHERMODE ETHERNET\n"];
    [self configureOutputSettings];
    if (self.settings) {
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %.3f\n", self.settings.measurementRate]];
    }
    [self->telnetCmds addObject:@"OUTPUT NONE\n"]; // turns off output.
    [self->telnetCmds addObject:@"GETINFO\n"];

    [self sendTelnetCommand];
}

- (void)configureController {
    NSLog(@"@configureController");
    //[self->delegate dispatchMessage:@{@"type":@"log",@"message":@"BaseController.configureController"}];
    // update controller configuration to GE defaults
    [self->telnetCmds addObject:@"LANGUAGE EN\n"];
    [self->telnetCmds addObject:@"BAUDRATE 460800\n"];
    [self->telnetCmds addObject:@"IPCONFIG STATIC 192.168.168.150 255.255.0.0 192.168.1.1\n"];
    // send multiple times to ensure settings are stored
    [self->telnetCmds addObject:@"BASICSETTINGS STORE\n"];
    [self->telnetCmds addObject:@"BASICSETTINGS STORE\n"];
    [self->telnetCmds addObject:@"BASICSETTINGS STORE\n"];
    // TODO: settings not saved after controller power cycle
    [self->telnetCmds addObject:@"RESET\n"];
    
    [self sendTelnetCommand];
}

- (void)readSensorParameters {
    NSLog(@"@readSensorParameters");
    //[self->delegate dispatchMessage:@{@"type":@"log",@"message":@"BaseController.readSensorParameters"}];
    if ([self->controllerType containsString:@"IFC2422"]) {
        self.state = initializationInProgress;
        [self->telnetCmds addObject:@"SENSORINFO_CH01\n"];
        [self sendTelnetCommand];
    } else if ([self->controllerType containsString:@"IFC2421"]) {
        self.state = initializationInProgress;
        [self->telnetCmds addObject:@"SENSORINFO\n"];
        [self sendTelnetCommand];
    } else {
        NSLog(@"Unknown controller type");
    }
}

- (void)masterDevice:(NSString*)masteringValue {
    if (![self checkReady]) {
        return;
    }
    NSLog(@"@masteringDevice: %@", masteringValue);
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"BaseController.masterDevice: masteringValue=%@", masteringValue]} keepOpen:YES];

    self.state = masteringInProgress;
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"mastering_in_progress"} keepOpen:YES];

    // Mastering is a process internal to the controller.
    // However, it can't complete unless output is being generated (apparently).  This has been shown
    // by manually trying to master using a telnet window.
    // However, we don't want to contend with data pouring in while we are just mastering.  So instead,
    // we enable data on the OPPOSITE output from that to which we are connected.  That way mastering
    // can proceed and we are not inundated with data.
    [self selectOppositeOutput];

    if (!masteringValue) {
        [self->telnetCmds addObject:@"MASTERSIGNAL 01DIST1 NONE\n"];
        [self->telnetCmds addObject:@"MASTER 01DIST1 RESET\n"];
    } else {
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MASTERSIGNAL 01DIST1 %@\n", masteringValue]];
        [self->telnetCmds addObject:@"MASTER 01DIST1 SET\n"];
    }
    [self->telnetCmds addObject:@"OUTPUT NONE\n"];
    [self sendTelnetCommand];
}

//TODO: handle unknown controller model
- (void)doDarkReference {
    if (![self checkReady]) return;
    NSLog(@"@doDarkReference");
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.doDarkReference"} keepOpen:YES];
    self.state = darkReferenceInProgress;
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"waiting"} keepOpen:YES];

    float processTime = 24.0; // Dark correction takes ~22s per channel on the IFC2422.
    if ([self->controllerType containsString:@"IFC2422"]) {
        [self->telnetCmds addObject:@"DARKCORR_CH01\n"];
        [self->telnetCmds addObject:@"DARKCORR_CH02\n"];
        processTime *= 2.0; // 2 channels = twice the time.
    } else if ([self->controllerType containsString:@"IFC2421"]) {
        [self->telnetCmds addObject:@"DARKCORR\n"];
    } else {
        self.state = ready;
        [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"connected"} keepOpen:YES];
        [self->delegate returnPluginResponse:@{@"type":@"alert",@"message":@"Unable to perform dark reference"}];
        return; // Shouldn't get here.
    }
    // This timer just updates progress information every second assuming each channel takes ~22s.
    // After the dark correction, it collects 3 seconds of data.
    self.settings.acquisitionTime = 3.0;
    self->delegate.progress = 0.0;
    [self recordStartTime]; // start time timestamp in whole seconds.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithFloat:processTime], @"timeout",
                              @"doDataCollection", @"nextProcess", nil];
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeoutWaitTimer:) userInfo:info repeats:YES];
    });
    [self->delegate startProgressReporting];
    [self sendTelnetCommand];
}

- (void)setMeasurementRate:(float)rate {
    [self setMeasurementRate:rate reportStatus:YES];
}

- (void)setMeasurementRate:(float)rate reportStatus:(bool)report {
    if (![self checkReady]) return;
    NSLog(@"@setMeasurementRate: %.3f", rate);
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"BaseController.setMeasurementRate %.3f", rate]} keepOpen:YES];
    self.state = setMeasurementRateInProgress;
    self.settings.measurementRate = rate;
    [self->telnetCmds addObject:[NSString stringWithFormat:@"MEASRATE %.3f\n", self.settings.measurementRate]];
    [self sendTelnetCommand];

    [self recordStartTime];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary* info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithFloat:5.0], @"timeout", nil];
        if (report)
            [info setValue:@"processComplete" forKey:@"nextProcess"];
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeoutWaitTimer:) userInfo:info repeats:YES];
    });
}

- (void)setIntensityThreshold:(float)threshold {
    [self setIntensityThreshold:threshold sendImmediately:YES];
}

- (void)setIntensityThreshold:(float)threshold sendImmediately:(bool)send {
    if (![self checkReady]) return;
    NSLog(@"@setIntensityThreshold: %.3f", threshold);
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"BaseController.setIntensityThreshold: %.3f", threshold]} keepOpen:YES];
    if (send) self.state = setThresholdInProgress;
    self.settings.intensityThreshold = threshold;
    if ([self->controllerType containsString:@"IFC2422"]) {
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH01 %.3f\n", self.settings.intensityThreshold]];
         [self->telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD_CH02 %.3f\n", self.settings.intensityThreshold]];
    } else if ([self->controllerType containsString:@"IFC2421"]) {
        [self->telnetCmds addObject:[NSString stringWithFormat:@"MIN_THRESHOLD %.3f\n", self.settings.intensityThreshold]];
    } else {
        self.state = ready;
        [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"connected"} keepOpen:YES];
        [self->delegate returnPluginResponse:@{@"type":@"alert",@"message":@"Unable to set intensity threshold"}];
        return; // Shouldn't get here.
    }
    if (send) [self sendTelnetCommand];
}

- (bool)checkReady {
    if (self.state != ready) {
        [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"Error: Device not ready. Please wait."}];
    }
    return self.state == ready;
}

// disconnectDevice stops both data and telnet streams.
- (void)disconnectDevice {
    NSLog(@"@disconnectDevice");
    //[self->delegate dispatchMessage:@{@"type":@"log",@"message":@"BaseController.disconnectDevice"}];
    [self disconnectData];
    [self disconnectTelnet];
}

- (void)disconnectTelnet {
    NSLog(@"@disconnectTelnet");
    //[self->delegate dispatchMessage:@{@"type":@"log",@"message":@"BaseController.disconnectTelnet"}];
    [self->telnetCmds removeAllObjects];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->timerSendTelnetCommand invalidate];
    });
}

- (void)abortDataCollection {
    //[self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.abortDataCollection"} keepOpen:YES];
    if (self.state == collectingDataInProgress) {
        self.state = clearanceComputationInProgress;
        self->delegate.progress = 1.0;
        self->set_count = 0;

        [self disconnectData];
        [self processResponse:@TELNET_PROMPT];
    }
}

- (void)queueDataCollection:(float)timeoutSecondsForPrep {
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.queueDataCollection"} keepOpen:YES];
    [self recordStartTime]; // start timeout timer

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithFloat:7.0], @"timeout",
                              @"doDataCollection", @"nextProcess", nil];
        [NSTimer scheduledTimerWithTimeInterval:timeoutSecondsForPrep
                                         target:self
                                       selector:@selector(timeoutWaitTimer:)
                                       userInfo:info
                                        repeats:YES];
    });
}

- (void)doDataCollection {
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.doDataCollection"} keepOpen:YES];
    [self turnOffCalc]; // Habib added this Nov 24th 2024
    [self prepareDataForCollection];

    // Update the status in the HTML page.
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"acquiring"} keepOpen:YES];
    [self collectDataSets];
}

- (void)prepareDataForCollection {
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.prepareDataForCollection"} keepOpen:YES];
    [self.measurementData clear];
    self->set_count = 0;
    self->num_sets = [self calculateNumberOfDatasetsToAcquireForTime:self.settings.acquisitionTime atRateInHertz:self.settings.measurementRate * 1000];
    NSLog(@"prepareDataForCollection: num_sets = %d", num_sets);

    self->delegate.progress = 0.0;
    self.state = collectingDataInProgress;
    [self recordStartTime]; // start time timestamp in whole seconds.
}

- (void)processResponse:(NSString*)rxData {
    NSLog(@"@processResponse");
    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.processResponse"} keepOpen:YES];
    // TODO: remove old processing logic after we are satisfied with the updated logic
    NSString* prompt = @"";
    if (rxData.length > 1) {
        // fix for DEMO mode
        if (!self-> buffer) {
            NSLog(@"WARNING: Buffer was not allocated, allocating buffer");
            self->buffer = [[NSMutableString alloc] initWithString:@""];
        }
        if (self->useSerialBuffer) {
            NSLog(@"Using SERIAL BUFFER logic");
            // TODO: check if needed
            // clear buffer if size over limit
            if (self->buffer.length > MAX_BUFFER_SIZE) {
                NSLog(@"WARNING: Buffer length %lu is over the limit (%d), clearing buffer", self->buffer.length, MAX_BUFFER_SIZE);
                [self->buffer setString:@""];
            }

            // add rxData to buffer until end of response
            [self->buffer appendString:rxData];

            // look for prompt at the end of buffer
            NSUInteger promptMatches = [promptRegex numberOfMatchesInString:self->buffer options:0 range:NSMakeRange(0, self->buffer.length)];
            if (promptMatches == 0) {
                NSLog(@"Partial response: %@", self->buffer);
                return;
            } else {
                NSLog(@"Complete response: %@", self->buffer);
            }
        } else {
            NSLog(@"Using SERIAL PROMPT logic");
            prompt = [rxData substringFromIndex: [rxData length] - 2];
            NSLog(@"prompt: %@",prompt);
            // set buffer to current response
            [self->buffer setString:rxData];
        }
    } else {
        return;
    }

    // process buffer containing response
    if ([self->buffer containsString:@"IFC2422"]) {
        NSLog(@"Controller is IFC2422");
        self->controllerType = @"IFC2422";
        [self->telnetCmds addObject:@"SENSORINFO_CH01\n"];
        [self sendTelnetCommand];
    } else if ([self->buffer containsString:@"IFC2421"]) {
        NSLog(@"Controller is IFC2421");
        self->controllerType = @"IFC2421";
        [self->telnetCmds addObject:@"SENSORINFO\n"];
        [self sendTelnetCommand];
    } else {
        [self->sensorNameRegex enumerateMatchesInString:self->buffer options:0 range:NSMakeRange(0, self->buffer.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
            if ([match numberOfRanges] > 1) {
                self.settings.sensor.name = [self->buffer substringWithRange:[match rangeAtIndex:1]];
                NSLog(@"Sensor name is %@", self.settings.sensor.name);
            }
        }];
        [self->mrRegex enumerateMatchesInString:self->buffer options:0 range:NSMakeRange(0, self->buffer.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
            if ([match numberOfRanges] > 1) {
                self.settings.sensor.mr = [[self->buffer substringWithRange:[match rangeAtIndex:1]] floatValue];
                NSLog(@"Sensor MR is %f", self.settings.sensor.mr);
            }
        }];
        [self->sensorParamRegex enumerateMatchesInString:self->buffer options:0 range:NSMakeRange(0, self->buffer.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
            if ([match numberOfRanges] > 1) {
                NSString* sensorParams = [self->buffer substringWithRange:[match rangeAtIndex:1]];
                NSLog(@"Sensor params from controller: %@", sensorParams);
                [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"BaseController.processResponse: sensor params from controller = %@", sensorParams]} keepOpen:YES];
                if (self->useSensorParams) {
                    /*
                     SENSORINFO code change:
                      
                     Name: IFS2403-10(221)_1234 and IFS2403-10(222)_1234 where 1234 = 4 digit SN of the sensor.
                     Measurement range: XX.XXXmm
                     Serial: XXXXYYYY where X = sensor length and Y = sensor start of range in mm. We are limited to 8 digits for this field.
                      
                     Longer one -> 24281194 -> 24.28 and 11.94
                     *will need to add leading 2 in the code, to identify the length as 224.28mm
                     Shorter one -> 75691194 -> 75.69 and 11.94
                     */
                    float lengthMM = [[sensorParams substringToIndex:4] floatValue] / 100.0;
                    // TODO: check rule
                    if (lengthMM < 50.0) {
                        NSLog(@"Adding 200mm to sensor length");
                        lengthMM += 200.0;
                    }
                    float lengthInches = lengthMM / IN_to_MM;
                    NSLog(@"Sensor Length is %.3f mm or %.3f inches", lengthMM, lengthInches);

                    float smrMM = [[sensorParams substringFromIndex:4] floatValue] / 100.0;

                    NSString* name = self.settings.sensor.name;
                    float mrMM = self.settings.sensor.mr;

                    // update sensor type based on length
                    // TODO: check rule
                    if (lengthInches > 5) {
                        NSLog(@"Setting sensor to LONG");
                        self.settings.sensor = [SensorSettings LONG];
                    } else {
                        NSLog(@"Setting sensor to SHORT");
                        self.settings.sensor = [SensorSettings SHORT];
                    }
                    // override defaults
                    self.settings.sensor.name = name;
                    self.settings.sensor.length = lengthInches;
                    self.settings.sensor.smr = smrMM;
                    self.settings.sensor.mr = mrMM;
                    self.settings.sensorParamsProvided = TRUE;
                    // need to update mastering values after reading sensor params from the controller
                    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.processResponse: updateMasteringValues"} keepOpen:YES];
                    [self.settings.sensor updateMasteringValues];
                    NSLog(@"Sensor Length is %.3f inches and SMR is %.2f mm", self.settings.sensor.length, self.settings.sensor.smr);
                    NSLog(@"Mastering Value is %.3f mm and Mastering Offset is %.2f inches", self.settings.sensor.mv, self.settings.sensor.mo);
                    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"BaseController.processResponse: length=%.3f, smr=%.2f, mv=%.3f, mo=%.2f", self.settings.sensor.length, self.settings.sensor.smr, self.settings.sensor.mv, self.settings.sensor.mo]} keepOpen:YES];
                } else {
                    NSLog(@"Ignoring sensor params");
                    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.processResponse: ignoring sensor params from controller"} keepOpen:YES];
                }
            }
        }];
    }

    if (self->useSerialBuffer || [prompt containsString:@TELNET_PROMPT]) {
        NSLog(@"Got telnet prompt: telnetCmds.count = %lu, pState = %d",(unsigned long)self->telnetCmds.count, self.state);
        if (!self->telnetIsReady) {
            NSLog(@"Telnet is ready");
        }
        self->telnetIsReady = YES;
        // reset buffer
        [self->buffer setString:@""];

        switch (self.state) {
            case ready:
            case collectingDataInProgress:
            case notReady:
            case timeOut:
                break;
            case masteringInProgress:
                if (self->telnetCmds.count == 0) {
                    NSLog(@"Mastering Complete.");
                    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.processResponse: mastering complete"} keepOpen:YES];
                    [self->delegate processComplete:@"done_mastering"];
                    self.state = ready;
                }
                break;
            case darkReferenceInProgress:
                if (self->telnetCmds.count == 0) {
                    NSLog(@"Dark Correction Complete.");
                    [self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.processResponse: dark reference complete"} keepOpen:YES];
                }
                break;
            case initializationInProgress:
            case setMeasurementRateInProgress:
                if (self->telnetCmds.count > 0) {
                    break;
                } else {
                    NSLog(@"Initialization Complete.");
                }
            case setThresholdInProgress:
            case clearanceComputationInProgress:
            case halted:
                // TODO: does not get received by app for serial connection
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
    NSTimeInterval dT = [self getElapsedTime];
    if (dT < [timeout doubleValue]) {
        if (self.state == ready) {
            [timer invalidate];  // Everything is good. Turn off the timer and do the next thing.
            if ([nextProc containsString:@"doDataCollection"]) {
                NSLog(@"No timeout. Do data collection");
                [self doDataCollection];
            } else if ([nextProc containsString:@"processComplete"]) {
                [self->delegate processComplete:@"connected"];
            }
        } else if (self.state == darkReferenceInProgress) {
            // update the progress bar.
            self->delegate.progress = dT / [timeout doubleValue];
        } else if (self.state == setMeasurementRateInProgress) {
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
                [self->delegate returnPluginResponse:@{@"type":@"alert",@"message":msg} keepOpen:YES];
                self.state = ready;
                [self->delegate processComplete:@"connected"];
            } else if (self.state == darkReferenceInProgress) {
                // update then hide the progress bar.
                self->delegate.progress = 1.0;
                [self->delegate dispatchMessage:@{@"type":@"alert",@"message":@"Dark referencing complete."}];
                //[self->delegate returnPluginResponse:@{@"type":@"log",@"message":@"BaseController.timeoutWaitTimer: dark referencing complete"} keepOpen:YES];
                if ([nextProc containsString:@"doDataCollection"]) {
                    NSLog(@"Dark reference complete. Do data collection. %fs", self.settings.acquisitionTime);
                    [self doDataCollection];
                }
            }
        } else if ([nextProc containsString:@"processComplete"]) {
            [self->delegate processComplete:@"connected"];
        }

        [timer invalidate];
    }
}

- (ERR_CODE)Error:(NSString*)errorMessage {
    NSLog(@"Error: %@", errorMessage);
    return ERR_NOERROR; // or appropriate error code
}

        // public ERR_CODE turnOffCalc()
        // {
        //     if (_sensor.SetParameterInt("SP_ComputationQueue", 0) != ERR_CODE.ERR_NOERROR)
        //         return Error("SP_ComputationQueue");
        //     if (_sensor.SetParameterInt("SP_ComputationID", 1) != ERR_CODE.ERR_NOERROR)
        //         return Error("SP_ComputationID");
        //     if (_sensor.SetParameterInt("SP_ComputationOperation", 0) != ERR_CODE.ERR_NOERROR)
        //         return Error("SP_ComputationOperation");
        //     //  Disable Calc Module
        //     if (_sensor.ExecSCmd("Set_Computation") != ERR_CODE.ERR_NOERROR)
        //         return Error("Set_Computation");
        //     if (_sensor.SetParameterInt("SP_StatisticSignal", 0)!=ERR_CODE.ERR_NOERROR)
        //         return Error("SP_StatisticSignal");
        //     if (_sensor.SetParameterInt("SP_StatisticDepth", 0) != ERR_CODE.ERR_NOERROR)
        //         return Error("SP_StatisticDepth");
        //     // Disable Statistics, no error check will errror if Statistics table is empty
        //     _sensor.ExecSCmd("Set_StatisticSignal");
        //     return ERR_CODE.ERR_NOERROR;
        // }


// Habib added this Nov 24th 2024
// - (ERR_CODE)turnOffCalc {
//     NSLog(@"entering turnOffCalc"); // Print log statement
//     [self popup:[NSString stringWithFormat:@"Entering TurnOffCalc"]];
//     if ([self.settings.sensor SetParameterInt:@"SP_ComputationQueue" value:0] != ERR_NOERROR)
//         return [self Error:@"SP_ComputationQueue"];
//     if ([self.settings.sensor SetParameterInt:@"SP_ComputationID" value:1] != ERR_NOERROR)
//         return [self Error:@"SP_ComputationID"];
//     if ([self.settings.sensor SetParameterInt:@"SP_ComputationOperation" value:0] != ERR_NOERROR)
//         return [self Error:@"SP_ComputationOperation"];


//     // Disable Calc Module
//     if ([self ExecSCmd:@"Set_Computation"] != ERR_NOERROR)
//         return [self Error:@"Set_Computation"];
//     if ([self.settings.sensor SetParameterInt:@"SP_StatisticSignal" value:0] != ERR_NOERROR)
//         return [self Error:@"SP_StatisticSignal"];
//     if ([self.settings.sensor SetParameterInt:@"SP_StatisticDepth" value:0] != ERR_NOERROR)
//         return [self Error:@"SP_StatisticDepth"];


//     // Disable Statistics, no error check will error if Statistics table is empty
//     [self ExecSCmd:@"Set_StatisticSignal"];
//     return ERR_NOERROR;
// }

// Habib added this Dec 2024 ~ Jan 2025
- (ERR_CODE)turnOffCalc {
    NSLog(@"Entering turnOffCalc"); // Log entry for debugging
    [self popup:[NSString stringWithFormat:@"Entering TurnOffCalc in 2025"]];
    
    // Command to disable the moving average calculations
    // NSString *command = @"SPIKECORR_CH01 OFF\n";
    // NSString *command =  // @"OUTPUT NONE\n";
    NSString *command = @"COMP CH01 1 NONE\n"; 

    
    //  serial communication already setup.
    @try {
        // Write the command to the serial port
        [self sendCommand:command];
        
        // Log for confirmation
        NSLog(@"Command sent to disable moving average: %@", command);
        
        // Optionally show a popup for user feedback
        [self popup:[NSString stringWithFormat:@"Disabling Moving Average: %@", command]];
        
         // Add a delay to allow the response to be received
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * 3.0)), dispatch_get_main_queue(), ^{
            // Check if response data is available
            NSString *response = [self readResponse];
            if (response) {
                NSLog(@"Response received: %@", response);
                [self popup:[NSString stringWithFormat:@"Response: %@", response]];
            } else {
                NSLog(@"No response received");
                [self popup:@"No response received"];
            }
        });
    }
    @catch (NSException *exception) {
        NSLog(@"Error sending serial command: %@", exception.reason);
        [self popup:[NSString stringWithFormat:@"error in TurnOffCalc"]];
        return [self Error:[NSString stringWithFormat:@"Failed to send command: %@", exception.reason]];
    }
    
    return ERR_NOERROR; // Return success
}
// Habib added this for debugging only.
- (NSString *)readResponse {
    // NSData *responseData = [self->rscMgr getDataFromBytesAvailable];
    // if (responseData.length > 0) {
    //     NSString *response = [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding];
    //     return response;
    // }
    return nil; // No data available
}



- (UIViewController*)topMostController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

- (void)popup:(NSString*)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Executing Command"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [[self topMostController] presentViewController:alert animated:YES completion:nil];
}

- (ERR_CODE)ExecSCmd:(NSString*)command {
    NSLog(@"Executing command %@", command);
    
    // Show a popup alert using the new popup function
    [self popup:[NSString stringWithFormat:@"Executing command: %@", command]];
    
    if ([command isEqualToString:@"Set_Computation"]) {
        // Send the computation command to the controller
        NSString *computationCommand = [NSString stringWithFormat:@"SP_ComputationQueue %d\nSP_ComputationID %d\nSP_ComputationOperation %d\n", self.settings.sensor.computationQueue, self.settings.sensor.computationID, self.settings.sensor.computationOperation];
        [self sendCommand:computationCommand];
    } else if ([command isEqualToString:@"Set_StatisticSignal"]) {
        // Send the statistic signal command to the controller
        NSString *statisticCommand = [NSString stringWithFormat:@"SP_StatisticSignal %d\nSP_StatisticDepth %d\n", self.settings.sensor.statisticSignal, self.settings.sensor.statisticDepth];
        [self sendCommand:statisticCommand];
    } else {
        NSLog(@"Unknown command: %@", command);
        return ERR_UNKNOWN_COMMAND; 
    }
    
    return ERR_NOERROR;
}

@end
