//
//  SerialController.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "AppDelegate.h"
#import "SerialController.h"

@interface SerialController ()
@property (nonatomic) enum CONTROLLER_STATE state;
@end

@implementation SerialController {
    BOOL dataStreamIsSynchronized;
    RscMgr* rscMgr;         // Redpark serial communications
    uint8_t* byteBuffer, *writePtr, *readPtr;
    uint32_t* val1Ptr;
    DataSizeType dataSizeType;
    ParityType parityType;
    StopBitsType stopBitsType;
    int baudRate, rts, cts, leftoverBytes;
    NSTimeInterval testTime;
    NSRunLoop* networkRunLoop;
}

@dynamic state;

- (void) cableConnected:(NSString *)protocol{
    NSLog(@"SerialController:cableConnected:%@",protocol);
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":[NSString stringWithFormat:@"SerialController.cableConnected: protocol=%@", protocol]}];
    
    if (self->byteBuffer == nil) {
        self->byteBuffer = (uint8_t *) malloc(BYTE_BUFFER_SIZE);
        self->readPtr = self->byteBuffer;
        self->writePtr = self->byteBuffer;
        self->val1Ptr = (uint32_t*)self->readPtr;
    }
    
    [self->rscMgr setBaud:self->baudRate];
    [self->rscMgr setDataSize:self->dataSizeType];
    [self->rscMgr setParity:self->parityType];
    [self->rscMgr setStopBits:self->stopBitsType];
    
    serialPortConfig portConfig;
    [self->rscMgr getPortConfig:&portConfig];
    portConfig.txAckSetting = 1;
    portConfig.rxFlowControl = self->rts;
    portConfig.txFlowControl = self->cts;
    portConfig.rxForwardCount = RX_FORWARD_COUNT;
    portConfig.rxForwardingTimeout = 50; // default = 100;
    [self->rscMgr setPortConfig:&portConfig requestStatus:NO];
}

//TODO: disconnectdevice, and cableConnected may need to run initialize
- (void) cableDisconnected {
    NSLog(@"SerialController:cableDisconnected");
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.cableDisconnected"}];
    self.state = notReady;
    self->rscMgr = nil;
    [self->delegate dispatchMessage:@{@"type":@"status",@"status":@"disconnected"}];
}

- (void) portStatusChanged{
    NSLog(@"SerialController:portStatusChanged");
    int modemStatus = [self->rscMgr getModemStatus];
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":[NSString stringWithFormat:@"SerialController.portStatusChanged: modemStatus=%02x", modemStatus]}];
}

- (void)sendEmptyCommand {
    [self sendCommand:@"OUTPUT NONE\n"];
}

- (void)sendCommand:(NSString*)command {
    [self->rscMgr writeString:command];
}

- (void)configureOutputSettings {
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.configureOutputSettings"}];
    // ifdefs below are structured the way they are because elseif didn't seem to work.
#ifdef SERIAL_SEND_TIMESTAMP
    // Output TIMESTAMP when using serial connection. This requires more bandwidth.
    //[self.telnetCmds addObject:[NSString stringWithFormat:@"OUT_RS422 01INTENSITY 01DIST1 TIMESTAMP\n"]];
    [self->telnetCmds addObject:@"OUT_RS422 01INTENSITY 01DIST1 COUNTER\n"];
#elif defined(SEND_DISPLACEMENT_ONLY)
    [self->telnetCmds addObject:@"OUT_RS422 01DIST1\n"];
#else
    // Don't output TIMESTAMP when using serial connection. This should allow us to increase throughput.
    [self->telnetCmds addObject:@"OUT_RS422 01INTENSITY 01DIST1\n"];
#endif
}

- (void)initialize {
    NSLog(@"@SerialController::initialize");
    NSLog(@"@SerialController:initialize");
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.initialize"}];
    dispatch_sync(dispatch_get_main_queue(), ^{
        self->baudRate = [((AppDelegate *)[UIApplication sharedApplication].delegate).baudRate intValue];
    });
    //self->baudRate = BAUD_RATE_FAST;
    //TODO: shouldn't need the following initializations as they are the default values
    self->dataSizeType = kDataSize8;
    self->parityType = kParityNone;
    self->stopBitsType = kStopBits1;
    self->rts = RXFLOW_NONE;
    self->cts = TXFLOW_NONE;
    
    [self startCommThread];
    [super initialize];
}

