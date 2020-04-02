var DocPickerViewController = function() {

};
/**
 * @param supportedFormats is a string of comma-separated values defined on web page
 *     https://escapetech.eu/manuals/qdrop/uti.html#image
 *     For iAcquire, the value for spreadsheets should be "public.composite-content".
 *     The value for image files should be "public.jpeg,public.png".
 */
DocPickerViewController.prototype.openBoxApp = function(dirName, supportedFormats) {
    //var supportedFormats = "public.composite-content,public.jpeg,public.png";
    cordova.exec(null, null, "DocPickerViewController", "openBoxApp", [supportedFormats, dirName]);
};

DocPickerViewController.prototype.uploadFileToBox = function(fileFullPath) {
    cordova.exec(null, null, "DocPickerViewController", "uploadFileToBox", [fileFullPath]);
};

module.exports = new DocPickerViewController();


