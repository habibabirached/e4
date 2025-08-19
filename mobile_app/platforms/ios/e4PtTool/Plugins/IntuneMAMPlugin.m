//
//  IntuneMAMPlugin.m
//  e4PtTool
//
//  Cordova plugin bridge for Intune MAM functionality
//

#import "IntuneMAMPlugin.h"
#import "IntuneMAMIntegration.h"

@implementation IntuneMAMPlugin

- (void)isDataSavingAllowed:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        BOOL isAllowed = [[IntuneMAMIntegration sharedInstance] isDataSavingAllowed];
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                            messageAsBool:isAllowed];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)isEmailSharingAllowed:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        BOOL isAllowed = [[IntuneMAMIntegration sharedInstance] isEmailSharingAllowed];
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                            messageAsBool:isAllowed];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getApprovedCloudStorageProviders:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        NSString* providers = [[IntuneMAMIntegration sharedInstance] getApprovedCloudStorageProviders];
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                         messageAsString:providers];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end