- (void)selectOppositeOutput {
    [self->telnetCmds addObject:@"OUTPUT ETHERNET\n"];
}

- (void)disconnectDevice {
    NSLog(@"@SerialController:disconnectDevice");
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.disconnectDevice"}];
    [super disconnectDevice];
    [self->rscMgr setDelegate:nil];
    if (self->networkRunLoop)
        CFRunLoopStop([self->networkRunLoop getCFRunLoop]);
    self->networkRunLoop = nil;
    self->rscMgr = nil;
}

- (void)disconnectData {
    NSLog(@"@SerialController:disconnectData");
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.disconnectData"}];
    [self sendCommand:@"OUTPUT NONE\n"];
    [self resetSerialParams];
}

- (int)calculateNumberOfDatasetsToAcquireForTime:(float)acqTime atRateInHertz:(float)rate {
#ifdef SERIAL_SEND_TIMESTAMP
    float bytesPerDataSet = 9.0;  // (3 bytes each, Inten., Disp., & Timestamp)
#elif defined(SEND_DISPLACEMENT_ONLY)
    float bytesPerDataSet = 3.0;  // (3 bytes for displacement)
#else
    float bytesPerDataSet = 6.0;  // (3 bytes each, Inten., Disp.)
#endif
    float dataSetsPerFrame = (float)RX_FORWARD_COUNT/bytesPerDataSet; // 64 bytes/Rx frame
    return ceil(rate * acqTime / dataSetsPerFrame);
}

- (void)collectDataSets {
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.collectDataSets"}];
    [self clearByteBuffer];
    self->testTime = 0.0;
    [self->telnetCmds addObject:@"OUTPUT RS422\n"];
    [self sendTelnetCommand];
    [self->delegate startProgressReporting];
}

//
// RS232 Serial Cable additions
//

- (void)clearByteBuffer {
    self->leftoverBytes = 0;
    if (self->byteBuffer != nil)
        for (int i=0; i<BYTE_BUFFER_SIZE; i++) self->byteBuffer[i] = 0;
}

// For IFC242x controller user 8N1 configuration.
- (void)setupSerialCable {
    NSLog(@"@SerialController:setupSerialCable");
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.setupSerialCable"}];
    
    //if (self->byteBuffer == nil) {
    //    self->byteBuffer = (uint8_t *) malloc(BYTE_BUFFER_SIZE);
    //    self->readPtr = self->byteBuffer;
    //    self->writePtr = self->byteBuffer;
    //    self->val1Ptr = (uint32_t*)self->readPtr;
    //}
    
    //[self->rscMgr enableExternalLogging:true];
    //[self->rscMgr enableTxRxExternalLogging:true];
    //TODO: do we need this?
    //[self cableConnected:@" not from red park "];
}

