/**
 * Intune MAM Bridge for e4PtTool
 * Provides JavaScript interface to Intune Mobile Application Management policies
 */

var IntuneMAM = {
    
    /**
     * Check if data saving to local storage is allowed by MAM policies
     * @param {Function} successCallback - Called with boolean result
     * @param {Function} errorCallback - Called on error
     */
    isDataSavingAllowed: function(successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "IntuneMAMPlugin", "isDataSavingAllowed", []);
    },
    
    /**
     * Check if email sharing is allowed by MAM policies
     * @param {Function} successCallback - Called with boolean result
     * @param {Function} errorCallback - Called on error
     */
    isEmailSharingAllowed: function(successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "IntuneMAMPlugin", "isEmailSharingAllowed", []);
    },
    
    /**
     * Get list of approved cloud storage providers
     * @param {Function} successCallback - Called with comma-separated string of providers
     * @param {Function} errorCallback - Called on error
     */
    getApprovedCloudStorageProviders: function(successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "IntuneMAMPlugin", "getApprovedCloudStorageProviders", []);
    }
};

// Make IntuneMAM available globally
window.IntuneMAM = IntuneMAM;

// Handle MAM policy changes
window.intuneMAMPolicyChanged = function() {
    console.log("Intune MAM policy has changed - refreshing compliance checks");
    // Trigger any necessary UI updates or compliance checks
    if (typeof window.refreshMAMCompliance === 'function') {
        window.refreshMAMCompliance();
    }
};
