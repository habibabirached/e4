# iwdc_cordova_plugin
Cordova plugin code to be used to communicate with the Micro-Epsilon IFC242x chromatic confocal optical sensor.

To install this plugin use the following command:

     cordova plugin add git+ssh://git@github.build.ge.com:iacquire-grc/IFC242xPlugin.git

You may have to set your proxy settings in your environment because Cordova may try to reach outside the GE network when updating the plugins.
Cordova may also prompt for your credentials two or three times.  This is normal.

When using this plugin in a Cordova project you will need to add the ExternalAccessory.framework to the project.
Also, you will need to add to the project on the 'Info' screen, "Supported External Accessory Protocols" with Item 0's value being "com.redpark.hobdb9" and Item 1's value being "com.redpark.hobdb9v".  This is according to the Redpark documentation.  However, the redpark demo application also includes entries for "com.redpark.ser45", "com.redpark.ser45v", "com.amanenterprises.hobbster".  These may also be good to add.

## Testing
In order to execute the tests for this plugin, it needs to be installed in a Cordova app and run from there.

1. [Create a new cordova app](https://cordova.apache.org/docs/en/latest/guide/cli/#create-the-app "Getting started with Cordova")
2. From the ios platform directory in the new Cordova app, add the plugin and the plugin javascript tests

        cordova plugin add <local path to this checkout>
        cordova plugin add plugins/IFC242xPlugin/tests

    _If you are developing for this plugin it is recommended that you use the **--link** option when adding the plugins to the app_
3. [Add the cordova-plugin-test-framework](https://github.com/apache/cordova-plugin-test-framework/blob/master/README.md#harness)
4. Create a unit testing bundle for the Objective-C tests
   1. Open the app in XCode
   2. File -> New -> Target
   3. Select "Unit Testing Bundle"
5. Add the unit tests to the testing target by right-click, "Add Files to ..."
   - Uncheck "Copy items if needed" (if you are developing for this plugin)
   - Choose "Create folder references" for Added folders
   - Select all files and folders under the XCTests directory of this project

### Executing Javascript tests
Simply run your Cordova app from XCode on a device and see a webpage open up with the autorun tests and results

### Executing Objective-C unit tests
From within XCode, Product -> Test
