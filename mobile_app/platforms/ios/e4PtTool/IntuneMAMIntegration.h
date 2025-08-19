//
//  IntuneMAMIntegration.h
//  e4PtTool
//
//  Created for Intune MAM SDK Integration
//

#import <Foundation/Foundation.h>
#import <IntuneMAM/IntuneMAM.h>

@interface IntuneMAMIntegration : NSObject <IntuneMAMPolicyDelegate>

+ (instancetype)sharedInstance;
- (void)initializeIntuneMAM;
- (BOOL)isDataSavingAllowed;
- (BOOL)isEmailSharingAllowed;
- (NSString *)getApprovedCloudStorageProviders;
- (void)handleMAMPolicyChange;

@end
