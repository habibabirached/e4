
var menu_open = false;
var e4PtSocket = null;
var clientID = 312;
var e4pt = null;
var MAX_STR_LEN = 64;
var downloadFileName = "";
var fsRoot = "";
var appDir = "";
var serialConnected = false;
var doDBSave = false;
var manualOverride = false;

var local_db = new PouchDB('e4ptdb');

var communicationChannel = "Plugin"; // "WebSocket" or "Plugin"

// Replace with remote instance when we get to that point.
//var remoteCouch = 'http://xxx.xxx.xxx.xxx/remote_e4ptdb';

var Data_Set = function() {
    this.stage = null;
    this.position = null;
    this.case_thickness = null;
    //this.pts = null;
    this.clearance = null;
    this.max_clr = null;
    this.min_clr = null;
    this.med_clr = null;
    this.std_clr = null;
    this.quality = null;
    this.state = null;
};

Data_Set.prototype.add_data = function(state, stage, position, case_thickness, blade_number, pts, used_in_avg, clearance, max_clr, min_clr, med_clr, std_clr, quality) {
    this.stage = stage;
    this.position = position;
    this.case_thickness = case_thickness;
    //this.pts = pts;
    this.clearance = clearance;
    this.max_clr = max_clr;
    this.min_clr = min_clr;
    this.med_clr = med_clr;
    this.std_clr = std_clr;
    this.quality = quality;
    this.state = state;
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
    "operator":"",
    "units":"",
    "state":"",
    "final":{
        "SCAN":"",
    },
    "date": "",
    "time": "",
    "sets":[],
    "locs":[],
    "minima":[],
    "data":[],
    "quality":[],
    "clearance":"",
    "max_clr":"",
    "min_clr":"",
    "med_clr":"",
    "std_clr":"",
    "alreadyOnLDB":"false",
    "pouchdb_id": ""
};

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const position_angle = {'TOP':0, 'BOTTOM':180, 'LEFT':270, 'RIGHT':90,
                        'TOP LEFT':315, 'BOTTOM LEFT':225, 'TOP RIGHT':45, 'BOTTOM RIGHT':135};
var current_stage_index = 0;
var current_stage = 0;
var current_position_index = 0;
var current_position = 0;
var current_frame_data = [];

$(document).ready(function(){
    var attachFastClick = Origami.fastclick;
    attachFastClick(document.body);
    document.getElementById("MAIN_MENU").addEventListener('click', function(){
              $("#TITLE_BAR").text("e-4Pt Tool");
	      $("#FRD_PAGE").fadeOut();
	      $("#SETUP_PAGE").fadeOut();
	      $("#SCAN_INFO_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#FILE_LOADING_PAGE").fadeOut();
        $("#DB_LOADING_PAGE").fadeOut();
        $("#SENSOR_SETUP_PAGE").fadeOut();
        $("#INITIALIZE_SENSOR_PAGE").fadeOut();
        $("#TURBINE_SETUP_PAGE").fadeOut();
        $("#LOCAL_DATA_PAGE").fadeOut();
        $("#FILE_CHOOSER_PAGE").fadeOut();
        $("#DATA_DETAILS_PAGE").fadeOut();
        toggle_menu();
    }, {passive: true});
    document.getElementById("FRD_BUTTON").addEventListener('click', function(){
        toggle_menu();
	$("#DATA_PLOT").fadeOut();
        $("#FRD_PAGE").fadeIn();
    }, {passive: true});
    document.getElementById("SETUP_BUTTON").addEventListener('click', function(){
        toggle_menu();
	      $("#DATA_PLOT").fadeOut();
        $("#SETUP_PAGE").fadeIn();
        set_frame_information();
    }, {passive: true});
    document.getElementById("SENSOR_SETUP_BUTTON").addEventListener('click', function(){
        $("#SETUP_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#DATA_PLOT").fadeOut();
        $("#LOCAL_DATA_PAGE").fadeOut();
        $("#SENSOR_SETUP_PAGE").fadeIn();
	      setMasterMessage("white","green","Ready");
    }, {passive: true});
    document.getElementById("SN_SUBMIT_BUTTON").addEventListener('click', function(){
        $("#SETUP_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#DATA_PLOT").fadeOut();
        $("#INITIALIZE_SENSOR_PAGE").fadeIn();
        $("#LOCAL_DATA_PAGE").fadeOut();
        send_scan_meta_data();
        initialize_sensor();
    }, {passive: true});
    document.getElementById("COLLECT_DATA_BUTTON").addEventListener('click', function(){
        $("#SETUP_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#DATA_PLOT").fadeOut();
        $("#INITIALIZE_SENSOR_PAGE").fadeOut();
        $("#LOCAL_DATA_PAGE").fadeOut();
        turbine_setup(true);
    }, {passive: true});
    document.getElementById("CLEAR_DB_BUTTON").addEventListener('click', function(){
        e4PtConfirm("Are you sure you want to clear all data from this database?",
          function(idx) {
            if (idx == 1) {
              console.log("Clearing database.");
              clearDB();
            }
            else {
              console.log("Database clear was cancelled.");
            }
          });
    }, {passive: true});

    function RESULTS_BUTTON_FUNC(){
        getCredentialforREST();
        toggle_menu();
        if ($("#TITLE_BAR").text() != "RESULTS"){
            $("#TITLE_BAR").text("RESULTS");
        }
        createTable();
        $("#RESULTS_PAGE").fadeIn();
    }
    document.getElementById("OPEN_LOCAL_DATA").addEventListener('click', function(){
       $("#DATA_PLOT").fadeOut();
        try {
            set_frame_information();
            listInternalFiles();
            SELECTED_FILE = "";
            toggle_menu();
            if ($("#TITLE_BAR").text() != "OPEN FROM DEVICE"){
                $("#TITLE_BAR").text("OPEN FROM DEVICE");
            }
            $("#LOCAL_DATA_PAGE").fadeIn();
        } catch (err) {
            console.log("Error getting local files.");
            console.log(err);
            toggle_menu();
        }
    }, {passive: true});
    document.getElementById("SHUTDOWN_BUTTON").addEventListener('click', function(){
        toggle_menu();
        systemShutdown();
    }, {passive: true});
    document.getElementById("GET_DATA_BUTTON").addEventListener('click', function(){
        console.log("@GET_DATA_BUTTON event listener function.");
        toggle_menu();
        $("#DATA_PLOT").fadeIn();
        var acquisitionTime = null;
        doDBSave = false;
        console.log("@GET_DATA_BUTTON: Prompting.");
        var nav = navigator.notification;
        if (nav != null) {
            // We have plugins so we're in Cordova.  Use the Cordova notification.
            console.log("@GET_DATA_BUTTON: Cordova Prompt");
            navigator.notification.prompt('Please enter the acquisition time in seconds.',
                                          acquisitionTimePromptCallback,
                                          'Acquisition Time',
                                          ['Ok','Cancel'],
                                          '3');
        }
        else {
            // No plugins, so we must not be in Cordova. Use a standard prompt.
            console.log("@GET_DATA_BUTTON: Windows Prompt");
            acquisitionTime = window.prompt("Please enter the acquisition time in seconds.", "3");
            acquisitionTimePromptCallback({"input1":acquisitionTime});
        }
    }, {passive: true});
    document.getElementById("SENSOR_SETUP_BUTTON").addEventListener('click', function(){
        toggle_menu();
        sensor_setup();
    }, {passive: true});
    document.getElementById("START_MASTER_BUTTON").addEventListener('click', function(){
	do_mastering();
    }, {passive: true});
    document.getElementById("START_MASTER_BUTTON_2").addEventListener('click', function(){
	do_mastering();
    }, {passive: true});
    document.getElementById("START_DARK_REFERENCE_BUTTON").addEventListener('click', function(){
	do_dark_reference();
    }, {passive: true});
    document.getElementById("SET_MEASUREMENT_RATE_BUTTON").addEventListener('click', function(){
    set_measurement_rate("1");
    }, {passive: true});
    document.getElementById("SET_THRESHOLD_BUTTON").addEventListener('click', function(){
    set_threshold();
    }, {passive: true});
    document.getElementById("DOWNLOAD_FILE_BUTTON_01").addEventListener('click', function(){
    toggle_menu();
    listDir(cordova.file.documentsDirectory + "data");
    }, {passive: true});
    document.getElementById("DOWNLOAD_FILE_BUTTON_02").addEventListener('click', function(){
    listDir(cordova.file.documentsDirectory + E4PTdata.serial_number);
    }, {passive: true});
    document.getElementById("STAGE_COLLECT_BUTTON").addEventListener('click', function(){
    collect_stage_data();
    }, {passive: true});
    document.getElementById("COLLECTION_RESET_BUTTON").addEventListener('click', function(){
        reset_data_collection();
    }, {passive: true});
    document.getElementById("CUSTOMER_REPORT_BUTTON").addEventListener('click', function(){
        generate_customer_report();
    }, {passive: true});
    document.getElementById("SENSOR_STAGE").addEventListener('change', function(){
        set_stage();
    }, {passive: true});
    document.getElementById("SENSOR_POSITION").addEventListener('change', function(){
        set_position();
    }, {passive: true});
    document.getElementById("CASING_THICKNESS").addEventListener('change', function(){
        update_spacer_value();
    }, {passive: true});
    document.getElementById("MODE_BUTTON_PROD").addEventListener('click', function(){
        document.getElementById('MODE_BUTTON_PROD').style.display = 'none'; //hide
        document.getElementById('MODE_BUTTON_DEMO').style.display = 'block';
        $("#MODE_INDICATOR").css("color", "red");
        $("#MODE_NAME").text('DEMO');
        $("#CUR_MODE").text('Current Mode: DEMO');
        document.getElementById('MODE_NAME').style.fontSize = "2vmin";
        document.getElementById('MODE_NAME').style.display = 'block';
        document.getElementById('MODE_INDICATOR').style.display = 'block';
        set_demo_mode("true");
    }, {passive: true});
    document.getElementById("MODE_BUTTON_DEMO").addEventListener('click', function(){
        document.getElementById('MODE_BUTTON_DEMO').style.display = 'none'; //hide
        document.getElementById('MODE_BUTTON_PROD').style.display = 'block';
        $("#MODE_INDICATOR").css("color", "limeGreen");
        $("#MODE_NAME").text('PROD');
        $("#CUR_MODE").text('Current Mode: PRODUCTION');
        document.getElementById('MODE_NAME').style.display = 'none';
        document.getElementById('MODE_INDICATOR').style.display = 'none';
        set_demo_mode("false");
    }, {passive: true});
    document.getElementById("CONN_BUTTON_ETHERNET").addEventListener('click', function(){
        document.getElementById('CONN_BUTTON_ETHERNET').style.display = 'none'; //hide
        document.getElementById('CONN_BUTTON_SERIAL').style.display = 'block';
        $("#CONNECTION_NAME").text('ETHERNET');
        $("#CUR_CONN").text('Current Connection: ETHERNET');
        document.getElementById('CONNECTION_NAME').style.fontSize = "2vmin";
        document.getElementById('CONNECTION_NAME').style.display = 'block';
        set_connection_mode("ethernet");
    }, {passive: true});
    document.getElementById("CONN_BUTTON_SERIAL").addEventListener('click', function(){
        document.getElementById('CONN_BUTTON_SERIAL').style.display = 'none'; //hide
        document.getElementById('CONN_BUTTON_ETHERNET').style.display = 'block';
        $("#CONNECTION_NAME").text('SERIAL');
        $("#CUR_CONN").text('Current Connection: SERIAL');
        document.getElementById('CONNECTION_NAME').style.fontSize = "2vmin";
        document.getElementById('CONNECTION_NAME').style.display = 'block';
        set_connection_mode("serial");
    }, {passive: true});
    document.getElementById("SETUP_CLOSE_BUTTON").addEventListener('click', function(){
        $("#FRD_PAGE").fadeOut();
    }, {passive: true});
    document.getElementById("SETUP_CLOSE_BUTTON2").addEventListener('click', function(){
        $("#INITIALIZE_SENSOR_PAGE").fadeOut();
    }, {passive: true});
    document.getElementById("SETUP_CLOSE_BUTTON3").addEventListener('click', function(){
        $("#SENSOR_SETUP_PAGE").fadeOut();
    }, {passive: true});
    document.getElementById("SETUP_CLOSE_BUTTON4").addEventListener('click', function(){
        $("#SETUP_PAGE").fadeOut();
    }, {passive: true});
    document.getElementById("SETUP_CLOSE_BUTTON5").addEventListener('click', function(){
        $("#LOCAL_DATA_PAGE").fadeOut();
        $("#TITLE_BAR").text("e-4Pt Tool");
    }, {passive: true});
    document.getElementById("SETUP_CLOSE_BUTTON6").addEventListener('click', function(){
        $("#FILE_CHOOSER_PAGE").fadeOut();
    }, {passive: true});
    document.getElementById("SETUP_CLOSE_BUTTON7").addEventListener('click', function(){
        $("#DATA_DETAILS_PAGE").fadeOut();
    }, {passive: true});
    document.getElementById("SENSOR_PARAMS_UPDATE_BUTTON").addEventListener('click', function(){
        authorizeSensorParamsUpdate();
    }, {passive: true});
    document.getElementById("FILE_EXPORT_BUTTON").addEventListener('click', function(){
        multipleFileDownloadFunction();
    }, {passive: true});
    document.getElementById("DATA_DETAILS_BUTTON").addEventListener('click', function(){
        populateDetailsTable();
    }, {passive: true});
    document.getElementById("DETAILS_EXPORT_BUTTON").addEventListener('click', function(){
        let prompt = "Email or Upload Files?";
        e4PtPrompt(prompt, exportDetailsFile, "Get File", ["Email","Upload to Box","Cancel"]);
    }, {passive: true});
    document.getElementById("MANUAL_OVERRIDE").addEventListener('click', function(){
        overrideSettings();
    }, {passive: true});
    setupAccordian();
    if (communicationChannel == "WebSocket") {
        createWS();
    }
    // Wait (0.5s) for the page load to complete, then get the file system.
    setTimeout(function(){
               window.requestFileSystem  = window.requestFileSystem || window.webkitRequestFileSystem;
               window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, gotFS, fsFail);
               }, 500);

    
});

