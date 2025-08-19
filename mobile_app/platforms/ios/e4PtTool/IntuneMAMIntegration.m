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
    
    // Set the policy delegate
    [IntuneMAMPolicyManager instance].delegate = self;
    
    // Initialize the SDK
    [[IntuneMAMEnrollmentManager instance] loginAndEnrollAccount:nil];
}

- (BOOL)isDataSavingAllowed {
    IntuneMAMPolicy *policy = [[IntuneMAMPolicyManager instance] policyForIdentity:nil];
    
    if (policy) {
        // Check if saving organizational data locally is allowed
        return policy.saveToLocationPolicy == IntuneMAMSaveLocationLocalDrive;
    }
    
    // Default to false for security
    return NO;
}

- (BOOL)isEmailSharingAllowed {
    IntuneMAMPolicy *policy = [[IntuneMAMPolicyManager instance] policyForIdentity:nil];
    
    if (policy) {
        // Check if sharing via email is allowed
        return policy.sharePolicy != IntuneMAMSharePolicyNone;
    }
    
    // Default to false for security
    return NO;
}

- (NSString *)getApprovedCloudStorageProviders {
    IntuneMAMPolicy *policy = [[IntuneMAMPolicyManager instance] policyForIdentity:nil];
    
    if (policy) {
        // Return comma-separated list of approved cloud storage providers
        NSMutableArray *approvedProviders = [[NSMutableArray alloc] init];
        
        // Check for specific approved cloud storage services
        if (policy.saveToLocationPolicy & IntuneMAMSaveLocationCloud) {
            [approvedProviders addObject:@"Box"];
            [approvedProviders addObject:@"OneDrive for Business"];
            [approvedProviders addObject:@"SharePoint"];
        }
        
        return [approvedProviders componentsJoinedByString:@","];
    }
    
    return @"";
}

#pragma mark - IntuneMAMPolicyDelegate

- (void)identityHasChanged {
    NSLog(@"Intune MAM: Identity has changed");
    [self handleMAMPolicyChange];
}

- (void)policyHasChanged {
    NSLog(@"Intune MAM: Policy has changed");
    [self handleMAMPolicyChange];
}

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
