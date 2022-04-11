//
//  IFC242xManager.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-30.
//
//

#import "AppDelegate.h"
#import "IFC242xManager.h"
#import "PostProcess.h"
#import "ScanMetaData.h"
#import "Controller/DemoController.h"
#import "Controller/EthernetController.h"
#import "Controller/SerialController.h"

@implementation IFC242xManager {
    CDVPlugin* plugin;
    NSObject<IController>* controller;
    ScanMetaData* metaData;
    PostProcess* postProcess;
    NSString* cmdCallbackId, *lastSavedFile, *connectionType;
    BOOL calibratedAcquire;
}

@synthesize progress = _progress;

-(instancetype)initWithPlugin:(CDVPlugin*)plugin {
    NSLog(@"@IFC242xManager::initWithPlugin");
    //[self dispatchMessage:@{@"type":@"log",@"message":@"Manager.initWithPlugin"}];
    if (self = [super init]) {
        self->plugin = plugin;

        dispatch_sync(dispatch_get_main_queue(), ^{
            self->connectionType = ((AppDelegate *)[UIApplication sharedApplication].delegate).connectionType;
        });
        NSLog(@"Connection type: %@", self->connectionType);
        if ([self->connectionType isEqualToString:@"serial"]) {
            self->controller = [[SerialController alloc] initWithDelegate:self];
        } else if ([self->connectionType isEqualToString:@"ethernet"]) {
            self->controller = [[EthernetController alloc] initWithDelegate:self];
        } else if ([self->connectionType isEqualToString:@"demo"]) {
            self->controller = [[DemoController alloc] initWithDelegate:self];
        } else {
            NSLog(@"Invalid connection type %@, defaulting to serial", self->connectionType);
            self->controller = [[SerialController alloc] initWithDelegate:self];
        }
        
        self->postProcess = [[PostProcess alloc] initWithDelegate:self];//[PostProcess new];
        
        // Remove notifications before adding them so they are not added multiple times.
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication* app = [UIApplication sharedApplication];
        if (![app isIdleTimerDisabled]) {
            [app setIdleTimerDisabled:YES];
        }
    });
    return self;
}

- (void)returnPluginResponse:(NSDictionary*)jsonMessage {
    [self returnPluginResponse:jsonMessage keepOpen:NO];
}

- (void)returnPluginResponse:(NSDictionary*)jsonMessage keepOpen:(BOOL)keepOpen {
    NSLog(@"returnPluginResponse [%d]: %@", keepOpen, jsonMessage);
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonMessage];
    [result setKeepCallback:[NSNumber numberWithBool:keepOpen]];
    [self->plugin.commandDelegate sendPluginResult:result callbackId:self->cmdCallbackId];
}

- (void)processComplete:(NSString*)statusMsg {
    NSLog(@"processComplete: %@", statusMsg);
    if (self->controller.state == darkReferenceInProgress) {
        return; // Dark referencing is followed by data collection
    } else if (self->controller.state == setMeasurementRateInProgress) {
        [self returnPluginResponse:@{@"type":@"alert",@"message":[NSString stringWithFormat:@"Measurement rate set to %.3f kHz.", self->controller.settings.measurementRate]} keepOpen:YES];
        return;
    } else if (self->controller.state == setThresholdInProgress) {
        [self returnPluginResponse:@{@"type":@"alert",@"message":[NSString stringWithFormat:@"Threshold is set to %.3f.", self->controller.settings.intensityThreshold]} keepOpen:YES];
    } else if (self->controller.state == halted) {
        [self returnData:[self computeClearance:self->controller.measurementData] measurementData:self->controller.measurementData];
    }
    [self returnPluginResponse:@{@"type":@"status",@"status":statusMsg}];
}