function gotFS(fileSystem) {
    // save the file system for later access
    appDir = cordova.file.applicationDirectory;
    console.log("@gotFS: appDir = ", appDir);
    window.rootFS = fileSystem.root;
    fsRoot = window.rootFS.nativeURL;
    fsRoot = fsRoot.replace("file://","");
    console.log("@gotFS: fsRoot = ", fsRoot);
}

function fsFail(err) {
    console.log("Failed to get file system: ", err);
}

// overrideSettings is called when the user checks the box to override.
function overrideSettings() {
    if (manualOverride == true) {
        manualOverride = false;
        $("#SENSOR_SETUP_PAGE").fadeOut(); // This line may not be strictly necessary.
    }
    else {
        manualOverride = true;
        $("#SENSOR_SETUP_PAGE").fadeIn();
    }
    var message = {"args":["set_manual_override",manualOverride]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
}

function acquisitionTimePromptCallback(results) {
    console.log("@acquisitionTimePromptCallback");
    if (results.buttonIndex > 1) return;
    current_frame_data = [];
    acquisitionTime = null;
    if (results.input1.includes("rpm") || results.input1.includes("RPM")) {
        // RPM was specified
        acquisitionTime = results.input1;
    }
    else {
        acquisitionTime = parseFloat(results.input1);
    }
    if (acquisitionTime != null) {
        if (Number.isFinite(acquisitionTime)) {
            if (acquisitionTime > 0) {
                requestE4PtData(acquisitionTime);
            }
        }
    }
}

function acquisitionTimePromptWithMetaDataCallback(results) {
    console.log("@acquisitionTimePromptWithMetaDataCallback");
    if (results.buttonIndex > 1) return;
    console.log("input1: ", results.input1);
    acquisitionTime = null;
    if (results.input1.includes("rpm") || results.input1.includes("RPM")) {
        // RPM was specified
        acquisitionTime = results.input1;
        console.log("w/RPM: ", acquisitionTime);
    }
    else {
        acquisitionTime = parseFloat(results.input1);
        // Append rpm if its not there already.
        acquisitionTime = acquisitionTime.toString() + "rpm";
        console.log("w/o RPM: ", acquisitionTime);
    }
    if (acquisitionTime != null) {
        //if (Number.isFinite(acquisitionTime)) {
        //    if (acquisitionTime > 0) {
                var sn = document.getElementById("SERIAL_NUMBER").value;
                var frame = document.getElementById("FRAME_SIZE").value;
                var casing_thickness = document.getElementById("CASING_THICKNESS").value;
                if (casing_thickness.length > MAX_STR_LEN) casing_thickness = casing_thickness.substr(0,MAX_STR_LEN);
                var spacer_thickness = document.getElementById("SPACER_THICKNESS").value;
                if (spacer_thickness.length > MAX_STR_LEN) spacer_thickness = spacer_thickness.substr(0,MAX_STR_LEN);
                requestE4PtDataWithMetaData(acquisitionTime, frame, sn, current_stage, current_position, casing_thickness, spacer_thickness);
        //    }
        //}
    }
}

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
      };
    }
}

// When the menu the code looks for Plugins.  If present, it sets the
// communication method and indicates that it is connected.
function toggle_menu() {
    console.log("fsRoot: ", fsRoot);
	if (menu_open){
		$('#LEFT_MENU').animate({"margin-left": '-=50vmin'});
		menu_open = false;
	}
	else{
        var plugins = window.plugins;
        if (plugins != null) {
            if (!serialConnected) {
                e4PtAlert("Connecting...\nPlease wait for indicator to turn green before proceeding.\n(~2s)");
            }
            communicationChannel = "Plugin";
            // Requesting the version here kicks off the initialization process and
            // eventually results in the indicator turning green.
            var message = {"args":["get_version"]};
            window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                                   pluginMessage(msg);
                                                   }, null);
        }
        else {
            communicationChannel = "WebSocket";
        }

		$('#LEFT_MENU').animate({"margin-left": '+=50vmin'});
		menu_open = true;
	}
}

function get_sensor_parameters() {
    // Get the sensor parameters
    message = {"args":["get_sensor_parameters"]};
    window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                           pluginMessage(msg);
                                           }, null);
}

function set_demo_mode(tf) {
    var message = {"args":["set_demo_mode",tf]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
}

function set_connection_mode(mode) {
    console.log("@set_connection_mode");
    var message = {"args":["set_connection_mode",mode]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
}

function sensor_setup() {
    console.log("@sensor_setup");
    $("#FRD_PAGE").fadeOut();
    $("#SETUP_PAGE").fadeOut();
    $("#SCAN_INFO_PAGE").fadeOut();
    $("#RESULTS_PAGE").fadeOut();
    $("#FILE_LOADING_PAGE").fadeOut();
    $("#DB_LOADING_PAGE").fadeOut();
    $("#SENSOR_SETUP_PAGE").fadeIn();
    $("#TURBINE_SETUP_PAGE").fadeOut();
    $("#LOCAL_DATA_PAGE").fadeOut();
    $("#FILE_CHOOSER_PAGE").fadeOut();
    $("#DATA_DETAILS_PAGE").fadeOut();
}

function send_scan_meta_data() {
  // Here we get values from the UI, but we make sure they don't overrun bounds.
  var frm_idx = document.getElementById("FRAME_SIZE").selectedIndex;
  E4PTdata.frame = frame_data[frm_idx].frame;
  E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
  if (E4PTdata.serial_number.length > MAX_STR_LEN) E4PTdata.serial_number = E4PTdata.serial_number.substr(0,MAX_STR_LEN);
  E4PTdata.customer = document.getElementById("CUSTOMER").value;
    if (E4PTdata.customer.length > MAX_STR_LEN) E4PTdata.customer = E4PTdata.customer.substr(0,MAX_STR_LEN);
  E4PTdata.site_name = document.getElementById("SITE").value;
  if (E4PTdata.site_name.length > MAX_STR_LEN) E4PTdata.site_name = E4PTdata.site_name.substr(0,MAX_STR_LEN);
  E4PTdata.operator = document.getElementById("OPERATOR").value;
  if (E4PTdata.operator.length > MAX_STR_LEN) E4PTdata.operator = E4PTdata.operator.substr(0,MAX_STR_LEN);
  E4PTdata.units = document.getElementById("UNITS").value;
  E4PTdata.state = document.getElementById("TURBINE_STATE").value;
  var message = {"args":["scan_meta_data", E4PTdata.frame, E4PTdata.serial_number, E4PTdata.customer, E4PTdata.site_name, E4PTdata.operator, E4PTdata.units, E4PTdata.state]};
  console.log("message: ", message);

  if (communicationChannel == "WebSocket") {
    message = JSON.stringify(message);
    sendWSMessage(message);
  }
  else if (communicationChannel == "Plugin") {
    window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                            pluginMessage(msg);
                                           }, null);
  }
}

function initialize_sensor() {
    console.log("@initialize_sensor");
    setMasterMessage2("white", "green", "Ready");
}

function turbine_setup(reset) {
    $("#TURBINE_SETUP_PAGE").fadeIn();

    // Get frame type
    var frm_idx = document.getElementById("FRAME_SIZE").selectedIndex;
    current_frame_data = frame_data[frm_idx];

    if (reset == true) {
      E4PTdata.pouchdb_id = "";
      reset_data_collection();
    }

    // Setup the Stage options
    set_stage_information();

    // Setup the position options
    set_position_information();
    current_position_index = 0;

    update_spacer_value();

    var units = document.getElementById("UNITS").value;
    if (units == "In") {
        document.getElementById("CASING_THICKNESS_LABEL").innerHTML = "Casing Thickness (in)";
        document.getElementById("SPACER_THICKNESS_LABEL").innerHTML = "Spacer Thickness (in)";
    }
    if (units == "MM") {
        document.getElementById("CASING_THICKNESS_LABEL").innerHTML = "Casing Thickness (mm)";
        document.getElementById("SPACER_THICKNESS_LABEL").innerHTML = "Spacer Thickness (mm)";
    }
}

