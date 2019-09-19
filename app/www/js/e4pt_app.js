
var menu_open = false;
var e4PtSocket = null;
var WebSocket = WebSocket;
var clientID = 312;
var e4pt = null;

var E4PTdata = {
    "ofs_id": "",
    "frame":"",
    "serial_number":"",
    "scan_name":"",
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
    "alreadyOnLDB":"false"
}

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

var stages = ["1", "2", "3"];
var positions = ["TOP", "LEFT", "BOTTOM", "RIGHT"];
var current_stage_index = 0;
var current_position_index = 0;

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
        frame_information();
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

function turbine_setup() {
    current_stage_index = 0;
    current_position_index = 0;
    // Fill in the header
    E4PTdata.frame = document.getElementById("FRAME_SIZE").value;
    E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
    var header = "Frame: " + E4PTdata.frame + "; S/N: " + E4PTdata.serial_number;
    document.getElementById("TURBINE_SETUP_HEADER").innerHTML = header;

    // Set up the grid that indicates which data has been collected.
    var html_buf = [];
    var stage_index = 0;
    var position_index = 0;
    html_buf.push("<tr><td>POSITION</td>");
    for (stage_index = 0; stage_index < stages.length; stage_index++) {
        html_buf.push("<td>STAGE " + stages[stage_index] + "</td>");
    }
    html_buf.push("</tr>");
    for (position_index = 0; position_index < positions.length; position_index++) {
        html_buf.push("<tr><td>" + positions[position_index] + "</td>");
        for (stage_index = 0; stage_index < stages.length; stage_index++) {
            html_buf.push("<td id='" + positions[position_index] + stages[stage_index] + 
                          "' onclick='set_grid_position(\"" + positions[position_index] + 
                          "\", \"" + stages[stage_index] + 
                          "\")'></td>");
        }
        html_buf.push("</tr>");
    }
    html = html_buf.join('\n')
    document.getElementById("SENSOR_DATA_TABLE").innerHTML = html;

    // Setup the position options
    html_buf = [];
    for (position_index = 0; position_index < positions.length; position_index++) {
        html_buf.push("<option value='" + positions[position_index] + "'>" + positions[position_index] + "</option>");
    }
    html = html_buf.join('\n')
    document.getElementById("SENSOR_POSITION").innerHTML = html;

    // Setup the Stage options
    html_buf = [];
    for (stage_index = 0; stage_index < stages.length; stage_index++) {
        html_buf.push("<option value='" + stages[stage_index] + "'>" + stages[stage_index] + "</option>");
    }
    html = html_buf.join('\n')
    document.getElementById("SENSOR_STAGE").innerHTML = html;
}

function frame_information() {
    document.getElementById("FRAME_SIZE").value = "";
    document.getElementById("SERIAL_NUMBER").value = "";
}

function collect_stage_data() {
    var position = document.getElementById("SENSOR_POSITION").value;
    var stage = document.getElementById("SENSOR_STAGE").value;
    var boxID = position + stage;

    current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
    current_position_index =  document.getElementById("SENSOR_POSITION").selectedIndex;

    var str = "&#x2714";
    var color_str = str.fontcolor("green");
    document.getElementById(boxID).innerHTML = color_str;

    // Auto-advance    
    advance_position();
    
}

function reset_data_collection() {
    current_stage_index = 0;
    current_position_index = 0;
    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
    var html_buf = [];
    var stage_index = 0;
    var position_index = 0;
    html_buf.push("<tr><td>POSITION</td>");
    for (stage_index = 0; stage_index < stages.length; stage_index++) {
        html_buf.push("<td>STAGE " + stages[stage_index] + "</td>");
    }
    html_buf.push("</tr>");
    for (position_index = 0; position_index < positions.length; position_index++) {
        html_buf.push("<tr><td>" + positions[position_index] + "</td>");
        for (stage_index = 0; stage_index < stages.length; stage_index++) {
            html_buf.push("<td id='" + positions[position_index] + stages[stage_index] + 
                          "' onclick='set_grid_position(\"" + positions[position_index] + 
                          "\", \"" + stages[stage_index] + 
                          "\")'></td>");
        }
        html_buf.push("</tr>");
    }
    html = html_buf.join('\n')
    document.getElementById("SENSOR_DATA_TABLE").innerHTML = html;
}

function advance_position() {
    // Auto-advance
    current_position_index = (current_position_index + 1) % positions.length;
    if (current_position_index == 0) {
        current_stage_index = (current_stage_index + 1) % stages.length;
    }
    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
}

function set_grid_position(position, stage) {
    current_position_index = positions.indexOf(position);
    current_stage_index = stages.indexOf(stage);
    document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
    document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
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
}

function done_mastering() {
    setMasterMessage("white","green","Mastering complete.");
    setIndicatorColor("green");    
}

function failed_mastering() {
    setMasterMessage("black","red","Mastering failed.");
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
  $("#DATA_PLOT").fadeIn(); 
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
        name: 'Capacitance Sensor',
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
