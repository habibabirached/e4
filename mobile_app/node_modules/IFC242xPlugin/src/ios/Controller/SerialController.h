//
//  SerialController.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "BaseController.h"
#import "RscMgr.h"

#define BAUD_RATE_FAST 460800
#define BAUD_RATE_SLOW 115200 // Slower cables only do 115200

// Hard coded values for RS232 serial cable
// 192 = 64 * 3.  Data seems to come in 64 byte packets and data from
// the IFC242x comes in 3-byte values.
#define BYTE_BUFFER_SIZE 192
#define RX_FORWARD_COUNT 64

// Define SERIAL_SEND_TIMESTAMP if you want to have the timestamp
// sent over the serial cable.  This takes more bits over the
// limited serial cable bandwidth.
//#define SERIAL_SEND_TIMESTAMP
// Define SEND_DISPLACEMENT_ONLY if you want to send just the
// displacement value to maximize bandwidth.
//#define SEND_DISPLACEMENT_ONLY

@interface SerialController : BaseController<RscMgrDelegate>
@end
