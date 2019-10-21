
var menu_open = false;
var e4PtSocket = null;
var WebSocket = WebSocket;
var clientID = 312;
var e4pt = null;

var Data_Set = function() {
    this.stage = null;
    this.location = null;
    this.case_thickness = null;
    this.pts = null;
    this.clearance = null;
    this.quality = null;
};

Data_Set.prototype.add_data = function(stage, location, case_thickness, blade_number, pts, used_in_avg, clearance, quality) {
    this.stage = stage;
    this.location = location;
    this.case_thickness = case_thickness;
    this.pts = pts;
    this.clearance = clearance;
    this.quality = quality;
};

var E4PTdata = {
    "ofs_id": "",
    "frame":"",
    "serial_number":"",
    "data_name":"",
    "description":"",
    "customer":"",
    "site_name":"",
    "inspection_type":"",
    "sso":"",
    "final":{
        "SCAN":"",
    },
    "date": "",
    "sets":[],
    "locs":[],
    "minima":[],
    "clearance":"",
    "alreadyOnLDB":"false"
}

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const position_angle = {'TOP':0, 'BOTTOM':180, 'LEFT':270, 'RIGHT':90,
                        'TOP LEFT':315, 'BOTTOM LEFT':225, 'TOP RIGHT':45, 'BOTTOM RIGHT':135};

// Positions should be listed clockwise, starting at the top.
var frame_data = [
    {frame:'6B',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'6FA',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'7E',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'7FA',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'7FA.05',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'TOP RIGHT', 'BOTTOM RIGHT', 'BOTTOM', 'BOTTOM LEFT', 'TOP LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'9E',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'LMS',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'7HA',
     stage:['1', '2', '3', '4'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '2':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '3':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '4':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}},
    {frame:'9HA',
     stage:['1', '6', '11', '14'],
     position:{'1':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '6':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '11':['TOP', 'RIGHT', 'BOTTOM', 'LEFT'],
               '14':['TOP', 'RIGHT', 'BOTTOM', 'LEFT']}}
];
var current_stage_index = 0;
var current_stage = 0;
var current_position_index = 0;
var current_position = 0;
var current_frame_data = [];