function set_frame_information() {
    var html_buf = [];
    var frmIdx = 0;
    var frame = "";
    var selectedIndex = 0;
    E4PTdata.pouchdb_id = "";
    for (frmIdx = 0; frmIdx < frame_data.length; frmIdx++) {
        html_buf.push("<option value='" + frame_data[frmIdx]['frame'] + "'>" + frame_data[frmIdx]['frame'] + "</option>");
        if (current_frame_data.length != 0) {
          if (current_frame_data.frame == frame_data[frmIdx]) {
            selectedIndex = frmIdx;
          }
        }
    }
    var html = html_buf.join('\n');
    document.getElementById("FRAME_SIZE").innerHTML = html;
    if (current_frame_data.length != 0) {
      document.getElementById("FRAME_SIZE").selectedIndex = selectedIndex;
      document.getElementById("FRAME_SIZE").value = current_frame_data.frame;
    }
}

function set_position_information() {
    var html_buf = [];
    var positions = current_frame_data['position'];
    positions = positions[current_stage];
    var posIdx = 0;
    for (posIdx = 0; posIdx < positions.length; posIdx++) {
        html_buf.push("<option value='" + positions[posIdx] + "'>" + positions[posIdx] + "</option>");
    }
    var html = html_buf.join('\n');
    document.getElementById("SENSOR_POSITION").innerHTML = html;
}

function set_stage_information() {
    html_buf = [];
    var stages = current_frame_data['stage'];
    for (stage_index = 0; stage_index < stages.length; stage_index++) {
      html_buf.push("<option value='" + stages[stage_index] + "'>" + stages[stage_index] + "</option>");
    }
    html = html_buf.join('\n');
    document.getElementById("SENSOR_STAGE").innerHTML = html;
    current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
    current_stage = stages[current_stage_index];
    set_position_information(); // When you change the stage, the position information changes too.
    current_position_index = 0;
}

function set_stage() {
  current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
  current_stage = current_frame_data['stage'][current_stage_index];
  set_position_information();
}

function set_position() {
  current_position_index =  document.getElementById("SENSOR_POSITION").selectedIndex;
  current_position = current_frame_data['position'][current_stage][current_position_index];
}

function set_measurement_rate(idx) {
  var el_id = "MEASUREMENT_RATE_" + idx;
  meas_rate_text = document.getElementById(el_id).value;
  var meas_rate_f = parseFloat(meas_rate_text);
  // Make sure the text is a number
  if ( (isNaN(meas_rate_f)) || (typeof(meas_rate_f) != "number")) {
    e4PtAlert("Measurement rate is not a number.");
    return;
  }
  
    if (meas_rate_f > 6.5) {
      e4PtConfirm("Measurement rates over 6.5kHz are not supported. Rate will be set to 6.5kHz.",
        function(buttonIndex) {
            if (buttonIndex==1){//OK
                // Proceed
                if (meas_rate_f > 6.5) {
                meas_rate_f = 6.5;
                document.getElementById(el_id).value = 6.5;
                }
                message = {"args":["set_measuring_rate",meas_rate_f]};
                if (communicationChannel == "WebSocket") {
                message = JSON.stringify(message);
                sendWSMessage(message);
                }
                else if (communicationChannel == "Plugin") {
                window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                                       pluginMessage(msg);
                                                       }, null);
                }
            } else if (buttonIndex==2){//Cancel
                document.getElementById(el_id).value = "";
                return;
            }
        })
    }
    else {
        if (meas_rate_f < 0.1) {
            meas_rate_f = 0.1;
            document.getElementById(el_id).value = 0.1;
        }
        message = {"args":["set_measuring_rate",meas_rate_f]};
        if (communicationChannel == "WebSocket") {
            message = JSON.stringify(message);
            sendWSMessage(message);
        }
        else if (communicationChannel == "Plugin") {
            window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                                   pluginMessage(msg);
                                                   }, null);
        }
    }
}

