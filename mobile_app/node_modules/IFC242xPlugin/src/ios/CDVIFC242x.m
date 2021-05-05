//
//  CDVIFC242x.m
//  IFC242x
//
//  Created by Glen Brooksby - March 24, 2020
//  Copyright (c) General Electric Co.
//
//
#import "CDVIFC242x.h"
#import "IFC242xManager.h"


// Take out the printf lines in release mode
#ifndef DEBUG
#define DBGcout if(0)printf
#else
#define DBGcout printf
#endif


@implementation CDVIFC242x {
    IFC242xManager* manager;
}


- (IFC242xManager*)manager {
    // TODO: ensure only one instance can exist
    if (!manager) {
        NSLog(@"CDVIFC242x::manger: does not exist, initializing");
        manager = [[IFC242xManager alloc] initWithPlugin:self];
    }
    return manager;
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
- (void)connectDevice:(CDVInvokedUrlCommand*)command {}

/**
 * disconnectDevice
 *
 * call this plugin method to disconnect a specific device. 
 *
 */

- (void)disconnectDevice:(CDVInvokedUrlCommand*)command {}

/**
 * setDeviceMode
 *
 * call this plugin method to set the acquisition mode of the connected
 * device.  Options are:
 *   Ethernet
 *   RS232
 */
- (void)setDeviceMode:(CDVInvokedUrlCommand*)command {
    [self messageHandler:[[CDVInvokedUrlCommand alloc] initWithArguments:@[@"set_connection_mode", command.arguments[0]] callbackId:command.callbackId className:command.className methodName:command.methodName]];
}

/**
 * doDarkReference
 */
- (void)doDarkReference:(CDVInvokedUrlCommand*)command {
    [self messageHandler:[[CDVInvokedUrlCommand alloc] initWithArguments:@[@"do_dark_reference"] callbackId:command.callbackId className:command.className methodName:command.methodName]];
}

/**
 * masterSensor
 */
- (void)masterSensor:(CDVInvokedUrlCommand*)command {
    [self messageHandler:[[CDVInvokedUrlCommand alloc] initWithArguments:@[@"do_mastering"] callbackId:command.callbackId className:command.className methodName:command.methodName]];
}

/**
 * collectData
 */
- (void)collectData:(CDVInvokedUrlCommand*)command {}

/**
 * setMeasureRate
 */
- (void)setMeasureRate:(CDVInvokedUrlCommand*)command {
    [self messageHandler:[[CDVInvokedUrlCommand alloc] initWithArguments:@[@"set_measuring_rate", command.arguments[0]] callbackId:command.callbackId className:command.className methodName:command.methodName]];
}

- (void)messageHandler:(CDVInvokedUrlCommand*)command {
    NSLog(@"@CDVIFC242x::messageHandler: command.callbackId = %@", command.callbackId);
    [self.commandDelegate runInBackground:^{
        if ([command.arguments[0] isKindOfClass:[NSDictionary class]])
            [self.manager messageHandler:command.arguments[0] callbackId:command.callbackId];
        else
            //support legacy format of array of strings
            [self.manager messageHandler:[self commandStringToDictionary:command.arguments] callbackId:command.callbackId];
        
    }];
}

- (NSDictionary*)commandStringToDictionary:(NSArray*)commands {
    NSLog(@"Detected the use of legacy payload structure, array of strings.  Compatibility with the legacy format will be removed in a future release. Replace the legacy payload with the supported JSON structure.");
    NSMutableDictionary* dict = [NSMutableDictionary new];
    [dict setValue:commands[0] forKey:@"command"];
    if (commands.count > 1) {
        if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"do_mastering"])
            [dict setValue:commands[1] forKey:@"reset"];
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"get_threshold_for_rate"])
                [dict setValue:commands[1] forKey:@"rate"];
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"set_measuring_rate"])
            [dict setValue:commands[1] forKey:@"rate"];
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"set_threshold"])
            [dict setValue:commands[1] forKey:@"threshold"];
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"set_measuring_rate_and_threshold"]) {
            [dict setValue:commands[1] forKey:@"rate"];
            [dict setValue:commands[2] forKey:@"threshold"];
        }
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"set_manual_override"])
            [dict setValue:commands[1] forKey:@"value"];
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"set_connection_mode"])
            [dict setValue:commands[1] forKey:@"mode"];
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"set_sensor_parameters"]) {
            [dict setValue:commands[1] forKey:@"hmf"];
            if (commands.count > 2) [dict setValue:commands[2] forKey:@"mv"];
            if (commands.count > 3) [dict setValue:commands[3] forKey:@"mo"];
            if (commands.count > 4) [dict setValue:commands[4] forKey:@"name"];
            if (commands.count > 5) [dict setValue:commands[5] forKey:@"length"];
            if (commands.count > 6) [dict setValue:commands[6] forKey:@"smr"];
            if (commands.count > 7) [dict setValue:commands[7] forKey:@"mr"];
        }
        else if (NSOrderedSame == [commands[0] localizedCaseInsensitiveCompare:@"send_data"]) {
            if (commands.count < 4) {
                [dict setValue:commands[1] forKey:@"acquisitionTime"];
                if (commands.count > 2) [dict setValue:commands[2] forKey:@"casingThickness"];
            } else {
                [dict setValue:commands[1] forKey:@"rpms"];
                [dict setValue:commands[3] forKey:@"serialNumber"];
                [dict setValue:commands[4] forKey:@"stage"];
                [dict setValue:commands[5] forKey:@"position"];
                [dict setValue:commands[6] forKey:@"casingThickness"];
                [dict setValue:commands[7] forKey:@"spacerThickness"];
                [dict setValue:commands[8] forKey:@"numberOfBlades"];
                [dict setValue:commands[9] forKey:@"tipDiameter"];
                [dict setValue:commands[10] forKey:@"bladeWidth"];
                [dict setValue:commands[12] forKey:@"clearanceCalculationMethod"];
            }
        }
    }
    return dict;
    //NSData* data = [[command.arguments objectAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding];
    //return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

@end