$(document).ready(function(){	
    var attachFastClick = Origami.fastclick;
    attachFastClick(document.body);
    //document.getElementById("DATA_PLOT").addEventListener('click', function(){
    //    toggle_menu();
    //}, {passive: true})
    document.getElementById("MAIN_MENU").addEventListener('click', function(){
        $("#TITLE_BAR").text("e-4Pt Tool")
	$("#FRD_PAGE").fadeOut();
	$("#SETUP_PAGE").fadeOut();
	$("#SCAN_INFO_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#FILE_LOADING_PAGE").fadeOut();
        $("#DB_LOADING_PAGE").fadeOut();
        $("#SENSOR_SETUP_PAGE").fadeOut();
        $("#INITIALIZE_SENSOR_PAGE").fadeOut();        
        $("#TURBINE_SETUP_PAGE").fadeOut();
        toggle_menu();
		
    }, {passive: true})
    document.getElementById("FRD_BUTTON").addEventListener('click', function(){
        toggle_menu();
	$("#DATA_PLOT").fadeOut();
        $("#FRD_PAGE").fadeIn();
    }, {passive: true})
    document.getElementById("SETUP_BUTTON").addEventListener('click', function(){
        toggle_menu();
	$("#DATA_PLOT").fadeOut();
        $("#SETUP_PAGE").fadeIn();
        set_frame_information();
    }, {passive: true})
    document.getElementById("SENSOR_SETUP_BUTTON").addEventListener('click', function(){
        $("#SETUP_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#DATA_PLOT").fadeOut();
        $("#SENSOR_SETUP_PAGE").fadeIn();
	setMasterMessage("white","green","Ready");
    }, {passive: true})
    document.getElementById("SN_SUBMIT_BUTTON").addEventListener('click', function(){
        $("#SETUP_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#DATA_PLOT").fadeOut();
        $("#INITIALIZE_SENSOR_PAGE").fadeIn();
        initialize_sensor();
    }, {passive: true})
    document.getElementById("COLLECT_DATA_BUTTON").addEventListener('click', function(){
        $("#SETUP_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#DATA_PLOT").fadeOut();
        $("#INITIALIZE_SENSOR_PAGE").fadeOut();
        $("#TURBINE_SETUP_PAGE").fadeIn();
        turbine_setup();
    }, {passive: true})
    

    function RESULTS_BUTTON_FUNC(){
        getCredentialforREST();
        toggle_menu()
        if ($("#TITLE_BAR").text() != "RESULTS"){
            $("#TITLE_BAR").text("RESULTS")
        }
        createTable()
        $("#RESULTS_PAGE").fadeIn()
    }
    //document.getElementById("OPEN_EXTERNAL_FILE_BUTTON").addEventListener('change', function(){
    //    loadExternalFile();
    //}, {passive: true})
    //document.getElementById("OPEN_EXTERNAL_FILE_BUTTON").addEventListener('click', function(){
    //    document.getElementById("OPEN_EXTERNAL_FILE_BUTTON").value =null;
    //}, {passive: true})
    document.getElementById("OPEN_BUTTON_DEVICE").addEventListener('click', function(){
        try {
            listInternalFile();
            SELECTED_FILE = "";
            toggle_menu();
            if ($("#TITLE_BAR").text() != "OPEN FROM DEVICE"){
                $("#TITLE_BAR").text("OPEN FROM DEVICE")
            }
            $("#FILE_LOADING_PAGE").fadeIn()
        } catch (err) {
            $("#OPEN_EXTERNAL_FILE_BUTTON").trigger("click")
            $("#OPEN_EXTERNAL_FILE_BUTTON").trigger("change")
            toggle_menu();
        }
    }, {passive: true})
    document.getElementById("CONNECT_WS_BUTTON").addEventListener('click', function(){
        toggle_menu();
        connectWebSocket();
    }, {passive: true})
    document.getElementById("SHUTDOWN_BUTTON").addEventListener('click', function(){
        toggle_menu();
        systemShutdown();
    }, {passive: true})
    document.getElementById("GET_DATA_BUTTON").addEventListener('click', function(){
        toggle_menu();
        $("#DATA_PLOT").fadeIn();        
        var acquisitionTime = window.prompt("Please enter the acquisition time in seconds.", "15");
        if (acquisitionTime != null) {
          requestE4PtData(acquisitionTime);
        }
    }, {passive: true})
    document.getElementById("SENSOR_SETUP_BUTTON").addEventListener('click', function(){
        toggle_menu();
        sensor_setup();
    }, {passive: true})
    document.getElementById("START_MASTER_BUTTON").addEventListener('click', function(){
	do_mastering();
    }, {passive: true})
    document.getElementById("START_MASTER_BUTTON_2").addEventListener('click', function(){
	do_mastering();
    }, {passive: true})
    document.getElementById("START_DARK_REFERENCE_BUTTON").addEventListener('click', function(){
	do_dark_reference();
    }, {passive: true})
    document.getElementById("DOWNLOAD_FILE_BUTTON").addEventListener('click', function(){
        toggle_menu();
	doFileDownload();
    }, {passive: true})
    document.getElementById("STAGE_COLLECT_BUTTON").addEventListener('click', function(){
        collect_stage_data();
    }, {passive: true})
    document.getElementById("COLLECTION_RESET_BUTTON").addEventListener('click', function(){
        reset_data_collection();
    }, {passive: true})
    document.getElementById("SENSOR_STAGE").addEventListener('change', function(){
        setup_data_collection();
    }, {passive: true})
    
    setupAccordian()
})

function setupAccordian(){
    var acc = $(".ACCORDION");
    var i;
    for (i = 0; i < acc.length; i++) {
      acc[i].onclick = function() {
        this.classList.toggle("active");
        var PANEL = this.nextElementSibling;
        if (PANEL.style.maxHeight){
          PANEL.style.maxHeight = null;
        } else {
          PANEL.style.maxHeight = PANEL.scrollHeight + "px";
        } 
      }
    }
}

function toggle_menu() {
	if (menu_open){
		$('#LEFT_MENU').animate({"margin-left": '-=25vmin'});
		menu_open = false;
	}
	else{
		$('#LEFT_MENU').animate({"margin-left": '+=25vmin'});
		menu_open = true;
	}
}

