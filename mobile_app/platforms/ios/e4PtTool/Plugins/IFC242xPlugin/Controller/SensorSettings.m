//
//  SensorSettings.h
//  IFC242x
//
//  Created by Marc Garbiras on 2021-Jan-23.
//
//

#import "SensorSettings.h"

@interface SensorSettings ()
@property (strong, nonatomic) NSString* name;
@end

@implementation SensorSettings

@synthesize name = _name;
@synthesize length = _length;
@synthesize smr = _smr;
@synthesize mr = _mr;
@synthesize hmf = _hmf;
@synthesize mv = _mv;
@synthesize mo = _mo;
@synthesize offsetSelector = _offsetSelector;
@synthesize offsetAdjustmentFormula = _offsetAdjustmentFormula;

+(SensorSettings*) LONG {
    return [[SensorSettings alloc] initWithName:@"LONG" lengthInches:8.825 measurementRangeMM:11.0 startOfMeasurementRangeMM:11.94 masterFixtureHeightInches:9.463];
}

+(SensorSettings*) SHORT {
    return [[SensorSettings alloc] initWithName:@"SHORT" lengthInches:2.979 measurementRangeMM:11.0 startOfMeasurementRangeMM:11.94 masterFixtureHeightInches:3.568];
}

+(SensorSettings*) PROTOTYPE {
    return [[SensorSettings alloc] initWithName:@"PROTOTYPE" lengthInches:8.933 measurementRangeMM:10.0 startOfMeasurementRangeMM:10.998 masterFixtureHeightInches:9.567];
}

+(SensorSettings*) CUSTOM {
    return [[SensorSettings alloc] initWithName:@"CUSTOM"];
}

+(SensorSettings*) forType:(NSString*)type {
    if ([@"LONG" isEqualToString:type])
        return [SensorSettings LONG];
    if ([@"SHORT" isEqualToString:type])
        return [SensorSettings SHORT];
    if ([@"PROTOTYPE" isEqualToString:type])
        return [SensorSettings PROTOTYPE];
    return [SensorSettings CUSTOM];
}

+(float) mvFromLength:(float)length hmf:(float)hmf smr:(float)smr {
    return IN_to_MM * (hmf - length) - smr;
}

+(float) moFromLength:(float)length hmf:(float)hmf smr:(float)smr mv:(float)mv {
    return length + (smr + mv)/IN_to_MM - hmf;
}

-(instancetype)initWithName:(NSString*)name {
    return [self initWithName:name lengthInches:0.0 measurementRangeMM:0.0 startOfMeasurementRangeMM:0.0 masterFixtureHeightInches:0.0];
}

-(instancetype)initWithName:(NSString*)name lengthInches:(float)length measurementRangeMM:(float)mr startOfMeasurementRangeMM:(float)smr masterFixtureHeightInches:(float)hmf {
    float mv = [SensorSettings mvFromLength:length hmf:hmf smr:smr];
    return [self initWithName:name lengthInches:length measurementRangeMM:mr startOfMeasurementRangeMM:smr masterFixtureHeightInches:hmf masteringValueMM:mv masteringOffsetInches:[SensorSettings moFromLength:length hmf:hmf smr:smr mv:mv]];
}

-(instancetype)initWithName:(NSString*)name lengthInches:(float)length measurementRangeMM:(float)mr startOfMeasurementRangeMM:(float)smr masterFixtureHeightInches:(float)hmf masteringValueMM:(float)mv masteringOffsetInches:(float)mo {
    if (self = [super init]) {
        self.name = name;
        self.length = length;
        self.smr = smr;
        self.mr = mr;
        self.hmf = hmf;
        self.mv = mv;
        self.mo = mo;
    }
    return self;
}

-(NSString*) offsetSelector {
    if (!_offsetSelector) _offsetSelector = @"1";
    return _offsetSelector;
}

-(void) setOffsetSelector:(NSString*)selector {
    if (![@"2" isEqualToString:selector])
        _offsetSelector = @"1";
    else
        _offsetSelector = selector;
}

-(NSString*) offsetAdjustmentFormula {
    if ([@"2" isEqualToString:[self offsetSelector]]) {
        return @"MV + SL - ST - CT + MO";
    }
    return @"Hmf - ST - CT + MO - MV";
}

-(float)calculateOffsetAdjustment:(float)spacerThickness casingThickness:(float)casingThickness {
    if ([@"2" isEqualToString:[self offsetSelector]]) {
        return [self calcOffsetUsingSL:spacerThickness casingThickness:casingThickness];
    }
    return [self calcOffsetUsingHmf:spacerThickness casingThickness:casingThickness];
}

-(float)calcOffsetUsingHmf:(float)spacerThickness casingThickness:(float)casingThickness {
    return IN_to_MM * ([self hmf] - spacerThickness - casingThickness + [self mo]) - [self mv];
}

-(float)calcOffsetUsingSL:(float)spacerThickness casingThickness:(float)casingThickness {
    return [self mv] + ([self length] - spacerThickness - casingThickness + [self mo]) * IN_to_MM;
}

@end