- (ClearanceData*)computeClearance:(MeasurementData*)measurementData {
    self->postProcess.outOfRange = self->controller.settings.outOfRange;
    
    float offsetAdjustment = 0.0;
    // Disabled until further testing, this would apply offsetAdjustment only for turbine measurements and not apply to acquisition via Get Data
    if (self->calibratedAcquire) {
        offsetAdjustment = [self->controller.settings.sensor calculateOffsetAdjustment:self->metaData.spacerThickness casingThickness:self->metaData.casingThickness];
    }
    return [self->postProcess computeClearance:measurementData bladeCount:self->metaData.numberOfBlades usingAdjustmentFactor:offsetAdjustment];
}

- (void)returnData:(ClearanceData*)clearanceData measurementData:(MeasurementData*)measurementData {
    //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.returnData"} keepOpen:YES];
    NSError* error;
    NSData* jsonData;
    // If we've done a calibrated acquisition we pass back the filtered, calibrated data.
    // If we've done an uncalibrated acquisition we pass back the raw, uncalibrated data.
    if (self->calibratedAcquire) {
        jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.filtered options:NSJSONWritingSortedKeys error:&error];
    } else {
        jsonData = [NSJSONSerialization dataWithJSONObject:measurementData.displacements options:NSJSONWritingSortedKeys error:&error];
    }
    NSString *dispJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:measurementData.intensities options:NSJSONWritingSortedKeys error:&error];
    NSString *intensJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.locations options:NSJSONWritingSortedKeys error:&error];
    NSString *minLocsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.bladeClearances options:NSJSONWritingSortedKeys error:&error];
    NSString *bladeClrsJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [NSJSONSerialization dataWithJSONObject:clearanceData.quality options:NSJSONWritingSortedKeys error:&error];
    NSString *clrQualityJSONString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate* date = [NSDate date];
    NSString* dateStr = [dateFormatter stringFromDate:date];
    NSString* clearance = [NSString stringWithFormat:@"%f", clearanceData.clearance];
    NSString* stg_max_clr = [NSString stringWithFormat:@"%f", clearanceData.max];
    NSString* stg_min_clr = [NSString stringWithFormat:@"%f", clearanceData.min];
    NSString* stg_med_clr = [NSString stringWithFormat:@"%f", clearanceData.median];
    NSString* stg_clr_std = [NSString stringWithFormat:@"%f", clearanceData.std];
    NSString* overall_avg = isnan(clearanceData.averageDisplacement) ? @"\"--\"" : [NSString stringWithFormat:@"%f", clearanceData.averageDisplacement];
    NSString* blades = [NSString stringWithFormat:@"%d", clearanceData.blades];
    NSString* blade_samples_avg = [NSString stringWithFormat:@"%f", clearanceData.averageBladeSamples];
    
    [self saveCSVFile:date clearanceData:clearanceData measurementData:measurementData];
    NSArray* savedFilepath;
    if (self->lastSavedFile) {
        savedFilepath = [self->lastSavedFile pathComponents];
    } else {
        savedFilepath = @[@"",@""];
    }
    NSRange endRange = NSMakeRange(savedFilepath.count - 2, 2);
    NSDictionary* jsonDataDict = @{@"type":@"data",
                                   @"data":dispJSONString,
                                   @"intensity":intensJSONString,
                                   @"locs":minLocsJSONString,
                                   @"gaps":bladeClrsJSONString,
                                   @"quality":clrQualityJSONString,
                                   @"clearance":clearance,
                                   @"casing_thickness":[NSString stringWithFormat:@"%.4f", self->metaData.casingThickness],
                                   @"spacer_thickness":[NSString stringWithFormat:@"%.4f", self->metaData.spacerThickness],
                                   @"max_clr":stg_max_clr,
                                   @"min_clr":stg_min_clr,
                                   @"med_clr":stg_med_clr,
                                   @"std_clr":stg_clr_std,
                                   @"overall_avg":overall_avg,
                                   @"blades":blades,
                                   @"blade_samples_avg":blade_samples_avg,
                                   @"date":dateStr,
                                   @"intensity_threshold":[NSString stringWithFormat:@"%.3f", self->controller.settings.intensityThreshold],
                                   @"measurement_rate":[NSString stringWithFormat:@"%.3f", self->controller.settings.measurementRate],
                                   @"filename":[[savedFilepath subarrayWithRange:endRange] componentsJoinedByString:@"/"]};
    [self returnPluginResponse:jsonDataDict keepOpen:YES];
}

