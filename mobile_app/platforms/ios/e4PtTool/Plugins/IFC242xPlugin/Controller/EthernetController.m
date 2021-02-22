//
//  EthernetController.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

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
}

@dynamic state;

- (void)sendEmptyCommand {
    [self sendCommand:@"\n"];
}

- (void)sendCommand:(NSString*)command {
    [self connectTelnetPortIfNecessary:self->outputTelnetStream];
    NSData* cmdData = [[NSData alloc] initWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
    [self->outputTelnetStream write:(const unsigned char*)[cmdData bytes] maxLength:[cmdData length]];
}

- (void)configureOutputSettings {
    [self->telnetCmds addObject:@"OUTPUT ETHERNET\n"];
    [self->telnetCmds addObject:@"MEASTRANSFER SERVER/TCP 1024\n"];
    [self->telnetCmds addObject:@"OUT_ETH 01INTENSITY 01DIST1 TIMESTAMP\n"];
}

- (void)initialize {
    self->ipAddress = @IFC_ADDR;
    self->dataPort = DATA_PORT;
    self->telnetPort = TELNET_PORT;
    [super initialize];
}

- (void)selectOppositeOutput {
    [self->telnetCmds addObject:@"OUTPUT RS422\n"];
}

-(void)connectTelnetPortIfNecessary:(NSStream*)streamToCheck {
    if (streamToCheck == nil || streamToCheck.streamStatus == NSStreamStatusNotOpen || streamToCheck.streamStatus == NSStreamStatusClosed || streamToCheck.streamStatus == NSStreamStatusError) {
        NSLog(@"  Attempting to (re)connect to telnet port.");
        [self connectDevice:self->ipAddress port:self->telnetPort];
    }
}

- (void)disconnectData {
    [self->telnetCmds addObject:@"OUTPUT NONE\n"];
    [self sendTelnetCommand];
    
    NSLog(@"@disconnectData.");
    if (self->inputDataStream != nil)
        [self->inputDataStream removeFromRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
    
    if (self->outputDataStream != nil)
        [self->outputDataStream removeFromRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
    
    if (self->inputDataStream != nil) {
        [self->inputDataStream close];
        self->inputDataStream = nil;
    }
    
    if (self->outputDataStream != nil) {
        [self->outputDataStream close];
        self->outputDataStream = nil;
    }
    
    self->dataStreamIsOpen = false;
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
    [super disconnectTelnet];
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
//            self->telnetIsReady = YES;
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
        
        if([port intValue] == DATA_PORT){
            foundInputDataS = (self->inputDataStream == theStream);
            foundOutputDataS = (self->outputDataStream == theStream);
            dataStreamFound = foundOutputDataS || foundInputDataS;
        }
        else if ([port intValue] == TELNET_PORT) {
            foundInputTelnetS = (self->inputTelnetStream == theStream);
            foundOutputTelnetS = (self->outputTelnetStream == theStream);
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
//                    if(telnetStreamFound) self->telnetIsReady = YES;
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
                    
                    if(dataStreamFound)  self->dataStreamIsOpen = YES;
                    if(telnetStreamFound) {
                        self->telnetStreamIsOpen = YES;
//                        self->telnetIsReady = YES;
                    }
                    
                    break;
                }
                case NSStreamEventHasBytesAvailable:
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
                case NSStreamEventErrorOccurred:
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
                    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":errorMessage} keepOpen:NO];
                    break;
                }
                case NSStreamEventEndEncountered:
                {
                    NSLog(@"NSStreamEventEndEncountered for port = %@", port);
                    [theStream close];
                    [theStream removeFromRunLoop:self->networkRunLoop forMode:NSDefaultRunLoopMode];
                    theStream = nil;
                    
                    if ([port intValue] == TELNET_PORT) {
                        self->inputTelnetStream = nil;
                        self->outputTelnetStream = nil;
                    }
                    else if ([port intValue] == DATA_PORT) {
                        self->inputDataStream = nil;
                        self->outputDataStream = nil;
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
    
    uint32_t order_number;
    uint32_t serial_number;
    uint32_t video_length;
    uint32_t len_meas_dat;
    uint32_t num_frames;
    uint32_t counter;
    uint32_t timestamp;
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
