//
//  EthernetController.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-29.
//
//

#import "BaseController.h"

// Hard coded address for the IFC-242x address, which should be static.
#define IFC_ADDR_GE "192.168.168.150" // GE default
#define IFC_ADDR_ME "169.254.168.150" // Micro-Epsilon default
#define DATA_PORT 1024
#define TELNET_PORT 23

@interface EthernetController : BaseController <NSStreamDelegate>
@end
