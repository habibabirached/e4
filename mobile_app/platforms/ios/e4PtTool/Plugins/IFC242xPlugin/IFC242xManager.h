//
//  IFC242xManager.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-30.
//
//

#import <Cordova/CDV.h>

@interface IFC242xManager : NSObject
@property (nonatomic) float progress;

-(instancetype)initWithPlugin:(CDVPlugin*)plugin;

- (void)dispatchMessage:(NSDictionary*)messagesDictionary;
- (void)messageHandler:(NSDictionary*)message callbackId:(NSString*)callbackId;
- (void)processComplete:(NSString*)statusMsg;
- (void)returnPluginResponse:(NSDictionary*)jsonMessage keepOpen:(BOOL)keepOpen;
- (void)startProgressReporting;
@end
