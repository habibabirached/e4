//
//  RscMgr.h
//
//  Copyright © 2011-2015 Redpark  All Rights Reserved
//
//

#ifndef RSC_MGR_H
#define RSC_MGR_H

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessoryDefines.h>
#import <ExternalAccessory/EAAccessoryManager.h>
#import <ExternalAccessory/EAAccessory.h>
#import <ExternalAccessory/EASession.h>

#include "redparkSerial.h"



enum
{	
 	kMsrCts = 0x01,
	kMsrRi =  0x02,
 	kMsrDsr = 0x04,
 	kMsrDcd = 0x08,
 
};

enum {
	kRSC_StreamBufferSize = 8192,
	kRSC_MaxMessageDataLength = 230,
	kRSC_SerialReadBufferSize = 8192,
    kRsc_TxFifoSize = 256,
    kRsc_TxFifoSize_V = 2048,
	kRSC_NoPasscode = 0
};


typedef enum DataSizeType
{
	kDataSize7 = SERIAL_DATABITS_7,
	kDataSize8 = SERIAL_DATABITS_8
} DataSizeType;

typedef enum ParityType
{
	kParityNone = SERIAL_PARITY_NONE,
	kParityOdd = SERIAL_PARITY_ODD,
	kParityEven = SERIAL_PARITY_EVEN
} ParityType;

typedef enum StopBitsType
{
	kStopBits1 = STOPBITS_1,
	kStopBits2 = STOPBITS_2
} StopBitsType;

enum
{
    kDownloadCompleteNoError = 0,
    kDownloadInProgress   = 1,
    kErasingSectors       = 2,
    kRebootingDevice      = 3,
    kDownloadBadAddress   = 0x81,
    kVDownloaderifyFailed = 0x82,
    kDownloadWriteError   = 0x83,
    kDownloadBadLength    = 0x84,
    kDownloadFlashTimeout = 0x85
    
};

#ifdef NMEAX_SDK
#include "GpsMgr.h"
#else
@protocol GpsMgrProtocol;
#endif

@protocol RscMgrDelegate;


@interface RscMgr : NSObject <NSNetServiceDelegate>{


}
	
- (void) setDelegate:(id) delegate;


// Initializes the RscMgr and reigsters for accessory connect/disconnect notifications. 
- (id) init;

// establish communication with the Redpark Serial Cable.  This call will also
// configure the serial port based on defaults or prior calls to set the port config
// (see setBaud, setDataSize, ...)
- (void) open;

// simple serial port config interface
// can be called anytime (even after open: call)
- (void) setBaud:(int)baud;
- (void) setDataSize:(DataSizeType)dataSize;
- (void) setParity:(ParityType)parity;
- (void) setStopBits:(StopBitsType)stopBits;

- (int) getBaud;

// returns TRUE if connected cable supports extended baud rates ( > 57600)
- (BOOL) supportsExtendedBaudRates;

// read write serial bytes
- (int) write:(UInt8 *)data length:(UInt32)length;
- (int) read:(UInt8 *)data length:(UInt32)length;
- (int) getReadBytesAvailable;


// same as write: but takes an NSData object instead of a C style buffer
- (void) writeData:(NSData *)data;

// Send a string over serial connection - same as write: but takes an NSString object
// Note - uses UTF8String to convert/retrieve bytes before sending and includes \0 character
- (void) writeString:(NSString *)string;


// returns an NSString containing the available bytes in rx fifo as a string.
// assumes the data is ASCII and encoded as UTF8
// calling this clears rx fifo similar to read:
- (NSString *) getStringFromBytesAvailable;

// returns an NSData containing the available bytes in rx fifo
// calling this clears rx fifo similar to read:
- (NSData *) getDataFromBytesAvailable;

/* 
 returns a bit field (see redparkSerial.h)
 0-3 current modem status bits for CTS, RI, DSR, DCD, 4-7 previous modem status bits

 MODEM_STAT_CTS  0x01
 MODEM_STAT_RI   0x02
 MODEM_STAT_DSR  0x04
 MODEM_STAT_DCD  0x08
 */
- (int) getModemStatus;

// returns true if DTR is asserted
- (BOOL) getDtr;

// returns true if RTS is asserted
- (BOOL) getRts;

// set DTR state 
- (void) setDtr:(BOOL)enable;

// set RTS state
- (void) setRts:(BOOL)enable;

// advanced (full) serial port config interface (see redparkSerial.h)
- (void) setPortConfig:(serialPortConfig *)config requestStatus:(BOOL)reqStatus;
- (void) setPortControl:(serialPortControl *)control requestStatus:(BOOL)reqStatus;
- (void) getPortConfig:(serialPortConfig *) portConfig;
- (void) getPortStatus:(serialPortStatus *) portStatus;

// new external debug log feature
- (void) enableExternalLogging:(BOOL)enable;
- (void) enableTxRxExternalLogging:(BOOL)enable;
- (void) logEvent:(NSString *)text color:(NSString *)color;

	
// GPS cable only - requires loopback connector
- (void) testGpsCable;

// returns the model name string associated with this EAAccessory
- (NSString *)getDeviceModel;

- (void) enableTxAckAdvance:(BOOL)on;

// Turn on/off RS485 like feature in the firmware.  If enabled, firmware will automatically control
// RTS and raise it when transmitting and then lower it after last byte has clocked out.
- (void) enableAutoRTS:(BOOL)enable;

///////////////////////////////////////////////////////////////////////





@end

@protocol RscMgrDelegate  <NSObject>

// Redpark Serial Cable has been connected and/or application moved to foreground.
// protocol is the string which matched from the protocol list passed to initWithProtocol:
- (void) cableConnected:(NSString *)protocol;

// Redpark Serial Cable was disconnected and/or application moved to background
- (void) cableDisconnected;

// serial port status has changed
// user can call getModemStatus or getPortStatus to get current state
- (void) portStatusChanged;

// bytes are available to be read (user should call read:, getDataFromBytesAvailable, or getStringFromBytesAvailable)
- (void) readBytesAvailable:(UInt32)length;

@optional

// Called when all pending characters have been sent out UART (i.e. TxACK - FIFO is empty).
// The "data" arguement is currently reserved for future use.  Do not use.
- (void) didWriteData:(NSData *)data;

// called when a response is received from cable with portConfig
- (void) didReceivePortConfig;

// GPS Cable only - called with result when loop test completes.  
- (void) didGpsLoopTest:(BOOL)pass;


// Delegate function used to track firmware download progress and update UI.
// percentComplete is a value 0-100 indicating the percent of file downloaded.
// error = kDowloadInProgress - download is in progress.
// error = kDownloadCompleteNoError - download is complete and was successful
// error = xx - and error occurred during download and was stopped.  Cable was not updated.
- (void) didFirmwareUpdateProgress:(int)percentComplete withError:(unsigned char)error;

// advanced advanced
// called when raw rcs message is received (user is expected to interpret redpark header)
// user should return TRUE if message is "handled" or FALSE to indicate RscMgr should
// process message
- (BOOL) rscMessageReceived:(UInt8 *)msg TotalLength:(int)len;



@end


#endif