// start the communication thread
- (void) startCommThread {
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.startCommThread"}];
    // Create and start the comm thread.  We'll use this thread so we don't tie up the UI thread.
    dispatch_async(dispatch_queue_create([[NSString stringWithFormat:@"com.ge.ent.e4PtTool.%@.network_comms_queue", NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL), ^{
        // initialize RscMgr on this thread
        // so it schedules delegate callbacks for this thread
        if (self->rscMgr == nil) {
            self->rscMgr = [[RscMgr alloc] init];
            [self->rscMgr setDelegate:self];
        }
        //[self setupSerialCable];
        // run the run loop
        self->networkRunLoop = [NSRunLoop currentRunLoop];
        [self->networkRunLoop run];
    });
}

- (void)resetSerialParams {
    [self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.resetSerialparams"}];
    // Flush the cable Rx buffer to prepare for next acquisition.
    serialPortControl portCtl;
    portCtl.rxFlush = 1;
    portCtl.txFlush = 1;
    [self->rscMgr setPortControl:&portCtl requestStatus:false];
    // Reset all the parameters needed to start serial acquisition from scratch.
    self->dataStreamIsSynchronized = false;
    self->nextIFCValue = IFCIntensity;
    self->readPtr = self->byteBuffer;
    self->writePtr = self->byteBuffer;
    self->set_count = 0;
    self->num_sets = 0;
    [self clearByteBuffer];
}

// bytes are available to be read (user calls read:)
- (void) readBytesAvailable:(UInt32)length {
    NSData* rxBytes = [self->rscMgr getDataFromBytesAvailable];
    if (rxBytes.length != 0) {
        NSLog(@"Got %lu bytes.", (unsigned long)rxBytes.length);
        [self parseSerialData:rxBytes];
    }
}

- (void)parseSerialData:(NSData*)data {
    NSLog(@"@SerialController:parseSerialData: pState = %d", self.state);
    //[self->delegate dispatchMessage:@{@"type":@"log",@"message":@"SerialController.parseSerialData"}];
    
    if ((self.state == masteringInProgress) ||
        (self.state == darkReferenceInProgress) ||
        (self.state == initializationInProgress) ||
        (self.state == setMeasurementRateInProgress) ||
        (self.state == setThresholdInProgress)) {
        NSString* response = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSLog(@"parseSerial: Got: %@",response);
        [self processResponse:response];
        return;
    } else if (self.state != collectingDataInProgress) {
        if (data.length >= 4) {
            NSString* response = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            if ([response containsString:@TELNET_PROMPT] && self.state != halted && self.state != clearanceComputationInProgress)
                [self processResponse:response];
        }
        return;  // if we're not collecting data, return.
    }

    //
    // It has been seen that the number of bytes per read on the serial interface
    // is not consistent.  So we have to count data sets (nominally 64 bytes)
    // in fractional increments.
    //
    float set_inc = data.length/(float)RX_FORWARD_COUNT;
    
    // For receiving serial measurement data...
    if (self->testTime == 0.0) {
        self->testTime = ([[NSDate date] timeIntervalSince1970]) * 1000000;
        NSLog(@"Data collection start time: %f",self->testTime);
    }
    int pt_count = (int)floor((float)(data.length)/9.0); // 9 bytes per data point.
    if (self->set_count < self->num_sets) {
        
        // Copy the data to the buffer in a circular fashion.
        const uint8_t* dPtr = [data bytes];
        uint32_t mask = 0xC0C0C000; // mask of the upper 3 bytes with the expected pattern.
        uint8_t* endPtr = &self->byteBuffer[BYTE_BUFFER_SIZE-1];
        uint32_t v1;
        self->val1Ptr = &v1;
        for (int i=0; i<data.length; i++) {
            *self->writePtr = *dPtr++;
            //advance the write pointer 1 byte forward, wrapping as needed.
            (self->writePtr == endPtr) ? (self->writePtr = self->byteBuffer) : self->writePtr++;
        }
        
        // We shouldn't have to scan through more than 9 bytes to find the data.
        // "AND" the data with the mask and compare to the expected value to find the
        // pattern.  This is for initial synchronization only.
        
        // If we were in sync, check to see if we still are.  It has been known to get out of sync.
        // copy next 4 bytes into v1 to check them.
        uint8_t* fromPtr = self->readPtr;
        uint8_t* toPtr = (uint8_t*)self->val1Ptr;
        for (int i=0; i< 4; i++) {
            *toPtr = *fromPtr;
            (fromPtr == endPtr) ? (fromPtr = self->byteBuffer) : fromPtr++;
            toPtr++;
        }
        int offset = 0;
        if (self->dataStreamIsSynchronized) {
            v1 = v1 & mask;
            bool syncFail = false;
#ifdef SEND_DISPLACEMENT_ONLY
            if (self.nextIFCValue == IFCDisplacement) {
                if (v1 != (uint32_t)0x00804000) {
                    syncFail = true;
                }
            }
#else
            if (self->nextIFCValue == IFCIntensity) {
                if (v1 != (uint32_t)0x00804000) {
                    syncFail = true;
                }
            }
            else if (self->nextIFCValue == IFCDisplacement) {
                if (v1 != (uint32_t)0x00C04000) {
                    syncFail = true;
                }
            }
            else if (self->nextIFCValue == IFCTimestamp) {
                if (v1 != (uint32_t)0x00C04000) {
                    syncFail = true;
                }
            }
#endif
            if (syncFail) {
                self->dataStreamIsSynchronized = false;
                self->val1Ptr = (uint32_t*)self->readPtr;
            }
        }
        if (!self->dataStreamIsSynchronized) {
            for (offset=0; offset<9; offset++) {
                v1 = v1 & mask;
                if (v1 == (uint32_t)0x00804000) {
                    NSLog(@"Found the pattern at offset %d!",offset);
                    // we found the pattern.
                    self->dataStreamIsSynchronized = true;
                    break;
                }
                else {
                    //advance the read pointer 1 byte forward, wrapping as needed.
                    (self->readPtr == endPtr) ? (self->readPtr = self->byteBuffer) : self->readPtr++;
                    // copy next 4 bytes into v1 to check them.
                    fromPtr = self->readPtr;
                    toPtr = (uint8_t*)self->val1Ptr;
                    for (int i=0; i< 4; i++) {
                        *toPtr = *fromPtr;
                        (fromPtr == endPtr) ? (fromPtr = self->byteBuffer) : fromPtr++;
                        toPtr++;
                    }
                }
            }
        }
        // readPtr should now be at the start of the data.
        /* Byte printing for debugging
         uint8_t* tmpPtr = self->readPtr;
         printf("Before: Next 8 bytes: ");
         for (int k=0; k<8; k++) {
         printf("%02X ", (0xff & *tmpPtr));
         (tmpPtr == endPtr) ? (tmpPtr = self->byteBuffer) : tmpPtr++;
         }
         printf("\n");
         */
        
        // Subtract the number of bytes we had to skip to get synced.  Add any leftover from previous frames.
        int numBytesLeft = (int)[data length] - offset + self->leftoverBytes;
        int numValues = (int)floor(numBytesLeft/3.0); // 3 bytes per value
        self->leftoverBytes = numBytesLeft - (numValues * 3);
        uint32_t ival = 0;
        uint32_t dval = 0;
        float displacement = 0;
        uint32_t tval = 0;
        NSTimeInterval unixTStamp;
        NSString* logStr = @"";
        for (int j=0; j<numValues; j++) {
            if (self->nextIFCValue == IFCIntensity) {
                ival = [self readNextValueFromBuffer:endPtr];
                NSString* log = [NSString stringWithFormat:@"I:%d: ",ival];
                logStr = [logStr stringByAppendingString:log];
                if (self.state == collectingDataInProgress) {
                    [self.measurementData.intensities addObject:[NSNumber numberWithFloat:(float)ival]];
                }
                self->nextIFCValue = IFCDisplacement;
            }
            else if (self->nextIFCValue == IFCDisplacement) {
                dval = [self readNextValueFromBuffer:endPtr];
                // Error checking
                if (dval > 262072) {
                    NSString* error_msg = @"Error unknown type";
                    if (dval == 262073) {
                        error_msg = @"Error RS422 interface underflow";
                    } else if (dval == 262074) {
                        error_msg = @"Error RS422 interface overflow";
                    } else if (dval == 262075) {
                        error_msg = @"Error Too much data for baud rate";
                    } else if (dval == 262076) {
                        error_msg = @"Error No peak present";
                    } else if (dval == 262077) {
                        error_msg = @"Error Peak in front of measuring range";
                    } else if (dval == 262078) {
                        error_msg = @"Error Peak is behind measuring range";
                    } else if (dval == 262079) {
                        error_msg = @"Error Measuring value cannot be calculated";
                    }
                    NSLog(@"%@", error_msg);
                    displacement = self.settings.outOfRange;
                }
                else {
                    displacement = ((float)dval - 98232.0) * self.settings.sensor.mr / 65536.0;
                }
                NSString* log = [NSString stringWithFormat:@"D:%f: ", displacement];
                logStr = [logStr stringByAppendingString:log];
                if (self.state == collectingDataInProgress) {
                    [self.measurementData.displacements addObject:[NSNumber numberWithFloat:displacement]];
#ifdef SERIAL_SEND_TIMESTAMP
                    self->nextIFCValue = IFCTimestamp; // Next element is the timestamp.
#elif defined(SEND_DISPLACEMENT_ONLY)
                    self->nextIFCValue = IFCDisplacement; // Only do displacement.
                    // Create a timestamp and record it.
                    unixTStamp = [self getElapsedTime] * 1000000; // microseconds since start.
                    tval = (uint32_t)floor(unixTStamp);
                    [self.measurementData.timestamps addObject:[NSNumber numberWithInt:(int)tval]];
                    [self.measurementData.intensities addObject:[NSNumber numberWithFloat:1.0]];
                    [self.measurementData.pointCounts addObject:[NSNumber numberWithInt:pt_count]];
                    [self.measurementData.datasetIDs addObject:[NSNumber numberWithInt:(int)self->set_count]];
#else
                    self->nextIFCValue = IFCIntensity; // Skip timestamp to increase throughput.
                    // Create a timestamp and record it.
                    unixTStamp = [self getElapsedTime] * 1000000; // microseconds since start.
                    tval = (uint32_t)floor(unixTStamp);
                    [self.measurementData.timestamps addObject:[NSNumber numberWithInt:(int)tval]];
                    [self.measurementData.pointCounts addObject:[NSNumber numberWithInt:pt_count]];
                    [self.measurementData.datasetIDs addObject:[NSNumber numberWithInt:(int)self->set_count]];
#endif
                }
            }
            else if (self->nextIFCValue == IFCTimestamp) {
                tval = [self readNextValueFromBuffer:endPtr];
                NSString* log = [NSString stringWithFormat:@"T:%d: ",tval];
                logStr = [logStr stringByAppendingString:log];
                if (self.state == collectingDataInProgress) {
                    [self.measurementData.timestamps addObject:[NSNumber numberWithInt:(int)tval]];
                    [self.measurementData.pointCounts addObject:[NSNumber numberWithInt:pt_count]];
                    [self.measurementData.datasetIDs addObject:[NSNumber numberWithInt:(int)self->set_count]];
                }
                self->nextIFCValue = IFCIntensity;
            }
        }
        NSLog(@"FrameData: %@",logStr);
        
        /* Byte printing for debugging
         tmpPtr = self->readPtr;
         (tmpPtr == self->byteBuffer) ? (tmpPtr = endPtr) : tmpPtr--; // back up pointer with wrap
         (tmpPtr == self->byteBuffer) ? (tmpPtr = endPtr) : tmpPtr--; // back up pointer with wrap
         (tmpPtr == self->byteBuffer) ? (tmpPtr = endPtr) : tmpPtr--; // back up pointer with wrap
         printf("After: Last 3 and Next 8 bytes: ");
         for (int k=0; k<11; k++) {
         printf("%02X ", (0xff & *tmpPtr));
         (tmpPtr == endPtr) ? (tmpPtr = self->byteBuffer) : tmpPtr++;
         }
         printf("\n");
         */
        
        self->set_count += set_inc;
        self->delegate.progress = (float)self->set_count / (float)self->num_sets;

    }
    if (self->set_count >= self->num_sets) {
        if ((self.state == halted) || (self.state == clearanceComputationInProgress)) return;
        self.state = halted;
        self->set_count = 0;
        self->delegate.progress = 1.0;
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
        NSLog(@"set_count >= num_sets: pState = %d", self.state);
        NSTimeInterval stop = ([[NSDate date] timeIntervalSince1970]) * 1000000;
        NSLog(@"Data collection stop time: %f",stop);
        NSLog(@"Elapsed Time: %f seconds.", (stop - self->testTime)/1000000.0);

        // Because data sets (Inten.,Disp.,Time) can be split across transmissions, we can end up
        // with different sized arrays here.  We need to trim the larger ones to the size of the
        // smallest.
        unsigned long minArrLen = MIN(MIN(self.measurementData.displacements.count, self.measurementData.intensities.count), self.measurementData.timestamps.count);
        while (self.measurementData.displacements.count > minArrLen) [self.measurementData.displacements removeLastObject];
        while (self.measurementData.intensities.count > minArrLen) [self.measurementData.intensities removeLastObject];
        while (self.measurementData.timestamps.count > minArrLen) [self.measurementData.timestamps removeLastObject];
        
        // At this point we should have all the data that was requested.
        // We need to do any required processing/filtering, save to file,
        // then bundle it up and send it back through to the javascript.
        [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"processing"} keepOpen:YES];
        NSLog(@"Compute clearance and return data...");
        [self processResponse:@TELNET_PROMPT];
    }
}

-(uint32_t)readNextValueFromBuffer:(uint8_t*)endPtr {
    uint32_t val = (uint32_t)(*self->readPtr & 0x3F);
    (self->readPtr == endPtr) ? (self->readPtr = self->byteBuffer) : self->readPtr++; // wrap pointer if needed.
    val |= ((*self->readPtr & 0x3F) << 6);
    (self->readPtr == endPtr) ? (self->readPtr = self->byteBuffer) : self->readPtr++;
    val |= ((*self->readPtr & 0x3F) << 12);
    (self->readPtr == endPtr) ? (self->readPtr = self->byteBuffer) : self->readPtr++;
    return val;
}

@end
