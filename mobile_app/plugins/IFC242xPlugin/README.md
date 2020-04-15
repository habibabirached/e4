# iwdc_cordova_plugin
Cordova plugin code to be used to communicate with the Micro-Epsilon IFC242x chromatic confocal optical sensor.

To install this plugin use the following command:

     cordova plugin add git+ssh://git@github.build.ge.com:iacquire-grc/IFC242xPlugin.git

You may have to set your proxy settings in your environment because Cordova may try to reach outside the GE network when updating the plugins.
Cordova may also prompt for your credentials two or three times.  This is normal.

When using this plugin in a Cordova project you will need to add the ExternalAccessory.framework to the project.
Also, you will need to add to the project on the 'Info' screen, "Supported External Accessory Protocols" with Item 0's value being "com.redpark.hobdb9" and Item 1's value being "com.redpark.hobdb9v".  This is according to the Redpark documentation.  However, the redpark demo application also includes entries for "com.redpark.ser45", "com.redpark.ser45v", "com.amanenterprises.hobbster".  These may also be good to add.