function sensor_setup() {
    console.log("@sensor_setup")
    $("#FRD_PAGE").fadeOut();
    $("#SETUP_PAGE").fadeOut();
    $("#SCAN_INFO_PAGE").fadeOut();
    $("#RESULTS_PAGE").fadeOut();
    $("#FILE_LOADING_PAGE").fadeOut();
    $("#DB_LOADING_PAGE").fadeOut();
    $("#SENSOR_SETUP_PAGE").fadeIn();
    $("#TURBINE_SETUP_PAGE").fadeOut();
}

function initialize_sensor() {
    console.log("@initialize_sensor")
    setMasterMessage2("white", "green", "Ready");
    var frm_idx = document.getElementById("FRAME_SIZE").selectedIndex;    
    E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
    E4Ptdata.frame = frame_data[frm_idx]['frame'];
}

function turbine_setup() {

    // Get frame type
    var frm_idx = document.getElementById("FRAME_SIZE").selectedIndex;
    current_frame_data = frame_data[frm_idx];

    reset_data_collection();

    // Setup the Stage options
    html_buf = [];
    var stages = current_frame_data['stage'];
    for (stage_index = 0; stage_index < stages.length; stage_index++) {
        html_buf.push("<option value='" + stages[stage_index] + "'>" + stages[stage_index] + "</option>");
    }
    html = html_buf.join('\n')
    document.getElementById("SENSOR_STAGE").innerHTML = html;
    current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
    current_stage = stages[current_stage_index];

    // Setup the position options
    html_buf = [];
    var positions = current_frame_data['position'];
    positions = positions[current_stage];
    for (position_index = 0; position_index < positions.length; position_index++) {
        html_buf.push("<option value='" + positions[position_index] + "'>" + positions[position_index] + "</option>");
    }
    html = html_buf.join('\n')
    document.getElementById("SENSOR_POSITION").innerHTML = html;
    current_position_index = 0;
}

function set_frame_information() {
    var html_buf = [];
    var frmIdx = 0;
    for (frmIdx = 0; frmIdx < frame_data.length; frmIdx++) {
        html_buf.push("<option value='" + frame_data[frmIdx]['frame'] + "'>" + frame_data[frmIdx]['frame'] + "</option>");
    }
    var html = html_buf.join('\n');
    document.getElementById("FRAME_SIZE").innerHTML = html;
}

function set_position_information() {
    var html_buf = [];
    var html = html_buf.join('\n');
    var positions = current_frame_data['position'];
    positions = positions[current_stage];
    var posIdx = 0;
    for (posIdx = 0; posIdx < positions.length; posIdx++) {
        html_buf.push("<option value='" + positions[posIdx] + "'>" + positions[posIdx] + "</option>");
    }
    var html = html_buf.join('\n');
    document.getElementById("SENSOR_POSITION").innerHTML = html;
}

function collect_stage_data() {
    // Make sure the plot doesn't show on screen
    var position = document.getElementById("SENSOR_POSITION").value;
    var stage = document.getElementById("SENSOR_STAGE").value;
    var boxID = position + stage;
    boxID = boxID.replace(/\s+/g, '_');
    //console.log("updating box with element id: ", boxID);

    current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
    current_stage = current_frame_data['stage'][current_stage_index];
    current_position_index =  document.getElementById("SENSOR_POSITION").selectedIndex;
    current_position = current_frame_data['position'][current_stage][current_position_index];

    // Collect data from the sensor.
    var acquisitionTime = window.prompt("Please enter the acquisition time in seconds.", "3");
    if (acquisitionTime != null) {
        //requestE4PtData(acquisitionTime);
        var sn = document.getElementById("SERIAL_NUMBER").value;
        var frame = document.getElementById("FRAME_SIZE").value;
        var casing_thickness = document.getElementById("CASING_THICKNESS").value;
        requestE4PtDataWithMetaData(acquisitionTime, frame, sn, current_stage, current_position, casing_thickness);
    }
}

function setup_data_collection() {
    current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
    current_stage = current_frame_data['stage'][current_stage_index];
    current_position_index = 0
    current_position = current_frame_data['position'][current_stage][current_position_index];
    setup_data_collection_page();
}