function set_threshold() {
    threshold_text = document.getElementById("THRESHOLD_1").value;
    var threshold_f = parseFloat(threshold_text);
    // Make sure the text is a number
    if ( (isNaN(threshold_f)) || (typeof(threshold_f) != "number")) {
        e4PtAlert("Threshold is not a number.");
        return;
    }
    if (threshold_f < 0.5) {
        threshold_f = 0.5;
        document.getElementById(el_id).value = 0.5;
    }
    if (threshold_f > 100.0) {
        threshold_f = 100.0;
        document.getElementById(el_id).value = 100.0;
    }
    message = {"args":["set_threshold",threshold_f]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
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
    doDBSave = true;

    // Collect data from the sensor.
    var nav = navigator.notification;
    if (nav != null) {
        // We have plugins so we're in Cordova.  Use the Cordova notification.
        navigator.notification.prompt('Please enter the rotor RPM.',
                                      acquisitionTimePromptWithMetaDataCallback,
                                      'Enter RPM',
                                      ['Ok','Cancel'],
                                      '1');
    }
    else {
        // No plugins, so we must not be in Cordova. Use a standard prompt.
        acquisitionTime = window.prompt("Please enter the rotor RPM.", "1");
        acquisitionTimePromptWithMetaDataCallback({"input1":acquisitionTime});
    }
}

function setup_data_collection(update_position) {
    current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
    current_stage = current_frame_data['stage'][current_stage_index];
    current_position_index = document.getElementById("SENSOR_POSITION").selectedIndex;
    current_position = current_frame_data['position'][current_stage][current_position_index];
    setup_data_collection_page("", "", update_position);
}

function reset_data_collection() {
    E4PTdata.sets = [];
    current_stage_index = 0;
    current_stage = current_frame_data['stage'][current_stage_index];
    current_position_index = 0;
    current_position = current_frame_data['position'][current_stage][current_position_index];
    document.getElementById("CASING_THICKNESS").value = "";
    document.getElementById("CLEARANCE_ERROR").innerHTML = "";
    document.getElementById("SPACER_COLOR_LABEL").innerHTML = "";
    setup_data_collection_page("", "", true);
    var obj = document.getElementById("DATA_PLOT2");
    var chart = Highcharts.charts[obj.getAttribute('data-highcharts-chart')];
    if (typeof chart !== 'undefined') {
      if (chart.series != null) {
        while(chart.series.length > 0)
          chart.series[0].remove(true);
      }
    }
    obj = document.getElementById("CLEARANCE_PLOT");
    var chart2 = Highcharts.charts[obj.getAttribute('data-highcharts-chart')];
    if (typeof chart2 !== 'undefined') {
      if (chart2.series != null) {
        while(chart2.series.length > 0)
          chart2.series[0].remove(true);
      }
    }
}

function b64toBlob(b64Data, contentType, sliceSize) {
    contentType = contentType || '';
    sliceSize = sliceSize || 512;
    
    var byteCharacters = atob(b64Data);
    var byteArrays = [];
    
    for (var offset = 0; offset < byteCharacters.length; offset += sliceSize) {
        var slice = byteCharacters.slice(offset, offset + sliceSize);
        
        var byteNumbers = new Array(slice.length);
        for (var i = 0; i < slice.length; i++) {
            byteNumbers[i] = slice.charCodeAt(i);
        }
        
        var byteArray = new Uint8Array(byteNumbers);
        
        byteArrays.push(byteArray);
    }
    
    var blob = new Blob(byteArrays, {type: contentType});
    return blob;
}

function generate_customer_report() {
  // This call gets the entire HTML report in memory.
  var reportHTML = generateHTMLReport(E4PTdata, current_frame_data);
    //console.log("reportHTML:\n",reportHTML);
    if (false) {
        // This method opens the report in a browser window.
        var newWindow = window.open();
        newWindow.document.write(reportHTML);
    }
    else {
        // This method generates a PDF, then exports it.
        baseURL = appDir + "www";
        var options = {
            documentSize: 'Letter',
            type: 'base64',
            fileName: 'customer_report.pdf',
            baseUrl:baseURL
        };
        if (communicationChannel == "Plugin") {
            // replace "./css/report.css" with "<%=css_file%>" for plugin
            reportHTML = reportHTML.replace("./css/report.css","<%=css_file%>");
            reportHTML = reportHTML.split("img/").join("www/img/"); // equivalent to replaceAll
            console.log("reportHTML:\n",reportHTML);
        }
        var payload = _.template(reportHTML);
        cssFile = "www/css/report.css";
        pdf.fromData(payload({css_file:cssFile}), options)
        .then(function(base64){
              var cust_rpt_fileName = "customer_report.pdf";
              var pdfBlob = b64toBlob(base64, "application/pdf");
              writeToFile(E4PTdata.serial_number, cust_rpt_fileName, pdfBlob, function() {
                                e4PtPrompt("Email or Upload File?", function(option) {
                                     exportReport(option, base64, cust_rpt_fileName);
                                     }, "Get File", ["Email","Upload to Box","Cancel"]);
                            });
        })
        .catch(function(err) {
            console.log("PDF Creation Error: ", err);
               });
        
    }
  return;
}

function writeToFile(folder, fileName, fileData, callback=null) {
    console.log("@writeToFile: fileName = ", fileName);
    var targetFolder = cordova.file.documentsDirectory + folder + "/";
    window.resolveLocalFileSystemURL(targetFolder, function(dir) {
        dir.getFile(fileName, {create:true, exclusive: false}, function(file) {
            if(!file) {
                return;
            }
            var myFileUrl = file.toURL();
            file.createWriter(function(fileWriter) {
                fileWriter.onwriteend = function (evt) {
                    console.log("@fileWriter.onwriteend");
                    if (callback != null) {
                        callback();
                    }
                }
                fileWriter.write(fileData);
            },
            function(error) {
                console.log(error);
                if (callback!=null){
                    callback();
                }
            });
        });
    });
}

function fileSaveCallback() {
    console.log("@fileSaveCallback");
}

// exportReport exports a base64 string as an email attachment or a
// Box file upload.
// The option is 1 (email), 2 (upload) or 3 (cancel).
function exportReport(option, base64, fileName) {
    console.log("@exportReport: ", option);
    if (option == 1) {
        console.log("Email");
        // do something with downloadFileName
        subject = "e-4Pt Tool " + fileName;
        // Add a prefix so the email plugin handles the attachment correctly
        var prefix = "base64:" + fileName + "//";
        base64 = prefix + base64;
        sendEmailWithAttachment( subject ,base64);
    }
    else if (option == 2) {
        console.log("Upload");
        var fileFullPath = cordova.file.documentsDirectory + E4PTdata.serial_number + "/" + fileName;
        fileFullPath = fileFullPath.replace("file://","");
        uploadFileToBox(fileFullPath);
    }
    else {
        console.log("Cancel");
    }
}
              
function setup_data_collection_page(dateStr, timeStr, update_position) {
    // Fill in the header
    var customer = document.getElementById("CUSTOMER").value;
    var site = document.getElementById("SITE").value;
    var d = new Date();
    if (timeStr.length == 0) {
      var hh = ( '0' + d.getHours()).substr(-2);
      var mm = ( '0' + d.getMinutes()).substr(-2);
      var ss = ( '0' + d.getSeconds()).substr(-2);
      timeStr = hh + ":" + mm;
    }
    if (dateStr.length == 0) {
        dateStr = monthNames[d.getMonth()] + "-" + d.getDate() + "-" + d.getFullYear();
    }
    E4PTdata.frame = document.getElementById("FRAME_SIZE").value;
    E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
    E4PTdata.description = document.getElementById("DESCRIPTION").value;
    E4PTdata.date = dateStr;
    E4PTdata.time = timeStr;
    var header = "<p>" + dateStr + "  -  " + timeStr + "</p><p>" + customer + " - " + site + "</p><p>Frame: " + E4PTdata.frame + "</p><p>S/N: " + E4PTdata.serial_number + "</p>";
    document.getElementById("HEADER_DATETIME").innerHTML = "Date: " + dateStr;
    document.getElementById("HEADER_CUSTOMER").innerHTML = "Customer: " + customer + " - " + site;
    document.getElementById("HEADER_FRAME").innerHTML = "Frame: " + E4PTdata.frame;
    document.getElementById("HEADER_SERIAL").innerHTML = "S/N: " + E4PTdata.serial_number + ";  Units: " + E4PTdata.units;
    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
    var html_buf = [];
    var stage_index = 0;
    var position_index = 0;

    // Setup the data tables.  We use different tables for each stage because
    // the number of positions for each stage could be different.
    // The "super" table contains all the tables for the different stages.
    
    var stages = current_frame_data['stage'];
    html_buf.push("<tr class=\"SENSOR_SUPER_TR\">"); // The sub-tables all go in one row in the super-table
    for (stage_index = 0; stage_index < stages.length; stage_index++) {
        var stage = stages[stage_index];
        var positions = current_frame_data['position'][stage];
        html_buf.push("<td class=\"SENSOR_SUPER_TD\"><table class=\"SENSOR_SUB_TABLE\">");
        var header_row = "<tr class=\"SENSOR_SUPER_TR\"><td class=\"SENSOR_SUB_TD\">POSITION</td><td class=\"SENSOR_SUB_TD\">";
        header_row = header_row + "STAGE " + stages[stage_index];
        header_row = header_row + "</td></tr>";
        html_buf.push(header_row);
        for (position_index = 0; position_index < positions.length; position_index++) {
            html_buf.push("<tr><td class=\"SENSOR_SUB_TD\">" + positions[position_index] + "</td>");
            var el_id = positions[position_index] + stages[stage_index];
            el_id = el_id.replace(/\s+/g, '_');
            html_buf.push("<td class=\"SENSOR_SUB_TD\" id='" + el_id +
                          "' onclick='set_grid_position(\"" + positions[position_index] +
                          "\", \"" + stages[stage_index] +
                          "\")'></td>");
            html_buf.push("</tr>");
        }
        html_buf.push("</table></td>");
    }
    html_buf.push("</tr>");
    html = html_buf.join('\n');
    document.getElementById("SENSOR_DATA_TABLE").innerHTML = html;

    // Update the positions selector based on the current stage.
    if (update_position) {
      set_position_information();
      current_position_index = 0;
    }

    update_spacer_value();
}

function get_spacer_information() {
  var spacers = current_frame_data['spacers'];
  var casing_thickness = parseFloat(document.getElementById("CASING_THICKNESS").value);
  var positions = current_frame_data['position'];
  positions = positions[current_stage];
  var position = positions[current_position_index];
  console.log("Getting spacer information for casing_thickness = ", casing_thickness, ", and position = ", position);
  var spacer = null;
  var spacer_found = false;
  for (var i=0; i<spacers.length; i++) {
    if (spacers[i].stage == current_stage) {
      var min = parseFloat(spacers[i].min);
      var max = parseFloat(spacers[i].max);
      if ((casing_thickness <= max) && (casing_thickness >= min)) {
        for(var j=0; j<spacers[i].position.length; j++) {
          if (position == spacers[i].position[j]) {
            spacer = {'size':spacers[i].size, 'color':spacers[i].color, 'image':spacers[i].image};
            spacer_found = true;
            break;
          }
        }
        if (spacer_found == true) break;
      }
    }
  }
  return spacer;
}

function update_spacer_value() {
  console.log("@update_spacer_value");
  var spacer = get_spacer_information();
  var spacer_value =  null;
  var spacer_color = "";
  if (spacer == null) {
    spacer_value = "Correct casing thickness.";
    spacer = {'color':'white'};
  }
  else {
    spacer_value = spacer.size;
    spacer_color = "Spacer color is " + spacer.color;
  }
  document.getElementById("SPACER_THICKNESS").value = spacer_value;
  document.getElementById("SPACER_COLOR_LABEL").innerHTML = spacer_color;
  document.getElementById("SPACER_COLOR_LABEL").style.color = spacer.color;
}

function advance_position() {
    // Don't try to advance the position if we're not set up for it.
    // (i.e. if we're not on the right page)
    console.log("@advance_position");
    if (current_frame_data['position'] == null) return;
    console.log("@advance_position - continuing");
    // Auto-advance
    var stages = current_frame_data['stage'];
    var positions = current_frame_data['position'][current_stage];
    //console.log("@advance_position");
    //console.log("stages:  ", stages);
    //console.log("positions: ", positions);

    current_position_index = (current_position_index + 1) % positions.length;
    current_position = positions[current_position_index];
    if (current_position_index == 0) {
        current_stage_index = (current_stage_index + 1) % stages.length;
        current_stage = stages[current_stage_index];
        set_position_information();
    }
    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
}

function set_grid_position(position, stage) {
    console.log("@set_grid_position: pos: ", position, "; stage: ", stage);
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
    update_spacer_value();
}

function do_dark_reference() {
    console.log("@do_dark_reference");
    var message = {"args":["do_dark_reference"]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
    $("#SENSOR_SETUP_PAGE").fadeOut();
    $("#LOCAL_DATA_PAGE").fadeOut();
    $("#RESULTS_PAGE").fadeIn();
    $("#DATA_PLOT").fadeIn();
    $("#STATUS_BAR").hide();
    $("#REV_PROGRESS_BAR").show();
}

function do_mastering() {
    console.log("@do_mastering");
    var message = {"args":["do_mastering"]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
}

function mastering_in_progress() {
    setMasterMessage("black","yellow","In Progress...");
    setMasterMessage2("black","yellow","In Progress...");
    setIndicatorColor("red");
}

function done_mastering() {
    console.log("@done_mastering");
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
    var message = {"args":["shutdown"]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        e4PtConfirm("Are you sure you want to exit?",
            function(idx) {
                if (idx == 1) {
                    console.log("Exit");
                    window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                                           pluginMessage(msg);
                                                           }, null);
                }
                else {
                    console.log("Exit was cancelled.");
                    return;
                }
            }
        );
    }
}

function doFileDownload() {
    console.log("@doFileDownload");
    var message = {"args":["get_data_file"]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
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


//    prompt: function (message, resultCallback, title, buttonLabels, defaultText) {
function e4PtPrompt(msg, callback, title, buttonLabels) {
    try{
        navigator.notification.confirm(
        String(msg),
        callback,
        String(title),
        buttonLabels
        );
    } catch (err){
        console.log("e4PtPrompt Error: ", err);
    }
}

function createWS(){
    if (navigator.onLine){
        if ("WebSocket" in window){
            //console.log("WebSocket is supported by your Browser!");
            e4PtSocket = new ReconnectingWebSocket("ws://192.168.168.41:3405", null, {reconnectInterval: 3000});
            //e4PtSocket = new ReconnectingWebSocket("ws://192.168.1.8:3405", null, {reconnectInterval: 3000});
	    //e4PtSocket = new ReconnectingWebSocket("ws://127.0.0.1:3405", null, {reconnectInterval: 3000});

            e4PtSocket.onopen = function(){
                // Web Socket is connected, send data using send()
                console.log("Connected to server");
                setIndicatorColor("green");
            };

            e4PtSocket.onmessage = function (evt){
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
                var message = {"args":["ping"]};
                message = JSON.stringify(message);
                setTimeout(function(){ sendWSMessage(message); }, 5000); // ping after 5s
                break;
              case "filename":
                {
                  console.log("Got filename: " + msg.fname);
                  if (msg.fname.length == 0) {
                    console.log("No filename: returning");
                    return;
                  }
                  var dl_file = "data/" + msg.fname;
                  //var dl_file = "data/" + "dummy.csv";
                  window.open(dl_file, "_blank"); // Try to open/download the file.
                  break;
                }
              } // end of switch
            };  // end of onmessage

            e4PtSocket.onclose = function(){
                console.log("DISCONNECTED");
                setIndicatorColor("white");
            };

            e4PtSocket.onerror = function(evt) {
              console.log("e4PtSocket error: ",evt);
              setIndicatorColor("white");
            };
        }
        else{
            // The browser doesn't support WebSocket
            send("WebSocket NOT supported by your Browser!");
        }
    }
    else{
        console.log('Waiting for a WiFi connection');
    }
}

function pluginMessage(msg) {
    console.log("@pluginMessage: msg.type = ", msg.type);
    switch(msg.type) {
        case "status":
            console.log("Received Status Message");
            console.log(msg);
            if (msg.status == "connected") {
                setIndicatorColor("green");
                document.getElementById("STATUS_DISPLAY").innerHTML = "Connected"
                serialConnected = true;
            }
            if (msg.status == "disconnected") {
                setIndicatorColor("white");
                document.getElementById("STATUS_DISPLAY").innerHTML = "Disconnected"
                serialConnected = false;
                e4PtAlert("Controller was disconnected.\nToggle side menu to reconnect.");
            }
            if (msg.status == "acquiring") {
                setIndicatorColor("red");
                $("#REV_PROGRESS").html('&nbsp' + '0%');
                $("#REV_PROGRESS").css('width', '0%');
                $("#REV_PROGRESS_BAR").show();
                $("#STATUS_BAR").hide();
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
            if (msg.status == "mastering_in_progress") {
                mastering_in_progress();
            }
            if (msg.status == "waiting") {
                setIndicatorColor("yellow");
            }
            if (msg.status.includes("Error:")) {
                var alertMsg = msg.status;
                e4PtAlert(alertMsg);
            }
            break;
        case "data":
            console.log("Received Data Message");
            setIndicatorColor("green");
            $("#REV_PROGRESS_BAR").hide();
            $("#STATUS_BAR").show();
            document.getElementById("CASING_THICKNESS").value = "";
            msg.data = JSON.parse(msg.data);
            msg.intensity = JSON.parse(msg.intensity);
            msg.locs = JSON.parse(msg.locs);
            msg.gaps = JSON.parse(msg.gaps);
            msg.quality = JSON.parse(msg.quality);
            processE4PtData(msg);
            break;
        case "filename":
            console.log("Recieved Filename Message: ", msg.fname);
            downloadFileName = msg.fname;
            e4PtPrompt("Email or Upload File?", exportFile, "Get File", ["Email","Upload to Box","Cancel"]);
            break;
        case "version":
            console.log("Received version message: ", msg.version);
            document.getElementById("APP_VERSION").innerHTML = "VERSION " + msg.version;
            get_sensor_parameters();
            break;
        case "alert":
            console.log("Received an alert message: ", msg.message);
            e4PtAlert(msg.message);
            break;
        case "progress":
            //console.log("Progress: ", msg.progress);
            $("#REV_PROGRESS").html('&nbsp' + msg.progress + '%');
            $("#REV_PROGRESS").css('width', msg.progress + '%');
            break;
        case "sensor_params":
            console.log("Received sensor parameters message: ", msg.start_measurement_range, ", ", msg.sensor_length, ", ", msg.master_offset);
            setIndicatorColor("green");
            serialConnected = true;
            sensor_data.start_measurement_range = JSON.parse(msg.start_measurement_range);
            sensor_data.master_offset = JSON.parse(msg.master_offset);
            sensor_data.sensor_length = JSON.parse(msg.sensor_length);
            document.getElementById("START_MEASUREMENT_RANGE").value = sensor_data.start_measurement_range.toString(10);
            document.getElementById("SENSOR_LENGTH").value = sensor_data.sensor_length.toString(10);
            document.getElementById("MASTER_OFFSET").value = sensor_data.master_offset.toString(10);
            break;
        default:
            console.log("pluginMessage: Hit default case.");
            break;
    }
}

function authorizeSensorParamsUpdate() {
    if (document.getElementById("START_MEASUREMENT_RANGE").disabled == false) {
        updateSensorParameters(document.getElementById("START_MEASUREMENT_RANGE").value,
                               document.getElementById("SENSOR_LENGTH").value,
                               document.getElementById("MASTER_OFFSET").value);
        return;
    }
    // Prompt user for password.
    var nav = navigator.notification;
    if (nav != null) {
        // We have plugins so we're in Cordova.  Use the Cordova notification.
        navigator.notification.prompt('Please enter the password.',
                                      confirmPassword,
                                      'Enter Password',
                                      ['Ok','Cancel'],
                                      '');
    }
    else {
        // No plugins, so we must not be in Cordova. Use a standard prompt.
        let pw = window.prompt("Please enter the password.", "1");
        confirmPassword({"input1":pw});
    }
}

function confirmPassword(results) {
    if (results.buttonIndex > 1) return;
    if (results.input1 == "Gr0undH0g") {
        document.getElementById("START_MEASUREMENT_RANGE").disabled = false;
        document.getElementById("SENSOR_LENGTH").disabled = false;
        document.getElementById("MASTER_OFFSET").disabled = false;
        document.getElementById("SENSOR_PARAMS_UPDATE_BUTTON").innerHTML = "LOCK VALUES";
    }
    else {
        e4PtAlert("Invalid password.");
    }
}

function updateSensorParameters(smr, sl, mo) {
    // Before updating the values, make sure the user has entered valid numbers.
    let smr_f = parseFloat(smr);
    let sl_f = parseFloat(sl);
    let mo_f = parseFloat(mo);
    // If a number is not valid, give the user a chance to try again or abort.
    if (isNaN(smr_f) || isNaN(sl_f) || isNaN(mo_f)) {
        e4PtConfirm("Please enter only floating point values.\nPlease try again.", function(buttonIndex) {
                    if (buttonIndex==1){//OK
                      return; // This changes nothing and lets the user try again.
                    } else if (buttonIndex==2) {//Cancel - This cancels and gets the previous values back.
                        let message = {"args":["get_sensor_parameters"]};
                        if (communicationChannel == "WebSocket") {
                            message = JSON.stringify(message);
                        sendWSMessage(message);
                        }
                        else if (communicationChannel == "Plugin") {
                            window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                                                   pluginMessage(msg);
                                                                   }, null);
                        }
                        document.getElementById("START_MEASUREMENT_RANGE").disabled = true;
                        document.getElementById("SENSOR_LENGTH").disabled = true;
                        document.getElementById("MASTER_OFFSET").disabled = true;
                        document.getElementById("SENSOR_PARAMS_UPDATE_BUTTON").innerHTML = "UPDATE";
                    }
                    });
        return;
    }
    document.getElementById("START_MEASUREMENT_RANGE").disabled = true;
    document.getElementById("SENSOR_LENGTH").disabled = true;
    document.getElementById("MASTER_OFFSET").disabled = true;
    document.getElementById("SENSOR_PARAMS_UPDATE_BUTTON").innerHTML = "UPDATE";
    let message = {"args":["set_sensor_parameters",smr_f.toString(10), sl_f.toString(10), mo_f.toString(10)]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
}

function exportDetailsFile(option) {
    let targetFolder = "data";
    let fileName = "data_details.csv";
    if ((typeof E4PTdata.serial_number !== 'undefined') || ( E4PTdata.serial_number.length > 0 )) {
        targetFolder = cordova.file.documentsDirectory + E4PTdata.serial_number;
        fileName = E4PTdata.serial_number + "_details.csv";
    }
    fileName = targetFolder + "/" + fileName;
    let attachmentList = [fileName];
    if (option == 1) {
        console.log("Email");
        subject = "e-4Pt Tool Data";
        sendEmailWithAttachment( subject , attachmentList);
    }
    else if (option == 2) {
        console.log("Upload To Box");
        for (let i=0; i<attachmentList.length; i++) {
            attachmentList[i] = attachmentList[i].replace("file://","");
        }
        uploadFileToBox(attachmentList);
    }
    else {
        console.log("Cancel");
    }
}

// exportFiles is the callback from a prompt to email, upload or cancel. Handles multiple files.
// The returned option is 1 (email), 2 (upload) or 3 (cancel).
function exportFiles(option) {
    console.log("@exportFiles");
    // generate attachment list (array).
    let attachmentList = [];
    let tbl = document.getElementById("LOCAL_FILE_TABLE_BODY");
    for (let i=0; i<tbl.rows.length; i++) {
        let row = tbl.rows[i];
        let cell = row.cells[0]; // Should only be one cell.
        for (let j=0; j<cell.classList.length; j++) {
            if (cell.classList[j] = "SELECTED_ROW") {
                console.log("exportFiles: Appending " + cell.attributes.nativeURL.value);
                attachmentList.push(cell.attributes.nativeURL.value);
            }
        }
    }
    if (option == 1) {
        console.log("Email");
        subject = "e-4Pt Tool Data";
        sendEmailWithAttachment( subject , attachmentList);
    }
    else if (option == 2) {
        console.log("Upload To Box");
        for (let i=0; i<attachmentList.length; i++) {
            attachmentList[i] = attachmentList[i].replace("file://","");
        }
        uploadFileToBox(attachmentList);
    }
    else {
        console.log("Cancel");
    }
    // Clear selected items.
    for (let i=0; i<tbl.rows.length; i++) {
        let row = tbl.rows[i];
        let cell = row.cells[0]; // Should only be one cell.
        cell.classList.remove("SELECTED_ROW");
    }
}

// exportFile is the callback from a prompt to email, upload or cancel. Only handles one file.
// The returned option is 1 (email), 2 (upload) or 3 (cancel).
function exportFile(option) {
    console.log("@exportFile: ", option);
    if (option == 1) {
        console.log("Email");
        // do something with downloadFileName
        subject = "e-4Pt Tool Data";
        attachmentFileName = downloadFileName;
        if (attachmentFileName.length > 0) {
            attachmentFileName = "file://" + attachmentFileName;
        }
        else {
            attachmentFileName = [];
        }
        sendEmailWithAttachment( subject , attachmentFileName);
    }
    else if (option == 2) {
        console.log("Upload");
        // do something with downloadFileName
        if (downloadFileName.length == 0) {
            e4PtAlert("There is no recent file to upload.");
            return;
        }
        uploadFileToBox(downloadFileName);
    }
    else {
        console.log("Cancel");
    }
}

function sendEmailWithAttachment(subject, attachment) {    
    // Check if email is set up on this device.  If not, alert the user.
    // If so, try to send the email.
    window.plugin.email.isAvailable('mailto', function(available) {
                                    if (!available) {
                                    alert("Error: Email is not set up on this device.");
                                    }
                                    else {
                                    window.plugin.email.open({
                                                             to: [],
                                                             cc: [],
                                                             bcc: [],
                                                             attachments: attachment,
                                                             subject: subject,
                                                             body: [],
                                                             isHtml: false
                                                             });
                                    }
                                    },
                                    this);
}

function uploadFileToBox(fileFullPath) {
    console.log(' fileFullPath  : ' + fileFullPath);
    // Uncomment the line below when we have a provisioning profile with iCloud entitlements from the COE.
    // Until then this function does nothing.
    if (communicationChannel == "Plugin") {
        window.plugins.doc_picker_plugin.uploadFileToBox(fileFullPath);
    }
    else if (communicationChannel == "WebSocket") {
        e4PtAlert("Box upload isn't supported in a browser yet.\nPlease export the file and upload to Box manually.");
    }
}

// boxUploadCallback is called when the file upload to box has completed.
function boxUploadCallback() {
    console.log("@boxUploadCallback");
}

//examples: 
//listDir(cordova.file.documentsDirectory + "data");
//listDir(cordova.file.documentsDirectory + serial_number);
function listDir(path){
    window.resolveLocalFileSystemURL(path,
        function (fileSystem) {
            var reader = fileSystem.createReader();
            reader.readEntries(
                function (entries) {
                    console.log(entries);
                    populateFileTable(entries);
                },
                function (err) {
                    err = "Error: " + err;
                    console.log(err);
                }
            );
        },
        function (err) {
            err = "Error: " + err;
            console.log(err);
        }
    );
}

function populateFileTable(entries) {
    $("#FILE_CHOOSER_PAGE").fadeIn();
    var prev_tbody = document.getElementById("LOCAL_FILE_TABLE_BODY");
    var tbody = document.createElement("tbody");
    tbody.setAttribute("id","LOCAL_FILE_TABLE_BODY");
    // Create the table body.
    let rowIdx = 0;
    for (var i=0; i<entries.length; i++) {
        if (!entries[i].isFile) continue;  // ignore any non-file entries
        if (entries[i].name == ".DS_Store") continue;
        let fileSelectFn = "toggleFileSelected(\"" + entries[i].nativeURL + "\"," + rowIdx + ")";
        var new_row = tbody.insertRow(-1);
        var cell0 = new_row.insertCell(-1);
        cell0.innerHTML = entries[i].name;
        cell0.setAttribute("onclick",fileSelectFn);
        cell0.setAttribute("nativeURL",entries[i].nativeURL);
        rowIdx += 1;
    }
    prev_tbody.parentNode.replaceChild(tbody, prev_tbody);
}

function populateDetailsTable() {
    writeDetailsFile();  // Write the CSV file so it will be produced at the same time as the table.
    $("#DATA_DETAILS_PAGE").fadeIn();
    var prev_tbody = document.getElementById("DATA_DETAILS_TABLE_BODY");
    var tbody = document.createElement("tbody");
    tbody.setAttribute("id","DATA_DETAILS_TABLE_BODY");
    // Create the table body.
    let tmp = "";
    let rowIdx = 0;
    for (let i=0; i<E4PTdata.sets.length; i++) {
        let clickFn = "toggleDetailsSelected(\"" + rowIdx + "\")";
        var new_row = tbody.insertRow(-1);
        var cell1 = new_row.insertCell(-1);
        cell1.setAttribute("onclick",clickFn);
        tmp = E4PTdata.sets[i].stage;
        if (typeof tmp == 'undefined') tmp = "";
        cell1.innerHTML = tmp;
        var cell2 = new_row.insertCell(-1);
        cell2.setAttribute("onclick",clickFn);
        tmp = E4PTdata.sets[i].position;
        if (typeof tmp == 'undefined') tmp = "";
        cell2.innerHTML = tmp;
        var cell3 = new_row.insertCell(-1);
        cell3.setAttribute("onclick",clickFn);
        tmp = E4PTdata.sets[i].clearance;
        cell3.innerHTML = checkValue(E4PTdata.sets[i].clearance,3);
        var cell4 = new_row.insertCell(-1);
        cell4.setAttribute("onclick",clickFn);
        cell4.innerHTML = checkValue(E4PTdata.sets[i].max_clr,3);
        var cell5 = new_row.insertCell(-1);
        cell5.setAttribute("onclick",clickFn);
        cell5.innerHTML = checkValue(E4PTdata.sets[i].min_clr,3);
        var cell6 = new_row.insertCell(-1);
        cell6.setAttribute("onclick",clickFn);
        cell6.innerHTML = checkValue(E4PTdata.sets[i].med_clr,3);
        var cell7 = new_row.insertCell(-1);
        cell7.setAttribute("onclick",clickFn);
        cell7.innerHTML = checkValue(E4PTdata.sets[i].std_clr,3);
        rowIdx += 1;
    }
    prev_tbody.parentNode.replaceChild(tbody, prev_tbody);
}

// checkValue(val) checks a string to make sure it's a number,
// and converts it to a string with only n decimal places.
function checkValue(val,n) {
    if (typeof val == 'undefined') {
        val = "";
    }
    else {
        let tmp_f = parseFloat(val);
        if (isNaN(tmp_f)) {
            val = "";
        }
        else {
            val = tmp_f.toFixed(n);
        }
    }
    return val;
}

// writeDetailsFile() does just that.  It writes a CSV file containing
// the details for the data collected.
function writeDetailsFile() {
    // Construct a string containing the file contents.
    let contents = "stage,position,clearance,max_clr,min_clr,med_clr,std_clr\n";
    for (let i=0; i<E4PTdata.sets.length; i++) {
        contents = contents + E4PTdata.sets[i].stage + ","
                            + E4PTdata.sets[i].position +  ","
                            + checkValue(E4PTdata.sets[i].clearance,3) + ","
                            + checkValue(E4PTdata.sets[i].max_clr,3) + ","
                            + checkValue(E4PTdata.sets[i].min_clr,3) + ","
                            + checkValue(E4PTdata.sets[i].med_clr,3) + ","
                            + checkValue(E4PTdata.sets[i].std_clr,3) + "\n";
    }
    let targetFolder = "data"; // default directory
    let fileName = "data_details.csv";
    if ((typeof E4PTdata.serial_number !== 'undefined') || ( E4PTdata.serial_number.length > 0 )) {
        targetFolder = E4PTdata.serial_number;
        fileName = E4PTdata.serial_number + "_details.csv";
    }
    writeToFile(targetFolder, fileName, contents, null);
}

function toggleFileSelected(fileName, idx) {
    let tbl = document.getElementById("LOCAL_FILE_TABLE_BODY");
    let row = tbl.rows[idx];
    let cell = row.cells[0]; // Should only be one cell.
    cell.classList.toggle("SELECTED_ROW");
}

function toggleDetailsSelected(idx) {
    let tbl = document.getElementById("DATA_DETAILS_TABLE_BODY");
    let row = tbl.rows[idx];
    let cell = row.cells[0]; // Should only be one cell.
    cell.classList.toggle("SELECTED_ROW");
}

function fileDownloadFunction(fileURL) {
    $("#FILE_CHOOSER_PAGE").fadeOut();
    $("#DATA_DETAILS_PAGE").fadeOut();
    // remove:"file://" from URL.  exportFile will export downloadFileName.
    downloadFileName = fileURL.replace("file://","");
    // The next two lines gets just the file name from the full file path.
    const segments = fileURL.split('/');
    let fileName = segments.pop() || segments.pop();
    let prompt = "Email or Upload\n" + fileName + "?";
    e4PtPrompt(prompt, exportFile, "Get File", ["Email","Upload to Box","Cancel"]);
}

function multipleFileDownloadFunction(){
    console.log("@multipleFileDownloadFunction");
    let prompt = "Email or Upload Files?";
    e4PtPrompt(prompt, exportFiles, "Get File", ["Email","Upload to Box","Cancel"]);
}

function selectedFilesDownloadFunction(){
    let tbl = document.getElementById("LOCAL_FILE_TABLE_BODY");
    for (let i=0; i<tbl.rows.length; i++) {
        let cell = tbl.rows[i].cells[0]; // There's only one cell per row in the file lists.
    }
}

function setIndicatorColor( color ) {
    document.getElementById("indicator-pulse").style.background = color;
    document.getElementById("indicator-solid").style.background = color;
}

function setMasterMessage( txtColor, bgColor, txt ) {
    document.getElementById("master_message").style.color = txtColor;
    document.getElementById("master_message").style.background = bgColor;
    document.getElementById("master_message").innerHTML = txt;
}

function setMasterMessage2( txtColor, bgColor, txt ) {
    document.getElementById("master_message_2").style.color = txtColor;
    document.getElementById("master_message_2").style.background = bgColor;
    document.getElementById("master_message_2").innerHTML = txt;
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
    update_scan_info(); // currently does nothing
    parse_data();
    plot_data();
    if (current_frame_data['position'] != null) {
      plot_data_2();
    }
    advance_position();
  } catch (error) {
    console.log(error);
  }
}

function requestE4PtData(acquisitionTime) {
  console.log("Requesting " + acquisitionTime + " seconds of data");
  var obj1 = document.getElementById("DATA_PLOT");
  var chart1 = Highcharts.charts[obj1.getAttribute('data-highcharts-chart')];
  var obj2 = document.getElementById("DATA_PLOT2");
  var chart2 = Highcharts.charts[obj2.getAttribute('data-highcharts-chart')];
  if (typeof chart1 !== 'undefined') {
    if (chart1.series != null) {
      while(chart1.series.length > 0)
        chart1.series[0].remove(true);
    }
  }
  if (typeof chart2 !== 'undefined') {
    if (chart2.series != null) {
      while(chart2.series.length > 0)
        chart2.series[0].remove(true);
    }
  }
    
    $("#STATUS_BAR").hide();
    $("#REV_PROGRESS_BAR").show();

    // send_data needs args: acquisition time and casing thickness
    // Casing thickness can be zero here.
    message = {"args":["send_data",acquisitionTime,"0.0"]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                                pluginMessage(msg);
                                               }, null);
    }
}

