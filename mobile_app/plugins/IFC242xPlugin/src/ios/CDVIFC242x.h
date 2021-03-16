//
//  CDVIFC242x.h
//  IFC242x
//
//  Created by Clinton Buie on 8/12/13.
//
//

#import <Cordova/CDV.h>

@interface CDVIFC242x : CDVPlugin

//- (void)echo:(CDVInvokedUrlCommand*)command;

/**
 * Error Handling
 *
 * All javascript calls into this plugin will initiate a method on a 
 * separate thread and will return immediately.
 *
 * In the event of an error, the following callback is called:
 *
 *    function window.plugins.IFC242x.OnError(methodName, errorMessage)
 */

/**
 * connectDevice
 *
 * call this plugin method to initiate a device connection.

 * The fully qualified name is window.plugins.IFC242x.connectDevice
 */
- (void)connectDevice:(CDVInvokedUrlCommand*)command;

/**
 * disconnectDevice
 *
 * call this plugin method to disconnect a specific device.
 *
 */
- (void)disconnectDevice:(CDVInvokedUrlCommand*)command;

/**
 * doDarkReference
 *
 * call this plugin method to perform a dark reference
 * on a sensor.
 *
 */
- (void)doDarkReference:(CDVInvokedUrlCommand*)command;

/**
 * masterDevice
 *
 * call this plugin method to master a sensor.
 *
 */
- (void)masterSensor:(CDVInvokedUrlCommand*)command;

/**
 * This option lets the user set the mode (ethernet or
 * serial RS232) of a device.
 */
- (void)setDeviceMode:(CDVInvokedUrlCommand*)command;

/**
 * collectData
 *
 * Call this plugin method to collect data from a
 * sensor.
 *
 */
- (void)collectData:(CDVInvokedUrlCommand*)command;

/**
 * setMeasureRate
 *
 * Call this plugin method to set the sensor sampling
 * rate.
 *
 */
- (void)setMeasureRate:(CDVInvokedUrlCommand*)command;

/**
 * messageHandler
 *
 * Call this plugin method to send a message to the
 * sensor control code.
 *
 */
- (void)messageHandler:(CDVInvokedUrlCommand*)command;

@end