function reset_data_collection() {
    current_stage_index = 0;
    current_stage = current_frame_data['stage'][current_stage_index];
    current_position_index = 0
    current_position = current_frame_data['position'][current_stage][current_position_index];
    document.getElementById("CASING_THICKNESS").value = "";
    setup_data_collection_page();
}

function setup_data_collection_page() {
    // Fill in the header
    E4PTdata.frame = document.getElementById("FRAME_SIZE").value;
    E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
    var header = "Frame: " + E4PTdata.frame + "; S/N: " + E4PTdata.serial_number;
    document.getElementById("TURBINE_SETUP_HEADER").innerHTML = header;

    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
    var html_buf = [];
    var stage_index = 0;
    var position_index = 0;

    // Setup the data tables.  We use different tables for each stage because
    // the number of positions for each stage could be different.
    var stages = current_frame_data['stage'];
    html_buf.push("<tr class=\"sensor_super_tr\">"); // The sub-tables all go in one row in the super-table
    for (stage_index = 0; stage_index < stages.length; stage_index++) {
        var stage = stages[stage_index];
        var positions = current_frame_data['position'][stage];
        html_buf.push("<td class=\"sensor_super_td\"><table class=\"sensor_sub_table\">");
        var header_row = "<tr class=\"sensor_super_tr\"><td>POSITION</td><td>";
        header_row = header_row + "STAGE " + stages[stage_index];
        header_row = header_row + "</td></tr>";
        html_buf.push(header_row);
        for (position_index = 0; position_index < positions.length; position_index++) {
            html_buf.push("<tr><td>" + positions[position_index] + "</td>");
            var el_id = positions[position_index] + stages[stage_index];
            el_id = el_id.replace(/\s+/g, '_');
            html_buf.push("<td id='" + el_id + 
                          "' onclick='set_grid_position(\"" + positions[position_index] + 
                          "\", \"" + stages[stage_index] + 
                          "\")'></td>");
            html_buf.push("</tr>");
        }
        html_buf.push("</table></td>");
    }
    html_buf.push("</tr>");
    html = html_buf.join('\n')
    document.getElementById("SENSOR_DATA_TABLE").innerHTML = html;

    // Update the positions selector based on the current stage.
    var positions = current_frame_data['position'];
    positions = positions[current_stage];
    for (position_index = 0; position_index < positions.length; position_index++) {
        html_buf.push("<option value='" + positions[position_index] + "'>" + positions[position_index] + "</option>");
    }
    html = html_buf.join('\n')
    document.getElementById("SENSOR_POSITION").innerHTML = html;
    current_position_index = 0;
}

function advance_position() {
    // Auto-advance
    var stages = current_frame_data['stage'];
    var positions = current_frame_data['position'][current_stage];
    //console.log("@advance_position");
    //console.log("stages:  ", stages);
    //console.log("positions: ", positions);

    current_position_index = (current_position_index + 1) % positions.length;
    current_position = positions[current_position_index]
    if (current_position_index == 0) {
        current_stage_index = (current_stage_index + 1) % stages.length;
        current_stage = stages[current_stage_index]
        set_position_information()
    }
    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
}

function set_grid_position(position, stage) {
    //console.log("@set_grid_position: pos: ", position, "; stage: ", stage);
    var stages = current_frame_data['stage'];
    var positions = current_frame_data['position'][stage];
    current_position_index = positions.indexOf(position);
    current_stage_index = stages.indexOf(stage);
    current_stage = stages[current_stage_index];
    current_position = positions[current_position_index];
    set_position_information();
    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
    var el_id = current_position + current_stage;
    el_id = el_id.replace(/\s+/g, '_');
    var clearance = document.getElementById(el_id).innerHTML;
    clearance = parseFloat(clearance);
    update_clearance(clearance);
}

function do_dark_reference() {
    console.log("@do_dark_reference");
    sendWSMessage('do_dark_reference');
    $("#SENSOR_SETUP_PAGE").fadeOut();
    $("#RESULTS_PAGE").fadeIn();
    $("#DATA_PLOT").fadeIn();
}

function do_mastering() {
    console.log("@do_mastering");
    sendWSMessage('do_mastering');
    setMasterMessage("black","yellow","In Progress...");
    setMasterMessage2("black","yellow","In Progress...");
    setIndicatorColor("red");    
}

