//
//  IntuneMAMIntegration.h
//  e4PtTool
//
//  Created for Intune MAM SDK Integration
//

#import <Foundation/Foundation.h>
// TODO: Uncomment after adding IntuneMAM.framework to project
// #import <IntuneMAM/IntuneMAM.h>

// TODO: Add <IntuneMAMPolicyDelegate> after adding IntuneMAM.framework
@interface IntuneMAMIntegration : NSObject // <IntuneMAMPolicyDelegate>

+ (instancetype)sharedInstance;
- (void)initializeIntuneMAM;
- (BOOL)isDataSavingAllowed;
- (BOOL)isEmailSharingAllowed;
- (NSString *)getApprovedCloudStorageProviders;
- (void)handleMAMPolicyChange;

@end
