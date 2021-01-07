var messaging, mockRWS;

beforeAll(() => {
    mockRWS = jest.fn();
    mockRWS.close = jest.fn();
    mockRWS.send = jest.fn();
    jest.mock('../lib/reconnecting-ws', () => {
        return jest.fn().mockImplementation(() => {
            return mockRWS;
        });
    });
});

beforeEach(() => {
    messaging = require('../messaging.js');
    jest.clearAllMocks();
});

afterEach(() => {
    mockRWS.send.mockReset();
    window.plugins = undefined;
});

test('uses* is false when not set', () => {
  expect(messaging.usesPlugin()).toBeFalsy();
  expect(messaging.usesWebSocket()).toBeFalsy();
});

test('setupPlugin sets usesPlugin to true', () => {
  messaging.setupPlugin(() => {});
  expect(messaging.usesPlugin()).toBeTruthy();
  expect(messaging.usesWebSocket()).toBeFalsy();
});

test('setupWebSocket sets usesWebSocket to true', () => {
  messaging.setupWebSocket(() => {});
  expect(messaging.usesPlugin()).toBeFalsy();
  expect(messaging.usesWebSocket()).toBeTruthy();
});

test('sendData for plugin executes callback', () => {
  const mockCallback = jest.fn();
  window.plugins =
    {IFC242x: {messageToDevice: jest.fn((msg, callback, err)=>{callback({arg: msg});})}}
  messaging.setupPlugin(mockCallback);
  messaging.sendMessage("any");
  expect(mockCallback).toHaveBeenCalledTimes(1);
  expect(mockCallback).toHaveBeenCalledWith({arg:"any"});
});

test('sendData for websocket creates JSON message', () => {
  messaging.setupWebSocket(()=>{});
  messaging.sendMessage({"some":["thing","else"]});
  expect(mockRWS.send).toHaveBeenCalledTimes(1);
  var actualMsg = JSON.parse(mockRWS.send.mock.calls[0][0]);
  expect(actualMsg).toMatchObject({text: {"some":["thing","else"]},type: "message",id: 312,date:expect.anything()});
});

test('sendData for websocket executes callback', () => {
  const mockCallback = jest.fn();
  mockRWS.send = jest.fn().mockImplementation(() => mockRWS.onmessage({"data":"{\"attr\":\"val\"}"}));
  messaging.setupWebSocket(mockCallback);
  messaging.sendMessage("any");
  expect(mockCallback).toHaveBeenCalledTimes(1);
  expect(mockCallback).toHaveBeenCalledWith({"attr":"val"});
});

test('websocket onopen callback is triggered', () => {
  const mockCallback = jest.fn();
  mockRWS.send = jest.fn().mockImplementation(() => mockRWS.onopen());
  messaging.setupWebSocket(() => {}, {onopen: mockCallback});
  messaging.sendMessage("any");
  expect(mockCallback).toHaveBeenCalledTimes(1);
});

test('websocket onclose callback is triggered', () => {
  const mockCallback = jest.fn();
  mockRWS.send = jest.fn().mockImplementation(() => mockRWS.onclose());
  messaging.setupWebSocket(() => {}, {onclose: mockCallback});
  messaging.sendMessage("any");
  expect(mockCallback).toHaveBeenCalledTimes(1);
});

test('websocket onerror callback is triggered', () => {
  const mockCallback = jest.fn();
  mockRWS.send = jest.fn().mockImplementation(() => mockRWS.onerror());
  messaging.setupWebSocket(() => {}, {onerror: mockCallback});
  messaging.sendMessage("any");
  expect(mockCallback).toHaveBeenCalledTimes(1);
});
