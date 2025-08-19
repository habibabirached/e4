//
//  IntuneMAMPlugin.h
//  e4PtTool
//
//  Cordova plugin bridge for Intune MAM functionality
//

#import <Cordova/CDVPlugin.h>

@interface IntuneMAMPlugin : CDVPlugin

- (void)isDataSavingAllowed:(CDVInvokedUrlCommand*)command;
- (void)isEmailSharingAllowed:(CDVInvokedUrlCommand*)command;
- (void)getApprovedCloudStorageProviders:(CDVInvokedUrlCommand*)command;

@end
