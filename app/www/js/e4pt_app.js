
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
    "alreadyOnLDB":"false"
}

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

$(document).ready(function(){	
    var attachFastClick = Origami.fastclick;
    attachFastClick(document.body);
    //document.getElementById("DATA_PLOT").addEventListener('click', function(){
    //    toggle_menu();
    //}, {passive: true})
    document.getElementById("MAIN_MENU").addEventListener('click', function(){
        $("#TITLE_BAR").text("e-4Pt Tool")
		$("#SETUP_PAGE").fadeOut();
		$("#SCAN_INFO_PAGE").fadeOut()
        $("#RESULTS_PAGE").fadeOut()
        $("#FILE_LOADING_PAGE").fadeOut()
        $("#DB_LOADING_PAGE").fadeOut()
        toggle_menu();
		
    }, {passive: true})
    document.getElementById("SETUP_BUTTON").addEventListener('click', function(){
        toggle_menu();
        $("#SETUP_PAGE").fadeIn();
                                                             
        //console.log("Calling getCredentials");
        //window.plugins.FEFCredentials.getCredentials(credentialSuccess,credentialFail,0)
                                                             
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
    document.getElementById("OPEN_EXTERNAL_FILE_BUTTON").addEventListener('change', function(){
        loadExternalFile();
    }, {passive: true})
    document.getElementById("OPEN_EXTERNAL_FILE_BUTTON").addEventListener('click', function(){
        document.getElementById("OPEN_EXTERNAL_FILE_BUTTON").value =null;
    }, {passive: true})
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
    document.getElementById("GET_DATA_BUTTON").addEventListener('click', function(){
        toggle_menu();
        requestE4PtData();
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
    e4PtSocket = new WebSocket("ws://192.168.7.77:3405");
  } catch (err) {
    console.log("Error connecting to WebSocket server");
  }
  if (e4PtSocket == null) return;

  e4PtSocket.onopen = function(evt) {
    console.log("e4PtSocket Opened");
    console.log("evt: " + evt);
  }

  e4PtSocket.onmessage = function(evt) {
    var msg = JSON.parse(evt.data);
    console.log("e4PtSocket Message Received: " + msg.type);
    switch(msg.type) {
    case "data":
      console.log("Received Data Message");
      console.log(msg);
      processE4PtData(msg);
      break;
    case "status":
      console.log("Received Status Message");
      console.log(msg);
      break;
    }
  }
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

function requestE4PtData() {
  sendWSMessage("send_data");
}

function sendWSMessage(msg_text) {
  var msg = {
  text: msg_text,
  type: "message",
  id: clientID,
  date: Date.now()
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
  Highcharts.chart('container', {
      
    title: {
      text: 'e-4Pt Acquired Data'
          },
        
        subtitle: {
      text: E4PTdata.date
          },
        yAxis: {
      title: {
        text: 'Displacement'
            }
      },
        xAxis: {
      title: {
        text: 'Index'
            }
      },
        legend: {
      enabled: 'false',
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
