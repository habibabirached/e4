cordova.define("IFC242xPlugin.IFC242x", function(require, exports, module) {
function IFC242x() {
}

IFC242x.prototype.getConnectedDevices = function(){
	return this.connectedDeviceID;
};

/**
 * A function called by callback function CDVIFC242x.deviceFound each time a new device is found.
 */
IFC242x.prototype.newDeviceFound = function (deviceID, deviceName) {
    var msg = "IFC242x.newDeviceFound";
};

IFC242x.prototype.connectDevice = function (deviceID, success, failure) {
    cordova.exec(success, failure, "IFC242x", "connectDevice", [deviceID]);
};

IFC242x.prototype.disconnectDevice = function(deviceID, success, failure) {
    cordova.exec(success, failure, "IFC242x", "disconnectDevice", [deviceID]);
 };

IFC242x.prototype.masterDevice = function(deviceID, success, failure) {
    console.log(" deviceID = " + deviceID);
    cordova.exec(success, failure, "IFC242x", "masterDevice", [deviceID]);
};

/*
 * This method is called from CDVIFC242x.m via function callBackWithCommandString
 */
IFC242x.prototype.messageFromDevice = function(message) {

};

IFC242x.prototype.messageToDevice = function(message) {
    console.log("@ifc242x.js::messageToDevice");
};
               
/**
 * An error callback to display the function name and error message from the FEF Library
 *
 * @param methodName method from which this is called
 * @param message error message
 */

IFC242x.prototype.OnError = function (methodName, message) {
    deviceStatusOut('** Error in method [' + methodName + ' ] message[ ' + message + ' ]');
};

IFC242x.install = function () {
  if (!window.plugins) {
    window.plugins = {};
  }

  window.plugins.IFC242x = new IFC242x();
  return window.plugins.IFC242x;
};

cordova.addConstructor(IFC242x.install);



});
