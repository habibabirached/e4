//
//  EthernetController.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "AppDelegate.h"
#import "EthernetController.h"


@interface EthernetController()
@property (nonatomic) enum CONTROLLER_STATE state;
@end

@implementation EthernetController {
    NSString* ipAddress;
    int dataPort, telnetPort;
    BOOL dataStreamIsOpen, telnetStreamIsOpen;
    NSInputStream* inputDataStream, *inputTelnetStream;
    NSOutputStream* outputDataStream, *outputTelnetStream;
    dispatch_queue_t networkQueue;
}

@dynamic state;

- (void)sendEmptyCommand {
    if ([self->outputTelnetStream hasSpaceAvailable]) {
        [self sendCommand:@"\n"];
    }
}

- (void)sendTelnetCommand {
    [self connectTelnetPortIfNecessary:self->outputTelnetStream];
    [super sendTelnetCommand];
}

- (void)sendCommand:(NSString*)command {
    NSData* cmdData = [[NSData alloc] initWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
    [self->outputTelnetStream write:(const unsigned char*)[cmdData bytes] maxLength:[cmdData length]];
}

- (void)configureOutputSettings {
    [self->telnetCmds addObject:@"OUTPUT ETHERNET\n"];
    [self->telnetCmds addObject:[NSString stringWithFormat:@"MEASTRANSFER SERVER/TCP %d\n", self->dataPort]];
    [self->telnetCmds addObject:@"OUT_ETH 01INTENSITY 01DIST1 TIMESTAMP\n"];
}

- (void)initialize {
    dispatch_sync(dispatch_get_main_queue(), ^{
        self->ipAddress = ((AppDelegate *)[UIApplication sharedApplication].delegate).ipAddress;
    });
    //self->ipAddress = IFC_ADDR_GE;
    self->dataPort = DATA_PORT;
    self->telnetPort = TELNET_PORT;
    self->networkQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.ge.e4pt.%@.global_network_queue", NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL); // Not DISPATCH_QUEUE_CONCURRENT
    [super initialize];
}

- (void)selectOppositeOutput {
    [self->telnetCmds addObject:@"OUTPUT RS422\n"];
}

-(void)connectTelnetPortIfNecessary:(NSStream*)streamToCheck {
    if (!streamToCheck) {
        NSLog(@"  Attempting to (re)connect to telnet port.");
        [self connectDevice:self->ipAddress port:self->telnetPort];
    }
}

- (void)abortDataCollection {
    if (self.state == collectingDataInProgress) {
        self.state = clearanceComputationInProgress;
        self->set_count = self->num_sets+1;
    }
}

- (void)disconnectDevice {
    [super disconnectDevice];
    self->networkQueue = nil;
}

- (void)disconnectData {
    [self->telnetCmds addObject:@"OUTPUT NONE\n"];
    [self sendTelnetCommand];
    
    NSLog(@"@disconnectData.");
    
    [self disconnectStream:self->inputDataStream];
    self->inputDataStream = nil;
    [self disconnectStream:self->outputDataStream];
    self->outputDataStream = nil;
    self->dataStreamIsOpen = NO;
}

- (void)disconnectTelnet {
    NSLog(@"@disconnectTelnet.");
    
    [self disconnectStream:self->inputTelnetStream];
    self->inputTelnetStream = nil;
    [self disconnectStream:self->outputTelnetStream];
    self->outputTelnetStream = nil;
    self->telnetStreamIsOpen = NO;
    [super disconnectTelnet];
}

- (void)disconnectStream:(NSStream*)stream {
    if (stream) {
        [stream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [stream setDelegate:nil];
        [stream close];
    }
}

- (int)calculateNumberOfDatasetsToAcquireForTime:(float)acqTime atRateInHertz:(float)rate {
    return ceil(rate * acqTime / 100.0);
}

- (void)collectDataSets {
    [self->telnetCmds addObject:@"OUTPUT ETHERNET\n"];
    [self sendTelnetCommand];
    [self connectDevice:self->ipAddress port:self->dataPort];
    [self->delegate startProgressReporting];
}

- (void)connectDevice:(NSString*)ip_address port:(int)port {
    dispatch_async(self->networkQueue, ^{
        NSLog(@"@connectDevice: %@:%d", ip_address, port);
        
        if (port == self->dataPort) {
            if (self->inputDataStream) {
                if(CFReadStreamGetStatus((__bridge CFReadStreamRef )self->inputDataStream) == (CFStreamStatus) kCFStreamStatusOpen) {
                    NSLog(@"This device is already connected for data.");
                    return;
                }
            }
            if(self->outputDataStream){
                NSLog(@"  Already Connected - Data");
                return;
            }
            self->dataStreamIsOpen = NO;
        } else if (port == self->telnetPort) {
            if (self->inputTelnetStream) {
                if(CFReadStreamGetStatus((__bridge CFReadStreamRef )self->inputTelnetStream) == (CFStreamStatus) kCFStreamStatusOpen){
                    NSLog(@"This device is already connected for telnet.");
                    return;
                }
            }
            if(self->outputTelnetStream) {
                NSLog(@"  Already Connected - Telnet");
                return;
            }
            self->telnetStreamIsOpen = NO;
        }
        
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)ip_address, port, &readStream, &writeStream);
        
        NSInputStream* inputStream = (__bridge NSInputStream *)readStream;
        NSOutputStream* outputStream = (__bridge NSOutputStream *)writeStream;
        [inputStream setDelegate:self];
        [outputStream setDelegate:self];
        [inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [inputStream open];
        [outputStream open];
        
        if (port == self->dataPort) {
            self->outputDataStream = outputStream;
            self->inputDataStream = inputStream;
            [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(timeoutTimerDataStreamOpening:) userInfo:@(port) repeats:NO];
        } else if (port == self->telnetPort) {
            self->outputTelnetStream = outputStream;
            self->inputTelnetStream = inputStream;
        }
    });
}

- (void)timeoutTimerDataStreamOpening:(NSTimer*)timer {
    NSLog(@"@timeoutDataStreamOpening: Timer expired (as expected)");
    int port = [timer.userInfo intValue];

    NSLog(@"    ipaddress = %@:%d",self->ipAddress,port);
    
    if(self->dataStreamIsOpen){
        NSLog(@"    OK - stream is open.");
    } else {
        NSLog(@"    stream not open.");
        
        //if (port == self->dataPort) {
            NSLog(@"    closing data port streams.");
            [self disconnectStream:self->inputDataStream];
            self->inputDataStream = nil;
            [self disconnectStream:self->outputDataStream];
            self->outputDataStream = nil;
        //}
        //else if (port == self->telnetPort) {
        //    NSLog(@"    closing telnet port streams.");
        //    [self disconnectStream:self->inputTelnetStream];
        //    self->inputTelnetStream = nil;
        //    [self disconnectStream:self->outputTelnetStream];
        //    self->outputTelnetStream = nil;
        //}
    }
}

#pragma mark - TCPSocketDelegate

- (void)stream:(NSStream *)inStream handleEvent:(NSStreamEvent)streamEvent {
    
    dispatch_async(self->networkQueue, ^{
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
        
        if([port intValue] == self->dataPort){
            foundInputDataS = (self->inputDataStream == theStream);
            foundOutputDataS = (self->outputDataStream == theStream);
            dataStreamFound = foundOutputDataS || foundInputDataS;
        }
        else if ([port intValue] == self->telnetPort) {
            foundInputTelnetS = (self->inputTelnetStream == theStream);
            foundOutputTelnetS = (self->outputTelnetStream == theStream);
            telnetStreamFound = foundOutputTelnetS || foundInputTelnetS;
        }
        NSLog(@"dataStreamFound = %d; telnetStreamFound = %d",dataStreamFound,telnetStreamFound);
        
        if (dataStreamFound || telnetStreamFound) {
            
            switch (streamEvent) {
                case NSStreamEventHasSpaceAvailable: //4
                    NSLog(@"NSStreamEventHasSpaceAvailable.");
                    break;
                case NSStreamEventNone: //0
                    NSLog(@"NSStreamEventNone.");
                    break;
                case NSStreamEventOpenCompleted: //1
                {
                    NSLog(@"NSStreamEventOpenCompleted.");
                    NSLog(@"  foundInputDataS: %d; foundOutputDataS: %d", foundInputDataS, foundOutputDataS);
                    if (foundInputDataS) NSLog(@"  stream is an input data stream");
                    if (foundOutputDataS) NSLog(@"  stream is an output data stream");
                    if (foundInputTelnetS) NSLog(@"  stream is an input telnet stream");
                    if (foundOutputTelnetS) NSLog(@"  stream is an output telnet stream");
                    
                    if (dataStreamFound) self->dataStreamIsOpen = YES;
                    if (telnetStreamFound) self->telnetStreamIsOpen = YES;
                    
                    break;
                }
                case NSStreamEventHasBytesAvailable: //2
                {
                    if ((self->dataStreamIsOpen == NO) && ([port intValue] == self->dataPort)) {
                        break;
                    }
                    if ((self->telnetStreamIsOpen == NO) && ([port intValue] == self->telnetPort)) {
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
                    
                    if ([self->inputDataStream hasBytesAvailable]) {
                        [self readInputDataStream];
                    }
                    if ([self->inputTelnetStream hasBytesAvailable]) {
                        NSLog(@"Got data on telnet stream");
                        uint8_t tmpBuf[1024];
                        long len2 = [self->inputTelnetStream read:tmpBuf maxLength:1024];
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
                case NSStreamEventErrorOccurred: //8
                {
                    NSLog(@"NSStreamEventErrorOccurred.");
                    NSError* error = [theStream streamError];
                    NSString* errorMessage = [NSString stringWithFormat:@"Error: %@ (Code = %ld)",
                                              [error localizedDescription],
                                              (long)[error code]];
                    NSLog(@"  %@",errorMessage);
                    if ([errorMessage containsString:@"Broken pipe"] && ([port intValue] ==  self->telnetPort)) {
                        [self disconnectTelnet]; // clean things up.
                        [self connectTelnetPortIfNecessary:self->inputTelnetStream];
                    }
                    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":errorMessage} keepOpen:YES];
                    break;
                }
                case NSStreamEventEndEncountered: //16
                {
                    NSLog(@"NSStreamEventEndEncountered for port = %@", port);
                    if ([port intValue] == self->telnetPort)
                        [self disconnectTelnet];
                    else if ([port intValue] == self->dataPort)
                        [self disconnectData];
                    else {
                        [self disconnectStream:theStream];
                        theStream = nil;
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

-(void)readInputDataStream {
    if (self.state == masteringInProgress) {
        return; // Don't do anything with incoming data while mastering.
    }
    
    uint32_t order_number, serial_number, video_length, len_meas_dat, num_frames, counter, timestamp;
    uint8_t tmpBuf[4];
    while (self->set_count < self->num_sets) {
        [self->inputDataStream read:tmpBuf maxLength:4];
        if ( strncmp((const char*)tmpBuf, "DATA", 4) == 0 ) {
            NSLog(@"FOUND DATA! - %f", self->set_count);
            
            //for (int i=0; i<5; i++) self.totalBuffer[i] =0;
            order_number = [self readValueFromStream:tmpBuf];
            serial_number = [self readValueFromStream:tmpBuf];
            video_length = [self readValueFromStream:tmpBuf];
            len_meas_dat = [self readValueFromStream:tmpBuf];
            num_frames = [self readValueFromStream:tmpBuf];
            counter = [self readValueFromStream:tmpBuf];
            NSLog(@"%f: %d, %d, %d, %d, %d, %d", self->set_count, order_number, serial_number, video_length, len_meas_dat, num_frames, counter);
            
            for (int i=0; i<num_frames; i++) {
                // Read data from which to extract intensity.
                float intensity = (([self readValueFromStream:tmpBuf] & 0x7FF) / 1024.0) * 100.00;
                
                // Read data from which to extract distance.
                uint32_t dVal = [self readValueFromStream:tmpBuf];
                float displacement = 0.0;
                if (dVal > 2147483392) {
                    NSString* error_msg = @"Error unknown type";
                    if (dVal == 2147483396) {
                        error_msg = @"Error No Peak";
                    } else if (dVal == 2147483397) {
                        error_msg = @"Error Peak in front of MR";
                    } else if (dVal == 2147483398) {
                        error_msg = @"Error Peak in back of MR";
                    } else if (dVal == 2147483399) {
                        error_msg = @"Error Measurement cannot be calculated";
                    } else if (dVal == 2147483400) {
                        error_msg = @"Error Measurement is outside representable area";
                    }
                    NSLog(@"%@", error_msg);
                    displacement = self.settings.outOfRange;
                }
                else {
                    displacement = ((float)dVal) * 1e-6;
                }
                
                // Read data from which to extract timestamp.
                timestamp = [self readValueFromStream:tmpBuf];
                
                [self.measurementData.displacements addObject:[NSNumber numberWithFloat:displacement]];
                [self.measurementData.timestamps addObject:[NSNumber numberWithUnsignedInteger:timestamp]];
                [self.measurementData.intensities addObject:[NSNumber numberWithFloat:intensity]];
                [self.measurementData.datasetIDs addObject:[NSNumber numberWithInt:(int)self->set_count]];
                [self.measurementData.pointCounts addObject:[NSNumber numberWithInteger:num_frames]];
                
                NSLog(@"\n%d: %u, %f, %f", i, timestamp, intensity, displacement);
            }
            
            // num_sets was calculated assuming 100 samples per report.  This is not always correct,
            // so we account for that here.
            float set_inc = (float)num_frames / 100.0;
            
            self->set_count += set_inc;
            float prog = (float)self->set_count / (float)self->num_sets;
            prog = floorf(prog * 10) / 10;  // Round down to the nearest 10 percent
            NSLog(@"num_sets: %d; set_count: %f; set_inc: %f; prog: %f; num_frames: %d",self->num_sets, self->set_count, set_inc, prog, num_frames);
            if ( prog > self->delegate.progress ) {
                self->delegate.progress = prog;
            }
            //NSLog(@"updating progress: %f", self->delegate.progress);
        }
        //else {
        //    NSLog(@"  no data");
        //}
    }
    self->delegate.progress = 1.0;
    self->set_count = 0;
    [self disconnectData]; // Stop receiving data

    // At this point we should have all the data that was requested.
    // We need to do any required processing/filtering, save to file,
    // then bundle it up and send it back through to the javascript.
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"processing"} keepOpen:YES];
    
    if (self.state != halted) {
        if (self.state != clearanceComputationInProgress && self.state != ready)
            self.state = halted;
        [self processResponse:@"->"];
    }
}

-(uint32_t)readValueFromStream:(uint8_t[])tmpBuf {
    [self->inputDataStream read:tmpBuf maxLength:4];
    return tmpBuf[0] | (uint32_t)tmpBuf[1] << 8
    | (uint32_t)tmpBuf[2] << 16 | (uint32_t)tmpBuf[3] << 24;
}

@end
