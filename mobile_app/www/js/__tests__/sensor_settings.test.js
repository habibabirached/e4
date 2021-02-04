var sensorSettings;

beforeEach(() => {
  sensorSettings = require('../sensor_settings.js');
  sensorSettings.set('sensor_selection', '');
  sensorSettings.set('sensor_length', 0);
  sensorSettings.set('start_measurement_range', 0);
  sensorSettings.set('sensor_mr', 0);
  sensorSettings.set('master_fixture_height', 0);
  sensorSettings.set('mastering_value', 0);
  sensorSettings.set('master_offset', 0);
});

test('converts inches to millimeters', () => {
  expect(sensorSettings.toMMs(1)).toBeCloseTo(25.4, 2);
});

test('converts millimeters to inches', () => {
  expect(sensorSettings.toInches(25.4)).toBe(1);
});

test('calculates mastering offset', () => {
  expect(sensorSettings.calculateMasteringOffsetInches(8.825, 9.463, 4.265, 11.94)).toBeCloseTo(0, 4);
});

test('calculates mastering value', () => {
  expect(sensorSettings.calculateMasteringValueMM(8.825, 9.463, 11.94)).toBeCloseTo(4.265, 3);
});

test('determines if measurement is within tolerance', () => {
  expect(sensorSettings.doesMeasurementExceedTolerance(0.07624)).toBeFalsy();
  expect(sensorSettings.doesMeasurementExceedTolerance(-0.07624)).toBeFalsy();
  expect(sensorSettings.doesMeasurementExceedTolerance(0.07625)).toBeTruthy();
  expect(sensorSettings.doesMeasurementExceedTolerance(-0.07625)).toBeTruthy();
  sensorSettings.set('mastering_value', 5);
  expect(sensorSettings.doesMeasurementExceedTolerance(5.07624)).toBeFalsy();
  expect(sensorSettings.doesMeasurementExceedTolerance(4.92376)).toBeFalsy();
  expect(sensorSettings.doesMeasurementExceedTolerance(5.0762501)).toBeTruthy();
  expect(sensorSettings.doesMeasurementExceedTolerance(4.9237499)).toBeTruthy();
});

test('parametersHaveBeenEdited returns true for CUSTOM', () => {
  sensorSettings.set('sensor_selection', 'CUSTOM');
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeTruthy();
});

test('*BeenEdited returns false when no sensor has been selected yet', () => {
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeFalsy();
  expect(sensorSettings.sensorLengthHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.smrHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.mrHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.mfhHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.mvHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.moHasBeenEdited()).toBeFalsy();
});

test('*BeenEdited returns false if value is close to type definition value', () => {
  sensorSettings.set('sensor_selection', 'LONG');
  sensorSettings.set('sensor_length', 8.8258);
  sensorSettings.set('start_measurement_range', 11.94009);
  sensorSettings.set('sensor_mr', 11.00009);
  sensorSettings.set('master_fixture_height', 9.4635);
  sensorSettings.set('mastering_value', 4.2574);
  sensorSettings.set('master_offset', -0.0005);
    
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeFalsy();
  expect(sensorSettings.sensorLengthHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.smrHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.mrHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.mfhHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.mvHasBeenEdited()).toBeFalsy();
  expect(sensorSettings.moHasBeenEdited()).toBeFalsy();
});