function done_mastering() {
    setMasterMessage("white","green","Mastering complete.");
    setMasterMessage2("white","green","Mastering complete.");
    setIndicatorColor("green");
}

function failed_mastering() {
    setMasterMessage("black","red","Mastering failed.");
    setMasterMessage2("black","red","Mastering failed.");    
    setIndicatorColor("green");
}

function systemShutdown() {
  console.log("@systemShutdown");
  sendWSMessage('shutdown');
}

function doFileDownload() {
    console.log("@doFileDownload");
    sendWSMessage('get_data_file');
}

// alert function to work on iOS and web browser
function e4PtAlert(msg, callback=null){
    try{
        navigator.notification.alert(
            String(msg),            // message
            callback,               // callback
            '',                     // no title
            'OK'                    // buttonName
        );
    } catch (err){
        alert(String(msg));
    }               
}

// confirm function to work on iOS and web browser
function e4PtConfirm(msg, callback){
    try{
        navigator.notification.confirm(
            String(msg),            // message
            callback,               // callback to invoke with index of button pressed
            '',                     // no title
            ['OK','Cancel']         // buttonLabels: 1=OK, 2=Cancel
        );
    } catch (err){
        if(confirm(String(msg))){
            callback(1);//OK
        } else {
            callback(2);//Cancel
        }
    }   
}

function connectWebSocket() {
 
  try {
    console.log("Connecting to WebSocket server.");
    //e4PtSocket = new WebSocket("ws://192.168.7.77:3405");
    e4PtSocket = new WebSocket("ws://127.0.0.1:3405"); // Local testing
    //e4PtSocket = new WebSocket("ws://192.168.168.41:3405"); // E4Pt sys.
  } catch (err) {
    console.log("Error connecting to WebSocket server");
  }
  if (e4PtSocket == null) return;

  e4PtSocket.onopen = function(evt) {
    console.log("e4PtSocket Opened: ");
    console.log("evt: " + evt);
    setIndicatorColor("green");
    //setTimeout(function(){ sendWSMessage("ping"); }, 5000); // ping after 5s
  }
 
  e4PtSocket.onclose = function(evt) {
    console.log("e4PtSocket Closed: ", evt);
    setIndicatorColor("white");
  }

  e4PtSocket.onerror = function(evt) {
    console.log("e4PtSocket error: ",evt);
    setIndicatorColor("white");
  }

  e4PtSocket.onmessage = function(evt) {
    var msg = JSON.parse(evt.data);
    console.log("e4PtSocket Message Received: " + msg.type);
    switch(msg.type) {
    case "data":
      console.log("Received Data Message");
      setIndicatorColor("green");
      document.getElementById("CASING_THICKNESS").value = "";
      //console.log(msg);
      processE4PtData(msg);
      break;
    case "status":
      console.log("Received Status Message");
      console.log(msg);
      if (msg.status == "acquiring") {
          setIndicatorColor("red");
      }
      if (msg.status == "processing") {
          setIndicatorColor("blue");
      }
      if (msg.status == "done_mastering") {
	  done_mastering();
      }
      if (msg.status == "failed_mastering") {
	  failed_mastering();
      }
      break;
    case "pong":
      console.log("Got pong. Send ping.");
      setTimeout(function(){ sendWSMessage("ping"); }, 5000); // ping after 5s
      break;
    case "filename":
	console.log("Got filename: " + msg.fname);
	if (msg.fname.length == 0) {
	    console.log("No filename: returning");
	    return;
	}
	window.open(msg.fname); // Try to open/download the file.
    }
      
  }
}

function setIndicatorColor( color ) {
    document.getElementById("indicator-pulse").style.background = color;
    document.getElementById("indicator-solid").style.background = color;
}

function setMasterMessage( txtColor, bgColor, txt ) {
    document.getElementById("master_message").style.color = txtColor;
    document.getElementById("master_message").style.background = bgColor;
    document.getElementById("master_message").value = txt;
}

function setMasterMessage2( txtColor, bgColor, txt ) {
    document.getElementById("master_message_2").style.color = txtColor;
    document.getElementById("master_message_2").style.background = bgColor;
    document.getElementById("master_message_2").value = txt;
}