function requestE4PtDataWithMetaData(acquisitionTime, frame, sn, stage, position, casing_thickness, spacer_thickness) {
    console.log("Requesting " + acquisitionTime + "s data");
    console.log("Meta data: " + frame + "; " + sn + "; " + stage + "; " + position);
    frame = frame.replace(/\s+/g, '_'); // replace all the spaces with underscores
    sn = sn.replace(/\s+/g, '_');
    stage = stage.replace(/\s+/g, '_');
    position = position.replace(/\s+/g, '_');
    casing_thickness = casing_thickness.replace(/\s+/g, '_');
    spacer_thickness = spacer_thickness.replace(/\s+/g, '_');
    var num_blades = 0;
    var blade_width = 0;
    var tip_diameter = 0;
    if (typeof current_frame_data.stage_info !== 'undefined') {
        if (typeof current_frame_data.stage_info[current_stage] !== 'undefined') {
            stage_details = get_stage_details(position, casing_thickness);
            num_blades = stage_details.blade_count;
            blade_width = stage_details.blade_width;
            tip_diameter = stage_details.tip_diameter;
        }
    }
    var message = {"args":["send_data",acquisitionTime, frame, sn, stage, position, casing_thickness, spacer_thickness, num_blades, tip_diameter, blade_width, sensor_data.master_offset]};
    if (communicationChannel == "WebSocket") {
        message = JSON.stringify(message);
        sendWSMessage(message);
    }
    else if (communicationChannel == "Plugin") {
        window.plugins.IFC242x.messageToDevice(message, function(msg) {
                                               pluginMessage(msg);
                                               }, null);
    }
}

