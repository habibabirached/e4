var sensorSettings;

beforeEach(() => {
  sensorSettings = require('../sensor_settings.js');
  sensorSettings.set('sensor_selection', '');
  sensorSettings.set('sensor_length', 0);
  sensorSettings.set('start_measurement_range', 0);
  sensorSettings.set('master_fixture_height', 0);
  sensorSettings.set('mastering_value', 0);
  sensorSettings.set('master_offset', 0);
});

test('mastering tolerance is 0.003 inches', () => {
  expect(sensorSettings.mastering_tolerance).toBeCloseTo(0.003 * 25.4, 5);
});

test('converts inches to millimeters', () => {
  expect(sensorSettings.toMMs(1)).toBeCloseTo(25.4, 2);
});

test('converts millimeters to inches', () => {
  expect(sensorSettings.toInches(25.4)).toBe(1);
});

test('calculates mastering offset', () => {
  expect(sensorSettings.calculateMasteringOffsetInches(9.5, 11.9, 0.2, 2.3)).toBeCloseTo(0.1, 2);
});

test('calculates mastering value', () => {
  expect(sensorSettings.calculateMasteringValueMM(9.5, 11.9)).toBeCloseTo(60.96, 3);
});

test('parametersHaveBeenEdited returns true for CUSTOM', () => {
  expect(sensorSettings.sensorParamsHaveBeenEdited('CUSTOM')).toBeTruthy();
});

test('saves type settings for CUSTOM type', () => {
    var defaultSensorType = sensorSettings.getSensorType('CUSTOM');
    
    sensorSettings.set('sensor_selection','CUSTOM');
    sensorSettings.set('sensor_length',8);
    sensorSettings.set('start_measurement_range',12);
    sensorSettings.set('master_fixture_height',11);
    sensorSettings.set('mastering_value',5);
    sensorSettings.saveValuesForSensorType();
    var sensorType = sensorSettings.getSensorType('CUSTOM');
    
    expect(sensorType).not.toEqual(defaultSensorType);
    expect(sensorType.measured_length_mm).toBe(sensorSettings.toMMs(8));
    expect(sensorType.measured_mastering_fixture_height_mm).toBe(sensorSettings.toMMs(11));
    expect(sensorType.measured_start_measurment_range_mm).toBe(12);
    expect(sensorType.measured_mastering_value_mm).toBe(5);
});

test('does not save type settings for non CUSTOM type', () => {
    [{name:'LONG',length:5,smr:7,mfh:11,mv:4.9},
     {name:'SHORT',length:3,smr:5,mfh:9,mv:4.32},
     {name:'PROTOTYPE',length:7,smr:12,mfh:10,mv:4.5}].forEach(sensor => {
        var defaultSensorType = sensorSettings.getSensorType(sensor.name);
        
        sensorSettings.set('sensor_selection',sensor.name);
        sensorSettings.set('sensor_length',sensor.length);
        sensorSettings.set('start_measurement_range',sensor.smr);
        sensorSettings.set('master_fixture_height',sensor.mfh);
        sensorSettings.set('mastering_value',sensor.mv);
        sensorSettings.saveValuesForSensorType();
        var sensorType = sensorSettings.getSensorType(sensor.name);
        
        expect(sensorType.measured_length_mm).not.toBe(sensorSettings.toMMs(sensor.length));
        expect(sensorType.measured_length_mm).toBe(defaultSensorType.measured_length_mm);
        expect(sensorType.measured_mastering_fixture_height_mm).not.toBe(sensorSettings.toMMs(sensor.mfh));
        expect(sensorType.measured_mastering_fixture_height_mm).toBe(defaultSensorType.measured_mastering_fixture_height_mm);
        expect(sensorType.measured_start_measurment_range_mm).not.toBe(sensor.smr);
        expect(sensorType.measured_start_measurment_range_mm).toBe(defaultSensorType.measured_start_measurment_range_mm);
        expect(sensorType.measured_mastering_value_mm).not.toBe(sensor.mv);
        expect(sensorType.measured_mastering_value_mm).toBe(defaultSensorType.measured_mastering_value_mm);
    });
});
