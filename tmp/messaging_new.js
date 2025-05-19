if (typeof define !== "function") {
  var define = require("./lib/amdefine")(module);
}

//TODO: refactor further to a websocketmessaging and pluginmessaging classes
//websocketmessaging class constructor should require URL, clientID, optional reconnect interval.  Attach callback and optional callbacks
//pluginmessaging class constructor should require pluginFn, optional callback
define(function (require, exports, module) {
  const ReconnectingWebSocket = require("./lib/reconnecting-ws");
  const clientID = 312;
  var communicationChannel, e4PtSocket, pluginCallback;

  const cleanupWebSocket = (socket) => {
    if (socket) {
      socket.close();
    }
  };

  const createWS = (callback, options) => {
    if (navigator.onLine) {
      if ("WebSocket" in window) {
        //console.log("WebSocket is supported by your Browser!");
        var myWS = new ReconnectingWebSocket("ws://192.168.168.41:3405", null, { reconnectInterval: 3000 });

        myWS.onmessage = function (evt) {
          callback(JSON.parse(evt.data));
        };

        if (options) {
          if (options.onopen) {
            myWS.onopen = options.onopen;
          }
          if (options.onclose) {
            myWS.onclose = options.onclose;
          }
          if (options.onerror) {
            myWS.onerror = options.onerror;
          }
        }

        return myWS;
      }
    } else {
      // console.log('Waiting for a WiFi connection');
    }
    return undefined;
  };

  const usesPlugin = () => {
    return communicationChannel === "Plugin";
  };
  const usesWebSocket = () => {
    return communicationChannel === "WebSocket";
  };

  const setupPlugin = (callback) => {
    communicationChannel = "Plugin";
    pluginCallback = callback;
    cleanupWebSocket(e4PtSocket);
    e4PtSocket = undefined;
  };

  const setupWebSocket = (callback, options) => {
    communicationChannel = "WebSocket";
    pluginCallback = undefined;
    cleanupWebSocket(e4PtSocket);
    e4PtSocket = createWS(callback, options);
  };

  const sendMessage = (message) => {
    if (usesWebSocket()) {
      e4PtSocket.send(
        JSON.stringify({
          text: message,
          type: "message",
          id: clientID,
          date: Date.now(),
        })
      );
    } else if (usesPlugin()) {
      window.plugins.IFC242x.messageToDevice(message, pluginCallback, null);
    }
  };

  module.exports = {
    sendMessage: sendMessage,
    setupPlugin: setupPlugin,
    setupWebSocket: setupWebSocket,
    usesPlugin: usesPlugin,
    usesWebSocket: usesWebSocket,
  };
});
