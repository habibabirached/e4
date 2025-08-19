# Intune MAM SDK Integration for e4PtTool

This document describes the Microsoft Intune Mobile Application Management (MAM) SDK integration for the e4PtTool iOS application.

## Overview

The e4PtTool has been enhanced to support Intune MAM policies, enabling :

- Control data saving to local storage
- Restrict email sharing of organizational data
- Limit cloud storage to approved services (Box, OneDrive for Business, SharePoint)
- Enforce data protection policies on organizational data

## Integration Components

### 1. Native iOS Components

#### IntuneMAMIntegration.h/m

- Singleton class that manages Intune MAM SDK integration
- Implements `IntuneMAMPolicyDelegate` protocol
- Provides methods to check MAM policy compliance

#### IntuneMAMPlugin.h/m

- Cordova plugin bridge between JavaScript and native Intune SDK
- Exposes MAM policy checks to JavaScript layer

### 2. JavaScript Components

#### intune-mam-bridge.js

- JavaScript interface to Intune MAM functionality
- Provides async methods for policy checking
- Handles MAM policy change notifications

#### Updated e4pt_app.js

- Enhanced email functionality with MAM policy checks
- Updated Box upload with cloud storage policy validation
- Added local file saving restrictions based on MAM policies
- Periodic compliance checking and UI updates

## MAM Policy Enforcement

### Email Sharing

- **Before**: Direct email sharing without policy checks
- **After**: Checks `isEmailSharingAllowed()` before allowing email operations
- **Restriction Message**: "Email sharing is restricted by your organization's security policies. Please use approved cloud storage services."

### Box Upload

- **Before**: Direct Box upload without policy validation
- **After**: Validates approved cloud storage providers before upload
- **Restriction Message**: "Box upload is not permitted by your organization's security policies."

### Local Data Saving

- **Before**: Unrestricted local file saving
- **After**: Checks `isDataSavingAllowed()` before local operations
- **Restriction Message**: "Local data saving is restricted by your organization's security policies."

## Build Requirements

### Prerequisites

1. **Intune App SDK for iOS** (Download from Microsoft)
2. **Xcode 12.0 or later**
3. **iOS 11.0 deployment target or later**
4. **Valid Apple Developer Program membership**

### Build Steps

1. **Add Intune SDK Framework**

   ```bash
   # Download IntuneMAM.framework from Microsoft
   # Add to your Xcode project under Frameworks
   ```
2. **Update Build Settings**

   - Add IntuneMAM.framework to "Linked Frameworks and Libraries"
   - Add framework search paths if needed
   - Ensure "Enable Bitcode" is set to NO (Intune requirement)
3. **Update Info.plist**

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLName</key>
           <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
           </array>
       </dict>
   </array>
   ```
4. **Build and Test**

   ```bash
   # Build the project in Xcode
   # Test MAM policy enforcement
   ```

## Configuration in Intune

### App Protection Policy Settings

1. **Data Protection**

   - Save copies of org data: `Block` or `Allow to approved services`
   - Send org data to other apps: `Policy managed apps`
   - Receive data from other apps: `Policy managed apps`
2. **Access Requirements**

   - PIN for access: `Require`
   - Corporate credentials for access: `Require`
3. **Conditional Launch**

   - Max offline grace period: Configure as needed
   - App version: Set minimum version requirements

### Approved Cloud Storage Services

Configure the following services as approved:

- Microsoft OneDrive for Business
- Microsoft SharePoint
- Box (if approved by organization)

## Testing MAM Policies

### Test Scenarios

1. **Email Restriction Test**

   - Set email sharing to blocked in Intune policy
   - Attempt to email data from app
   - Verify restriction message appears
2. **Local Storage Test**

   - Set local storage to blocked in Intune policy
   - Attempt to save files locally
   - Verify restriction message appears
3. **Cloud Storage Test**

   - Configure only specific cloud services as approved
   - Attempt Box upload with/without approval
   - Verify policy enforcement

### Debugging

Enable debug logging to troubleshoot MAM policy issues:

```javascript
// In browser console or app logs
console.log("MAM Policy Debug Info:");
IntuneMAM.isDataSavingAllowed(console.log, console.error);
IntuneMAM.isEmailSharingAllowed(console.log, console.error);
IntuneMAM.getApprovedCloudStorageProviders(console.log, console.error);
```

## Compliance Monitoring

The app performs automatic compliance checks:

- **Initial Check**: On app startup
- **Periodic Checks**: Every 5 minutes
- **Policy Change Events**: When Intune policies are updated
- **UI Updates**: Visual indicators for restricted actions

## Support and Troubleshooting

### Common Issues

1. **"IntuneMAM not available" message**

   - Ensure Intune SDK framework is properly linked
   - Check that app is enrolled in Intune
2. **Policy checks always return false**

   - Verify app is assigned Intune App Protection Policy
   - Check user is licensed for Intune
   - Ensure app bundle ID matches Intune configuration
3. **UI not updating based on policies**

   - Check browser console for JavaScript errors
   - Verify MAM policy change notifications are working
   - Test manual compliance refresh

### Contact Information

For technical support with Intune integration, contact your IT administrator or Microsoft Intune support.

## Security Considerations

- All MAM policy checks are enforced at the UI level and native level
- Organizational data is protected according to Intune policies
- App respects user privacy while enforcing corporate data protection
- Regular compliance checking ensures ongoing policy enforcement

---

**Note**: This integration requires the app to be distributed through Intune Company Portal or wrapped with Intune App Wrapping Tool for full MAM policy enforcement.
