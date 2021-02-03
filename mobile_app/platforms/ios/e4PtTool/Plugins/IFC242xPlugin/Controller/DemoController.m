//
//  DemoController.m
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "DemoController.h"
#import "../IFC242xManager.h"


@implementation DemoController


- (void)initialize {
    self->telnetIsReady = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->timerSendTelnetCommand invalidate];
    });
    [self->telnetCmds removeAllObjects];
    [self sendTelnetCommand];
}

- (void)sendEmptyCommand {
    self->telnetIsReady = YES;
}

- (void)sendCommand:(NSString*)command {
    [self processResponse:@"->\r\n"];
}

- (void)selectOppositeOutput {}

- (void)connectTelnetPortIfNecessary:(NSStream*)streamToCheck {}

- (void)disconnectData {}

- (void)connectDevice:(NSString*)ip_address port:(int)port {}

//TODO is casing thickness needed as an input here?
- (void)doDataCollection {
    [self loadCSVFile:@""];
    [self->delegate returnPluginResponse:@{@"type":@"status",@"status":@"processing"} keepOpen:YES];
    [self->delegate computeClearance];
    [self->delegate returnData];
}

-(NSString*)getPathToDataFile:(NSString*)relativePath {
    return [[NSBundle mainBundle] pathForResource:relativePath ofType:@"csv"];
}

// loadCSVFile reads a CSV file and populates the data structures as though
// the data had come from the sensor.
- (bool)loadCSVFile:(NSString*)relativePath {
    NSString* filePath = [self getPathToDataFile:relativePath];
    NSFileManager* fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:filePath]) {
        NSLog(@"Demo file not found.");
        return false;
    }
    NSString* fullFile = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
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
        [self.measurementData.displacements addObject:[NSNumber numberWithFloat:[[lineArray objectAtIndex:4] floatValue]]];
        [self.measurementData.datasetIDs addObject:[NSNumber numberWithInteger:[[lineArray objectAtIndex:2] intValue]]];
        [self.measurementData.timestamps addObject:[NSNumber numberWithUnsignedInteger:(unsigned int)[[lineArray objectAtIndex:3] intValue]]];
        [self.measurementData.pointCounts addObject:[NSNumber numberWithInteger:[[lineArray objectAtIndex:1] intValue]]];
        [self.measurementData.intensities addObject:[NSNumber numberWithFloat:[[lineArray objectAtIndex:6] floatValue]]];
        r++;
    }
    NSLog(@"Completed parsing CSV file.");
    return true;
}

@end
