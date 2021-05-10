//
//  SensorSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#define IN_to_MM 25.4

@interface SensorSettings : NSObject
@property (readonly, strong, nonatomic) NSString* name;
@property (nonatomic) float length;
@property (nonatomic) float smr;
@property (nonatomic) float mr;
@property (nonatomic) float hmf;
@property (nonatomic) float mv;
@property (nonatomic) float mo;
@property (strong, nonatomic) NSString* offsetSelector;
@property (readonly, strong, nonatomic) NSString* offsetAdjustmentFormula;

+(SensorSettings*) LONG;
+(SensorSettings*) SHORT;
+(SensorSettings*) PROTOTYPE;
+(SensorSettings*) CUSTOM;
+(SensorSettings*) forType:(NSString*)type;
+(float) mvFromLength:(float)length hmf:(float)hmf smr:(float)smr;
+(float) moFromLength:(float)length hmf:(float)hmf smr:(float)smr mv:(float)mv;

-(instancetype)initWithName:(NSString*)name;
-(instancetype)initWithName:(NSString*)name lengthInches:(float)length measurementRangeMM:(float)mr startOfMeasurementRangeMM:(float)smr masterFixtureHeightInches:(float)hmf;
-(instancetype)initWithName:(NSString*)name lengthInches:(float)length measurementRangeMM:(float)mr startOfMeasurementRangeMM:(float)smr masterFixtureHeightInches:(float)hmf masteringValueMM:(float)mv masteringOffsetInches:(float)mo;
-(float)calculateOffsetAdjustment:(float)spacerThickness casingThickness:(float)casingThickness;
-(NSString*)offsetAdjustmentExplanation:(float)spacerThickness casingThickness:(float)casingThickness;
@end
