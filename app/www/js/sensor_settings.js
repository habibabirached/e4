if (typeof define !== 'function') {
    var define = require('./lib/amdefine')(module);
}

define(function(require, exports, module) {
                
    const mmPerInch = 25.4;
    const mastering_tolerance = 0.0762; // mm
    const sensor_data = {
        sensor_selection: '',
        sensor_length: 0, //in
        start_measurement_range: 0, //mm
        sensor_mr: 0, //mm
        master_fixture_height: 0, //in
        mastering_value: 0, //mm
        master_offset: 0 //in
    };
    const sensor_types = {
        'LONG': {'measured_length_mm': 224.164, 'measured_mastering_fixture_height_mm': 240.3602, 'measured_start_measurement_range_mm': 11.94, 'measured_mastering_value_mm': 4.2567, 'measurement_range_mm': 11.0},
        'SHORT': {'measured_length_mm': 75.667, 'measured_mastering_fixture_height_mm': 90.6272, 'measured_start_measurement_range_mm': 11.94, 'measured_mastering_value_mm': 3.0205, 'measurement_range_mm': 11.0},
        'PROTOTYPE': {'measured_length_mm': 226.898, 'measured_mastering_fixture_height_mm': 243.0018, 'measured_start_measurement_range_mm': 10.998, 'measured_mastering_value_mm': 5.1054, 'measurement_range_mm': 10.0},
        'CUSTOM': {}
    };
    
    const toInches = (mms) => {
        return mms / mmPerInch;
    }
    
    const toMMs = (inches) => {
        return inches * mmPerInch;
    }
    
    const get = (sensor_attr) => {
        return sensor_data[sensor_attr];
    }
    
    const set = (sensor_attr, attr_val) => {
        sensor_data[sensor_attr] = attr_val;
    }
    
    const getSensorType = (sensorType) => {
        return {...sensor_types[sensorType]};
    }
    
    const doesMeasurementExceedTolerance = (measurement) => {
        return Math.round(Math.abs(measurement - get('mastering_value'))*10000)/10000 > mastering_tolerance;
    }

    const saveValuesForSensorType = () => {
        if (sensor_data.sensor_selection === 'CUSTOM') {
            sensor_types[sensor_data.sensor_selection].measured_length_mm = toMMs(sensor_data.sensor_length);
            sensor_types[sensor_data.sensor_selection].measured_mastering_fixture_height_mm = toMMs(sensor_data.master_fixture_height);
            sensor_types[sensor_data.sensor_selection].measured_start_measurement_range_mm = sensor_data.start_measurement_range;
            sensor_types[sensor_data.sensor_selection].measurement_range_mm = sensor_data.sensor_mr;
            sensor_types[sensor_data.sensor_selection].measured_mastering_value_mm = sensor_data.mastering_value;
        }
    }
                                                  
    const calculateMasteringOffsetInches = (lengthIn, heightIn, masteringValueMM, smrMM) => {
        return (lengthIn + toInches(smrMM + masteringValueMM)) - heightIn;
    }
    
    const calculateMasteringValueMM = (lengthIn, heightIn, smrMM) => {
        return toMMs(heightIn - lengthIn) - smrMM;
    }
                                           
    const sensorParamsHaveBeenEdited = () => {
        if (sensor_data.sensor_selection === 'LONG' || sensor_data.sensor_selection === 'SHORT' || sensor_data.sensor_selection === 'PROTOTYPE') {
            return sensorLengthHasBeenEdited() || smrHasBeenEdited() || mrHasBeenEdited() || mfhHasBeenEdited() || mvHasBeenEdited() || moHasBeenEdited();
        }
        return sensor_data.sensor_selection === 'CUSTOM';
    }
      
    const sensorLengthHasBeenEdited = () => {
        return sensor_data.sensor_selection != '' && !almostEqual(sensor_data.sensor_length, toInches(sensor_types[sensor_data.sensor_selection].measured_length_mm), 0.0005);
    }
                            
    const smrHasBeenEdited = () => {
        return sensor_data.sensor_selection != '' && !almostEqual(sensor_data.start_measurement_range, sensor_types[sensor_data.sensor_selection].measured_start_measurement_range_mm, 0.0001);
    }
    
    const mrHasBeenEdited = () => {
        return sensor_data.sensor_selection != '' && !almostEqual(sensor_data.sensor_mr, sensor_types[sensor_data.sensor_selection].measurement_range_mm, 0.0001);
    }
                            
    const mfhHasBeenEdited = () => {
        return sensor_data.sensor_selection != '' && !almostEqual(sensor_data.master_fixture_height, toInches(sensor_types[sensor_data.sensor_selection].measured_mastering_fixture_height_mm), 0.0005);
    }

    const mvHasBeenEdited = () => {
        return sensor_data.sensor_selection != '' && !almostEqual(sensor_data.mastering_value,
                            calculateMasteringValueMM(
                                sensor_data.sensor_length,
                                sensor_data.master_fixture_height,
                                sensor_data.start_measurement_range),
                            0.0001);
    }
                            
    const moHasBeenEdited = () => {
        return sensor_data.sensor_selection != '' && !almostEqual(sensor_data.master_offset,
                            calculateMasteringOffsetInches(
                                sensor_data.sensor_length,
                                sensor_data.master_fixture_height,
                                sensor_data.mastering_value,
                                sensor_data.start_measurement_range),
                            0.0005);
    }
                            
    const almostEqual = (num1, num2, tolerance) => {
        return Math.abs(num1 - num2) < tolerance;
    }
    
    const parseAndSetSensorValue = (varName, value) => {
        sensor_data[varName] = JSON.parse(value);
        return sensor_data[varName].toFixed(4).toString(10);
    }
        
    module.exports = {
        toMMs: toMMs,
        toInches: toInches,
        get: get,
        set: set,
        getSensorType: getSensorType,
        doesMeasurementExceedTolerance: doesMeasurementExceedTolerance,
        saveValuesForSensorType: saveValuesForSensorType,
        calculateMasteringOffsetInches: calculateMasteringOffsetInches,
        calculateMasteringValueMM: calculateMasteringValueMM,
        sensorParamsHaveBeenEdited: sensorParamsHaveBeenEdited,
        sensorLengthHasBeenEdited: sensorLengthHasBeenEdited,
        smrHasBeenEdited: smrHasBeenEdited,
        mrHasBeenEdited: mrHasBeenEdited,
        mfhHasBeenEdited: mfhHasBeenEdited,
        mvHasBeenEdited: mvHasBeenEdited,
        moHasBeenEdited: moHasBeenEdited,
        parseAndSetSensorValue: parseAndSetSensorValue
    }
});