function processE4PtData(msg) {
  console.log("@processE4PtData");
  try {
    $.extend(E4PTdata, msg);
  } catch (err) {
    console.log(err);
  }
  dataSet = E4PTdata.sets.length;
  
  try {
    update_scan_info();
    parse_data();
    plot_data();
    plot_data_2();
    advance_position();
  } catch (error) {
    console.log(error);
  }      
}

function requestE4PtData(acquisitionTime) {
  console.log("Requesting " + acquisitionTime + " seconds of data");
  if (Highcharts.charts.series != null) {
    while(Highcharts.chart.series.length > 0)
      Highcharts.chart.series[0].remove(true);
  }
  message = "send_data," + acquisitionTime;
  sendWSMessage(message);
}

function requestE4PtDataWithMetaData(acquisitionTime, frame, sn, stage, position, casing_thickness) {
    console.log("Requesting " + acquisitionTime + " seconds of data");
    console.log("Meta data: " + frame + "; " + sn + "; " + stage + "; " + position);
    frame = frame.replace(/\s+/g, '_'); // replace all the spaces with underscores
    sn = sn.replace(/\s+/g, '_');
    stage = stage.replace(/\s+/g, '_');    
    position = position.replace(/\s+/g, '_');
    casing_thickness = casing_thickness.replace(/\s+/g, '_');
    var message = "send_data," + acquisitionTime + "," + frame + "," + sn + "," + stage + "," + position + "," + casing_thickness;
    sendWSMessage(message);
}

function sendWSMessage(msg_text) {
  console.log("@sendWSMessage: " + msg_text);
  var msg = {
  text: msg_text,
  type: "message",
  id: clientID,
  date: Date.now()
  }
  if (msg_text.indexOf('send_data') >= 0) {
      setIndicatorColor("yellow");
  }
  if (msg_text = 'do_dark_reference') {
      setIndicatorColor("yellow");
  }
  e4PtSocket.send(JSON.stringify(msg));
}

function update_scan_info(){
  var tempDate = new Date();
  tempDate = String(tempDate.getDate()+"-"+monthNames[tempDate.getMonth()]+"-"+tempDate.getFullYear())
    if (tempDate.indexOf("undefined")>0 || tempDate.indexOf("NaN")>=0 ){
      tempDate ="";
    } else {
      tempDate = "Date: " + String(tempDate);
      E4PTdata.date = tempDate;
      console.log(tempDate);
    }
  // Do something else with the data...
}

function parse_data() {
  var minima = new Array(E4PTdata.locs.length);
  for (var i=0; i<E4PTdata.locs.length; i++) {
    minima[i] = [E4PTdata.locs[i], E4PTdata.gaps[i]];
  }
    E4PTdata.minima = minima;
    console.log("Clearance average: ", E4PTdata.clearance);
    update_clearance(E4PTdata.clearance);
    //var set = new DataSet();
    //set.stage = current_stage;
    //set.location = current_position;
    //set.case_thickness = document.getElementById("CASING_THICKNESS").value;
    //set.clearance = E4PTdata.clearance;
    //set.pts = E4PTdata.data;
    //set.quality = E4PTdata.intensity;
    E4PTdata.frame = document.getElementById("FRAME_SIZE").value;
    E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
    //E4PTdata.sets = E4PTdata.sets.push(set);
}

function update_clearance(clearance) {
    if (current_frame_data.length == 0) {
        return;
    }
    var stage = current_frame_data['stage'][current_stage_index];
    var position = current_frame_data['position'][stage][current_position_index];
    var el_id = position + stage;
    el_id = el_id.replace(/\s+/g, '_');
    var clearance_f = parseFloat(clearance.toFixed(4))
    if (isNaN(clearance_f)) {
        document.getElementById(el_id).innerHTML = "";        
    }
    else {
        document.getElementById(el_id).innerHTML = clearance_f;
    }
    
    clearances = [];
    for (var i=0; i<current_frame_data['position'][stage].length; i++) {
        var p = current_frame_data['position'][stage][i];
        var angle = position_angle[p];
        var el_id = p + stage;
        el_id = el_id.replace(/\s+/g, '_');
        var c = document.getElementById(el_id).innerHTML;
        var c_f = parseFloat(c);
        if (isNaN(c_f)) {
            clearances.push("");
        }
        else {
            clearances.push(c_f);
        }
    }
    plot_clearances(clearances);
}

