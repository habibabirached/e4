//
//  ScanMetaData.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Feb-02.
//
//

@interface ScanMetaData : NSObject
@property (strong, nonatomic) NSString* serialNumber;
@property (strong, nonatomic) NSString* stage;
@property (strong, nonatomic) NSString* position;
@property (nonatomic) float casingThickness;
@property (nonatomic) float spacerThickness;
@property (nonatomic) int numberOfBlades;
@end
