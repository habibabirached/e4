//
//  IntuneMAMIntegration.m
//  e4PtTool
//
//  Created for Intune MAM SDK Integration
//

#import "IntuneMAMIntegration.h"

@implementation IntuneMAMIntegration

+ (instancetype)sharedInstance {
    static IntuneMAMIntegration *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[IntuneMAMIntegration alloc] init];
    });
    return sharedInstance;
}

- (void)initializeIntuneMAM {
    NSLog(@"Initializing Intune MAM SDK");
    
    // TODO: Uncomment after adding IntuneMAM.framework to project
    // Set the policy delegate
    // [IntuneMAMPolicyManager instance].delegate = self;
    
    // Initialize the SDK
    // [[IntuneMAMEnrollmentManager instance] loginAndEnrollAccount:nil];
}

- (BOOL)isDataSavingAllowed {
    // TODO: Uncomment after adding IntuneMAM.framework to project
    // IntuneMAMPolicy *policy = [[IntuneMAMPolicyManager instance] policyForIdentity:nil];
    
    // if (policy) {
    //     // Check if saving organizational data locally is allowed
    //     return policy.saveToLocationPolicy == IntuneMAMSaveLocationLocalDrive;
    // }
    
    // Temporary: Allow all operations until framework is added
    NSLog(@"IntuneMAM framework not available - allowing data saving");
    return YES; // Change to NO for security when framework is added
}

- (BOOL)isEmailSharingAllowed {
    // TODO: Uncomment after adding IntuneMAM.framework to project
    // IntuneMAMPolicy *policy = [[IntuneMAMPolicyManager instance] policyForIdentity:nil];
    
    // if (policy) {
    //     // Check if sharing via email is allowed
    //     return policy.sharePolicy != IntuneMAMSharePolicyNone;
    // }
    
    // Temporary: Allow all operations until framework is added
    NSLog(@"IntuneMAM framework not available - allowing email sharing");
    return YES; // Change to NO for security when framework is added
}

- (NSString *)getApprovedCloudStorageProviders {
    // TODO: Uncomment after adding IntuneMAM.framework to project
    // IntuneMAMPolicy *policy = [[IntuneMAMPolicyManager instance] policyForIdentity:nil];
    
    // if (policy) {
    //     // Return comma-separated list of approved cloud storage providers
    //     NSMutableArray *approvedProviders = [[NSMutableArray alloc] init];
    //     
    //     // Check for specific approved cloud storage services
    //     if (policy.saveToLocationPolicy & IntuneMAMSaveLocationCloud) {
    //         [approvedProviders addObject:@"Box"];
    //         [approvedProviders addObject:@"OneDrive for Business"];
    //         [approvedProviders addObject:@"SharePoint"];
    //     }
    //     
    //     return [approvedProviders componentsJoinedByString:@","];
    // }
    
    // Temporary: Return all services as approved until framework is added
    NSLog(@"IntuneMAM framework not available - allowing all cloud storage providers");
    return @"Box,OneDrive for Business,SharePoint";
}

#pragma mark - IntuneMAMPolicyDelegate
// TODO: Uncomment after adding IntuneMAM.framework to project

/*
- (void)identityHasChanged {
    NSLog(@"Intune MAM: Identity has changed");
    [self handleMAMPolicyChange];
}

- (void)policyHasChanged {
    NSLog(@"Intune MAM: Policy has changed");
    [self handleMAMPolicyChange];
}
*/

- (void)handleMAMPolicyChange {
    // Notify JavaScript layer about policy changes
    NSString *jsCallback = [NSString stringWithFormat:@"if(window.intuneMAMPolicyChanged) { window.intuneMAMPolicyChanged(); }"];
    
    // This will be called from the main view controller
    dispatch_async(dispatch_get_main_queue(), ^{
        // The actual JS execution will be handled by the main view controller
        [[NSNotificationCenter defaultCenter] postNotificationName:@"IntuneMAMPolicyChanged" object:nil];
    });
}

@end