test('*BeenEdited returns true if value is not close to type definition value', () => {
  sensorSettings.set('sensor_selection', 'LONG');
  sensorSettings.set('sensor_length', 8.825);
  sensorSettings.set('start_measurement_range', 11.94);
  sensorSettings.set('start_measurement_range', 11.0);
  sensorSettings.set('master_fixture_height', 9.463);
  sensorSettings.set('mastering_value', 4.2652);
  sensorSettings.set('master_offset', 0);
    
  sensorSettings.set('sensor_length', 8.8259);
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeTruthy();
  expect(sensorSettings.sensorLengthHasBeenEdited()).toBeTruthy();
    
  sensorSettings.set('sensor_length', 8.825);
  sensorSettings.set('start_measurement_range', 11.94011);
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeTruthy();
  expect(sensorSettings.smrHasBeenEdited()).toBeTruthy();
    
  sensorSettings.set('start_measurement_range', 11.94);
  sensorSettings.set('sensor_mr', 11.00011);
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeTruthy();
  expect(sensorSettings.mrHasBeenEdited()).toBeTruthy();
    
  sensorSettings.set('sensor_mr', 11.0);
  sensorSettings.set('master_fixture_height', 9.4636);
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeTruthy();
  expect(sensorSettings.mfhHasBeenEdited()).toBeTruthy();
    
  sensorSettings.set('master_fixture_height', 9.463);
  sensorSettings.set('mastering_value', 4.265);
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeTruthy();
  expect(sensorSettings.mvHasBeenEdited()).toBeTruthy();
    
  sensorSettings.set('mastering_value', 4.2652);
  sensorSettings.set('master_offset', 0.0005);
  expect(sensorSettings.sensorParamsHaveBeenEdited()).toBeTruthy();
  expect(sensorSettings.moHasBeenEdited()).toBeTruthy();
});

test('saves type settings for CUSTOM type', () => {
    var defaultSensorType = sensorSettings.getSensorType('CUSTOM');
    
    sensorSettings.set('sensor_selection','CUSTOM');
    sensorSettings.set('sensor_length',8);
    sensorSettings.set('start_measurement_range',12);
    sensorSettings.set('sensor_mr',9);
    sensorSettings.set('master_fixture_height',11);
    sensorSettings.set('mastering_value',5);
    sensorSettings.saveValuesForSensorType();
    var sensorType = sensorSettings.getSensorType('CUSTOM');
    
    expect(sensorType).not.toEqual(defaultSensorType);
    expect(sensorType.measured_length_mm).toBe(sensorSettings.toMMs(8));
    expect(sensorType.measured_mastering_fixture_height_mm).toBe(sensorSettings.toMMs(11));
    expect(sensorType.measured_start_measurement_range_mm).toBe(12);
    expect(sensorType.measurement_range_mm).toBe(9);
    expect(sensorType.measured_mastering_value_mm).toBe(5);
});

test('does not save type settings for non CUSTOM type', () => {
    [{name:'LONG',length:5,smr:7,mr:6,mfh:11,mv:4.9},
     {name:'SHORT',length:3,smr:5,mr:7,mfh:9,mv:4.32},
     {name:'PROTOTYPE',length:7,smr:12,mr:9.9,mfh:10,mv:4.5}].forEach(sensor => {
        var defaultSensorType = sensorSettings.getSensorType(sensor.name);
        
        sensorSettings.set('sensor_selection',sensor.name);
        sensorSettings.set('sensor_length',sensor.length);
        sensorSettings.set('start_measurement_range',sensor.smr);
        sensorSettings.set('sensor_mr',sensor.mr);
        sensorSettings.set('master_fixture_height',sensor.mfh);
        sensorSettings.set('mastering_value',sensor.mv);
        sensorSettings.saveValuesForSensorType();
        var sensorType = sensorSettings.getSensorType(sensor.name);
        
        expect(sensorType.measured_length_mm).not.toBe(sensorSettings.toMMs(sensor.length));
        expect(sensorType.measured_length_mm).toBe(defaultSensorType.measured_length_mm);
        expect(sensorType.measured_mastering_fixture_height_mm).not.toBe(sensorSettings.toMMs(sensor.mfh));
        expect(sensorType.measured_mastering_fixture_height_mm).toBe(defaultSensorType.measured_mastering_fixture_height_mm);
        expect(sensorType.measured_start_measurement_range_mm).not.toBe(sensor.smr);
        expect(sensorType.measured_start_measurement_range_mm).toBe(defaultSensorType.measured_start_measurement_range_mm);
        expect(sensorType.measurement_range_mm).not.toBe(sensor.mr);
        expect(sensorType.measurement_range_mm).toBe(defaultSensorType.measurement_range_mm);
        expect(sensorType.measured_mastering_value_mm).not.toBe(sensor.mv);
        expect(sensorType.measured_mastering_value_mm).toBe(defaultSensorType.measured_mastering_value_mm);
    });
});