function plot_data() {
  console.log("@e4pt_app::plot_data()");
  Highcharts.chart('DATA_PLOT', {
    chart: {
      renderTo: 'DATA_PLOT',
      spacingBottom: 0,
      spacingTop: 80,
      spacingLeft: 80,
      spacingRight: 80,
      marginBottom: 100,
      marginTop: 80,
      marginLeft: 80,
      marginRight: 80,
      backgroundColor: 'white',
      animation: false,
      //zoomType: "x",
      //margin: 0,
      padding: 0
    },
    boost: {
      enabled: true,
      //seriesThreshold: 1,
      useGPUTranslations: true,
      allowForce: true
    },
    title: {
      text: 'e-4Pt Acquired Data'
    },
    style: {
      fontFamily: 'Veranda'
    },
    subtitle: {
      text: E4PTdata.date
    },
    yAxis: {
      title: {
        text: 'Blade Gap'
      },
      labels: {
        style: {
        color: 'black',
        fontSize: 10
        }
      }
    },
    xAxis: {
      title: {
        text: 'Index'
            },
      labels: {
        style: {
        color: 'black',
        fontSize: 10
        }
      }
    },
    legend: {
      enabled: 'false',
    },
    tooltip: {
      enabled: false
    },
    pane: {
      startAngle: 0
    },
    plotOptions: {
      series: {
        label: { connectorAllowed: false },
            pointStart: 0
      }
    },
    series: [
      {
        type: 'line',
        name: 'Confocal Sensor',
        data: E4PTdata.data
      },
      {
        type: 'scatter',
        name: 'Gap Minima',
        data: E4PTdata.minima
      }
    ],
    responsive: {
      rules: [{
        condition: { maxWidth: 1000 }
      }]
    }
  });
}

function plot_data_2() {
  console.log("@e4pt_app::plot_data_2()");
  Highcharts.chart('DATA_PLOT2', {
    chart: {
      renderTo: 'DATA_PLOT2',
      spacingBottom: 0,
      spacingTop: 80,
      spacingLeft: 80,
      spacingRight: 80,
      marginBottom: 100,
      marginTop: 80,
      marginLeft: 80,
      marginRight: 80,
      backgroundColor: 'white',
      animation: false,
      //zoomType: "x",
      //margin: 0,
      padding: 0
    },
    boost: {
      enabled: true,
      //seriesThreshold: 1,
      useGPUTranslations: true,
      allowForce: true
    },
    title: {
      text: 'e-4Pt Acquired Data'
    },
    style: {
      fontFamily: 'Veranda'
    },
    subtitle: {
      text: E4PTdata.date
    },
    yAxis: {
      title: {
        text: 'Blade Gap'
      },
      labels: {
        style: {
        color: 'black',
        fontSize: 10
        }
      }
    },
    xAxis: {
      title: {
        text: 'Index'
            },
      labels: {
        style: {
        color: 'black',
        fontSize: 10
        }
      }
    },
    legend: {
      enabled: 'false',
    },
    tooltip: {
      enabled: false
    },
    pane: {
      startAngle: 0
    },
    plotOptions: {
      series: {
        label: { connectorAllowed: false },
            pointStart: 0
      }
    },
    series: [
      {
        type: 'line',
        name: 'Confocal Sensor',
        data: E4PTdata.data
      },
      {
        type: 'scatter',
        name: 'Gap Minima',
        data: E4PTdata.minima
      }
    ],
    responsive: {
      rules: [{
        condition: { maxWidth: 1000 }
      }]
    }
  });
}