// get_stage_details find the specific information for this stage, given the frame, position,
// and casing thickness.
function get_stage_details(position, casing_thickness) {
    var details = {};
    details["blade_width"] = 0;
    details["blade_count"] = 0;
    details["tip_diameter"] = 0;
    var stageKeys = Object.keys(current_frame_data.stage_info); // Get all the stage information names
    for (var idx in stageKeys) {
        var stageKey = stageKeys[idx];
        var stageInt = Math.floor(parseFloat(stageKeys[idx])); // Get the stage number for this entry.
        var stageStr = stageInt.toString(10);
        var foundDetails = false;
        if (stageStr == current_stage ) {
            var detailKeys = Object.keys(current_frame_data.stage_info[stageKey]);
            for (var key in detailKeys) {
                let pos = position.replace(/_+/g, ' '); // Put spaces back in position for comparisons
                if (detailKeys[key] == pos) {
                    console.log("Found Position");
                    var caseThck = current_frame_data.stage_info[stageKey][pos][3];
                    if ((casing_thickness > (caseThck - 0.050)) && (casing_thickness < (caseThck + 0.05))) {
                        console.log("For: position = ", position, "; casing_thickness = ", casing_thickness);
                        console.log("Found: ", stageKey, "; ", detailKeys[key], "; ", caseThck);
                        details["blade_width"] = current_frame_data.stage_info[stageKey].blade_width;
                        details["blade_count"] = current_frame_data.stage_info[stageKey].blade_count;
                        details["tip_diameter"] = current_frame_data.stage_info[stageKey].tip_diameter;
                        console.log("blade_width: ", details["blade_width"], "; blade_count: ", details["blade_count"], "; tip_diameter: ", details["tip_diameter"]);
                        foundDetails = true;
                        break;
                    }
                }
            }
        }
        if (foundDetails) break;
    }
    return details;
}

