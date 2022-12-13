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
@synthesize length = _length; // provided by controller (in)
@synthesize smr = _smr; // provided by controller (mm)
@synthesize mr = _mr; // provided by controller (mm)
@synthesize hmf = _hmf; // (in)
@synthesize mv = _mv; // (mm)
@synthesize mo = _mo; // (in)
@synthesize offsetSelector = _offsetSelector;
@synthesize offsetAdjustmentFormula = _offsetAdjustmentFormula;

+(SensorSettings*) LONG {
    // 8.751
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
    if ([@"LONG" isEqualToString:type]) {
        return [SensorSettings LONG];
    } else if ([@"SHORT" isEqualToString:type]) {
        return [SensorSettings SHORT];
    } else if ([@"PROTOTYPE" isEqualToString:type]) {
        return [SensorSettings PROTOTYPE];
    } else {
        return [SensorSettings CUSTOM];
    }
}

+(float) mvFromLength:(float)length hmf:(float)hmf smr:(float)smr {
    float mv = IN_to_MM * (hmf - length) - smr;
    NSLog(@"@mvFromLength: %f = %f * (%f - %f) - %f", mv, IN_to_MM, hmf, length, smr);
    return mv;
}

+(float) moFromLength:(float)length hmf:(float)hmf smr:(float)smr mv:(float)mv {
    // should always be 0.0
    float mo = length + (smr + mv)/IN_to_MM - hmf;
    NSLog(@"@moFromLength: %f = %f + (%f - %f)/%f - %f", mo, length, smr, mv, IN_to_MM, hmf);
    if (fabsf(mo) <= 0.00001) {
        // set to 0 for small values
        mo = 0.0;
    } else {
        NSLog(@"Error: mastering offset should be 0.0, but was %f", mo);
    }
    return mo;
}

-(instancetype)initWithName:(NSString*)name {
    NSLog(@"@initWithName: %@", name);
    return [self initWithName:name lengthInches:0.0 measurementRangeMM:0.0 startOfMeasurementRangeMM:0.0 masterFixtureHeightInches:0.0];
}

-(instancetype)initWithName:(NSString*)name lengthInches:(float)length measurementRangeMM:(float)mr startOfMeasurementRangeMM:(float)smr masterFixtureHeightInches:(float)hmf {
    NSLog(@"@initWithName: %@, %f, %f, %f", name, length, mr, smr);
    float mv = [SensorSettings mvFromLength:length hmf:hmf smr:smr];
    float mo = [SensorSettings moFromLength:length hmf:hmf smr:smr mv:mv];
    return [self initWithName:name lengthInches:length measurementRangeMM:mr startOfMeasurementRangeMM:smr masterFixtureHeightInches:hmf masteringValueMM:mv];
}

-(instancetype)initWithName:(NSString*)name lengthInches:(float)length measurementRangeMM:(float)mr startOfMeasurementRangeMM:(float)smr masterFixtureHeightInches:(float)hmf masteringValueMM:(float)mv {
    NSLog(@"@initWithName: %@, %f, %f, %f, %f, %f", name, length, mr, smr, hmf, mv);
    if (self = [super init]) {
        self.name = name;
        self.length = length;
        self.smr = smr;
        self.mr = mr;
        self.hmf = hmf;
        self.mv = mv;
    }
    return self;
}

-(void)updateMasteringValues {
    NSLog(@"@updateMasteringValues");
    self.mv = [SensorSettings mvFromLength:self.length hmf:self.hmf smr:self.smr];
    self.mo = [SensorSettings moFromLength:self.length hmf:self.hmf smr:self.smr mv:self.mv];
}

-(NSString*) offsetSelector {
    if (!_offsetSelector) {
        _offsetSelector = @"1";
    }
    return _offsetSelector;
}

-(void) setOffsetSelector:(NSString*)selector {
    NSLog(@"@setOffsetSelector: %@", selector);
    _offsetSelector = selector;
}

-(NSString*) offsetAdjustmentFormula {
    if ([@"1" isEqualToString:[self offsetSelector]]) {
        return @"Hmf - ST - CT + MO - MV";
    } else if ([@"2" isEqualToString:[self offsetSelector]]) {
        return @"MV + SL - ST - CT + MO";
    } else if ([@"3" isEqualToString:[self offsetSelector]]) {
        return @"SMR + SL - ST - CT";
    } else {
        return @"0.0";
    }
}

-(NSString*) offsetAdjustmentExplanation:(float)spacerThickness casingThickness:(float)casingThickness {
    if ([@"1" isEqualToString:[self offsetSelector]]) {
        return [NSString stringWithFormat:@"%.3f * (%.3f - %.3f - %.3f + %.3f) - %.3f", IN_to_MM, [self hmf], spacerThickness, casingThickness, [self mo], [self mv]];
    } else if ([@"2" isEqualToString:[self offsetSelector]]) {
        return [NSString stringWithFormat:@"%.3f + (%.3f - %.3f - %.3f + %.3f) * %.3f", [self mv], [self length], spacerThickness, casingThickness, [self mo], IN_to_MM];
    } else if ([@"3" isEqualToString:[self offsetSelector]]) {
        return [NSString stringWithFormat:@"%.3f + (%.3f - %.3f - %.3f) * %.3f", [self smr], [self length], spacerThickness, casingThickness, IN_to_MM];
    } else {
        return @"0.0";
    }
}

-(float)calculateOffsetAdjustment:(float)spacerThickness casingThickness:(float)casingThickness {
    if ([@"1" isEqualToString:[self offsetSelector]]) {
        return [self calcOffsetUsingHmf:spacerThickness casingThickness:casingThickness];
    } else if ([@"2" isEqualToString:[self offsetSelector]]) {
        return [self calcOffsetUsingSL:spacerThickness casingThickness:casingThickness];
    } else if ([@"3" isEqualToString:[self offsetSelector]]) {
        return [self calcOffsetUsingSMR:spacerThickness casingThickness:casingThickness];
    } else {
        return 0.0;
    }
}

-(float)calcOffsetUsingHmf:(float)spacerThickness casingThickness:(float)casingThickness {
    float offset = IN_to_MM * ([self hmf] - spacerThickness - casingThickness + [self mo]) - [self mv];
    NSLog(@"@calcOffsetUsingHmf: %f = %f * (%f - %f - %f + %f) - %f", offset, IN_to_MM, [self hmf], spacerThickness, casingThickness, [self mo], [self mv]);
    return offset;
}

-(float)calcOffsetUsingSL:(float)spacerThickness casingThickness:(float)casingThickness {
    float offset = [self mv] + ([self length] - spacerThickness - casingThickness + [self mo]) * IN_to_MM;
    NSLog(@"@calcOffsetUsingSL: %f = %f + (%f - %f - %f + %f) * %f", offset, [self mv], [self length], spacerThickness, casingThickness, [self mo], IN_to_MM);
    return offset;
}

-(float)calcOffsetUsingSMR:(float)spacerThickness casingThickness:(float)casingThickness {
    float offset = [self smr] + ([self length] - spacerThickness - casingThickness) * IN_to_MM;
    NSLog(@"@calcOffsetUsingSMR: %f = %f + (%f - %f - %f) * %f", offset, [self smr], [self length], spacerThickness, casingThickness, IN_to_MM);
    return offset;
}

@end