function plot_clearances(clearance_data) {
  console.log("@e4pt_app::plot_clearances()");
  var pt_interval = 360.0/clearance_data.length;
  Highcharts.chart('CLEARANCE_PLOT', {
    chart: {
      renderTo: 'CLEARANCE_PLOT',
      spacingBottom: 0,
      spacingTop: 80,
      spacingLeft: 80,
      spacingRight: 80,
      marginBottom: 100,
      marginTop: 80,
      marginLeft: 80,
      marginRight: 80,
      backgroundColor: 'white',
      animation: false,
      //zoomType: "x",
      //margin: 0,
      padding: 0,
      polar: true
    },
    boost: {
      enabled: true,
      //seriesThreshold: 1,
      useGPUTranslations: true,
      allowForce: true
    },
    title: {
      text: 'e-4Pt Clearance Data'
    },
    style: {
      fontFamily: 'Veranda'
    },
    subtitle: {
      text: E4PTdata.date
    },
    yAxis: {
      min: 0,
      title: {
        text: 'Clearance'
      },
      labels: {
        style: {
        color: 'black',
        fontSize: 10
        }
      }
    },
      xAxis: {
      tickInterval: pt_interval,
      min: 0,
      max: 360,
      title: {
        text: 'Position'
            },
      labels: {
        style: {
        color: 'black',
        fontSize: 10
        },
        format: '{value}°'
      }
    },
    legend: {
      enabled: 'false',
    },
    tooltip: {
      enabled: false
    },
    pane: {
      startAngle: 0,
      endAngle: 360
    },
    plotOptions: {
      series: {
        label: { connectorAllowed: false },
          pointStart: 0,
          pointInterval: pt_interval
      },
      column: {
          pointPadding: 0,
          groupPadding: 0
      }
    },
    series: [
      {
        type: 'line',
        name: 'Clearances',
        data: clearance_data
      },
    ],
    responsive: {
      rules: [{
        condition: { maxWidth: 1000 }
      }]
    }
  });
}

function loadExternalFile(){
    var input = $('#OPEN_EXTERNAL_FILE_BUTTON');
    
    if (typeof window.FileReader !== 'function') {
        e4PtAlert("The file API isn't supported on this browser yet.");
        return;
    }

    if (!input) {
        e4PtAlert("Couldn't find the fileinput element.");
        return;
    }
    else if (!input.prop('files')) {
        e4PtAlert("This browser doesn't seem to support the `files` property of file inputs.");
        return;
    }
    else if (!input.prop('files')[0]) {
        e4PtAlert("Please select a file before clicking 'Load'");
        return;
    }
        
    if (E4PTdata.sets.length > 1) {
        e4PtConfirm("LOADING A NEW DATA SET WILL OVERWRITE IN-MEMORY DATA\n\nProceed to load this file?", function(buttonIndex) {
            if (buttonIndex==1){//OK
                loadThisFile();
            } else if (buttonIndex==2){//Cancel
                document.getElementById("OPEN_EXTERNAL_FILE_BUTTON").value =null;
            }
        });
    } else {
        loadThisFile();
    }    
    

    function loadThisFile(){
        var file = input.prop('files')[0];
        var freader = new FileReader();
        freader.onload = receivedText;
        freader.readAsText(file);
    } 

    function receivedText(e) {
        var lines = e.target.result;
        try {
            $.extend(E4PTdata, JSON.parse(lines));
        } catch (err) {
            console.log(err);
        }
        dataSet = E4PTdata.sets.length;
        
        try {
          update_scan_info();
          parse_data();
          plot_data();
          plot_data_2();
          advance_position();            
        } catch (error) {
          console.log(error);
        }

        console.log("Data Loaded from an external file");
        $("#FILE_LOADING_PAGE").fadeOut()
        if ($("#TITLE_BAR").text() != "DATA"){
            $("#TITLE_BAR").text("DATA")
        }
        
        $("#RESULTS_PAGE").fadeIn()
    }
}

function doSSO() {
  console.log("@doSSO");
  var authServerUri = "https://fssfed.ge.com/fss/as/authorization.oauth2?response_type=code&scope=openid+profile&client_id=GEPW_FFA_TRACC_01&redirect_uri=TRaCC://authorization_grant/";
  //var authServerUri = "https://fssfed.ge.com/fss/as/authorization.oauth2";
  var authParams = {
    response_type: "code",
    scope: "openid+profile",
    client_id: "GEPW_FFA_TRACC_01",
    redirect_uri: "TRaCC://authorization_grant/"
  }
  // Redirect to Authorization page.
  //var replacementUri = authServerUri + "?" + $.param(authParams);
  var replacementUri = authServerUri;
  console.log("replacementUri: " + replacementUri);
  window.location.replace(replacementUri);
}