function sendWSMessage(msg_text) {
  console.log("@sendWSMessage: " + msg_text);
  var msg = {
  text: msg_text,
  type: "message",
  id: clientID,
  date: Date.now()
  };
  if (msg_text.indexOf('send_data') >= 0) {
    console.log("yellow - send_data");
      setIndicatorColor("yellow");
  }
  if (msg_text.indexOf('do_dark_reference') >=0) {
    console.log("yellow - do_dark_reference");
      setIndicatorColor("yellow");
  }
  e4PtSocket.send(JSON.stringify(msg));
}

function update_scan_info(){
  // Do something with the data...
  return;
}

function parse_data() {
    console.log("@parse_data");
    if (E4PTdata.locs.length > 0) {
        var minima = new Array(E4PTdata.locs.length);
        for (var i=0; i<E4PTdata.locs.length; i++) {
            minima[i] = [E4PTdata.locs[i], E4PTdata.gaps[i]];
        }
        E4PTdata.minima = minima;
    }
    else {
        E4PTdata.minima = [];
    }
    console.log("Clearance average: ", E4PTdata.clearance);
    // Only update the clearance(s) info if we have all the data to do so.
    if (current_frame_data['position'] != null) {
        let clearance_f = parseFloat(E4PTdata.clearance);
        let max_clr_f = parseFloat(E4PTdata.max_clr);
        let min_clr_f = parseFloat(E4PTdata.min_clr);
        let med_clr_f = parseFloat(E4PTdata.med_clr);
        let std_clr_f = parseFloat(E4PTdata.std_clr);
        let units = E4PTdata.units.toUpperCase();
        if (units.includes("IN")) {
            clearance_f = clearance_f / 25.4; // Clearances come back in mm. Convert to inches if needed.
            max_clr_f = max_clr_f / 25.4;
            min_clr_f = min_clr_f / 25.4;
            med_clr_f = med_clr_f / 25.4;
            std_clr_f = std_clr_f / 25.4;
            E4PTdata.clearance = clearance_f.toString(10);
            E4PTdata.max_clr = max_clr_f.toString(10);
            E4PTdata.min_clr = min_clr_f.toString(10);
            E4PTdata.med_clr = med_clr_f.toString(10);
            E4PTdata.std_clr = std_clr_f.toString(10);
        }
      update_clearance(clearance_f);
    }

    E4PTdata.frame = document.getElementById("FRAME_SIZE").value;
    E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
    var set = new Data_Set();
    set.stage = current_stage;
    set.position = current_position;
    set.case_thickness = E4PTdata.casing_thickness;
    set.clearance = E4PTdata.clearance;
    set.state = E4PTdata.state;
    set.max_clr = E4PTdata.max_clr;
    set.min_clr = E4PTdata.min_clr;
    set.med_clr = E4PTdata.med_clr;
    set.std_clr = E4PTdata.std_clr;
    addOrReplaceSet(set);
    if (doDBSave) {
      addDBEntry(E4PTdata); // save the data autmatically after acquisition
    }
}

// addOrReplace(set) will check existing data to see if there is already data for this
// stage & position.  If not, it will add it.  If so, it will replace it.
function addOrReplaceSet(set) {
    // This next line looks up any previous data set for this stage and position.  If it is not
    // found the result will be undefined.
    let priorSet = E4PTdata.sets.find(o => ((o.stage === set.stage) && (o.position === set.position)));
    if (typeof priorSet == 'undefined') {
        // There is no prior data for this set, so add this set and return.
        E4PTdata.sets.push(set);
        return;
    }
    // If prior data for this stage & position was found, replace it with this new data.
    console.log("priorSet before:  ", priorSet);
    priorSet.stage = set.stage;
    priorSet.position = set.position;
    priorSet.case_thickness = set.case_thickness;
    priorSet.clearance = set.clearance;
    priorSet.state = set.state;
    priorSet.max_clr = set.max_clr;
    priorSet.min_clr = set.min_clr;
    priorSet.med_clr = set.med_clr;
    priorSet.std_clr = set.std_clr;
    console.log("priorSet after:  ", priorSet);
}

function update_clearance(clearance) {
    if (current_frame_data.length == 0) {
        return;
    }
    var stage = current_frame_data['stage'][current_stage_index];
    var position = current_frame_data['position'][stage][current_position_index];
    var el_id = position + stage;
    el_id = el_id.replace(/\s+/g, '_');
    if (clearance.length == 0) {
        clearance = 0.0;
    }
    var clearance_f = 0.0
    if ((typeof clearance) != "string") {
        clearance_f = clearance;
    }
    else {
        clearance_f = parseFloat(clearance);
    }
    var err_id = document.getElementById("CLEARANCE_ERROR");
    var err_str = "";
    if (clearance_f == -9.997) {
        err_str = "Error: No gaps detected in data.";
    }
    if (clearance_f == -9.998) {
        err_str = "Error: gaps contains all NaN values.";
    }
    if (clearance_f == -9.999) {
        err_str = "Error: Clearance computed to NaN value.";
    }
    if (clearance_f == -9.996) {
        err_str = "Error: Problem finding blade tips (1).";
    }
    if (clearance_f == -9.995) {
        err_str = "Error: Problem finding blade tips (2).";
    }
    if (clearance_f == -9.994) {
        err_str = "Error: Problem finding blade tips (3).";
    }
    if (clearance_f < -9.0) {
        document.getElementById(el_id).innerHTML = "Err";
        err_id.innerHTML = err_str;
        return;
    }
    if (isNaN(clearance_f)) {
        document.getElementById(el_id).innerHTML = "";
        err_id.innerHTML = err_str;
        return;
    }
    if (E4PTdata.quality.length > 0) {
        var defects = 0;
        for (var i=0; i<E4PTdata.quality.length; i++) {
            if (E4PTdata.quality[i] < 1.0) {
                defects = defects + 1;
            }
        }
        if (defects > 0) {
            err_str = err_str + " Data for " + defects + " blades deviates by >0.001 in.";
            err_id.innerHTML = err_str;
        }
    }
    err_id.innerHTML = err_str;

    document.getElementById(el_id).innerHTML = clearance_f.toFixed(3);
    
    clearances = [];
    for (var i=0; i<current_frame_data['position'][stage].length; i++) {
        var p = current_frame_data['position'][stage][i];
        var angle = position_angle[p];
        el_id = p + stage;
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
  let subtitle = E4PTdata.date + "; Avg. Tip Dist: " + E4PTdata.clearance;
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
      zoomType: 'xy',
      panning: true,
      panKey: 'shift',
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
      text: subtitle
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
        enabled: true,
        valueDecimals: 2
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
        name: 'Sensor Data',
        data: E4PTdata.data
        //data: E4PTdata.sets[E4PTdata.sets.length-1].pts
      },
      {
        type: 'scatter',
        name: 'Clearance Minima',
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
  let subtitle = E4PTdata.date + "; Avg. Tip Dist: " + E4PTdata.clearance;
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
      backgroundColor: 'transparent',
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
      text: subtitle
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
        name: 'Filtered Sensor Data',
        data: E4PTdata.data
        //data: E4PTdata.sets[E4PTdata.sets.length-1].pts
      },
      {
        type: 'scatter',
        name: 'Clearance Minima',
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
      backgroundColor: 'transparent',
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
          update_scan_info(); // currently does nothing.
          parse_data();
          plot_data();
          if (current_frame_data['position'] != null) {
            plot_data_2();
          }
          advance_position();
        } catch (error) {
          console.log(error);
        }

        console.log("Data Loaded from an external file");
        $("#FILE_LOADING_PAGE").fadeOut();
        if ($("#TITLE_BAR").text() != "DATA"){
            $("#TITLE_BAR").text("DATA");
        }

        $("#RESULTS_PAGE").fadeIn();
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
  };
  // Redirect to Authorization page.
  //var replacementUri = authServerUri + "?" + $.param(authParams);
  var replacementUri = authServerUri;
  console.log("replacementUri: " + replacementUri);
  window.location.replace(replacementUri);
}

// Initialise a sync with the remote server
function sync() {
  syncDom.setAttribute('data-sync-state', 'syncing');
  var opts = {live: true};
  local_db.replicate.to(remoteCouch, opts, syncError);
  local_db.replicate.from(remoteCouch, opts, syncError);
}

// There was some form or error syncing
function syncError() {
  syncDom.setAttribute('data-sync-state', 'error');
}

function addDBEntry(e4pt_data) {

  var entry = {
    _id: "",
    ofs_id: e4pt_data.ofs_id,
    frame: e4pt_data.frame,
    serial_number: e4pt_data.serial_number,
    data_name: e4pt_data.data_name,
    description: e4pt_data.description,
    customer: e4pt_data.customer,
    site_name: e4pt_data.site_name,
    inspection_type: e4pt_data.inspection_type,
    operator: e4pt_data.operator,
    units: e4pt_data.units,
    state: e4pt_data.state,
    final: e4pt_data.final,
    date: e4pt_data.date,
    time: e4pt_data.time,
    sets: e4pt_data.sets,
    alreadyOnLDB: e4pt_data.alreadyOnLDB
    // We don't save the locs, minima, or data elements of e4pt_data because it
    // contains dense data and could overwhelm the database & browser memory.
    // We also don't save the clearance element because it is saved in the sets
    // element.
  };

  if (e4pt_data.pouchdb_id.length == 0) {
    // This is a new db entry, so get a new id.
    e4pt_data.pouchdb_id = uuidv4();
    entry._id = e4pt_data.pouchdb_id;
    local_db.put(entry, function callback(err, result) {
      if (!err) {
        console.log('PouchDB: Successfully added an entry!');
      }
    });
  }
  else {
    // This db entry exists, so just update it.
    local_db.get(e4pt_data.pouchdb_id, function(err, doc){
      if (err) {
        console.log("Error getting existing document from the database.");
      }
      else {
        // Since we're updating this entry make sure its _id & _ref agree
        // with what's in the DB.
        entry._id = doc._id;
        entry._rev = doc._rev;
        entry.sets = e4pt_data.sets;
        local_db.put(entry, function callback(err, result) {
          if (!err) {
            console.log('Successfully updated an entry!');
          }
        });
      }
    });
  }
  return e4pt_data;
}

function getDBEntry(uuid) {
  return local_db.get(uuid);
}

