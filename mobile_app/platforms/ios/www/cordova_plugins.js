cordova.define('cordova/plugin_list', function(require, exports, module) {
module.exports = [
  {
    "id": "cordova-plugin-splashscreen.SplashScreen",
    "file": "plugins/cordova-plugin-splashscreen/www/splashscreen.js",
    "pluginId": "cordova-plugin-splashscreen",
    "clobbers": [
      "navigator.splashscreen"
    ]
  },
  {
    "id": "cordova-sqlite-storage.SQLitePlugin",
    "file": "plugins/cordova-sqlite-storage/www/SQLitePlugin.js",
    "pluginId": "cordova-sqlite-storage",
    "clobbers": [
      "SQLitePlugin"
    ]
  },
  {
    "id": "cordova-plugin-dialogs.notification",
    "file": "plugins/cordova-plugin-dialogs/www/notification.js",
    "pluginId": "cordova-plugin-dialogs",
    "merges": [
      "navigator.notification"
    ]
  },
  {
    "id": "IFC242xPlugin.IFC242x",
    "file": "plugins/IFC242xPlugin/www/ifc242x.js",
    "pluginId": "IFC242xPlugin",
    "clobbers": [
      "window.plugins.IFC242xPlugin"
    ]
  }
];
module.exports.metadata = 
// TOP OF METADATA
{
  "cordova-plugin-splashscreen": "5.0.3",
  "cordova-plugin-whitelist": "1.3.4",
  "cordova-sqlite-storage": "3.4.0",
  "cordova-plugin-dialogs": "2.0.2",
  "IFC242xPlugin": "0.1.0"
};
// BOTTOM OF METADATA
});