// Sensor parameters (in mm).
sensor_data = {
    'smr':0.433,
    'sensor_length':8.922
};
frame_data = [
    {'frame':'6B',
     'stage':['8','13','17'],
     'position':{'8':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '13':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '17':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'8', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'2.538', 'color':'RED', 'image':'6B-R8-R13-R17'},
         {'stage':'13', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'2.538', 'color':'RED', 'image':'6B-R8-R13-R17'},
         {'stage':'17', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'2.538', 'color':'RED', 'image':'6B-R8-R13-R17'}
     ],
     'stage_info':{
         '8':{
             'RIGHT':['A', 13.0, 15.0, 0.93],
             'TOP':['B', 90.0, 90.0, 0.93],
             'LEFT':['C', 163.0, 165.0, 0.93],
             'BOTTOM':['D', 270.0, 270.0, 0.93],
             'blade_count':60,
             'tip_diameter':43.759,
             'blade_width':0.5
         },
         '13':{
             'RIGHT':['A', 16.0, 15.0, 0.93],
             'TOP':['B', 100.0, 100.0, 0.93],
             'LEFT':['C', 164.0, 165.0, 0.93],
             'BOTTOM':['D', 280.0, 280.0, 0.93],
             'blade_count':66,
             'tip_diameter':43.739,
             'blade_width':0.25
         },
         '17':{
             'RIGHT':['A', 16.0, 15.0, 0.93],
             'TOP':['B', 100.0, 100.0, 0.93],
             'LEFT':['C', 164.0, 165.0, 0.93],
             'BOTTOM':['D', 280.0, 280.0, 0.93],
             'blade_count':56,
             'tip_diameter':43.719,
             'blade_width':0.184
         },
     },
     'turning_gear_rpm':6.9,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'6FA',
     'stage':['2', '6', '10', '15'],
     'position':{'2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '6':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '10':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '15':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'2', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.43', 'color':'RED', 'image':'6FA-R2'},
         {'stage':'6', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.502', 'color':'BLUE', 'image':'6FA-R6'},
         {'stage':'10', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.178', 'color':'BLACK', 'image':'6FA-R10'},
         {'stage':'15', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.978', 'color':'GREEN', 'image':'6FA-R15'}
     ],
     'stage_info':{
         '2':{
             'RIGHT':['A', 10.0, 10.0, 2.038],
             'TOP':['B', 80.0, 80.0, 2.038],
             'LEFT':['C', 170.0, 170.0, 2.038],
             'BOTTOM':['D', 260.0, 260.0, 2.038],
             'blade_count':34,
             'tip_diameter':50.053,
             'blade_width':0.2
         },
         '6':{
             'RIGHT':['A', 10.0, 10.0, 1.966],
             'TOP':['B', 80.0, 80.0, 1.966],
             'LEFT':['C', 170.0, 170.0, 1.966],
             'BOTTOM':['D', 260.0, 260.0, 1.966],
             'blade_count':58,
             'tip_diameter':45.338,
             'blade_width':0.218
         },
         '10':{
             'RIGHT':['A', 10.0, 10.0, 2.29],
             'TOP':['B', 80.0, 80.0, 2.29],
             'LEFT':['C', 170.0, 170.0, 2.29],
             'BOTTOM':['D', 260.0, 260.0, 2.29],
             'blade_count':70,
             'tip_diameter':45.143,
             'blade_width':0.208
         },
         '15':{
             'RIGHT':['A', 10.0, 10.0, 2.49],
             'TOP':['B', 80.0, 80.0, 2.49],
             'LEFT':['C', 170.0, 170.0, 2.49],
             'BOTTOM':['D', 260.0, 260.0, 2.49],
             'blade_count':64,
             'tip_diameter':45.037,
             'blade_width':0.162
         },
     },
     'turning_gear_rpm':6.0,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'7E',
     'stage':['7', '12', '17'],
     'position':{'7':['TOP', 'BOTTOM', 'RIGHT', 'LEFT'],
                 '12':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '17':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'7', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'1.715', 'max':'1.815', 'size':'1.703', 'color':'RED', 'image':'7E-R7-1'},
         {'stage':'7', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'1.955', 'max':'2.055', 'size':'1.463', 'color':'BLUE', 'image':'7E-R7-2'},
         {'stage':'12', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.708', 'color':'BLACK', 'image':'7E-R12-R17'},
         {'stage':'17', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.708', 'color':'BLACK', 'image':'7E-R12-R17'}
     ],
     'stage_info':{
         '7':{
             'RIGHT':['A', 10.0, 10.0, 1.765],
             'TOP':['B', 90.0, 90.0, 1.765],
             'LEFT':['C', 170.0, 170.0, 1.765],
             'BOTTOM':['D', 270.0, 270.0, 1.765],
             'blade_count':58,
             'tip_diameter':62.51,
             'blade_width':0.26
         },
         '7':{
             'RIGHT':['A', 10.0, 10.0, 2.005],
             'TOP':['B', 90.0, 90.0, 2.005],
             'LEFT':['C', 170.0, 170.0, 2.005],
             'BOTTOM':['D', 270.0, 270.0, 2.005],
             'blade_count':58,
             'tip_diameter':62.005,
             'blade_width':0.26
         },
         '12':{
             'RIGHT':['A', 10.0, 10.0, 1.76],
             'TOP':['B', 90.0, 90.0, 1.76],
             'LEFT':['C', 170.0, 170.0, 1.76],
             'BOTTOM':['D', 270.0, 270.0, 1.76],
             'blade_count':56,
             'tip_diameter':62.44,
             'blade_width':0.404
         },
         '17':{
             'RIGHT':['A', 10.0, 10.0, 1.76],
             'TOP':['B', 90.0, 90.0, 1.76],
             'LEFT':['C', 170.0, 170.0, 1.76],
             'BOTTOM':['D', 270.0, 270.0, 1.76],
             'blade_count':56,
             'tip_diameter':62.44,
             'blade_width':0.404
         },
     },
     'turning_gear_rpm':0.3,
     'max_turn_time':25,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'quarter_turn'
    },
    {'frame':'7FA+e',
     'stage':['2', '5', '10', '17'],
     'position':{'2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '5':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '10':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '17':['TOP', 'TOP RIGHT', 'BOTTOM RIGHT', 'BOTTOM', 'BOTTOM LEFT', 'TOP LEFT']},
     'spacers':[
         {'stage':'2', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'2.668', 'max':'2.768', 'size':'0.75', 'color':'BLACK', 'image':'7FA-R2'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'1.337', 'max':'1.437', 'size':'2.0815', 'color':'BLACK', 'image':'7FA-R5-R10'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'1.59', 'max':'1.69', 'size':'1.828', 'color':'GREEN', 'image':'7FA-R5-2'},
         {'stage':'10', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'2.0815', 'color':'BLACK', 'image':'7FA-R5-R10'},
         {'stage':'17', 'position':['TOP RIGHT', 'TOP LEFT', 'BOTTOM LEFT', 'BOTTOM RIGHT'], 'min':'1.336', 'max':'1.436', 'size':'2.0815', 'color':'BLACK', 'image':'7FA-R5-R10'},
         {'stage':'17', 'position':['TOP RIGHT', 'TOP LEFT', 'BOTTOM LEFT', 'BOTTOM RIGHT'], 'min':'1.736', 'max':'1.836', 'size':'1.682', 'color':'BLACK', 'image':'7FA-R17'},
         {'stage':'17', 'position':['TOP RIGHT', 'TOP LEFT', 'BOTTOM LEFT', 'BOTTOM RIGHT'], 'min':'2.236', 'max':'2.336', 'size':'1.182', 'color':'GOLD', 'image':'7FA-R17-2'},
         {'stage':'17', 'position':['TOP', 'BOTTOM'], 'min':'1.336', 'max':'1.436', 'size':'2.0815', 'color':'BLACK', 'image':'7FA-R5-R10'},
         {'stage':'17', 'position':['TOP', 'BOTTOM'], 'min':'1.736', 'max':'1.836', 'size':'1.682', 'color':'BLACK', 'image':'7FA-R17'},
         {'stage':'17', 'position':['TOP', 'BOTTOM'], 'min':'2.236', 'max':'2.336', 'size':'1.182', 'color':'GOLD', 'image':'7FA-R17-2'},
         {'stage':'17', 'position':['TOP', 'BOTTOM'], 'min':'3.001', 'max':'3.101', 'size':'0.417', 'color':'SILVER', 'image':'7FA-R17-3'}
     ],
     'turning_gear_rpm':6.9,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'7FA.05',
     'stage':['1', '5', '9', '14'],
     'position':{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '5':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '9':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'1', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.617', 'color':'RED', 'image':'7FA05-R1'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.696', 'color':'BLUE', 'image':'7FA05-R5'},
         {'stage':'9', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.331', 'color':'BLACK', 'image':'7FA05-R9'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.297', 'color':'GREEN', 'image':'7FA05-R14'}
     ],
     'stage_info':{
         '1':{
             'RIGHT':['A', 7.931, 10.0, 2.851],
             'TOP':['B', 95.86, 90.0, 2.851],
             'LEFT':['C', 172.068, 170.0, 2.851],
             'BOTTOM':['D', 270.0, 270.0, 2.851],
             'blade_count':24,
             'tip_diameter':85.706,
             'blade_width':0.78
         },
         '5':{
             'RIGHT':['A', 10.0, 10.0, 2.772],
             'TOP':['B', 82.5, 80.0, 2.772],
             'LEFT':['C', 168.0, 170.0, 2.772],
             'BOTTOM':['D', 262.5, 260.0, 2.772],
             'blade_count':69,
             'tip_diameter':79.176,
             'blade_width':0.35
         },
         '9':{
             'RIGHT':['A', 31.5, 30.0, 3.137],
             'TOP':['B', 98.5, 100.0, 3.137],
             'LEFT':['C', 167.0, 165.0, 3.137],
             'BOTTOM':['D', 278.5, 280.0, 3.137],
             'blade_count':82,
             'tip_diameter':73.3,
             'blade_width':0.33
         },
         '14':{
             'RIGHT':['A', 345.0, 345.0, 3.171],
             'TOP':['B', 80.0, 80.0, 3.171],
             'LEFT':['C', 195.0, 195.0, 3.171],
             'BOTTOM':['D', 257.0, 255.0, 3.171],
             'blade_count':70,
             'tip_diameter':69.714,
             'blade_width':0.42
         },
     },
     'turning_gear_rpm':3,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'7FA.05-TEST',
     'stage':['1', '5', '9', '14'],
     'position':{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '5':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '9':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'1', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'4.554', 'color':'RED', 'image':'7FA05-R1'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'4.633', 'color':'BLUE', 'image':'7FA05-R5'},
         {'stage':'9', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'4.268', 'color':'BLACK', 'image':'7FA05-R9'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'3.937', 'color':'GREEN', 'image':'7FA05-R14'}
     ],
     'stage_info':{
         '1':{
             'RIGHT':['A', 7.931, 10.0, 2.851],
             'TOP':['B', 95.86, 90.0, 2.851],
             'LEFT':['C', 172.068, 170.0, 2.851],
             'BOTTOM':['D', 270.0, 270.0, 2.851],
             'blade_count':24,
             'tip_diameter':85.706,
             'blade_width':0.78
         },
         '5':{
             'RIGHT':['A', 10.0, 10.0, 2.772],
             'TOP':['B', 82.5, 80.0, 2.772],
             'LEFT':['C', 168.0, 170.0, 2.772],
             'BOTTOM':['D', 262.5, 260.0, 2.772],
             'blade_count':69,
             'tip_diameter':79.176,
             'blade_width':0.35
         },
         '9':{
             'RIGHT':['A', 31.5, 30.0, 3.137],
             'TOP':['B', 98.5, 100.0, 3.137],
             'LEFT':['C', 167.0, 165.0, 3.137],
             'BOTTOM':['D', 278.5, 280.0, 3.137],
             'blade_count':82,
             'tip_diameter':73.3,
             'blade_width':0.33
         },
         '14':{
             'RIGHT':['A', 345.0, 345.0, 3.171],
             'TOP':['B', 80.0, 80.0, 3.171],
             'LEFT':['C', 195.0, 195.0, 3.171],
             'BOTTOM':['D', 257.0, 255.0, 3.171],
             'blade_count':70,
             'tip_diameter':69.714,
             'blade_width':0.42
         },
     },
     'turning_gear_rpm':6.9,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'7FB',
     'stage':['2', '5', '11', '16', '17'],
     'position':{'2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '5':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '11':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '16':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '17':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'2', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.75', 'color':'RED', 'image':'7FB-R2'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.653', 'color':'BLUE', 'image':'7FB-R5'},
         {'stage':'11', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.871', 'color':'BLACK', 'image':'7FB-R11'},
         {'stage':'16', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.682', 'color':'GREEN', 'image':'7FB-R16-R17'},
         {'stage':'17', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.682', 'color':'GREEN', 'image':'7FB-R16-R17'}
     ],
     'stage_info':{
         '2':{
             'RIGHT':['A', 350.0, 350.0, 2.718],
             'TOP':['B', 80.0, 80.0, 2.718],
             'LEFT':['C', 170.0, 170.0, 2.718],
             'BOTTOM':['D', 260.0, 260.0, 2.718],
             'blade_count':34,
             'tip_diameter':73.294,
             'blade_width':0.3
         },
         '5':{
             'RIGHT':['A', 350.0, 350.0, 1.815],
             'TOP':['B', 80.0, 80.0, 1.815],
             'LEFT':['C', 170.0, 170.0, 1.815],
             'BOTTOM':['D', 260.0, 260.0, 1.815],
             'blade_count':46,
             'tip_diameter':66.049,
             'blade_width':0.38
         },
         '11':{
             'RIGHT':['A', 25.0, 25.0, 2.597],
             'TOP':['B', 115.0, 115.0, 2.597],
             'LEFT':['C', 205.0, 205.0, 2.597],
             'BOTTOM':['D', 295.0, 295.0, 2.597],
             'blade_count':70,
             'tip_diameter':65.511,
             'blade_width':0.36
         },
         '16':{
             'RIGHT':['A', 17.0, 15.0, 1.786],
             'LEFT':['B', 163.0, 165.0, 1.786],
             'blade_count':64,
             'tip_diameter':65.475,
             'blade_width':0.38
         },
         '17':{
             'TOP':['A', 100.0, 100.0, 1.786],
             'BOTTOM':['B', 280.0, 280.0, 1.786],
             'blade_count':60,
             'tip_diameter':65.513,
             'blade_width':0.365
         },
     },
     'turning_gear_rpm':6.0,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'7HA.01',
     'stage':['6', '10', '14'],
     'position':{'6':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '10':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'6', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'4.121', 'max':'4.221', 'size':'5.192', 'color':'BLUE', 'image':'7HA01-R6'},
         {'stage':'6', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'4.3', 'max':'4.4', 'size':'5.013', 'color':'BLUE', 'image':'7HA01-R6'},
         {'stage':'10', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'6.83', 'max':'6.93', 'size':'2.483', 'color':'BLACK', 'image':'7HA01-R11'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'4.191', 'max':'4.291', 'size':'5.122', 'color':'GREEN', 'image':'7HA01-R14'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'6.83', 'max':'6.93', 'size':'2.483', 'color':'GREEN', 'image':'7HA01-R14'}
     ],
     'turning_gear_rpm':6.9,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'7HA.02',
     'stage':['1', '6', '10', '14'],
     'position':{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '6':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '10':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'1', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'4.402', 'color':'RED', 'image':'7HA02-R1'},
         {'stage':'6', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'6.715', 'color':'BLUE', 'image':'7HA02-R6'},
         {'stage':'10', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'2.793', 'color':'BLACK', 'image':'7HA02-R11'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'4.159', 'max':'4.259', 'size':'5.154', 'color':'GREEN', 'image':'7HA02-R14'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'6.531', 'max':'6.631', 'size':'2.782', 'color':'GREEN', 'image':'7HA02-R14'}
     ],
     'turning_gear_rpm':6.9,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'9E',
     'stage':['1', '2', '8', '14', '17'],
     'position':{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '8':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '17':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'1', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.77', 'color':'RED', 'image':'9E-R1-R2'},
         {'stage':'2', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.77', 'color':'RED', 'image':'9E-R1-R2'},
         {'stage':'8', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.062', 'color':'BLUE', 'image':'9E-R8'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.22', 'color':'BLACK', 'image':'9E-R14-R17'},
         {'stage':'17', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.22', 'color':'BLACK', 'image':'9E-R14-R17'}
     ],
     'stage_info':{
         '1':{
             'RIGHT':['A', 350.0, 350.0, 2.698],
             'LEFT':['B', 190.0, 190.0, 2.698],
             'blade_count':32,
             'tip_diameter':84.967,
             'blade_width':0.305
         },
         '2':{
             'RIGHT':['A', 10.0, 10.0, 2.698],
             'TOP':['B', 90.0, 90.0, 2.698],
             'LEFT':['C', 170.0, 170.0, 2.698],
             'BOTTOM':['D', 270.0, 270.0, 2.698],
             'blade_count':32,
             'tip_diameter':81.436,
             'blade_width':0.373
         },
         '8':{
             'RIGHT':['A', 10.0, 10.0, 2.406],
             'TOP':['B', 90.0, 90.0, 2.406],
             'LEFT':['C', 170.0, 170.0, 2.406],
             'BOTTOM':['D', 270.0, 270.0, 2.406],
             'blade_count':60,
             'tip_diameter':74.412,
             'blade_width':0.423
         },
         '14':{
             'TOPRIGHT':['A', 10.0, 20.0, 2.248],
             'TOP':['B', 90.0, 90.0, 2.248],
             'TOPLEFT':['C', 170.0, 160.0, 2.248],
             'BOTTOMLEFT':['D', 190.0, 200.0, 2.248],
             'BOTTOM':['E', 270.0, 270.0, 2.248],
             'BOTTOMRIGHT':['F', 350.0, 340.0, 2.248],
             'blade_count':60,
             'tip_diameter':74.394,
             'blade_width':0.447
         },
         '17':{
             'TOPRIGHT':['A', 10.0, 20.0, 2.248],
             'TOP':['B', 90.0, 90.0, 2.248],
             'TOPLEFT':['C', 170.0, 160.0, 2.248],
             'BOTTOMLEFT':['D', 190.0, 200.0, 2.248],
             'BOTTOM':['E', 270.0, 270.0, 2.248],
             'BOTTOMRIGHT':['F', 350.0, 340.0, 2.248],
             'blade_count':56,
             'tip_diameter':74.358,
             'blade_width':0.559
         },
     },
     'turning_gear_rpm':0.05,
     'max_turn_time':90.0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'tenth_turn'
    },
    {'frame':'9FA',
     'stage':['2', '5', '10', '17'],
     'position':{'2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '5':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '10':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '17':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'2', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'6.127', 'color':'BLACK', 'image':'9FA-R2'},
         {'stage':'5', 'position':['LEFT', 'RIGHT'], 'min':'2.027', 'max':'2.127', 'size':'7.286', 'color':'BLACK', 'image':'9FA-R5LR'},
         {'stage':'5', 'position':['TOP', 'BOTTOM'], 'min':'2.027', 'max':'2.127', 'size':'3.624', 'color':'BLACK', 'image':'9FA-R5TB'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'2.273', 'max':'2.373', 'size':'7.04', 'color':'BLUE', 'image':'9FA-R5-2'},
         {'stage':'10', 'position':['LEFT', 'RIGHT'], 'min':'2.027', 'max':'2.127', 'size':'7.613', 'color':'BLACK', 'image':'9FA-R10LR'},
         {'stage':'10', 'position':['TOP', 'BOTTOM'], 'min':'2.027', 'max':'2.127', 'size':'0.75', 'color':'BLACK', 'image':'9FA-R10TB'},
         {'stage':'10', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'2.273', 'max':'2.373', 'size':'7.471', 'color':'GREEN', 'image':'9FA-R10-2'},
         {'stage':'17', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'2.273', 'max':'2.373', 'size':'7.04', 'color':'BLACK', 'image':'9FA-R17-1'},
         {'stage':'17', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'2.692', 'max':'2.792', 'size':'6.621', 'color':'RED', 'image':'9FA-R17-2'}
     ],
     'stage_info':{
         '2':{
             'RIGHT':['A', 10.0, 10.0, 3.236],
             'TOP':['B', 90.0, 90.0, 3.236],
             'LEFT':['C', 170.0, 170.0, 3.236],
             'BOTTOM':['D', 270.0, 270.0, 3.236],
             'blade_count':34,
             'tip_diameter':87.315,
             'blade_width':0.461
         },
         '5':{
             'RIGHT':['A', 15.0, 15.0, 2.077],
             'TOP':['B', 90.0, 90.0, 5.739],
             'LEFT':['C', 165.0, 165.0, 2.077],
             'BOTTOM':['D', 270.0, 270.0, 5.739],
             'blade_count':46,
             'tip_diameter':79.255,
             'blade_width':0.496
         },
         '5':{
             'RIGHT':['A', 15.0, 15.0, 2.323],
             'TOP':['B', 90.0, 90.0, 2.323],
             'LEFT':['C', 165.0, 165.0, 2.323],
             'BOTTOM':['D', 270.0, 270.0, 2.323],
             'blade_count':46,
             'tip_diameter':79.255,
             'blade_width':0.496
         },
         '10':{
             'RIGHT':['A', 15.0, 15.0, 1.75],
             'TOP':['B', 90.0, 90.0, 8.613],
             'LEFT':['C', 165.0, 165.0, 1.75],
             'BOTTOM':['D', 270.0, 270.0, 8.613],
             'blade_count':70,
             'tip_diameter':78.597,
             'blade_width':0.305
         },
         '10X':{
             'RIGHT':['A', 15.0, 15.0, 1.892],
             'TOP':['B', 90.0, 90.0, 1.892],
             'LEFT':['C', 165.0, 165.0, 1.892],
             'BOTTOM':['D', 270.0, 270.0, 1.892],
             'blade_count':70,
             'tip_diameter':78.597,
             'blade_width':0.305
         },
         '17':{
             'RIGHT':['A', 13.0, 13.0, 2.323],
             'TOP':['B', 90.0, 90.0, 2.323],
             'LEFT':['C', 167.0, 167.0, 2.323],
             'BOTTOM':['D', 270.0, 270.0, 2.323],
             'blade_count':60,
             'tip_diameter':78.549,
             'blade_width':0.446
         },
         '17X':{
             'RIGHT':['A', 13.0, 13.0, 2.742],
             'TOP':['B', 90.0, 90.0, 2.742],
             'LEFT':['C', 167.0, 167.0, 2.742],
             'BOTTOM':['D', 270.0, 270.0, 2.742],
             'blade_count':60,
             'tip_diameter':78.549,
             'blade_width':0.446
         },
     },
     'turning_gear_rpm':7.9,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'9FB',
     'stage':['2', '5', '11', '16', '17'],
     'position':{'2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '5':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '11':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '16':['RIGHT', 'LEFT'],
                 '17':['TOP', 'BOTTOM']},
     'spacers':[
         {'stage':'2', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.618', 'color':'RED', 'image':'9FB-R2'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.29', 'color':'BLUE', 'image':'9FB-R5'},
         {'stage':'11', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'0.618', 'color':'BLACK', 'image':'9FB-R11'},
         {'stage':'16', 'position':['RIGHT', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.322', 'color':'GREEN', 'image':'9FB-R16-R17'},
         {'stage':'17', 'position':['TOP', 'BOTTOM'], 'min':'0', 'max':'100', 'size':'1.322', 'color':'GREEN', 'image':'9FB-R16-R17'}
     ],
     'stage_info':{
         '2':{
             'RIGHT':['A', 10.0, 10.0, 2.85],
             'TOP':['B', 80.0, 80.0, 2.85],
             'LEFT':['C', 170.0, 170.0, 2.85],
             'BOTTOM':['D', 260.0, 260.0, 2.85],
             'blade_count':34,
             'tip_diameter':87.946,
             'blade_width':0.39
         },
         '5':{
             'RIGHT':['A', 10.0, 10.0, 2.178],
             'TOP':['B', 80.0, 80.0, 2.178],
             'LEFT':['C', 170.0, 170.0, 2.178],
             'BOTTOM':['D', 260.0, 260.0, 2.178],
             'blade_count':46,
             'tip_diameter':79.246,
             'blade_width':0.5
         },
         '11':{
             'RIGHT':['A', 25.0, 25.0, 2.85],
             'TOP':['B', 115.0, 115.0, 2.85],
             'LEFT':['C', 154.0, 155.0, 2.85],
             'BOTTOM':['D', 295.0, 295.0, 2.85],
             'blade_count':70,
             'tip_diameter':78.558,
             'blade_width':0.612
         },
         '16':{
             'RIGHT':['A', 17.0, 15.0, 2.146],
             'LEFT':['B', 163.0, 165.0, 2.146],
             'blade_count':64,
             'tip_diameter':78.605,
             'blade_width':0.367
         },
         '17':{
             'TOP':['A', 100.0, 100.0, 2.146],
             'BOTTOM':['B', 280.0, 280.0, 2.146],
             'blade_count':60,
             'tip_diameter':78.592,
             'blade_width':0.313
         },
     },
     'turning_gear_rpm':6.0,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
    },
    {'frame':'LMS',
     'stage':['0', '3', '5'],
     'position':{'0':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '5':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'0', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.728', 'color':'RED', 'image':'LMS-R0'},
         {'stage':'3', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.468', 'color':'BLUE', 'image':'LMS-R3'},
         {'stage':'5', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.168', 'color':'BLACK', 'image':'LMS-R5'}
     ],
     'stage_info':{
         '0':{
             'RIGHT':['A', 14.06, 15.0, 1.74],
             'TOP':['B', 81.56, 90.0, 1.74],
             'LEFT':['C', 165.94, 165.0, 1.74],
             'BOTTOM':['D', 265.49, 270.0, 1.74],
             'blade_count':32,
             'tip_diameter':84.967,
             'blade_width':0.305
         },
         '3':{
             'RIGHT':['A', 10.0, 10.0, 2.0],
             'TOP':['B', 80.0, 90.0, 2.0],
             'LEFT':['C', 170.0, 170.0, 2.0],
             'BOTTOM':['D', 260.0, 270.0, 2.0],
             'blade_count':32,
             'tip_diameter':84.967,
             'blade_width':0.305
         },
         '5':{
             'RIGHT':['A', 13.0, 13.0, 2.3],
             'TOP':['B', 80.0, 90.0, 2.3],
             'LEFT':['C', 170.0, 170.0, 2.3],
             'BOTTOM':['D', 260.0, 270.0, 2.3],
             'blade_count':32,
             'tip_diameter':84.967,
             'blade_width':0.305
         }
     },
     'turning_gear_rpm':6.9,
     'max_turn_time':0,
     'rotor_mode':'rotating',
     'measure_mode':'dynamic',
     'option':'full_turn'
   },
    {'frame':'9HA.01',
     'stage':['1', '6', '10', '14'],
     'position':{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '6':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '10':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'1', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'6.028', 'color':'RED', 'image':'9HA01-R1'},
         {'stage':'6', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'4.281', 'color':'BLUE', 'image':'9HA01-R6'},
         {'stage':'10', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'1.533', 'color':'BLACK', 'image':'9HA01-R11'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'3.575', 'color':'GREEN', 'image':'9HA01-R14'}
     ]
    },
    {'frame':'9HA.02',
     'stage':['1', '6', '11', '14'],
     'position':{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '6':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '11':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
                 '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']},
     'spacers':[
         {'stage':'1', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'4.221', 'color':'RED', 'image':'9HA02-R1'},
         {'stage':'6', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'5.541', 'color':'BLUE', 'image':'9HA02-R6'},
         {'stage':'11', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'6.154', 'color':'BLACK', 'image':'9HA02-R11'},
         {'stage':'14', 'position':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'], 'min':'0', 'max':'100', 'size':'6.156', 'color':'GREEN', 'image':'9HA02-R14'}
     ]
    }
];
