/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

//
//  AppDelegate.m
//  e4PtTool
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  Copyright ___ORGANIZATIONNAME___ ___YEAR___. All rights reserved.
//

#import "AppDelegate.h"
#import "MainViewController.h"

@implementation AppDelegate

@synthesize connectionType = _connectionType;
@synthesize ipAddress = _ipAddress;
@synthesize baudRate = _baudRate;
@synthesize useSerialBuffer = _useSerialBuffer;
@synthesize useSensorParams = _useSensorParams;
@synthesize pointsPerBlade = _pointsPerBlade;

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self.viewController = [[MainViewController alloc] init];
    
    [self checkAppSettings];
    
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)checkAppSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSObject *connectionTypeObject = [defaults objectForKey:@"connectionType"];
    NSObject *ipAddressObject = [defaults objectForKey:@"ipAddress"];
    NSObject *baudRateObject = [defaults objectForKey:@"baudRate"];
    NSObject *useSerialBufferObject = [defaults objectForKey:@"useSerialBuffer"];
    NSObject *useSensorParamsObject = [defaults objectForKey:@"useSensorParams"];
    NSObject *pointsPerBladeObject = [defaults objectForKey:@"pointsPerBlade"];
    if (connectionTypeObject == nil || ipAddressObject == nil || baudRateObject == nil || useSerialBufferObject == nil || useSensorParamsObject == nil || pointsPerBladeObject == nil) {
        [self registerDefaultsFromSettingsBundle];
    }

    self.connectionType = [defaults stringForKey:@"connectionType"];
    self.ipAddress = [defaults stringForKey:@"ipAddress"];
    self.baudRate = [NSNumber numberWithInt:[[defaults stringForKey:@"baudRate"] intValue]];
    self.useSerialBuffer = [defaults boolForKey:@"useSerialBuffer"];
    self.useSensorParams = [defaults boolForKey:@"useSensorParams"];
    self.pointsPerBlade = [NSNumber numberWithInt:[[defaults stringForKey:@"pointsPerBlade"] intValue]];
}

- (void)registerDefaultsFromSettingsBundle {
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        NSLog(@"Could not find Settings.bundle");
        return;
    }
    
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
    
    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for(NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        if(key && [[prefSpecification allKeys] containsObject:@"DefaultValue"]) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
}

- (BOOL)application:(UIApplication*)application openURL:(nonnull NSURL *)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if ([[url lastPathComponent] hasSuffix:@"json"])
        [self.viewController.commandDelegate evalJs:[NSString stringWithFormat:@"loadExternalFile('%@', '%@')", [url URLByDeletingLastPathComponent], [url lastPathComponent]]];
    return true;
}

@end