- (void)saveCSVFile:(NSDate*)date clearanceData:(ClearanceData*)clearanceData measurementData:(MeasurementData*)measurementData {
    //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.saveCSVFile"} keepOpen:YES];
    // If called with no displacements, don't write a file, just return;
    if (measurementData.displacements.count == 0) {
        return;
    }
    // Get the date & time for the filename.
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* dateStr = [[dateFormatter stringFromDate:date] substringFromIndex:2]; // Remove char 0-1, to get a shortened 2-digit year.
    // Get path to documents directory
    NSString* docPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        docPath = [paths objectAtIndex:0];
    }
    // Create a sub-directory for this turbine's data if it doesn't exist.
    NSString* turbineDir = [NSString stringWithFormat:@"%@/%@",docPath,self->metaData.serialNumber];
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
    if (self->metaData.position.length > 0) {
        NSArray* posArr = [self->metaData.position componentsSeparatedByString:@"_"];
        for (NSString* p in posArr) {
            pos = [NSString stringWithFormat:@"%@%@",pos,[p substringToIndex:1]]; // Use the first char from each word in the position string.
        }
    }
    // Create a file name as sn_stage_pos_state_datetime.csv.
    // If there is no serial number, just save to the data folder.
    NSString* csvFileName = [[NSString alloc] init];
    if (self->metaData.serialNumber.length == 0) {
        csvFileName = [NSString stringWithFormat:@"%@/%@",
                       dataDir,
                       [NSString stringWithFormat:@"data_%@_mm.csv",dateStr]];
    } else {
        NSString* fName = [NSString stringWithFormat:@"%@_%@_%@_%@_mm.csv",
                           self->metaData.serialNumber, self->metaData.stage,
                           pos, dateStr];
        csvFileName = [NSString stringWithFormat:@"%@/%@", turbineDir, fName];
    }
    // Change the data-time string format in the filename.
    csvFileName = [csvFileName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    csvFileName = [csvFileName stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    self->lastSavedFile = csvFileName;
    // Now write the file...
    // Open the output file.
    NSFileHandle *handle;
    if ([fm fileExistsAtPath:csvFileName]) {
        NSLog(@"Deleting existing CSV file...");
        NSError* error;
        BOOL success = [fm removeItemAtPath:csvFileName error:&error];
        if (success) {
            NSLog(@"Existing CSV file removed.");
        }
        else {
            NSLog(@"Failed to remove existing CSV File.");
            NSLog(@"Error message: %@", [error localizedDescription]);
        }
    }
    NSLog(@"Creating empty CSV file...");
    BOOL success = [fm createFileAtPath:csvFileName contents:nil attributes:nil];
    if (success) {
        NSLog(@"Created CSV File %@.", csvFileName);
    }
    else {
        NSLog(@"Failed to create CSV File %@.", csvFileName);
    }
    handle = [NSFileHandle fileHandleForWritingAtPath:csvFileName];
    [handle truncateFileAtOffset:[handle seekToEndOfFile]];
    // Write the header line
    NSString* dataStr = [NSString stringWithFormat:@"index,pt_count,dataset_id,timestamp,displacement,filtered,intensity,casing_thickness,avg_disp_over_blade,applied_offset\n"];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Write the individual data lines.
    for (int i=0; i<measurementData.displacements.count; i++) {
        dataStr =  [NSString stringWithFormat:@"%d,%@,%@,%@,%@,%@,%@,%.4f,%@,%f\n",
                    i,[measurementData.pointCounts objectAtIndex:i],[measurementData.datasetIDs objectAtIndex:i],
                    [measurementData.timestamps objectAtIndex:i], [measurementData.displacements objectAtIndex:i],
                    [clearanceData.clearances objectAtIndex:i], [measurementData.intensities objectAtIndex:i],
                    self->metaData.casingThickness, [clearanceData.filtered objectAtIndex:i], clearanceData.offsetAdjustmentFactor];
        [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    float acquisitionMinutes = self->controller.settings.acquisitionTime / 60.0;
    // RPM will be 0 for Get Data
    float rotations = self->metaData.rpm * acquisitionMinutes;
    int expectedBlades = roundf(self->metaData.numberOfBlades * rotations);
    
    //  Write the sensor parameters and app version to the CSV file.
    dataStr = [NSString stringWithFormat:@"\n - Sensor Parameters,,,,,,,,,,,,\nSensor Selection,Sensor Length (in),MR (mm),SMR (mm),Mastering Fixture Height (in),Mastering Value (mm),Master Offset (in),Spacer Thickness (in),Shelf Threshold (mm),Expected Blades,Observed Blades,Avg Samples per Blade,Applied Offset Formula\n%@,%f,%f,%f,%f,%f,%f,%f,%f,%d,%d,%@,%@\n",
               self->controller.settings.sensor.name,
               self->controller.settings.sensor.length,
               self->controller.settings.sensor.mr,
               self->controller.settings.sensor.smr,
               self->controller.settings.sensor.hmf,
               self->controller.settings.sensor.mv,
               self->controller.settings.sensor.mo,
               self->metaData.spacerThickness,
               clearanceData.shelfThreshold,
               expectedBlades,
               clearanceData.blades,
               [NSString stringWithFormat:@"%.02f", clearanceData.averageBladeSamples],
               self->controller.settings.sensor.offsetAdjustmentFormula];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];

    NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    dataStr = [NSString stringWithFormat:@"\n - Created by e4PtTool version %@,,,,,,,,,",appVersion];
    [handle writeData:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];

    [handle closeFile];
}

- (void)appMovedToBackground:(NSNotification*)note {
    NSLog(@"App moved to background.");
    [self dispatchMessage:@{@"type":@"log",@"message":@"Manager.appMovedToBackground"}];
    // Some stuff to stop the serial cable & prepare it to be reconnected.
    //CFRunLoopStop(CFRunLoopGetCurrent());
    [self->controller disconnectDevice];
    //self.rscMgr = nil;
    //[self cableDisconnected];
}

- (void)appMovedToForeground:(NSNotification*)note {
    NSLog(@"App moved to foreground.");
    [self dispatchMessage:@{@"type":@"log",@"message":@"Manager.appMovedToForeground"}];
}

- (void)messageHandler:(NSDictionary*)message callbackId:(NSString*)callbackId {
    
    NSLog(@"@messageHandler: controller state = %d", self->controller.state);
    NSString* cmd = [message valueForKey:@"command"];
    self->cmdCallbackId = callbackId;
    
    if ([cmd containsString:@"send_data"]) {
        NSLog(@"Got send_data");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: send_data"} keepOpen:YES];
        NSString* acqTime = [message valueForKey:@"acquisitionTime"];
        float rpms = [[message valueForKey:@"rpms"] floatValue];
        self->controller.settings.sensor.offsetSelector = [message valueForKey:@"clearanceCalculationMethod"];
        //TODO: block in case acquisition already in progress
        self->metaData = [ScanMetaData new];
        self->metaData.serialNumber = [message valueForKey:@"serialNumber"];
        self->metaData.stage = [message valueForKey:@"stage"];
        self->metaData.position = [message valueForKey:@"position"];
        self->metaData.casingThickness = [[message valueForKey:@"casingThickness"] floatValue];
        self->metaData.spacerThickness = [[message valueForKey:@"spacerThickness"] floatValue];
        self->metaData.numberOfBlades = [[message valueForKey:@"numberOfBlades"] floatValue];
        
        // Check if the value is specified in rpm.  If so, extract the rpm value.
        if (!acqTime) {
            [self returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"Manager.messageHandler: send_data, rpm=%f", rpms]} keepOpen:YES];
            self->calibratedAcquire = true;
            self->metaData.rpm = rpms;
            float interval = 1.0;
            if (!self->controller.settings.overrideRateAndIntensity) {
                // Set new measurement rate
                interval = 3.0; // Give it more time to set things up.
                NSString* err = [self->controller.settings calculateAcquisitionTimeAndSamplingFrequencyAndIntensityThresholdFromRPM:rpms forBladeWidth:[[message valueForKey:@"bladeWidth"] floatValue] forTipDiameter:[[message valueForKey:@"tipDiameter"] floatValue]];
                if (err.length != 0) {
                    // Report errors.
                    [self returnPluginResponse:@{@"type":@"alert",@"message":err} keepOpen:YES];
                    return;
                }
                NSLog(@"Using auto-settings: Found measurement rate: %.3f; intensity threshold: %.3f", self->controller.settings.measurementRate, self->controller.settings.intensityThreshold);
                [self->controller setIntensityThreshold:self->controller.settings.intensityThreshold sendImmediately:NO];
                [self->controller setMeasurementRate:self->controller.settings.measurementRate reportStatus:NO];
            } else {
                NSString* err = [self->controller.settings calculateAcquisitionTimeFromRPM:rpms forBladeWidth:[[message valueForKey:@"bladeWidth"] floatValue] forTipDiameter:[[message valueForKey:@"tipDiameter"] floatValue]];
                if (err.length != 0) {
                    // Report errors.
                    [self returnPluginResponse:@{@"type":@"alert",@"message":err} keepOpen:YES];
                    return;
                }
                NSLog(@"Overriding auto-settings: Found measurement rate: %.3f; intensity threshold: %.3f", self->controller.settings.measurementRate, self->controller.settings.intensityThreshold);
            }
            NSLog(@"Acquisition time: %.3f", self->controller.settings.acquisitionTime);
            [self->controller queueDataCollection:interval];
        } else {
            [self returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"Manger.messageHandler: send_data, acquisitionTime=%@", acqTime]} keepOpen:YES];
            self->calibratedAcquire = false;
            self->controller.settings.acquisitionTime = [acqTime floatValue];
            [self->controller doDataCollection];
        }
    } else if ([cmd containsString:@"abort"]) {
        NSLog(@"Got ABORT");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: abort"} keepOpen:YES];
        [self->controller abortDataCollection];
    } else if ([cmd containsString:@"get_threshold_for_rate"]) {
        NSLog(@"Got threshold for rate");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: get_threshold_for_rate"} keepOpen:YES];
        [self returnPluginResponse:@{@"type":@"setting",@"varName":@"intensity_threshold",@"value":[NSString stringWithFormat:@"%.3f", [self->controller.settings calculateIntensityThresholdFromMeasurementRateKHz:[[message valueForKey:@"rate"] floatValue]]]}];
    } else if ([cmd containsString:@"get_data_file"]) {
        NSLog(@"Got get_data_file");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: get_data_file"} keepOpen:YES];
        [self returnPluginResponse:@{@"type":@"filename",@"fname":self->lastSavedFile ?: [NSNull null]}];
    } else if ([cmd containsString:@"do_dark_reference"]) {
        NSLog(@"Got do_dark_reference");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: do_dark_reference"} keepOpen:YES];
        self->metaData = [ScanMetaData new];
        [self->controller doDarkReference];
    } else if ([cmd containsString:@"do_mastering"]) {
        NSLog(@"Got do_mastering");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: do_mastering"} keepOpen:YES];
        if ([message objectForKey:@"reset"])
            [self->controller masterDevice:nil];
        else
            [self->controller masterDevice:[NSString stringWithFormat:@"%f", self->controller.settings.sensor.mv]];
    } else if ([cmd containsString:@"set_measuring_rate_and_threshold"]) {
        NSLog(@"Got set_measuring_rate_and_threshold");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: set_measuring_rate_and_threshold"} keepOpen:YES];
        [self->controller setIntensityThreshold:[[message valueForKey:@"threshold"] floatValue] sendImmediately:NO];
        [self->controller setMeasurementRate:[[message valueForKey:@"rate"] floatValue]];
    } else if ([cmd containsString:@"set_measuring_rate"]) {
        NSLog(@"Got set_measuring_rate");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: set_measuring_rate"} keepOpen:YES];
        [self->controller setMeasurementRate:[[message valueForKey:@"rate"] floatValue]];
    } else if ([cmd containsString:@"set_threshold"]) {
        NSLog(@"Got set_threshold");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: set_threshold"} keepOpen:YES];
        [self->controller setIntensityThreshold:[[message valueForKey:@"threshold"] floatValue]];
    } else if ([cmd containsString:@"set_manual_override"]) {
        NSLog(@"Got set_manual_override");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: set_manual_override"} keepOpen:YES];
        self->controller.settings.overrideRateAndIntensity = [[message objectForKey:@"value"] boolValue];
    } else if ([cmd containsString:@"get_connection_mode"]) {
        NSLog(@"Got get_connection_mode");
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: get_connection_mode"} keepOpen:YES];
        [self returnPluginResponse:@{@"type":@"connection",@"mode":self->connectionType}];
    } else if ([cmd containsString:@"get_offset_adjustment"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: get_offset_adjustment"} keepOpen:YES];
        NSString* offsetFormula = [self->controller.settings.sensor offsetAdjustmentFormula];
        NSString* offsetCalculation = [self->controller.settings.sensor offsetAdjustmentExplanation:self->metaData.spacerThickness casingThickness:self->metaData.casingThickness];
        float offsetValue = [self->controller.settings.sensor calculateOffsetAdjustment:self->metaData.spacerThickness casingThickness:self->metaData.casingThickness];
        //[self returnPluginResponse:@{@"type":@"alert",@"message":[NSString stringWithFormat:@"Offset Adjustment is applied to all Clearance values below threshold and all Blade Clearance values.\n\nFormula: %@\n\nCalculation: %@\n\nValue: %.3f", offsetFormula, offsetCalculation, offsetValue]}];
        [self returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"Offset adjustment formula: %@", offsetFormula]} keepOpen:YES];
        [self returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"Offset adjustment calculation: %@", offsetCalculation]} keepOpen:YES];
        [self returnPluginResponse:@{@"type":@"log",@"message":[NSString stringWithFormat:@"Offset adjustment value: %.3f", offsetValue]}];
    } else if ([cmd containsString:@"set_connection_mode"]) {
        NSString* mode = [message objectForKey:@"mode"];
        NSLog(@"Recieved set_connection_mode:%@",mode);
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: set_connection_mode"} keepOpen:YES];
        [self->controller disconnectDevice];
        ControllerSettings* controllerSettings = self->controller.settings;
        self->controller = nil;
        self->connectionType = mode;
        if ([mode containsString:@"serial"]) {
            self->controller = [[SerialController alloc] initWithDelegate:self andSettings:controllerSettings];
            [self returnPluginResponse:@{@"type":@"alert",@"message":@"App is now using serial connection."} keepOpen:YES];
        } else if ([mode containsString:@"ethernet"]) {
            self->controller = [[EthernetController alloc] initWithDelegate:self andSettings:controllerSettings];
            [self returnPluginResponse:@{@"type":@"alert",@"message":@"App is now using ethernet connection."} keepOpen:YES];
        } else if ([mode containsString:@"demo"]) {
            self->controller = [[DemoController alloc] initWithDelegate:self andSettings:controllerSettings];
            [self returnPluginResponse:@{@"type":@"alert",@"message":@"App is now in demo mode."} keepOpen:YES];
        }
    } else if ([cmd containsString:@"get_version"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: get_version"} keepOpen:YES];
        //if (self->controller.state == notReady) {
        //    [self->controller initialize];
        //}
        [self returnPluginResponse:@{@"type":@"version",@"version":[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]}];
    } else if ([cmd containsString:@"open_settings"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: open_settings"} keepOpen:YES];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    } else if ([cmd containsString:@"check_connection_status"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: check_connection_status"} keepOpen:YES];
        if (self->controller.state == ready) {
            [self returnPluginResponse:@{@"type":@"status",@"status":@"connected"}];
        } else if (self->controller.state == initializationInProgress) {
            [self returnPluginResponse:@{@"type":@"status",@"status":@"connecting"}];
        }
    } else if ([cmd containsString:@"configure_controller"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: configure_controller"} keepOpen:YES];
        [self->controller configureController];
        [self returnPluginResponse:@{@"type":@"alert",@"message":@"Controller configuration is updated, you should shutdown and restart this application."}];
    } else if ([cmd containsString:@"read_sensor_parameters"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: read_sensor_parameters"} keepOpen:YES];
        [self->controller readSensorParameters];
    } else if ([cmd containsString:@"get_sensor_parameters"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: get_sensor_parameters"} keepOpen:YES];
        NSDictionary* jsonDict = @{@"type":@"sensor_params", @"master_fixture_height":[NSString stringWithFormat:@"%f", self->controller.settings.sensor.hmf], @"mastering_value":[NSString stringWithFormat:@"%f", self->controller.settings.sensor.mv], @"master_offset":[NSString stringWithFormat:@"%f", self->controller.settings.sensor.mo], @"sensor_selection":self->controller.settings.sensor.name, @"sensor_length":[NSString stringWithFormat:@"%f", self->controller.settings.sensor.length], @"start_measurement_range":[NSString stringWithFormat:@"%f", self->controller.settings.sensor.smr], @"sensor_measurement_range":[NSString stringWithFormat:@"%f", self->controller.settings.sensor.mr], @"from_controller":@(self->controller.settings.sensorParamsProvided)
        };
        [self returnPluginResponse:jsonDict];
    } else if ([cmd containsString:@"set_sensor_parameters"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: set_sensor_parameters"} keepOpen:YES];
        self->controller.settings.sensor = [[SensorSettings alloc] initWithName:[message valueForKey:@"name"] lengthInches:[[message valueForKey:@"length"] floatValue] measurementRangeMM:[[message valueForKey:@"mr"] floatValue] startOfMeasurementRangeMM:[[message valueForKey:@"smr"] floatValue] masterFixtureHeightInches:[[message valueForKey:@"hmf"] floatValue] masteringValueMM:[[message objectForKey:@"mv"] floatValue] masteringOffsetInches:[[message objectForKey:@"mo"] floatValue]];
        
        [self returnPluginResponse:@{@"type":@"alert",@"message":@"Sensor Parameters are Set."}];
    } else if ([cmd containsString:@"shutdown"]) {
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: shutdown"} keepOpen:YES];
        [self->controller disconnectDevice];
        exit(0);
    } else {
        NSLog(@"Got %@", message);
        //[self returnPluginResponse:@{@"type":@"log",@"message":@"Manager.messageHandler: unknown"} keepOpen:YES];
    }
}

- (void)timeoutProgressTimer:(NSTimer*)timer {
    if (self.progress >= 1.0) {
        [timer invalidate];
        self.progress = 1.0;
    }
    [self reportProgress:self.progress];
}

- (void)startProgressReporting {
    // This timer updates the progress bar.
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeoutProgressTimer:) userInfo:nil repeats:YES];
    });
}

- (void)reportProgress:(float)progress {
    NSLog(@"Reporting progress: %f",progress);
    int intProgress = (int)roundf(progress*100); // Convert progress to a rounded whole %.
    [self dispatchMessage:@{@"type":@"progress",@"progress":[NSString stringWithFormat:@"%d",intProgress]}];
}

- (void)dispatchMessage:(NSDictionary*)messagesDictionary {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        //if (/* DISABLES CODE */ (true)) {
            NSError* error;
            NSData *jsonData=[NSJSONSerialization dataWithJSONObject:messagesDictionary options:NSJSONWritingSortedKeys error:&error];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            [self->plugin.commandDelegate evalJs:[NSString stringWithFormat:@"pluginMessage(%@);",jsonString]];
        //}
        //else {
        //    [self returnPluginResponse:messagesDictionary keepOpen:YES];
        //}
    });
}

@end