function getAllDBEntries() {
  local_db.allDocs({include_docs: true, descending: true}, function(err, docs) {
    console.log("offset: " + docs.offset + "; total_rows: " + docs.total_rows);
    redrawDataSetsUI(docs.rows);
  });
}

function redrawDataSetsUI(rows) {
  console.log("@redrawDataSetsUI");
  var prev_tbody = document.getElementById("LOCAL_DATA_TABLE_BODY");
  var tbody = document.createElement("tbody");
  tbody.setAttribute("id","LOCAL_DATA_TABLE_BODY");
  // Create the table body.
  for (var i=0; i<rows.length; i++) {
    console.log("Row: id:" + rows[i].doc._id + "; rev: " + rows[i].doc._rev);
    var new_row = tbody.insertRow(-1);
    // save the ID in a hidden column so we can get it to retrieve the data.
    // The first column is hidden.
    var cell0 = new_row.insertCell(-1);
    cell0.innerHTML = rows[i].doc._id;
    cell0.setAttribute("style","display:none;");
    var clickFn = "loadLocalData(\"" + rows[i].doc._id + "\")";
    var cell1 = new_row.insertCell(-1);
    cell1.setAttribute("onclick",clickFn);
    cell1.innerHTML = rows[i].doc.frame;
    var cell2 = new_row.insertCell(-1);
    cell2.setAttribute("onclick",clickFn);
    cell2.innerHTML = rows[i].doc.serial_number;
    var cell3 = new_row.insertCell(-1);
    cell3.setAttribute("onclick",clickFn);
    cell3.innerHTML = rows[i].doc.customer;
    var cell4 = new_row.insertCell(-1);
    cell4.setAttribute("onclick",clickFn);
    cell4.innerHTML = rows[i].doc.site_name;
    var cell5 = new_row.insertCell(-1);
    cell5.setAttribute("onclick",clickFn);
    cell5.innerHTML = rows[i].doc.description;
    var cell6 = new_row.insertCell(-1);
    cell6.setAttribute("onclick",clickFn);
    cell6.innerHTML = rows[i].doc.date;
    var cell7 = new_row.insertCell(-1);
    cell7.setAttribute("onclick",clickFn);
    cell7.innerHTML = rows[i].doc.time;
  }
  prev_tbody.parentNode.replaceChild(tbody, prev_tbody);
}

function addDBDummyData() {
  var tmpData1 = {};
  tmpData1.pouchdb_id = "";
  tmpData1.ofs_id = 12345;
  tmpData1.frame = "7FA.05";
  tmpData1.serial_number = "246810";
  tmpData1.data_name = "none";
  tmpData1.description = "Description 1";
  tmpData1.customer = "GE Research";
  tmpData1.site_name = "Niskayuna";
  tmpData1.inspection_type = "type 1";
  tmpData1.operator = "200005229";
  tmpData1.units = "In";
  tmpData1.state = "opening";
  tmpData1.final = false;
  tmpData1.date = "Jul-04-1776";
  tmpData1.time = "13:13";
  var set1 = new Data_Set();
  set1.stage = 5;
  set1.position = "TOP";
  set1.case_thickness = 4.967;
  set1.clearance = 3.1415;
  set1.state = "opening";
  tmpData1.sets = [set1];
  addDBEntry(tmpData1);
  var tmpData2 = {};
  tmpData2.pouchdb_id = "";
  tmpData2.ofs_id = 67890;
  tmpData2.frame = "6B";
  tmpData2.serial_number = "135790";
  tmpData2.data_name = "none";
  tmpData2.description = "Description 2";
  tmpData2.customer = "GE Power";
  tmpData2.site_name = "Greenville";
  tmpData2.inspection_type = "type 2";
  tmpData2.operator = "Sandra Kolvick";
  tmpData2.units = "MM";
  tmpData2.state = "closing";
  tmpData2.final = true;
  tmpData2.date = "Jul-24-1969";
  tmpData2.time = "20:17";
  var set2 = new Data_Set();
  set2.stage = 17;
  set2.position = "BOTTOM";
  set2.case_thickness = 4.321;
  set2.clearance = 1.4142;
  set2.state = "closing";
  tmpData2.sets = [set2];
  addDBEntry(tmpData2);
}

// Not sure if we'll need this in production, but for development it could
// be handy.
function clearDB() {
  if (false) {
    // This method 'removes' the objects from the pouchdb.
    // However, pouchdb retains the objects and just marks them deleted.
    // This can cause a memory buildup, but may be more sync-friendly.
    //  The 'else' statement below provides and alternate method by just
    // destroying the DB and re-creating it.  I'm not sure of the implications
    // of this on syncing, but it is a brute-force method.
    local_db.allDocs({include_docs: true, descending: true}, function(err, docs) {
      console.log("Clearing DB");
      for (var i=0; i<docs.rows.length; i++) {
        console.log("Removing doc: ", docs.rows[i].id);
        var doc = docs.rows[i].doc;
        local_db.remove(doc, function(err, response) {
          if (err) {
            console.log("Error removing document:\n", err);
          }
        });
      }
    });
  }
  else {
    local_db.destroy(function (err, response) {
      if (err) {
        console.log("Error destroying database:\n", err);
        return;
      } else {
        console.log("Database destroyed. Creating new empty database.");
        local_db = new PouchDB('e4ptdb');
        setTimeout(function(){listInternalFiles();}, 1000);
      }
    });
  }
}

// uuidv4 function grabbed from:
// https://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript
function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function listInternalFiles() {
  getAllDBEntries();
}

// sortTable(n) is lifted straight from https://www.w3schools.com/howto/howto_js_sort_table.asp
function sortTable(srtTable, n) {
  var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
  table = document.getElementById(srtTable);
  switching = true;
  // Set the sorting direction to ascending:
  dir = "asc";
  /* Make a loop that will continue until
  no switching has been done: */
  while (switching) {
    // Start by saying: no switching is done:
    switching = false;
    rows = table.rows;
    /* Loop through all table rows (except the
    first, which contains table headers): */
    for (i = 1; i < (rows.length - 1); i++) {
      // Start by saying there should be no switching:
      shouldSwitch = false;
      /* Get the two elements you want to compare,
      one from current row and one from the next: */
      x = rows[i].getElementsByTagName("TD")[n];
      y = rows[i + 1].getElementsByTagName("TD")[n];
      /* Check if the two rows should switch place,
      based on the direction, asc or desc: */
      if (dir == "asc") {
        if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
          // If so, mark as a switch and break the loop:
          shouldSwitch = true;
          break;
        }
      } else if (dir == "desc") {
        if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
          // If so, mark as a switch and break the loop:
          shouldSwitch = true;
          break;
        }
      }
    }
    if (shouldSwitch) {
      /* If a switch has been marked, make the switch
      and mark that a switch has been done: */
      rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
      switching = true;
      // Each time a switch is done, increase this count by 1:
      switchcount ++;
    } else {
      /* If no switching has been done AND the direction is "asc",
      set the direction to "desc" and run the while loop again. */
      if (switchcount == 0 && dir == "asc") {
        dir = "desc";
        switching = true;
      }
    }
  }
    
  // Add color to the header of the column by which the table is sorted.
  let cols = ["FRAME_COL","SN_COL","CUSTOMER_COL","SITE_COL","DESC_COL","DATE_COL","TIME_COL"];
  if (srtTable == "DATA_DETAILS_TABLE") {
    cols = ["STAGE_COL","POSITION_COL","CLEARANCE_COL","MAX_CLR_COL","MIN_CLR_COL","MED_CLR_COL","STD_CLR_COL"];
  }
  for (i=0; i<cols.length; i++) {
    document.getElementById(cols[i]).style.color = "white";
  }
  document.getElementById(cols[n-1]).style.color = "aqua";
}

function loadLocalData(id) {
  console.log("@loadLocalData: id = ", id);
  E4PTdata.pouchdb_id = id;
  local_db.get(id, function(err, doc) {
    console.log("Row: ", doc);
    var frm_idx = 0;
    for (frm_idx=0; frm_idx<frame_data.length; frm_idx++) {
      if (frame_data[frm_idx].frame == doc.frame) {
        break;
      }
    }
    document.getElementById("FRAME_SIZE").value = doc.frame;
    document.getElementById("FRAME_SIZE").selectedIndex = frm_idx;
    document.getElementById("UNITS").value = doc.units;
    document.getElementById("CUSTOMER").value = doc.customer;
    document.getElementById("SITE").value = doc.site_name;
    document.getElementById("SERIAL_NUMBER").value = doc.serial_number;
    document.getElementById("DESCRIPTION").value = doc.description;
    document.getElementById("OPERATOR").value = doc.operator;
    if (doc.units == "In") {
      document.getElementById("UNITS").selectedIndex = 0;
    }
    if (doc.units == "MM") {
      document.getElementById("UNITS").selectedIndex = 1;
    }
    E4PTdata.frame = doc.frame;
    E4PTdata.serial_number = doc.serial_number;
    E4PTdata.data_name = doc.data_name;
    E4PTdata.description = doc.description;
    E4PTdata.customer = doc.customer;
    E4PTdata.site_name = doc.site_name;
    E4PTdata.inspection_type = doc.inspection_type;
    E4PTdata.operator = doc.operator;
    E4PTdata.units = doc.units;
    E4PTdata.state = doc.state;
    E4PTdata.date = doc.date;
    E4PTdata.time = doc.time;
    E4PTdata.final = doc.final;
    E4PTdata.sets = doc.sets;

    current_frame_data = frame_data[frm_idx];
    current_stage_index = 0;
    current_stage = current_frame_data.stage[0];
    current_position_index = 0;
    current_position = current_frame_data.position[current_stage][0];

    $("#LOCAL_DATA_PAGE").fadeOut();
    // Have to set up the data collection page before we can populate
    // the clearance entries in the tables.
    //var tmp = document.getElementById("FRAME_SIZE").selectedIndex;
      setup_data_collection_page(doc.date, doc.time, true);

    for (var i=0; i<doc.sets.length; i++) {
      var pos = doc.sets[i].position;
      var stg = doc.sets[i].stage;
      var clr = doc.sets[i].clearance;
      var clr_f = 0;
      if ((typeof clr) == "string") {
        clr_f = parseFloat(clr)
      }
      else {
        clr_f = clr;
      }
      var positions = current_frame_data.position[stg];
      var stages = current_frame_data.stage;
      var position_index = 0;
      for (position_index = 0; position_index<positions.length; position_index++) {
        if (positions[position_index] == pos) {
          break;
        }
      }
      var stage_index = 0;
      for (stage_index = 0; stage_index < stages.length; stage_index++) {
        if (stages[stage_index] == stg) {
          break;
        }
      }
      var el_id = positions[position_index] + stages[stage_index];
      el_id = el_id.replace(/\s+/g, '_');
      document.getElementById(el_id).innerHTML = clr_f.toFixed(3);
    }

    turbine_setup(false);
  });
}
