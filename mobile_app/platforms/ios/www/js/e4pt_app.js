define(function(require, exports, module) {
    const messaging = require('./messaging');
    const sensorSettings = require('./sensor_settings');
    const charting = require('./charting');
    
    // override console.log behavior
    var logMessages = [];
    var oldLog = console.log;
    console.log = function() {
        logMessages.push({"timestamp": new Date().toISOString(), "message": Object.values(arguments).join(" ")});
        oldLog.apply(null, arguments);
    }

    var menu_open = false;
    var downloadFileName = "";
    var fsRoot = "";
    var appDir = "";
    var serialConnected = false;
    var doDBSave = false;
    var manualOverride = false;
    var savedRPM = "";
    var computedRPM = "";
    var fromGetData = false;
    var fromDataCollectionPage = false;
    var fromSensorSetupPage = false;
    var fromDataPlotPage = false;
    var fromCalculateRPM = false;
    var collectionAborted = false;
    var masteringPerformed = false;

    var sensorParamsFromController = false;
    var sensorFromController = "";
    var sensorLengthFromController = 0.0;
    var smrFromController = 0.0;
    var sensorMRFromController = 0.0;
    
    var APP_NAME = "e-4Pt Tool";
    var UPDATE_SETTINGS_PASSWORD = "Gr0undH0g";
    var MAX_STR_LEN = 64;
    var FRD_FILE = 'www/FRD.pdf';
    var DEFAULT_SPACER_FILE = 'img/spacers/Unknown.gif';
    var MIN_RPM = 0.5;
    var MAX_RPM = 15.0;
    var MIN_SAMPLING_RATE = 0.1;
    var MAX_SAMPLING_RATE = 6.5;
    var CLEARANCE_OVERRIDE_PRECISION = 4;
    var DETAILS_PRECISION = 4;
    
    var CALC_METHOD_ORIGINAL = 1;
    var CALC_METHOD_NEW = 2;
    var CALC_METHOD_NONE = 3;
    
    var MAX_LOG_MESSAGES = 10;
    
    var CUSTOMER_REPORT_FILE_PREFIX = "customer_report_e4Pt";
    var DETAILS_FILE_PREFIX = "details_e4pt";
    var EMAIL_FILE_PREFIX = "e4pt";
    var DATA_FILE_PREFIX = "data";
    var LOG_FILE_PREFIX = "log";

    // This is the obscure address of the e4Pt field data Box folder.
    var FIELD_DATA_BOX_FOLDER = "Field_D.c55377p707j2cweu@u.box.com";

    var SSO_AUTH_URL = "https://fssfed.ge.com/fss/as/authorization.oauth2";
    var SSO_RESPONSE_TYPE = "code";
    var SSO_SCOPE = "openid+profile";
    var SSO_CLIENT_ID = "GEPW_FFA_TRACC_01";
    var SSO_REDIRECT_URI = "TRaCC://authorization_grant/";
    
    var LABEL_GO = "COLLECT";
    var LABEL_ABORT = "ABORT";
    var LABEL_START_DARK = "START DARK REFERENCE";
    var LABEL_DARK = "PERFORMING DARK REFERENCE";
    var LABEL_CALCULATE = "CALCULATE";
    var LABEL_CALCULATING = "CALCULATING";
    var LABEL_LOAD_PARAMS = "LOAD FROM CONTROLLER";
    var LABEL_LOADING_PARAMS = "LOADING FROM CONTROLLER";

    var local_db = new PouchDB('e4ptdb', {revs_limit: 1, auto_compaction: true});
    var archive_db = new PouchDB('e4ptarchive', {revs_limit: 1, auto_compaction: true});
    
    var editModal = new bootstrap.Modal(document.getElementById('EDIT_MODAL'));
    var clearanceOverrideModal = new bootstrap.Modal(document.getElementById('CLEARANCE_OVERRIDE_MODAL'));
    var spacerModal = new bootstrap.Modal(document.getElementById('SPACER_MODAL'));
    var logModal = new bootstrap.Modal(document.getElementById('LOG_MODAL'));
    
    var POSITION_DISPLAY_MODE = 'TEXT'; // TEXT, ICON, BOTH
    var ARROW_ICONS = {
        "TOP": '<i class="fas fa-arrow-up"></i>',
        "BOTTOM": '<i class="fas fa-arrow-down"></i>',
        "LEFT": '<i class="fas fa-arrow-left"></i>',
        "RIGHT": '<i class="fas fa-arrow-right"></i>',
        "TOP LEFT": '<i class="fas fa-arrow-left" data-fa-transform="rotate-45"></i>',
        "TOP RIGHT": '<i class="fas fa-arrow-up" data-fa-transform="rotate-45"></i>',
        "BOTTOM LEFT": '<i class="fas fa-arrow-down" data-fa-transform="rotate-45"></i>',
        "BOTTOM RIGHT": '<i class="fas fa-arrow-right" data-fa-transform="rotate-45"></i>',
    };

    // Replace with remote instance when we get to that point.
    //var remoteCouch = 'http://xxx.xxx.xxx.xxx/remote_e4ptdb';
    // include "purged": true for deleted entries
    // filter replication to ignore "purged"
    // validate_doc_update to reject "purged"
    // https://github.com/pouchdb/issues/802#issuecomment-448507342

    var Data_Set = function() {
        this.stage = null;
        this.position = null;
        this.case_thickness = null;
        //this.pts = null;
        this.clearance = null;
        this.manualOverride = false;
        this.overrideName = null;
        this.overrideSSO = null;
        this.max_clr = null;
        this.min_clr = null;
        this.med_clr = null;
        this.std_clr = null;
        this.quality = null;
        this.state = null;
        this.intensity_threshold = null;
        this.measurement_rate = null;
        this.dateStr = null;
        this.filename = null;
        this.ambient_temperature = null;
    };

    Data_Set.prototype.add_data = function(state, stage, position, case_thickness, blade_number, pts, used_in_avg, clearance, manualOverride, overrideName, overrideSSO, max_clr, min_clr, med_clr, std_clr, quality, intensity_threshold, measurement_rate, dateStr, filename, ambient_temperature) {
        this.stage = stage;
        this.position = position;
        this.case_thickness = case_thickness;
        //this.pts = pts;
        this.clearance = clearance;
        this.manualOverride = manualOverride;
        this.overrideName = overrideName;
        this.overrideSSO = overrideSSO;
        this.max_clr = max_clr;
        this.min_clr = min_clr;
        this.med_clr = med_clr;
        this.std_clr = std_clr;
        this.quality = quality;
        this.state = state;
        this.intensity_threshold = intensity_threshold;
        this.measurement_rate = measurement_rate;
        this.dateStr = dateStr;
        this.filename = filename;
        this.ambient_temperature = ambient_temperature;
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
        "temperature_units":"",
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
        "turbine_casing_thicknesses":{},
        "clearance":"",
        "manualOverride":false,
        "overrideName":"",
        "overrideSSO":"",
        "max_clr":"",
        "min_clr":"",
        "med_clr":"",
        "std_clr":"",
        "overall_avg":"",
        "blades":"",
        "blade_samples_avg":"",
        "alreadyOnLDB":"false",
        "pouchdb_id": "",
        "details_filename": "",
        "report_filename": "",
        "email_filename": ""
    };

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    const position_angle = {'TOP':0, 'BOTTOM':180, 'LEFT':270, 'RIGHT':90,
                            'TOP LEFT':315, 'BOTTOM LEFT':225, 'TOP RIGHT':45, 'BOTTOM RIGHT':135};
    var current_stage_index = 0;
    var current_stage = 0;
    var current_stage_type = '';
    var current_position_index = 0;
    var current_position = 0;
    var current_frame_data = [];

    var selected_frame_data = {
        frameIdx: 0,
        stageInfoIdx: 0,
        frameName: frame_data[0].frame,
        stageName: Object.keys(frame_data[0].stage_info)[0],
        bladeCount: Object.values(frame_data[0].stage_info)[0].blade_count,
        RPM: 'not computed yet'
    };
    var previous_frame = '';

    $(document).ready(function() {
        console.log("@ready");
        var attachFastClick = Origami.fastclick;
        attachFastClick(document.body);
        
        if (window.plugins != null) {
            messaging.setupPlugin(pluginMessage);
        } else {
            createWebSocket();
        }
        getSensorParameters();
        // TODO: fix, results in multiple IFC242xManager references
        //getConnectionMode();
        
        $("#REV_PROGRESS_BAR").hide();
        var currentHeaderHeight = $('header').css('height');
        var currentFooterHeight = $('footer').css('height');
        var newContentHeight = 'calc(100vh - ' + currentHeaderHeight + ' - ' + currentFooterHeight + ')';
        $('#sidebar-wrapper').css('height', newContentHeight);
        $('#page-content-wrapper').css('height', newContentHeight);
        fadeOutAll();
        
        // set default button values
        setButtonProperties($("#STAGE_COLLECT_BUTTON"), LABEL_GO, 'green');
        setButtonProperties($("#START_DARK_REFERENCE_BUTTON"), LABEL_START_DARK, 'blue');
        setButtonProperties($("#CALCULATE_RPM_BUTTON"), LABEL_CALCULATE, 'green');
        setButtonProperties($("#READ_SENSOR_PARAMETERS_BUTTON"), LABEL_LOAD_PARAMS, 'blue');
        
        // update default sensor alerts
        var infoShort = sensorSettings.getSensorType('SHORT');
        var smf = sensorSettings.toInches(infoShort['measured_mastering_fixture_height_mm']).toFixed(3);
        var ss = sensorSettings.toInches(infoShort['measured_length_mm']).toFixed(3);
        var infoLong = sensorSettings.getSensorType('LONG');
        var lmf = sensorSettings.toInches(infoLong['measured_mastering_fixture_height_mm']).toFixed(3);
        var ls = sensorSettings.toInches(infoLong['measured_length_mm']).toFixed(3);
        $("#DEFAULT_SMF").text(smf);
        $("#DEFAULT_SS").text(ss);
        $("#DEFAULT_LMF").text(lmf);
        $("#DEFAULT_LS").text(ls);

        $("#MIN_SAMPLING_RATE").text(MIN_SAMPLING_RATE.toFixed(3));
        $("#MAX_SAMPLING_RATE").text(MAX_SAMPLING_RATE.toFixed(3));
        
        document.addEventListener("pause", function () {
            console.log("pause");
            //messaging.sendMessage({args:[{command:'disconnect'}]});
        }, false);
        document.addEventListener("resume", function() {
            console.log("resume");
            set_connection_mode();
        }, false);
        document.getElementById("MAIN_MENU").addEventListener('click', function() {
            $("#TITLE_BAR").text(APP_NAME);
            toggleMenu();
        }, {passive: true});
        document.getElementById("FRD_BUTTON").addEventListener('click', function() {
            toggleMenu();
            fadeOutAll();
            $("#FRD_PAGE").fadeIn();
        }, {passive: true});
        document.getElementById("FRD_VIEW_BUTTON").addEventListener('click', function() {
            show_FRD();
        }, {passive: true});
        document.getElementById("SETUP_BUTTON").addEventListener('click', function() {
            toggleMenu();
            fadeOutAll();
            $("#SETUP_PAGE").fadeIn();
            set_frame_information();
        }, {passive: true});
        document.getElementById("FRAME_SIZE").addEventListener('change', function() {
            setupCasingThicknessTable(null);
            document.getElementById("FRAME_DEFAULT_SENSOR").value = current_frame_data.default_sensor;
        }, {passive: true});
        document.getElementById("SN_SUBMIT_BUTTON").addEventListener('click', function() {
            record_casing_thickness();
            confirm_new_or_continue();
        }, {passive: true});
        document.getElementById("COLLECT_DATA_BUTTON").addEventListener('click', function() {
            fadeOutAll();
            turbine_setup();
        }, {passive: true});
        document.getElementById("CLEAR_DB_BUTTON").addEventListener('click', function() {
            e4PtConfirm("Are you sure you want to clear all data from this database?",
              function(idx) {
                if (idx == 1) {
                  console.log("Clearing database.");
                  clearDB();
                } else {
                  console.log("Database clear was cancelled.");
                }
              });
        }, {passive: true});
        document.getElementById("CLEAR_SELECTED_BUTTON").addEventListener('click', function() {
            e4PtConfirm("Are you sure you want to delete the selected records?",
              function(idx) {
                if (idx == 1) {
                  console.log("Deleting selected records.");
                  clearSelectedDB(false) // if true it would clear all Database, even these not selected.
                } else {
                  console.log("Deleting selected records was cancelled.");
                }
              });
        }, {passive: true});
        document.getElementById("ARCHIVE_SELECTED_BUTTON").addEventListener('click', function() {
            e4PtConfirm("Are you sure you want to archive the selected records?",
              function(idx) {
                if (idx == 1) {
                  console.log("Archiving selected records.");
                  archiveSelectedDB(false) // if true it would delete local files, even these not selected.
                } else {
                  console.log("Archiving selected records was cancelled.");
                }
              });
        }, {passive: true});
        document.getElementById("DELETE_ARCHIVE_DB_BUTTON").addEventListener('click', function() {
            e4PtConfirm("Are you sure you want to clear and delete all data from this archive and local drive?",
              function(idx) {
                if (idx == 1) {
                  console.log("Clearing archive.");
                  clearArchive();
                } else {
                  console.log("Archive clear was cancelled.");
                }
              });
        }, {passive: true});
        document.getElementById("DELETE_SELECTED_ARCHIVE_BUTTON").addEventListener('click', function() {
            e4PtConfirm("Are you sure you want to delete the selected archive records?",
              function(idx) {
                if (idx == 1) {
                  console.log("Deleting selected archive records.");
                  clearSelectedArchive(false) // if true it would clear all Database, even these not selected.
                } else {
                  console.log("Deleting selected archive records was cancelled.");
                }
              });
        }, {passive: true});
        document.getElementById("UNARCHIVE_SELECTED_BUTTON").addEventListener('click', function() {
            e4PtConfirm("Are you sure you want to unarchive the selected records?",
              function(idx) {
                if (idx == 1) {
                  console.log("Unarchiving selected records.");
                  unarchiveSelectedDB(false) // if true it would delete local files, even these not selected.
                } else {
                  console.log("Unarchiving selected records was cancelled.");
                }
              });
        }, {passive: true});

        function RESULTS_BUTTON_FUNC() {
            getCredentialforREST();
            toggleMenu();
            if ($("#TITLE_BAR").text() != "Results") {
                $("#TITLE_BAR").text("Results");
            }
            createTable();
            $("#RESULTS_PAGE").fadeIn();
        }
        document.getElementById("OPEN_LOCAL_DATA_BUTTON").addEventListener('click', function() {
           fadeOutAll();
            try {
                set_frame_information();
                listInternalFiles("LOCAL_DATA_TABLE_BODY", local_db, true);
                SELECTED_FILE = "";
                toggleMenu();
                if ($("#TITLE_BAR").text() != "Open From Device") {
                    $("#TITLE_BAR").text("Open From Device");
                }
                $("#LOCAL_DATA_PAGE").fadeIn();
            } catch (err) {
                console.log("Error getting local files.");
                console.log(err);
                toggleMenu();
            }
        }, {passive: true});
        document.getElementById("OPEN_ARCHIVE_DATA_BUTTON").addEventListener('click', function() {
            fadeOutAll();
             try {
                 set_frame_information();
                 listInternalFiles("ARCHIVE_DATA_TABLE_BODY", archive_db, false);
                 SELECTED_FILE = "";
                 toggleMenu();
                 if ($("#TITLE_BAR").text() != "Open From Archive") {
                     $("#TITLE_BAR").text("Open From Archive");
                 }
                 $("#ARCHIVED_DATA_PAGE").fadeIn();
             } catch (err) {
                 console.log("Error getting archive files.");
                 console.log(err);
                 toggleMenu();
             }
        }, {passive: true});
        document.getElementById("SHUTDOWN_BUTTON").addEventListener('click', function() {
            toggleMenu();
            systemShutdown();
        }, {passive: true});
        document.getElementById("CONN_SELECTION").addEventListener('change', function() {
            set_connection_mode();
        }, {passive: true});
        document.getElementById("CONFIGURE_CONTROLLER_BUTTON").addEventListener('click', function() {
            authorizeControllerSettingsUpdate();
        }, {passive: true});
        document.getElementById("READ_SENSOR_PARAMETERS_BUTTON").addEventListener('click', function() {
            readSensorParameters();
        }, {passive: true});
        document.getElementById("DATA_PLOT_CLOSE_BUTTON").addEventListener('click', function() {
            $("#DATA_PLOT_PAGE").fadeOut();
            // re-open previous page
            if (fromSensorSetupPage) {
                $("#SENSOR_SETUP_PAGE").fadeIn();
            }
            // disabled since showing data on plot2
            /* else if (fromDataCollectionPage) {
                $("#TURBINE_SETUP_PAGE").fadeIn();
                fromDataCollectionPage = false;
            }*/
            fromGetData = false;
            fromSensorSetupPage = false;
        }, {passive: true});
        document.getElementById("FRD_CLOSE_BUTTON").addEventListener('click', function() {
            $("#FRD_PAGE").fadeOut();
        }, {passive: true});
        document.getElementById("INITIALIZE_SENSOR_CLOSE_BUTTON").addEventListener('click', function() {
            $("#INITIALIZE_SENSOR_PAGE").fadeOut();
        }, {passive: true});
        document.getElementById("SENSOR_SETUP_CLOSE_BUTTON").addEventListener('click', function() {
            $("#SENSOR_SETUP_PAGE").fadeOut();
            // re-open DATA COLLECTION page
            if (fromDataCollectionPage) {
                $("#TURBINE_SETUP_PAGE").fadeIn();
                fromDataCollectionPage = false;
            }
        }, {passive: true});
        document.getElementById("SETUP_CLOSE_BUTTON").addEventListener('click', function() {
            $("#SETUP_PAGE").fadeOut();
        }, {passive: true});
        document.getElementById("LOCATION_CLOSE_BUTTON").addEventListener('click', function() {
            $("#LOCATION_PAGE").fadeOut();
            $("#TURBINE_SETUP_PAGE").fadeIn();
        }, {passive: true});
        document.getElementById("LOCAL_DATA_CLOSE_BUTTON").addEventListener('click', function() {
            $("#LOCAL_DATA_PAGE").fadeOut();
            $("#TITLE_BAR").text(APP_NAME);
        }, {passive: true});
        document.getElementById("ARCHIVED_DATA_CLOSE_BUTTON").addEventListener('click', function() {
            $("#ARCHIVED_DATA_PAGE").fadeOut();
            $("#TITLE_BAR").text(APP_NAME);
        }, {passive: true});
        document.getElementById("FILE_CHOOSER_CLOSE_BUTTON").addEventListener('click', function() {
            $("#FILE_CHOOSER_PAGE").fadeOut();
            if (fromDataCollectionPage) {
                $("#TURBINE_SETUP_PAGE").fadeIn();
            } else if (fromDataPlotPage) {
                $("#DATA_PLOT_PAGE").fadeIn();
            }
            fromDataCollectionPage = false;
            fromDataPlotPage = false;
        }, {passive: true});
        document.getElementById("DATA_DETAILS_CLOSE_BUTTON").addEventListener('click', function() {
            $("#DATA_DETAILS_PAGE").fadeOut();
            // open DATA COLLECTION page
            $("#TURBINE_SETUP_PAGE").fadeIn();
        }, {passive: true});
        document.getElementById("GET_DATA_BUTTON").addEventListener('click', function() {
            console.log("@GET_DATA_BUTTON event listener function.");
            toggleMenu();
            fadeOutAll();
            if (!masteringPerformed) {
                //e4PtAlert('Mastering has not been performed. Please perform mastering before collecting data.');
                e4PtConfirm("Mastering has not been performed. Do you want to collect data without mastering?",
                  function(idx) {
                    if (idx == 1) {
                      console.log("Proceeding without mastering");
                      getData();
                    } else {
                      console.log("Get data was cancelled.");
                    }
                  });
            } else {
                getData();
            }
        }, {passive: true});
        document.getElementById("SENSOR_SETUP_BUTTON").addEventListener('click', function() {
            toggleMenu();
            fadeOutAll();
            $("#SENSOR_SETUP_PAGE").fadeIn();
            setMasterMessage("green","READY");
        }, {passive: true});
        document.getElementById("START_MASTER_BUTTON").addEventListener('click', function() {
        do_mastering();
        }, {passive: true});
        document.getElementById("RESET_MASTER_BUTTON").addEventListener('click', function() {
        do_mastering(true);
        }, {passive: true});
        document.getElementById("START_MASTER_BUTTON_2").addEventListener('click', function() {
        do_mastering();
        }, {passive: true});
        document.getElementById("RESET_MASTER_BUTTON_2").addEventListener('click', function() {
        do_mastering(true);
        }, {passive: true});
        document.getElementById("START_DARK_REFERENCE_BUTTON").addEventListener('click', function() {
            if (document.getElementById("START_DARK_REFERENCE_BUTTON").innerHTML === LABEL_START_DARK) {
                do_dark_reference();
            } else {
                console.log('already performing dark reference');
            }
        }, {passive: true});
        document.getElementById("MEASUREMENT_RATE").addEventListener('input', function() {
            var sf = parseFloat(document.getElementById('MEASUREMENT_RATE').value);
            // Make sure the text is a number
            if (isNaN(sf) || typeof(sf) !== 'number') {
                document.getElementById('THRESHOLD').value = "";
            } else {
                messaging.sendMessage({args:[{command:'get_threshold_for_rate',rate:sf.toFixed(3)}]});
            }
        }, {passive: true});
        document.getElementById("SET_MEASUREMENT_RATE_BUTTON").addEventListener('click', function() {
            set_measurement_and_intensity_value('MEASUREMENT_RATE', 'Measurement rate', MIN_SAMPLING_RATE, MAX_SAMPLING_RATE, {command:'set_measuring_rate_and_threshold',threshold:parseFloat(document.getElementById('THRESHOLD').value).toFixed(3),rate:parseFloat(document.getElementById('MEASUREMENT_RATE').value)});
        }, {passive: true});
        document.getElementById("RESET_MEASUREMENT_RATE_BUTTON").addEventListener('click', function() {
            messaging.sendMessage({args:[{command:'set_manual_override',value:false}]});
            setSpanProperties($("#measurement_override_message"), "AUTOMATIC CALCULATION", 'green');
            setSpanProperties($("#measurement_override_message_2"), "AUTOMATIC<br/>CALCULATION", 'green');
        }, {passive: true});
        document.getElementById("EXPORT_DATA_BUTTON").addEventListener('click', function() {
            fromDataPlotPage = true;
            fromDataCollectionPage = false;
            $("#DATA_PLOT_PAGE").fadeOut();
            listDir(cordova.file.documentsDirectory + "data");
        }, {passive: true});
        document.getElementById("EXPORT_DATA_BUTTON_02").addEventListener('click', function() {
            fromDataPlotPage = false;
            fromDataCollectionPage = true;
            $("#TURBINE_SETUP_PAGE").fadeOut();
            let sn = processString(E4PTdata.serial_number);
            listDir(cordova.file.documentsDirectory + sn);
        }, {passive: true});
        document.getElementById("STAGE_COLLECT_BUTTON").addEventListener('click', function() {
            if (document.getElementById("STAGE_COLLECT_BUTTON").innerHTML === LABEL_GO) {
                collectionAborted = false;
                if (!masteringPerformed) {
                    //e4PtAlert('Mastering has not been performed. Please perform mastering before collecting data.');
                    e4PtConfirm("Mastering has not been performed. Do you want to collect stage data without mastering?",
                      function(idx) {
                        if (idx == 1) {
                          console.log("Proceeding without mastering");
                            confirm_collect_stage_data();
                        } else {
                          console.log("Collect stage data was cancelled.");
                        }
                      });
                } else {
                    confirm_collect_stage_data();
                }
            } else if (document.getElementById("STAGE_COLLECT_BUTTON").innerHTML === LABEL_ABORT) {
                messaging.sendMessage({args:[{command:'abort'}]});
                // ignore data response to hide DATA_PLOT
                collectionAborted = true;
                $("#PROCESSING_PAGE").fadeOut();
                resetDataCollection();
            }
        }, {passive: true});
        document.getElementById("COLLECTION_RESET_BUTTON").addEventListener('click', function() {
            confirm_reset_data_collection();
        }, {passive: true});
        document.getElementById("CUSTOMER_REPORT_BUTTON").addEventListener('click', function() {
            generate_customer_report();
        }, {passive: true});
        document.getElementById("SENSOR_STAGE").addEventListener('change', function() {
            set_stage();
            update_spacer_value();
        }, {passive: true});
        document.getElementById("SENSOR_POSITION").addEventListener('change', function() {
            set_position();
            update_spacer_value();
        }, {passive: true});
        document.getElementById("CURR_CASE_THICKNESS").addEventListener('change', function() {
            update_spacer_value();
        }, {passive: true});
        document.getElementById("SENSOR_PARAMS_UPDATE_BUTTON").addEventListener('click', function() {
            authorizeSensorParamsUpdate();
        }, {passive: true});
        document.getElementById("FILE_DELETE_BUTTON").addEventListener('click', function() {
            deleteMultipleFiles();
        }, {passive: true});
        document.getElementById("FILE_EXPORT_BUTTON").addEventListener('click', function() {
            multipleFileDownloadFunction();
        }, {passive: true});
        document.getElementById("DATA_DETAILS_BUTTON").addEventListener('click', function() {
            populateDetailsTable();
        }, {passive: true});
        document.getElementById("DETAILS_EXPORT_BUTTON").addEventListener('click', function() {
            let prompt = "Email or Upload Files?";
            e4PtPrompt(prompt, exportDetailsFile, "Get File", ["Email","Upload to Box","Cancel"]);
        }, {passive: true});
        /*document.getElementById("MANUAL_OVERRIDE").addEventListener('click', function() {
            overrideSettings();
        }, {passive: true});*/
        document.getElementById("SPACER_THUMBNAIL").addEventListener('click', function() {
            showSpacerImage();
        }, {passive: true });
        document.getElementById("LOG_BUTTON").addEventListener('click', function() {
            showLog();
        }, {passive: true });
        document.getElementById("LOG_CLEAR_BUTTON").addEventListener('click', function() {
            clearLog();
        }, {passive: true});
        document.getElementById("LOG_EXPORT_BUTTON").addEventListener('click', function() {
            exportLog();
        }, {passive: true});
        document.getElementById("CALCULATE_RPM_BUTTON").addEventListener('click', function() {
             calculateRPM();
        }, {passive: true});
        document.getElementById("LOCATION_BUTTON").addEventListener('click', function() {
            showLocationImages();
        }, {passive: true});
        document.getElementById("EDIT_BUTTON").addEventListener('click', function() {
            edit();
        }, {passive: true});
        document.getElementById("EDIT_SAVE_BUTTON").addEventListener('click', function() {
            edit_save();
        }, {passive: true});
        document.getElementById("CLEARANCE_OVERRIDE_BUTTON").addEventListener('click', function() {
            clearance_override();
        }, {passive: true});
        document.getElementById("CLEARANCE_OVERRIDE_SAVE_BUTTON").addEventListener('click', function() {
            clearance_override_save();
        }, {passive: true});
        document.getElementById("FRAME_DATA_CLEAR_BUTTON").addEventListener('click', function() {
            clearFrameData();
        }, {passive: true});
        document.getElementById("OPEN_SETTINGS_BUTTON").addEventListener('click', function() {
            messaging.sendMessage({args:[{command:'open_settings'}]});
        }, {passive: true});
        document.getElementById("SENSOR_SELECTION").addEventListener('change', function() {
            getSensorParametersForSensorSelection(document.getElementById("SENSOR_SELECTION").value);
        }, {passive: true});
        document.getElementById("MASTER_FIXTURE_HEIGHT").addEventListener('change', function() {
            updateMasteringValue();
            updateMasteringOffset();
            enableMasteringValuesForEditing(true);
        }, {passive: true});
        document.getElementById("MASTERING_VALUE").addEventListener('change', function() {
            updateMasteringOffset();
            enableMasteringValuesForEditing(true);
        }, {passive: true});
        document.getElementById("SENSOR_LENGTH").addEventListener('change', function() {
            updateMasteringValue();
            updateMasteringOffset();
            enableMasteringValuesForEditing(true);
        }, {passive: true});
        document.getElementById("SMR").addEventListener('change', function() {
            updateMasteringValue();
            updateMasteringOffset();
            enableMasteringValuesForEditing(true);
        }, {passive: true});
        document.getElementById("SENSOR_MR").addEventListener('change', function() {
            enableMasteringValuesForEditing(true);
        }, {passive: true});
        document.getElementById("MASTER_OFFSET").addEventListener('change', function() {
            enableMasteringValuesForEditing(true);
        }, {passive: true});
        
        // Wait (0.9s) for the page load to complete, then get the file system.
        setTimeout(function() {
            window.requestFileSystem  = window.requestFileSystem || window.webkitRequestFileSystem;
            window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, gotFS, fsFail);
        }, 900);
        
        // Wait (2s) and update connection status if connected before menu is opened
        setTimeout(function() {
            //getConnectionMode();
            checkConnectionStatus();
        }, 2000);
    });

    function fadeOutAll() {
        $("#PROCESSING_PAGE").fadeOut();
        $("#DATA_PLOT_PAGE").fadeOut();
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
        $("#ARCHIVED_DATA_PAGE").fadeOut();
        $("#FILE_CHOOSER_PAGE").fadeOut();
        $("#DATA_DETAILS_PAGE").fadeOut();
        $("#LOCATION_PAGE").fadeOut();
    }

    function gotFS(fileSystem) {
        // save the file system for later access
        appDir = cordova.file.applicationDirectory;
        console.log("@gotFS: appDir = ", appDir);
        window.rootFS = fileSystem.root;
        fsRoot = window.rootFS.nativeURL;
        fsRoot = fsRoot.replace("file://","");
        console.log("@gotFS: fsRoot = ", fsRoot);
        
        // Attempt to load files from Inbox,
        // because AppDelegate method fails when app has not yet been loaded
        // so this is specifically for the case when the app starts for the first time
        window.resolveLocalFileSystemURL(cordova.file.documentsDirectory + "Inbox", function(dirEntry) {
            dirEntry.createReader().readEntries(function(entries) {
                entries.forEach(function(entry) {
                    if (entry.isFile && entry.name.endsWith(".json")) {
                        this(entry);
                    }
                }, loadJSONFile);
            });
        });
    }

    function fsFail(err) {
        console.log("Failed to get file system: ", err);
    }
    
    function processString(s) {
        // replace spaces with _ and : with -
        return s.replace(/\s+/g, '_').replace(/:/g, '-');
    }
    
    function edit() {
        console.log("@edit");
        // update values from
        document.getElementById("FRAME_SIZE_EDIT").value = document.getElementById("FRAME_SIZE").value;
        document.getElementById("SERIAL_NUMBER_EDIT").value = document.getElementById("SERIAL_NUMBER").value;
        document.getElementById("CUSTOMER_EDIT").value = document.getElementById("CUSTOMER").value;
        document.getElementById("SITE_EDIT").value = document.getElementById("SITE").value;
        document.getElementById("OPERATOR_EDIT").value = document.getElementById("OPERATOR").value;
        document.getElementById("UNITS_EDIT").value = document.getElementById("UNITS").value;
        editModal.show();
    }
    
    function edit_save() {
        console.log("@edit_save");
        editModal.hide();
        // changing frame will erase data
        if (document.getElementById("FRAME_SIZE_EDIT").value !== document.getElementById("FRAME_SIZE").value) {
            document.getElementById("FRAME_SIZE").value = document.getElementById("FRAME_SIZE_EDIT").value;
            document.getElementById("FRAME_SIZE").selectedIndex = document.getElementById("FRAME_SIZE_EDIT").selectedIndex;
            document.getElementById("HEADER_FRAME").innerHTML = document.getElementById("FRAME_SIZE_EDIT").value;
            setupCasingThicknessTable(null);
            document.getElementById("FRAME_DEFAULT_SENSOR").value = current_frame_data.default_sensor;
            record_casing_thickness();
            send_scan_metadata(true, true);
            turbine_setup();
        }
        if (document.getElementById("SERIAL_NUMBER_EDIT").value !== document.getElementById("SERIAL_NUMBER").value) {
            document.getElementById("SERIAL_NUMBER").value = document.getElementById("SERIAL_NUMBER_EDIT").value;
            document.getElementById("HEADER_SERIAL").innerHTML = document.getElementById("SERIAL_NUMBER_EDIT").value;
            send_scan_metadata(true, true);
        }
        if (document.getElementById("CUSTOMER_EDIT").value !== document.getElementById("CUSTOMER").value) {
            document.getElementById("CUSTOMER").value = document.getElementById("CUSTOMER_EDIT").value;
            document.getElementById("HEADER_CUSTOMER").innerHTML = document.getElementById("CUSTOMER_EDIT").value;
            send_scan_metadata(true, true);
        }
        if (document.getElementById("SITE_EDIT").value !== document.getElementById("SITE").value) {
            document.getElementById("SITE").value = document.getElementById("SITE_EDIT").value;
            document.getElementById("HEADER_SITE").innerHTML = document.getElementById("SITE_EDIT").value;
            send_scan_metadata(true, true);
        }
        if (document.getElementById("OPERATOR_EDIT").value !== document.getElementById("OPERATOR").value) {
            document.getElementById("OPERATOR").value = document.getElementById("OPERATOR_EDIT").value;
            document.getElementById("HEADER_SITE").innerHTML = document.getElementById("OPERATOR_EDIT").value;
            send_scan_metadata(true, true);
        }
        if (document.getElementById("UNITS_EDIT").value !== document.getElementById("UNITS").value) {
            document.getElementById("UNITS").value = document.getElementById("UNITS_EDIT").value;
            document.getElementById("HEADER_UNITS").innerHTML = document.getElementById("UNITS_EDIT").value;
            send_scan_metadata(true, true);
        }
        send_scan_metadata(false, true);
        $("#TURBINE_SETUP_PAGE").fadeIn();
    }

    function showSpacerImage() {
        console.log("@showSpacerImage");
        let imageName = document.getElementById("SPACER_THUMBNAIL").getAttribute("src");
        let spacerName = document.getElementById("SPACER_THUMBNAIL").getAttribute("alt");
        console.log("imageName: ", imageName);
        console.log("spacerName: ", spacerName);
        document.getElementById("SPACER_NAME").innerHTML = spacerName;
        document.getElementById("SPACER_IMAGE").setAttribute("src", imageName);
        document.getElementById("SPACER_IMAGE").setAttribute("alt", spacerName);
        spacerModal.show();
    }
    
    function showLocationImages() {
        console.log("@showLocationImages");
        let locationName = document.getElementById("FRAME_SIZE").value;
        // frame image
        let locationImage = document.getElementById("LOCATION_IMAGE");
        let imageStr = "";
        if (typeof current_frame_data.image !== 'undefined') {
            let frameImageName = 'img/frames/' + current_frame_data.image + '.png';
            imageStr = '<img class="img-fluid" src="' + frameImageName + '">';
        } else {
            imageStr += '<h5><span class="badge bg-warning text-dark">No Frame Image</span></h5>';
        }
        locationImage.innerHTML = imageStr;
        // stage images
        let tabs = document.getElementById("LOCATION_TABS");
        let content = document.getElementById("LOCATION_CONTENT");
        let tabStr = "";
        let contentStr = "";
        let isFirst = true;
        // only include one tab/image per stage
        if (typeof current_frame_data.stage_images !== 'undefined') {
            for (let stageId of Object.keys(current_frame_data.stage_images)) {
                let stageImage = current_frame_data.stage_images[stageId];
                tabStr += '<li class="nav-item" role="presentation"><button class="nav-link' + (isFirst ? ' active' : '') + '" id="tab' + stageId + '" data-bs-toggle="tab" data-bs-target="#content' + stageId + '" type="button" role="tab" aria-controls="content' + stageId + '" aria-selected="' + isFirst + '">Stage ' + stageId + '</button></li>';
                contentStr += '<div class="tab-pane show' + (isFirst ? ' active' : '') + '" id="content' + stageId + '" role="tabpanel" aria-labelledby="tab' + stageId + '">';
                if (stageImage) {
                    let stageImageName = 'img/frames/' + stageImage + '.png';
                    contentStr += '<img class="img-fluid" src="' + stageImageName + '">';
                } else {
                    contentStr += '<h5><span class="badge bg-warning text-dark">No Stage Image</span></h5>';
                }
                contentStr += '</div>';
                isFirst = false;
            }
        } else {
            contentStr += '<h5><span class="badge bg-warning text-dark">No Stage Images</span></h5>';
        }
        tabs.innerHTML = tabStr;
        content.innerHTML = contentStr;
        $("#TURBINE_SETUP_PAGE").fadeOut();
        $("#LOCATION_PAGE").fadeIn();
    }
    
    function showLog() {
        $("#PROCESSING_PAGE").fadeIn();
        $("#LOG_MESSAGE_COUNT").text(logMessages.length);
        var displayCount = Math.min(logMessages.length, MAX_LOG_MESSAGES);
        $("#MAX_MESSAGE_COUNT").text(displayCount);
        var elementID = "LOG_TABLE_BODY";
        var prev_tbody = document.getElementById(elementID);
        var tbody = document.createElement("tbody");
        tbody.setAttribute("id",elementID);
        for (var i = displayCount - 1; i >= 0; i--) {
            var new_row = tbody.insertRow(-1);
            
            var cell1 = new_row.insertCell(-1);
            cell1.innerHTML = logMessages[i].timestamp;

            var cell3 = new_row.insertCell(-1);
            cell3.innerHTML = logMessages[i].message;
        }
        prev_tbody.parentNode.replaceChild(tbody, prev_tbody);
        setTimeout(function() {
            $("#PROCESSING_PAGE").fadeOut();
            logModal.show();
        }, 500);
    }
    
    function clearLog() {
        logMessages = [];
        showLog();
    }
    
    function exportLog() {
        $("#PROCESSING_PAGE").fadeIn();
        let contents = "";
        for (let i=0; i<logMessages.length; i++) {
            contents += logMessages[i].timestamp + ": " + logMessages[i].message;
            contents += "\n";
        }
        let targetFolder = "data"; // default directory
        let logDate = new Date().toJSON().slice(0, 19).replace(/-/g,'').replace(/:/g,'').replace('T','');
        let fileName = LOG_FILE_PREFIX + "_" + logDate + ".txt";
        let fileUrl = cordova.file.documentsDirectory + targetFolder + "/" + fileName;
        writeToFile(targetFolder, fileName, contents, function() {
            $("#PROCESSING_PAGE").fadeOut();
            fileDownloadFunction(fileUrl);
        });
    }
    
    function calculateRPM() {
        console.log('@calculateRPM');
        position = document.getElementById("SENSOR_POSITION").value;
        casing_thickness = document.getElementById("CURR_CASE_THICKNESS").value;
        if (position && casing_thickness) {
            if (messaging.usesPlugin) {
                e4PtConfirm("Note: please ensure that you have selected the cell that represents the location of the sensor in the turbine.\n\nThe app will collect data for 60 seconds and then calculate RPM. Do you wish to continue?",
                    function(idx) {
                        if (idx === 1) {
                            fromCalculateRPM = true;
                            setButtonProperties($("#CALCULATE_RPM_BUTTON"), LABEL_CALCULATING, 'yellow');
                            requestE4PtData(60.0);
                        }
                    });
            } else {
                fromCalculateRPM = true;
                setButtonProperties($("#CALCULATE_RPM_BUTTON"), LABEL_CALCULATING, 'yellow');
                requestE4PtData(60.0);
            }
        } else {
            e4PtAlert('No position or casing thickness, could not calculate RPM.');
        }
    }
    
    function getData() {
        console.log('@getData');
        fromGetData = true;
        fromDataCollectionPage = false;

        var acquisitionTime = null;
        doDBSave = false;
        console.log("@GET_DATA_BUTTON: Prompting.");
        var nav = navigator.notification;
        if (nav != null) {
            // We have plugins so we're in Cordova.  Use the Cordova notification.
            console.log("@GET_DATA_BUTTON: Cordova Prompt");
            // For issue #69: added additional text to the prompt for acquisition time
            navigator.notification.prompt('Raw data is the displacement from the sensor with an unknown (default) reference point. This should be used only when relative data is desired.\n\nPlease enter the acquisition time in seconds.\n\nSelect \'Cancel\' to view local data files.',
                                          acquisitionTimePromptCallback,
                                          'Acquisition Time',
                                          ['Ok','Cancel'],
                                          '3');
        } else {
            // No plugins, so we must not be in Cordova. Use a standard prompt.
            console.log("@GET_DATA_BUTTON: Windows Prompt");
            // For issue #69: added additional text to the prompt for acquisition time
            acquisitionTime = window.prompt("Raw data is the displacement from the sensor with an unknown (default) reference point. This should be used only when relative data is desired.\n\nPlease enter the acquisition time in seconds.\n\nSelect \'Cancel\' to view local data files.", "3");
            acquisitionTimePromptCallback({"input1":acquisitionTime});
        }
    }
    
    function resetDataCollection() {
        setButtonProperties($("#START_DARK_REFERENCE_BUTTON"), LABEL_START_DARK, 'blue');
        displayGoButton();
        setIndicatorColor("green");
        $("#REV_PROGRESS_BAR").hide();
        $("#STATUS_BAR").show();
    }
    
    function startProgressBar() {
        $("#REV_PROGRESS")
              .css("width", 0 + "%")
              .attr("aria-valuenow", 0)
              .text(0 + "%");
        $("#REV_PROGRESS_BAR").show();
        $("#STATUS_BAR").hide();
    }

    // Clear all the current data to start fresh.
    function clearFrameData() {
        // First, confirm that this is what the user want.
        e4PtConfirm("Are you sure you want to clear all data and start a new collection?",
                 function(idx) {
                   // 1=OK, 2=Cancel
                   if (idx == 1) {
                     console.log("Clearing all data.");
                     // First clear the data E4PTdata structure
                     E4PTdata.ofs_id = "";
                     E4PTdata.frame = "";
                     E4PTdata.serial_number = "";
                     E4PTdata.data_name = "";
                     E4PTdata.description = "";
                     E4PTdata.customer = "";
                     E4PTdata.site_name = "";
                     E4PTdata.inspection_type = "";
                     E4PTdata.operator = "";
                     E4PTdata.units = "";
                     E4PTdata.state = "";
                     E4PTdata.temperature_units = "";
                     E4PTdata.final = {
                         "SCAN":"",
                     };
                     E4PTdata.date =  "";
                     E4PTdata.time =  "";
                     E4PTdata.sets = [];
                     E4PTdata.locs = [];
                     E4PTdata.minima = [];
                     E4PTdata.data = [];
                     E4PTdata.quality = [];
                     E4PTdata.clearance = "";
                     E4PTdata.manualOverride = false;
                     E4PTdata.overrideName = "";
                     E4PTdata.overrideSSO = "";
                     E4PTdata.max_clr = "";
                     E4PTdata.min_clr = "";
                     E4PTdata.med_clr = "";
                     E4PTdata.std_clr = "";
                     E4PTdata.alreadyOnLDB = "false";
                     E4PTdata.pouchdb_id =  "";
                     E4PTdata.details_filename = "";
                     E4PTdata.report_filename = "";
                     E4PTdata.email_filename = "";
                     // Clear the entries on the page
                     document.getElementById("FRAME_SIZE").selectedIndex = 0;
                     document.getElementById("SERIAL_NUMBER").value = "";
                     document.getElementById("CUSTOMER").value = "";
                     document.getElementById("SITE").value = "";
                     document.getElementById("OPERATOR").value = "";
                     document.getElementById("UNITS").selectedIndex = 0;
                     document.getElementById("TURBINE_STATE").selectedIndex = 0;
                     document.getElementById("TEMPERATURE_UNITS").selectedIndex = 0;
                     document.getElementById("AMBIENT_TEMPERATURE").value = "";
                     document.getElementById("DESCRIPTION").value = "";
                     setupCasingThicknessTable(null);
                     document.getElementById("FRAME_DEFAULT_SENSOR").value = current_frame_data.default_sensor;
                   } else {
                     console.log("Database clear was cancelled.");
                   }
               });
    }

    function setupCasingThicknessTable(callback) {
        console.log('@setupCasingThicknessTable');
        // Get frame type
        let frm_idx = document.getElementById("FRAME_SIZE").selectedIndex;
        current_frame_data = frame_data[frm_idx];
        current_stage_index = 0;
        current_stage = current_frame_data.stage[current_stage_index];
        current_position_index = 0;
        current_position = current_frame_data.position[current_stage][current_position_index];
        
        // Update selected_frame_data for computing RPM and remembering it when we come back to the page
        selected_frame_data.frameIdx = frm_idx;
        selected_frame_data.stageInfoIdx = current_stage_index;
        selected_frame_data.frameName = current_frame_data.frame;
        selected_frame_data.stageName = current_stage;
        // use index instead of name due to *.* stages
        //selected_frame_data.bladeCount = current_frame_data.stage_info[current_stage].blade_count;
        selected_frame_data.bladeCount = Object.values(current_frame_data.stage_info)[current_stage_index].blade_count;
        
        let pos = current_frame_data.position;
        let tbl = document.getElementById("CASING_THICKNESS_TABLE");
        let stageText = "STAGE";
        let htmlStr = "";
        for (let p of Object.keys(pos)) {
            //console.log("stageText:  ", stageText);
            console.log("current_frame_data.position: ", p);
            htmlStr += '<tr>';
            htmlStr += '<th class="align-middle">' + stageText + '</th>';
            stageText = "";
            console.log("pos[p]: ", pos[p]);
            for (let j=0; j<pos[p].length; j++) {
                if (POSITION_DISPLAY_MODE == 'TEXT') {
                    htmlStr += '<th class="align-middle" scope="row">' + pos[p][j] + '</th>';
                } else if (POSITION_DISPLAY_MODE == 'ICON') {
                    htmlStr += '<th class="align-middle">' + ARROW_ICONS[pos[p][j]] + '</th>';
                } else if (POSITION_DISPLAY_MODE == 'BOTH') {
                    htmlStr += '<th class="align-middle" scope="row">' + ARROW_ICONS[pos[p][j]] + '&nbsp;' + pos[p][j] + '</th>';
                }
            }
            htmlStr += '</tr>';
            htmlStr += '<tr>';
            htmlStr += '<td scope="row">' + p + '</td>';
            for (let j=0; j<pos[p].length; j++) {
                let casingThickness_el_id = p + '_' + pos[p][j];
                htmlStr += '<td><input class="form-control" type="number" inputmode="decimal" id="' + casingThickness_el_id + '" value=""/></td>';
            }
            htmlStr += '</tr>';
        }
        tbl.innerHTML = htmlStr;
        if (callback != null) {
            callback(); // execute the callback if there is one.
        }
    }

    // unused, called on MANUAL_OVERRIDE checked
    /*function overrideSettings() {
        manualOverride = document.getElementById("MANUAL_OVERRIDE").checked;
        console.log("@overrideSettings: ", manualOverride);
        messaging.sendMessage({args:[{command:'set_manual_override',value:manualOverride}]});
        if (manualOverride) {
            $("#TURBINE_SETUP_PAGE").fadeOut();
            // set flag to show DATA COLLECTION page on close
            fromGetData = false;
            fromDataCollectionPage = true;
            $("#SENSOR_SETUP_PAGE").fadeIn();
        }
    }*/

    function acquisitionTimePromptCallback(results) {
        console.log("@acquisitionTimePromptCallback");
        if (results.buttonIndex > 1) {
            // display local files if Get Data prompt is cancelled
            listDir(cordova.file.documentsDirectory + "data");
            return;
        }
        console.log("input1: ", results.input1);
        current_frame_data = [];
        acquisitionTime = null;
        if (results.input1.includes("rpm") || results.input1.includes("RPM")) {
            // RPM was specified
            acquisitionTime = results.input1;
        } else {
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
        if (results.buttonIndex > 1) {
            return;
        }
        console.log("input1: ", results.input1);
        acquisitionTime = null;
        if (results.input1.includes("rpm") || results.input1.includes("RPM")) {
            // RPM was specified
            acquisitionTime = results.input1;
            console.log("w/ RPM: ", acquisitionTime);
        } else {
            acquisitionTime = parseFloat(results.input1);
            // Append rpm if its not there already.
            acquisitionTime = acquisitionTime.toString() + "rpm";
            console.log("w/o RPM: ", acquisitionTime);
        }
        //savedRPM = acquisitionTime.replace("rpm","");
        if (acquisitionTime != null) {
            let checkRPM = parseFloat(acquisitionTime.replace("rpm",""));
            if (checkRPM < MIN_RPM || checkRPM > MAX_RPM) {
                e4PtAlert("RPM must be between " + MIN_RPM + " and " + MAX_RPM + ".");
                /*if (checkRPM < MIN_RPM) {
                    document.getElementById("MEASUREMENT_RPM").value = MIN_RPM;
                } else if (checkRPM > MAX_RPM) {
                    document.getElementById("MEASUREMENT_RPM").value = MAX_RPM;
                }*/
            } else {
            //if (Number.isFinite(acquisitionTime)) {
            //    if (acquisitionTime > 0) {
                    var sn = document.getElementById("SERIAL_NUMBER").value;
                    var frame = document.getElementById("FRAME_SIZE").value;
                    let casing_thickness = document.getElementById("CURR_CASE_THICKNESS").value;
                    let ct_id = current_stage + "_" + current_position; // get element id for casing thickness
                    E4PTdata.turbine_casing_thicknesses[ct_id] = casing_thickness;
                    document.getElementById(ct_id).value = casing_thickness;
                    if (casing_thickness.length > MAX_STR_LEN) {
                        casing_thickness = casing_thickness.substr(0,MAX_STR_LEN);
                    }
                    var spacer_thickness = document.getElementById("SPACER_THICKNESS").value;
                    if (spacer_thickness.length > MAX_STR_LEN) {
                        spacer_thickness = spacer_thickness.substr(0,MAX_STR_LEN);
                    }
                    requestE4PtDataWithMetaData(acquisitionTime, frame, sn, current_stage, current_position, casing_thickness, spacer_thickness, sensorSettings.get('master_offset'), document.getElementById("CLEARANCE_CALCULATION_METHOD").value);
            //    }
            //}
            }
        }
    }

    function toggleMenu() {
        console.log("fsRoot: ", fsRoot);

        $("#wrapper").toggleClass("toggled");
        //$("header").toggleClass("toggled");
        //$("footer").toggleClass("toggled");
        
        if (!menu_open) {
            if (!serialConnected) {
                e4PtAlert('Connecting...\nPlease wait for indicator to turn green before proceeding.');
                // ensure that the connection state updates in case the original message was not received
                checkConnectionStatus();
            }
            messaging.sendMessage({args:[{command:'get_version'}]});
            //checkConnectionStatus();
        }
        menu_open = !menu_open;
        
        /*$("body").css("overflow-x", "hidden");
        setTimeout(function () {
            $("body").css("overflow-x", "auto");
        }, 1500);*/
    }

    function show_FRD() {
        fileviewer2.open(appDir + FRD_FILE, {
                error : function(e) {
                    console.log('Error status: ' + e.status + ' - Error message: ' + e.message);
                },
                success : function () {
                    console.log('file opened successfully');
                }
            }
        );
    }

    function hide_FRD() {
        fileviewer2.dismiss();
    }
    
    // unused
    function getOffsetAdjustment() {
        console.log("@getOffsetAdjustment");
        messaging.sendMessage({args:[{command:'get_offset_adjustment'}]});
    }

    function getSensorParameters() {
        console.log("@getSensorParameters");
        messaging.sendMessage({args:[{command:'get_sensor_parameters'}]});
    }
    
    function getConnectionMode() {
        console.log("@getConnectionMode");
        messaging.sendMessage({args:[{command:'get_connection_mode'}]});
    }
    
    function checkConnectionStatus() {
        console.log("@checkConnectionStatus");
        messaging.sendMessage({args:[{command:'check_connection_status'}]});
    }
    
    function update_connection_mode(mode) {
        console.log("@update_connection_mode: ", mode);
        $('#CONNECTION_NAME').text(mode.toUpperCase());
        
        if (mode === 'demo') {
            console.log('DEMO mode: ignore mastering');
            masteringPerformed = true;
        }
    }

    function set_connection_mode() {
        console.log("@set_connection_mode");
        var mode = document.getElementById('CONN_SELECTION').value;
        update_connection_mode(mode);

        pluginMessage({type:'status',status:'disconnected',noAlert:true});
        messaging.sendMessage({args:[{command:'set_connection_mode',mode:mode}]});
    }

    
    function authorizeControllerSettingsUpdate() {
        // Prompt user for password.
        var nav = navigator.notification;
        if (nav != null) {
            // We have plugins so we're in Cordova.  Use the Cordova notification.
            navigator.notification.prompt('Please enter the password.',
                                          confirmControllerSettingsPassword,
                                          'Enter Password',
                                          ['Ok','Cancel'],
                                          '');
        } else {
            // No plugins, so we must not be in Cordova. Use a standard prompt.
            let pw = window.prompt("Please enter the password.", "1");
            confirmSensorParamsPassword({"input1":pw});
        }
    }

    function confirmControllerSettingsPassword(results) {
        if (results.buttonIndex > 1) {
            return;
        }
        if (results.input1 == UPDATE_SETTINGS_PASSWORD) {
            configureController();
        } else {
            e4PtAlert("Invalid password.");
        }
    }
    
    function configureController() {
        console.log('@configureController');
        if (!serialConnected) {
            e4PtAlert('Please connect to the controller before proceeding.');
        } else {
            if (messaging.usesPlugin) {
                e4PtConfirm("Are you sure you want to configure the controller?",
                            function(idx) {
                                if (idx === 1) {
                                    messaging.sendMessage({args:[{command:'configure_controller'}]});
                                }
                            });
            } else {
                messaging.sendMessage({args:[{command:'configure_controller'}]});
            }
        }
    }
    
    function readSensorParameters() {
        console.log('@readSensorParameters');
        let mode = document.getElementById("CONN_SELECTION").value;
        if (mode != 'demo') {
            setButtonProperties($("#READ_SENSOR_PARAMETERS_BUTTON"), LABEL_LOADING_PARAMS, 'yellow');
            messaging.sendMessage({args:[{command:'read_sensor_parameters'}]});
        }
    }

    function record_casing_thickness() {
        console.log('@record_casing_thickness');
        let frm_idx = document.getElementById("FRAME_SIZE").selectedIndex;
        current_frame_data = frame_data[frm_idx];
        let pos = current_frame_data.position;
        E4PTdata.turbine_casing_thicknesses = {}; // Clear old casing thicknesses
        for (let p of Object.keys(pos)) {
            for (let j=0; j<pos[p].length; j++) {
                let casingThickness_el_id = p + '_' + pos[p][j];
                let ct_el = document.getElementById(casingThickness_el_id);
                let casethickness = ct_el.value;
                E4PTdata.turbine_casing_thicknesses[casingThickness_el_id] = casethickness;
            }
        }
        
        // Clear out any old value in this existing location.
        // This is needed to break a cycle where previous data in this element prevents
        // new data from E4PTdata.turbine_casing_thicknesses from updating it.
        document.getElementById("CURR_CASE_THICKNESS").value = "";
        console.log("E4PTdata.turbine_casing_thicknesses: ", E4PTdata.turbine_casing_thicknesses);
    }

    function send_scan_metadata(reset, updatingExisting = false) {
      console.log('@send_scan_metadata');
      // Set element suffix if we are updating existing measurement
      var suffix = (updatingExisting ? '_EDIT' : '');

      // First make sure the user has input some metadata.
      E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER" + suffix).value;
      if (E4PTdata.serial_number.length == 0) {
        e4PtAlert("Serial Number is required.");
        return;
      }
        
      if (!updatingExisting) {
        $("#SETUP_PAGE").fadeOut();
        $("#RESULTS_PAGE").fadeOut();
        $("#DATA_PLOT_PAGE").fadeOut();
        $("#INITIALIZE_SENSOR_PAGE").fadeIn();
        $("#LOCAL_DATA_PAGE").fadeOut();
        $("#ARCHIVED_DATA_PAGE").fadeOut();
      }

      // Here we get values from the UI, but we make sure they don't overrun bounds.
      if (E4PTdata.serial_number.length > MAX_STR_LEN) {
        E4PTdata.serial_number = E4PTdata.serial_number.substr(0,MAX_STR_LEN);
      }

      var frm_idx = document.getElementById("FRAME_SIZE" + suffix).selectedIndex;
      E4PTdata.frame = frame_data[frm_idx].frame;

      E4PTdata.customer = document.getElementById("CUSTOMER" + suffix).value;
      if (E4PTdata.customer.length > MAX_STR_LEN) {
          E4PTdata.customer = E4PTdata.customer.substr(0,MAX_STR_LEN);
      }

      E4PTdata.site_name = document.getElementById("SITE" + suffix).value;
      if (E4PTdata.site_name.length > MAX_STR_LEN) {
          E4PTdata.site_name = E4PTdata.site_name.substr(0,MAX_STR_LEN);
      }

      E4PTdata.operator = document.getElementById("OPERATOR" + suffix).value;
      if (E4PTdata.operator.length > MAX_STR_LEN) {
          E4PTdata.operator = E4PTdata.operator.substr(0,MAX_STR_LEN);
      }

      E4PTdata.units = document.getElementById("UNITS" + suffix).value;
      E4PTdata.state = document.getElementById("TURBINE_STATE").value;
      E4PTdata.temperature_units = document.getElementById("TEMPERATURE_UNITS").value;

      // Get a timestamp in prepartion for saving.
      let d = new Date();
      let hh = ( '0' + d.getHours()).substr(-2);
      let mm = ( '0' + d.getMinutes()).substr(-2);
      let ss = ( '0' + d.getSeconds()).substr(-2);
      let timeStr = hh + ":" + mm;
      let dateStr = monthNames[d.getMonth()] + "-" + d.getDate() + "-" + d.getFullYear();
      E4PTdata.date = dateStr;
      E4PTdata.time = timeStr;

      if (reset) {
          if (!updatingExisting) {
            E4PTdata.pouchdb_id = "";  // setting this to an empty string will cause a new DB entry to be created.
          }
          reset_data_collection();
      }
      addDBEntry(E4PTdata); // Save to the database here so we don't lose this data.
        
      initialize_sensor();
    }

    function initialize_sensor() {
        console.log("@initialize_sensor");
        setMasterMessage2("green", "Ready");
    }

    function confirm_new_or_continue() {
        let msg = "Continue collecting data for a turbine, or clear data and start a new collection? Starting a new collection will create a new entry in the database with the same serial number."
        console.log ("previous_frame: ", previous_frame);
        console.log ("current_frame_data.frame: ", current_frame_data.frame);

        if ((E4PTdata.pouchdb_id.length > 0) && (previous_frame == current_frame_data.frame) ){
            previousFrameWas = current_frame_data.frame
            try{
                navigator.notification.confirm(
                    String(msg),            // message
                    function(idx) {
                        if (idx == 1) { // Continue
                            send_scan_metadata(false);
                        } else if (idx == 2) { // Start New
                            send_scan_metadata(true);
                        } else if (idx == 3) { // Cancel
                            return; // Do nothing
                        }
                    }, // callback to invoke with index of button pressed
                    'Confirm',                     // title
                    ['Continue','Start New', 'Cancel']         // buttonLabels: 1=OK, 2=Cancel
                );
            } catch (err) {
                if (confirm(String(msg))) {
                    console.log("@confirm_new_or_continue: Error caught(1): ", msg);
                } else {
                    console.log("@confirm_new_or_continue: Error caught(2): ", msg);
                }
            }
        } else {
            send_scan_metadata(true);
            previous_frame = current_frame_data.frame
        }
        return;
    }

    function turbine_setup() {
        console.log('@turbine_setup');
        $("#TITLE_BAR").text("Data Collection");
        $("#TURBINE_SETUP_PAGE").fadeIn();
        savedRPM = computedRPM;

        // Get frame type
        var frm_idx = document.getElementById("FRAME_SIZE").selectedIndex;
        current_frame_data = frame_data[frm_idx];
        document.getElementById("FRAME_DEFAULT_SENSOR").value = current_frame_data.default_sensor;

        // Setup the Stage options
        set_stage_information();

        // Setup the position options
        // TODO: called already by set_stage_information()
        set_position_information();
        current_position_index = 0;
        current_position = current_frame_data['position'][current_stage][current_position_index];
        highlight_cell(current_position, current_stage);
        
        update_spacer_value();

        var units = document.getElementById("UNITS").value.toUpperCase();
        if (units.includes('IN')) {
            document.getElementById("CURR_CASE_THICKNESS_LABEL").innerHTML = "in";
            document.getElementById("SPACER_THICKNESS_LABEL").innerHTML = "in";
        } else if (units.includes('MM')) {
            document.getElementById("CURR_CASE_THICKNESS_LABEL").innerHTML = "mm";
            document.getElementById("SPACER_THICKNESS_LABEL").innerHTML = "mm";
        }
        var temperatureUnits = document.getElementById("TEMPERATURE_UNITS").value.toUpperCase();
        if (temperatureUnits.includes('FAHRENHEIT')) {
            document.getElementById("AMBIENT_TEMPERATURE_LABEL").innerHTML = "°F";
        } else {
            document.getElementById("AMBIENT_TEMPERATURE_LABEL").innerHTML = "°C";
        }
        let customer = document.getElementById("CUSTOMER").value;
        let site = document.getElementById("SITE").value;
        let dateStr = E4PTdata.date;
        let d = new Date();
        let hh = ('0' + d.getHours()).substr(-2);
        let mm = ('0' + d.getMinutes()).substr(-2);
        let ss = ('0' + d.getSeconds()).substr(-2);
        let timeStr = hh + ":" + mm;
        if (dateStr.length == 0) {
            dateStr = monthNames[d.getMonth()] + "-" + d.getDate() + "-" + d.getFullYear();
        }
        document.getElementById("HEADER_DATETIME").innerHTML = dateStr;

        document.getElementById("HEADER_FRAME").innerHTML = E4PTdata.frame;
        document.getElementById("HEADER_SERIAL").innerHTML = E4PTdata.serial_number;
        document.getElementById("HEADER_CUSTOMER").innerHTML = customer;
        document.getElementById("HEADER_SITE").innerHTML = site;
        document.getElementById("HEADER_OPERATOR").innerHTML = E4PTdata.operator;
        document.getElementById("HEADER_UNITS").innerHTML = E4PTdata.units;
        
        document.getElementById("FRAME_SIZE_EDIT").value = document.getElementById("FRAME_SIZE").value;
        document.getElementById("SERIAL_NUMBER_EDIT").value = document.getElementById("SERIAL_NUMBER").value;
        document.getElementById("CUSTOMER_EDIT").value = document.getElementById("CUSTOMER").value;
        document.getElementById("SITE_EDIT").value = document.getElementById("SITE").value;
        document.getElementById("OPERATOR_EDIT").value = document.getElementById("OPERATOR").value;
        document.getElementById("UNITS_EDIT").value = document.getElementById("UNITS").value;

        updateSensorHeaderMessage();
        checkSensorSelection();
    }

    function updateSensorHeaderMessage() {
        document.getElementById("SL_CONFIG_MSG").innerHTML = sensorSettings.get('sensor_length') + "&quot; SL";
        document.getElementById("SMR_CONFIG_MSG").innerHTML = sensorSettings.get('start_measurement_range') + "mm SMR";
        document.getElementById("MR_CONFIG_MSG").innerHTML = sensorSettings.get('sensor_mr') + "mm MR";
        document.getElementById("MFH_CONFIG_MSG").innerHTML = sensorSettings.get('master_fixture_height') + "&quot; MFH";
        document.getElementById("MV_CONFIG_MSG").innerHTML = sensorSettings.get('mastering_value') + "mm MV";
        document.getElementById("MO_CONFIG_MSG").innerHTML = sensorSettings.get('master_offset') + "&quot; MO";
        if (sensorParamsFromController) {
            setSpanProperties($("#SENSOR_PARAMS_CONFIG_MSG"), "Using controller-provided '" + sensorSettings.get('sensor_selection') + "' sensor settings", 'green');
            $("#SL_CONFIG_MSG").css('color', 'black');
            $("#SMR_CONFIG_MSG").css('color', 'black');
            $("#MR_CONFIG_MSG").css('color', 'black');
            $("#MFH_CONFIG_MSG").css('color', 'black');
            $("#MV_CONFIG_MSG").css('color', 'black');
            $("#MO_CONFIG_MSG").css('color', 'black');
        } else if (sensorSettings.sensorParamsHaveBeenEdited()) {
            setSpanProperties($("#SENSOR_PARAMS_CONFIG_MSG"), "Using non-standard '" + sensorSettings.get('sensor_selection') + "' sensor settings: ", 'yellow');
            $("#SL_CONFIG_MSG").css('color', sensorSettings.sensorLengthHasBeenEdited()?'red':'black');
            $("#SMR_CONFIG_MSG").css('color', sensorSettings.smrHasBeenEdited()?'red':'black');
            $("#MR_CONFIG_MSG").css('color', sensorSettings.mrHasBeenEdited()?'red':'black');
            $("#MFH_CONFIG_MSG").css('color', sensorSettings.mfhHasBeenEdited()?'red':'black');
            $("#MV_CONFIG_MSG").css('color', sensorSettings.mvHasBeenEdited()?'red':'black');
            $("#MO_CONFIG_MSG").css('color', sensorSettings.moHasBeenEdited()?'red':'black');
        } else {
            setSpanProperties($("#SENSOR_PARAMS_CONFIG_MSG"), "Using pre-configured '" + sensorSettings.get('sensor_selection') + "' sensor settings", 'red');
            $("#SL_CONFIG_MSG").css('color', 'black');
            $("#SMR_CONFIG_MSG").css('color', 'black');
            $("#MR_CONFIG_MSG").css('color', 'black');
            $("#MFH_CONFIG_MSG").css('color', 'black');
            $("#MV_CONFIG_MSG").css('color', 'black');
            $("#MO_CONFIG_MSG").css('color', 'black');
        }
    }

    function set_frame_information() {
        var html_buf = [];
        var frmIdx = 0;
        var frame = "";
        var selectedIndex = 0;
        // E4PTdata.pouchdb_id = "";
        for (frmIdx = 0; frmIdx < frame_data.length; frmIdx++) {
            html_buf.push("<option value='" + frame_data[frmIdx]['frame'] + "'>" + frame_data[frmIdx]['frame'] + "</option>");
            if (current_frame_data.length != 0) {
              if (current_frame_data.frame == frame_data[frmIdx]['frame']) {
                selectedIndex = frmIdx;
              }
            }
        }
        var html = html_buf.join('\n');
        document.getElementById("FRAME_SIZE").innerHTML = html;
        document.getElementById("FRAME_SIZE_EDIT").innerHTML = html;
        if (current_frame_data.length != 0) {
          document.getElementById("FRAME_SIZE").selectedIndex = selectedIndex;
          document.getElementById("FRAME_SIZE").value = current_frame_data.frame;
        } else {
            // otherwise, put back the last thing that was selected by the user.
            document.getElementById("FRAME_SIZE").selectedIndex = selected_frame_data.frameIdx;
            document.getElementById("FRAME_SIZE").value = frame_data[selected_frame_data.frameIdx].frame;
            setupCasingThicknessTable(null);
        }
        document.getElementById("FRAME_DEFAULT_SENSOR").value = current_frame_data.default_sensor;
    }

    function set_position_information() {
        console.log('@set_position_information');
        var html_buf = [];
        var positions = current_frame_data['position'];
        positions = positions[current_stage];
        var posIdx = 0;
        for (posIdx = 0; posIdx < positions.length; posIdx++) {
            html_buf.push("<option value='" + positions[posIdx] + "'>" + positions[posIdx] + "</option>");
        }
        var html = html_buf.join('\n');
        document.getElementById("SENSOR_POSITION").innerHTML = html;
        
        // update in set_stage_information
        //selected_frame_data.stageInfoIdx = current_stage_index;
        //selected_frame_data.stageName = current_stage;
        //selected_frame_data.bladeCount = current_frame_data.stage_info[current_stage].blade_count;
    }

    function set_stage_information() {
        console.log("@set_stage_information");
        html_buf = [];
        var stages = current_frame_data['stage'];
        for (stage_index = 0; stage_index < stages.length; stage_index++) {
          html_buf.push("<option value='" + stages[stage_index] + "'>" + stages[stage_index] + "</option>");
        }
        html = html_buf.join('\n');
        document.getElementById("SENSOR_STAGE").innerHTML = html;
        document.getElementById("SENSOR_STAGE").selectedIndex = selected_frame_data.stageInfoIdx;
        selected_frame_data.stageName = Object.keys(frame_data[selected_frame_data.frameIdx].stage_info)[selected_frame_data.stageInfoIdx];
        // don't use stage name due to x.x formats
        //document.getElementById("SENSOR_STAGE").value = selected_frame_data.stageName;
        console.log ("selected_frame_data.stageName  , index= ", selected_frame_data.stageName, selected_frame_data.stageInfoIdx);
        current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
        current_stage = stages[current_stage_index];
        
        selected_frame_data.stageInfoIdx = current_stage_index;
        selected_frame_data.stageName = current_stage;

        set_position_information(); // When you change the stage, the position information changes too.
        current_position_index = 0;
    }

    function set_stage() {
      console.log("@set_stage");
      current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
      
      // memorise which stage index we are at, for RPM computation,
      selected_frame_data.stageInfoIdx = current_stage_index

      current_stage = current_frame_data['stage'][current_stage_index];
      set_position_information();
      current_position_index = 0;
      current_position = current_frame_data['position'][current_stage][current_position_index];
      document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
      highlight_cell(current_position, current_stage);
    }

    function set_position() {
      console.log("@set_position");
      current_position_index =  document.getElementById("SENSOR_POSITION").selectedIndex;
      current_position = current_frame_data['position'][current_stage][current_position_index];
      highlight_cell(current_position, current_stage);
    }
    
    function set_measurement_and_intensity_value(el_id, label, minVal, maxVal, cmd) {
        console.log("@set_measurement_and_intensity_value");
        var input_f = parseFloat(document.getElementById(el_id).value);
        // Make sure the text is a number
        if ((isNaN(input_f)) || (typeof(input_f) != 'number')) {
            e4PtAlert(label + ' is not a number.');
            return;
        }
        
        document.getElementById(el_id).value = input_f.toFixed(3);
        input_f = parseFloat(document.getElementById(el_id).value);
        cmd.rate = input_f;
        
        if (input_f > maxVal) {
            e4PtConfirm(label + 's over ' + maxVal + ' are not supported. Value will be set to ' + maxVal,
              function(buttonIndex) {
                  if (buttonIndex==1) {//OK
                      input_f = maxVal;
                      document.getElementById(el_id).value = input_f.toFixed(3);
                      cmd.rate = input_f;
                      override_measurement_rate(cmd);
                  } else if (buttonIndex==2) {//Cancel
                      document.getElementById(el_id).value = '';
                      return;
                  }
              });
        } else if (input_f < minVal) {
            e4PtConfirm(label + 's below ' + minVal + ' are not supported. Value will be set to ' + minVal,
              function(buttonIndex) {
                  if (buttonIndex==1) {//OK
                      input_f = minVal;
                      document.getElementById(el_id).value = input_f.toFixed(3);
                      cmd.rate = input_f;
                      override_measurement_rate(cmd);
                  } else if (buttonIndex==2) {//Cancel
                      document.getElementById(el_id).value = '';
                      return;
                  }
              });
        } else {
            override_measurement_rate(cmd);
        }
    }
    
    function override_measurement_rate(cmd) {
        console.log('@override_measurement_rate');
        messaging.sendMessage({args:[cmd]});
        messaging.sendMessage({args:[{command:'set_manual_override',value:true}]});
        setSpanProperties($("#measurement_override_message"), "MANUAL OVERRIDE", 'yellow');
        setSpanProperties($("#measurement_override_message_2"), "MANUAL<br/>OVERRIDE<br/>" + cmd.rate.toFixed(3) + "kHz", 'yellow');
    }
    
    function displayGoButton() {
        setButtonProperties($("#STAGE_COLLECT_BUTTON"), LABEL_GO, 'green');
    }
    
    function displayAbortButton() {
        setButtonProperties($("#STAGE_COLLECT_BUTTON"), LABEL_ABORT, 'red');
    }
    
    function setButtonProperties(button, text, buttonColor) {
        let allColors = "btn-secondary btn-dark btn-danger btn-success btn-warning btn-info";
        let targetColor = "btn-secondary";
        switch(buttonColor) {
          case "black":
            targetColor = "btn-dark";
            break;
          case "red":
            targetColor = "btn-danger";
            break;
          case "blue":
            targetColor = "btn-primary";
            break;
          case "green":
            targetColor = "btn-success";
            break;
          case "yellow":
            targetColor = "btn-warning";
            break;
          case "cyan":
            targetColor = "btn-info";
            break;
          case "gray":
            targetColor = "btn-secondary";
            break;
          default:
            targetColor = "btn-secondary";
        }
        button
            .removeClass(allColors)
            .addClass(targetColor)
            .html(text);
    }
    
    function setSpanProperties(span, text, spanColor) {
        let allColors = "bg-secondary bg-dark bg-danger bg-success bg-warning bg-info text-dark";
        let targetColor = "bg-secondary";
        switch(spanColor) {
          case "black":
            targetColor = "bg-dark";
            break;
          case "red":
            targetColor = "bg-danger";
            break;
          case "green":
            targetColor = "bg-success";
            break;
          case "blue":
            targetColor = "bg-primary";
            break;
          case "yellow":
            targetColor = "bg-warning text-dark";
            break;
          case "cyan":
            targetColor = "bg-info text-dark";
            break;
          default:
            targetColor = "bg-secondary";
        }
        span
            .removeClass(allColors)
            .addClass(targetColor)
            .html(text);
    }

    function confirm_collect_stage_data() {
        // Disable prompt since offset calculation is disabled, default to Original
        let calcMethod = CALC_METHOD_ORIGINAL;
        //e4PtPrompt('Original calculation assumes master fixture height is SMR+SL+5mm, New calculation uses MV=fixture height - sensor length', function(calcMethod) {
        document.getElementById("CLEARANCE_CALCULATION_METHOD").value = calcMethod;
        // Here we check to see if data is in the cell that is about to be populated.
        // If there is already data there then we confirm with the user to overwrite it.
        let stage = current_frame_data['stage'][current_stage_index];
        let position = current_frame_data['position'][stage][current_position_index];
        let el_id = position + stage;
        el_id = el_id.replace(/\s+/g, '_');
        let cell_contents = document.getElementById(el_id).innerHTML;
        if (cell_contents.length > 0) {
            let msg = "Are you sure you want to overwrite stage " + stage + "-" + position + " data, " + cell_contents + "?";
            e4PtConfirm(msg, function(buttonIndex) {
                if (buttonIndex==1) {//OK
                    collect_stage_data();
                } else if (buttonIndex==2) {//Cancel
                    return;
                }
            });
        } else {
            collect_stage_data();
        }
        return;
//        }, 'Select Clearance Calculation', ['Original','New','None']);
//        return;
    }

    function collect_stage_data() {
        console.log("@collect_stage_data");
        // Make sure the plot doesn't show on screen
        var position = document.getElementById("SENSOR_POSITION").value;
        var stage = document.getElementById("SENSOR_STAGE").value;
        var boxID = position + stage;
        boxID = boxID.replace(/\s+/g, '_');
        //console.log("updating box with element id: ", boxID);

        current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
        current_stage = current_frame_data['stage'][current_stage_index];
        current_position_index = document.getElementById("SENSOR_POSITION").selectedIndex;
        current_position = current_frame_data['position'][current_stage][current_position_index];
        doDBSave = true;
        
        fromGetData = false;
        fromDataCollectionPage = true;
        fromSensorSetupPage = false;

        // Collect data from the sensor.
        var nav = navigator.notification;
        if (nav != null) {
            // We have plugins so we're in Cordova.  Use the Cordova notification.
            savedRPM = document.getElementById('MEASUREMENT_RPM').value;
            if (savedRPM == "") {
                savedRPM = "1";
                document.getElementById("MEASUREMENT_RPM").value = savedRPM;
            }
            /*navigator.notification.prompt('Please enter or confirm the rotor RPM.\nEstimate within +/- 1rpm if possible.',
                                          acquisitionTimePromptWithMetaDataCallback,
                                          'Enter RPM',
                                          ['Ok','Cancel'],
                                          savedRPM);*/
            acquisitionTimePromptWithMetaDataCallback({ "input1": savedRPM });
        } else {
            // No plugins, so we must not be in Cordova. Use a standard prompt.
            acquisitionTime = window.prompt("Please enter the rotor RPM.", "1");
            acquisitionTimePromptWithMetaDataCallback({ "input1": acquisitionTime });
        }
    }

    // unused, was called on SENSOR_STAGE change event
    function setup_data_collection(update_position) {
        current_stage_index = document.getElementById("SENSOR_STAGE").selectedIndex;
        current_stage = current_frame_data['stage'][current_stage_index];
        current_position_index = document.getElementById("SENSOR_POSITION").selectedIndex;
        current_position = current_frame_data['position'][current_stage][current_position_index];
        setup_data_collection_page("", "", update_position);
    }

    function confirm_reset_data_collection() {
        e4PtConfirm("Are you sure you want to clear all data on this page?",
          function(idx) {
            if (idx == 1) {
                console.log("Resetting data collection.");
                reset_data_collection();
            } else {
                console.log("Reset data collection was cancelled.");
            }
          });
    }

    function reset_data_collection() {
        console.log("@reset_data_collection");
        E4PTdata.sets = [];
        current_stage_index = 0;
        // load data for current stage
        current_stage = current_frame_data['stage'][current_stage_index];
        current_position_index = 0;
        current_position = current_frame_data['position'][current_stage][current_position_index];
        let ct_id = current_stage + "_" + current_position;
        document.getElementById("CURR_CASE_THICKNESS").value = E4PTdata.turbine_casing_thicknesses[ct_id];
        document.getElementById("CLEARANCE_ERROR").innerHTML = "";
        document.getElementById("SPACER_COLOR_LABEL").innerHTML = "";
        savedRPM = computedRPM;
        setup_data_collection_page("", "", true);
        //charting.clearChartData(document.getElementById('DATA_PLOT'));
        charting.clearChartData(document.getElementById('DATA_PLOT2'));
        document.getElementById("DATA_PLOT2").innerHTML = "";
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
        } else {
            // This method generates a PDF, then exports it.
            let sn = processString(E4PTdata.serial_number);
            let fileDate = processString(E4PTdata.date);
            let cust_rpt_fileName = CUSTOMER_REPORT_FILE_PREFIX + "_" + sn + "_" + fileDate + ".pdf";
            E4PTdata.report_filename = cust_rpt_fileName;
            console.log("CUSTOMER REPORT FILE: ", cust_rpt_fileName);
            addDBEntry(E4PTdata); // update filename
            baseURL = appDir + "www";
            var options = {
                documentSize: 'Letter',
                type: 'base64',
                fileName: cust_rpt_fileName,
                baseUrl:baseURL
            };
            if (messaging.usesPlugin()) {
                // replace "./css/report.css" with "<%=css_file%>" for plugin
                reportHTML = reportHTML.replace("./css/report.css","<%=css_file%>");
                reportHTML = reportHTML.split("img/").join("www/img/"); // equivalent to replaceAll
            }
            var payload = _.template(reportHTML);
            cssFile = "www/css/report.css";
            pdf.fromData(payload({css_file:cssFile}), options)
            .then(function(base64) {
                  var pdfBlob = b64toBlob(base64, "application/pdf");
                  writeToFile(E4PTdata.serial_number, cust_rpt_fileName, pdfBlob,
                    function() {
                      e4PtPrompt("Email/Upload/View/Send.",
                          function(option) {
                              exportReport(option, base64, cust_rpt_fileName);
                          }, "Report Options", ["Email","Upload to Box","View","Send Final Data","Cancel"]);
                    });
            })
            .catch(function(err) {
                console.log("PDF Creation Error: ", err);
            });
        }
      return;
    }

    function emailJSONData(toAddress, data) {
        console.log("@emailJSONData");
        // first write the data to a file...
        let json_data = JSON.stringify(data);
        var json_blob = new Blob( [json_data], { type: 'application/json'} );
        let targetFolder = "data"; // default directory
        let fileName = "e4Pt.json";
        let subject = "e-4Pt JSON Data";
        if ((typeof E4PTdata.serial_number !== 'undefined') || ( E4PTdata.serial_number.length > 0 )) {
            let sn = processString(E4PTdata.serial_number);
            targetFolder = sn;
            fileName = processString(EMAIL_FILE_PREFIX + "_" + sn + "_" + E4PTdata.date + ".json");
            subject = subject + " SN: " + E4PTdata.serial_number + " " + E4PTdata.date;
        }
        E4PTdata.email_filename = fileName;
        console.log("EMAIL FILE: ", fileName);
        addDBEntry(E4PTdata); // update filename
        writeToFile(targetFolder, fileName, json_blob, function() {
            let fileURL = cordova.file.documentsDirectory + targetFolder + "/" + fileName;
            let attachment = [fileURL];
            sendEmailWithAttachment(toAddress, subject, attachment)
        });
    }

    function writeToFile(folder, fileName, fileData, callback=null) {
        console.log("@writeToFile: folder=" + folder + ", fileName=" + fileName);
        var targetFolder = cordova.file.documentsDirectory + folder + "/";
        window.resolveLocalFileSystemURL(targetFolder, function(dir) {
            dir.getFile(fileName, {create:true, exclusive: false}, function(file) {
                if (!file) {
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
                    if (callback != null) {
                        callback();
                    }
                });
            }, function(msg) {
                // Error callback for dir.getFile
                console.log("Error: ", msg);
            });
        });
    }

    function fileSaveCallback() {
        console.log("@fileSaveCallback");
    }

    // exportReport exports a base64 string as an email attachment or a
    // Box file upload.
    // The option is 1 (email), 2 (upload), 3 (view) or 4 (cancel).
    function exportReport(option, base64, fileName) {
        console.log("@exportReport: ", option);
        if (option == 1) {
            console.log("Email");
            // do something with downloadFileName
            subject = APP_NAME + " " + fileName;
            // Add a prefix so the email plugin handles the attachment correctly
            var prefix = "base64:" + fileName + "//";
            base64 = prefix + base64;
            let toAddress = [];
            sendEmailWithAttachment(toAddress, subject ,base64);
        } else if (option == 2) {
            console.log("Upload");
            var fileFullPath = cordova.file.documentsDirectory + E4PTdata.serial_number + "/" + fileName;
            fileFullPath = fileFullPath.replace("file://","");
            uploadFileToBox(fileFullPath);
        } else if (option == 3) {
            console.log("View");
            var fileFullPath = cordova.file.documentsDirectory + E4PTdata.serial_number + "/" + fileName;
            fileviewer2.open(fileFullPath, {
                    error : function(e) {
                        console.log('Error status: ' + e.status + ' - Error message: ' + e.message);
                    },
                    success : function () {
                        console.log('file opened successfully');
                    }
                }
            );
        } else if (option == 4) {
            let toAddress = [FIELD_DATA_BOX_FOLDER];
            emailJSONData(toAddress, E4PTdata);
        } else {
            console.log("Cancel");
        }
    }
                  
    function setup_data_collection_page(dateStr, timeStr, update_position) {
        console.log('@setup_data_collection_page');
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
        E4PTdata.customer = customer;
        E4PTdata.site = site;
        E4PTdata.operator = document.getElementById("OPERATOR").value;

        document.getElementById("HEADER_DATETIME").innerHTML = dateStr;

        updateSensorHeaderMessage();

        document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
        document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;

        var html_buf = [];
        var stage_index = 0;
        var position_index = 0;

        // Setup the data tables.  We use different tables for each stage because
        // the number of positions for each stage could be different.
        // The "super" table contains all the tables for the different stages.
        
        var stages = current_frame_data['stage'];
        html_buf.push("<tr>"); // The sub-tables all go in one row in the super-table
        for (stage_index = 0; stage_index < stages.length; stage_index++) {
            var stage = stages[stage_index];
            var positions = current_frame_data['position'][stage];
            html_buf.push("<td><table class=\"table table-bordered border-secondary table-sm\">");
            var header_row = "<thead class=\"table-light table-bordered border-secondary align-middle text-center\"><tr><th scope=\"col\">POSITION</th><th scope=\"col\">";
            header_row = header_row + "STAGE " + stages[stage_index];
            header_row = header_row + "</th></tr></thead><tbody>";
            html_buf.push(header_row);
            for (position_index = 0; position_index < positions.length; position_index++) {
                if (POSITION_DISPLAY_MODE == 'TEXT') {
                    html_buf.push("<tr><td>" + positions[position_index] + "</td>");
                } else if (POSITION_DISPLAY_MODE == 'ICON') {
                    html_buf.push('<tr><td class="text-center">' + ARROW_ICONS[positions[position_index]] + '</td>');
                } else if (POSITION_DISPLAY_MODE == 'BOTH') {
                    html_buf.push('<tr><td class="text-center">' + ARROW_ICONS[positions[position_index]] + '&nbsp;' + positions[position_index] + '</td>');
                }
                var el_id = positions[position_index] + stages[stage_index];
                el_id = el_id.replace(/\s+/g, '_');
                html_buf.push("<td id='" + el_id +
                              "' onclick='set_grid_position(\"" + positions[position_index] +
                              "\", \"" + stages[stage_index] +
                              "\")'></td>");
                html_buf.push("</tr>");
            }
            html_buf.push("</tbody></table></td>");
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

    //
    // get_spacer_information not only gets the spacer information, but it updates
    // the casing thickness information based on any user input.
    //
    function get_spacer_information() {
      console.log('@get_spacer_information');
      var spacer = null;
      var spacers = current_frame_data['spacers'];
      let ct_id = current_stage + "_" + current_position;
      let case_thick = document.getElementById("CURR_CASE_THICKNESS").value;
      if (case_thick.length > 0) {
          document.getElementById(ct_id).value = document.getElementById("CURR_CASE_THICKNESS").value;
      } else {
          // If the cell is empty, fill in in the field with what's stored in the data structure.
          case_thick = E4PTdata.turbine_casing_thicknesses[ct_id]
          document.getElementById("CURR_CASE_THICKNESS").value = case_thick;
      }
      if (typeof E4PTdata.turbine_casing_thicknesses[ct_id] !== 'undefined') {
          // If nothing is in the data structure, fill in the structure with what's in the field.
          E4PTdata.turbine_casing_thicknesses[ct_id] = case_thick;
      }
      if (case_thick.length == 0) {
          console.log('no case thickness, could not determine spacer');
          return spacer;
      }
      var casing_thickness = parseFloat(case_thick);
      var positions = current_frame_data['position'];
      positions = positions[current_stage];
      var position = positions[current_position_index];
      console.log("Getting spacer information for casing_thickness = ", casing_thickness, ", and position = ", position);
      var spacer_found = false;
      for (var i=0; i<spacers.length; i++) {
        // special handling for stages with multiple configurations
        if (spacers[i].stage.split('.')[0] == current_stage) {
          var min = parseFloat(spacers[i].min);
          var max = parseFloat(spacers[i].max);
          if ((casing_thickness <= max) && (casing_thickness >= min)) {
            for(var j=0; j<spacers[i].position.length; j++) {
              if (position == spacers[i].position[j]) {
                console.log(JSON.stringify(spacers[i]));
                spacer = {'size':spacers[i].size, 'color':spacers[i].color, 'image':spacers[i].image};
                current_stage_type = spacers[i].stage;
                spacer_found = true;
                break;
              }
            }
            if (spacer_found == true) {
                break;
            }
          }
        }
      }
      if (spacer_found == true) {
        // We found a spacer.  Now check to make sure it's not a confusing image
        // and if so, warn the user.
        let warnUser = true;
        let stageStr = "R" + current_stage;
        if (spacer.image.includes(stageStr)) {
            // The image string at least contains the stage string, e.g. R1.
            // but we need to be sure we don't mistake R1 for R17, so we reduce
            // each part of the filename to Rx, where x is purely numeric.
            let config_strings = spacer.image.split("-");
            for (idx = 0; idx < config_strings.length; idx++) {
                let config_stg = config_strings[idx].replace(/\D/g,''); // This strips all non-numerics
                if (config_stg == current_stage) {
                    warnUser = false; // If we find the exact stage, don't warn the user.
                    break;
                }
            }
        }
        if (warnUser == true) {
            // This function may be called in different places so only show the alert
            // if we're on the expected screen.
            // Disabled per user feedback
            /*if (!isHidden(document.getElementById("TURBINE_SETUP_PAGE"))) {
              e4PtAlert("The image for this spacer may be misleading, but it is correct.");
            }*/
        }
      }
      return spacer;
    }

    // isHidden just determines if the element passed in is visible on screen.
    function isHidden(el) {
        var style = window.getComputedStyle(el);
        return (style.display === 'none')
    }

    //
    // Updates the spacer value based on the current stage, position and casing thickness.
    //
    function update_spacer_value() {
      console.log("@update_spacer_value");
      var spacer = get_spacer_information();
      // spacer.image contains the image name (without the filename ending).
      var spacer_value =  null;
      var spacer_color = "";
      if (spacer == null) {
        //spacer_value = "Enter spacer thickness.";
        spacer_value = "";
        spacer = {'color':'white'};
      } else {
        spacer_value = spacer.size;
        spacer_color = "Spacer color is " + spacer.color;
      }

      let imageName = DEFAULT_SPACER_FILE;
      if (typeof spacer.image !== 'undefined') {
        imageName = 'img/spacers/' + spacer.image + '.gif';
        let wwwPath = appDir + "www/";
        window.resolveLocalFileSystemURL(wwwPath, function(dir) {
            dir.getFile(imageName, {create:false, exclusive: false}, function(file) {
                document.getElementById("SPACER_THUMBNAIL").setAttribute("src",imageName);
                document.getElementById("SPACER_THUMBNAIL").setAttribute("alt",spacer.image);
            }, function() {
                imageName = DEFAULT_SPACER_FILE;
                document.getElementById("SPACER_THUMBNAIL").setAttribute("src",imageName);
                document.getElementById("SPACER_THUMBNAIL").setAttribute("alt",'Unknown');
            });
        });
      } else {
          document.getElementById("SPACER_THUMBNAIL").setAttribute("src",imageName);
          document.getElementById("SPACER_THUMBNAIL").setAttribute("alt",'Unknown');
      }

      document.getElementById("SPACER_THICKNESS").value = spacer_value;
      document.getElementById("SPACER_COLOR_LABEL").innerHTML = spacer_color;
      document.getElementById("SPACER_COLOR_LABEL").style.color = spacer.color;
    }

    function advance_position() {
        // Don't try to advance the position if we're not set up for it.
        // (i.e. if we're not on the right page)
        console.log("@advance_position");
        if (current_frame_data['position'] == null) {
            return;
        }
        console.log("@advance_position - continuing");
        // Auto-advance
        var stages = current_frame_data['stage'];
        var positions = current_frame_data['position'][current_stage];

        current_position_index = (current_position_index + 1) % positions.length;
        current_position = positions[current_position_index];
        if (current_position_index == 0) {
            current_stage_index = (current_stage_index + 1) % stages.length;
            current_stage = stages[current_stage_index];
            set_position_information();
            // update positions for new stage
            positions = current_frame_data['position'][current_stage];
            current_position = positions[current_position_index];
        }
        document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
        document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
        let ct_id = current_stage + "_" + current_position;
        document.getElementById("CURR_CASE_THICKNESS").value = E4PTdata.turbine_casing_thicknesses[ct_id];
        highlight_cell(current_position, current_stage);
        update_spacer_value();
    }

    function set_grid_position(position, stage) {
        console.log("@set_grid_position: pos: ", position, "; stage: ", stage);
        var stages = current_frame_data['stage'];
        var positions = current_frame_data['position'][stage];
        current_position_index = positions.indexOf(position);
        current_stage_index = stages.indexOf(stage);
        current_stage = stages[current_stage_index];
        current_position = positions[current_position_index];
        
        selected_frame_data.stageInfoIdx = current_stage_index;
        selected_frame_data.stageName = current_stage;
        // use index instead of name due to *.* stages
        //selected_frame_data.bladeCount = current_frame_data.stage_info[current_stage].blade_count;
        selected_frame_data.bladeCount = Object.values(current_frame_data.stage_info)[current_stage_index].blade_count;

        set_position_information();
        document.getElementById("SENSOR_STAGE").selectedIndex = current_stage_index;
        document.getElementById("SENSOR_POSITION").selectedIndex = current_position_index;
        var el_id = current_position + current_stage;
        el_id = el_id.replace(/\s+/g, '_');
        var clearance = document.getElementById(el_id).innerHTML;
        clearance = parseFloat(clearance);
        update_clearance(clearance, true);
        let ct_id = current_stage + "_" + current_position;
        document.getElementById("CURR_CASE_THICKNESS").value = E4PTdata.turbine_casing_thicknesses[ct_id];
        highlight_cell(position, stage);
        update_spacer_value();
    }
    
    function clearance_override() {
        console.log("@clearance_override");
        var el_id = current_position + current_stage;
        el_id = el_id.replace(/\s+/g, '_');
        var clearance = document.getElementById(el_id).innerHTML;
        if (E4PTdata.units.toUpperCase().includes("IN") && clearance != "") {
          clearance = sensorSettings.toMMs(clearance);
          clearance = checkValue(clearance, CLEARANCE_OVERRIDE_PRECISION);
        }
        document.getElementById("CLEARANCE_OVERRIDE_STAGE").innerHTML = current_stage;
        document.getElementById("CLEARANCE_OVERRIDE_POSITION").innerHTML = current_position;
        // get values for Name and SSO from current measurement
        let priorSet = E4PTdata.sets.find(o => ((o.stage === current_stage) && (o.position === current_position)));
        let overrideName = document.getElementById("OPERATOR_EDIT").value;
        let overrideSSO = "";
        if (typeof priorSet !== 'undefined' && priorSet.overrideName != "") {
          overrideName = priorSet.overrideName;
          overrideSSO = priorSet.overrideSSO;
        }
        document.getElementById("CLEARANCE_OVERRIDE_NAME").value = overrideName;
        document.getElementById("CLEARANCE_OVERRIDE_SSO").value = overrideSSO;
        document.getElementById("CLEARANCE_OVERRIDE_VALUE").value = clearance;
        document.getElementById("CLEARANCE_OVERRIDE_CERTIFY").checked = false;
        clearanceOverrideModal.show();
    }
    
    function clearance_override_save() {
        console.log("@clearance_override_save");
        charting.clearChartData(document.getElementById('DATA_PLOT2'));
        document.getElementById("DATA_PLOT2").innerHTML = "";
        clearanceOverrideModal.hide();
        var clearanceOverrideName = document.getElementById("CLEARANCE_OVERRIDE_NAME").value;
        var clearanceOverrideSSO = document.getElementById("CLEARANCE_OVERRIDE_SSO").value;
        var clearanceOverrideValue = document.getElementById("CLEARANCE_OVERRIDE_VALUE").value;
        var clearanceOverrideCertify = document.getElementById("CLEARANCE_OVERRIDE_CERTIFY").checked;
        if (clearanceOverrideCertify) {
            var clearance = parseFloat(clearanceOverrideValue);
            if (clearanceOverrideName != "" && clearanceOverrideSSO != "") {
                if (!isNaN(clearance)) {
                    E4PTdata.manualOverride = true;
                    E4PTdata.overrideName = clearanceOverrideName;
                    E4PTdata.overrideSSO = clearanceOverrideSSO;
                    E4PTdata.clearance = clearanceOverrideValue;
                    E4PTdata.max_clr = clearanceOverrideValue;
                    E4PTdata.min_clr = clearanceOverrideValue;
                    E4PTdata.med_clr = clearanceOverrideValue;
                    E4PTdata.std_clr = 0.0;
                    E4PTdata.intensity_threshold = null;
                    E4PTdata.measurement_rate = null;
                    E4PTdata.filename = null;

                    doDBSave = true;

                    parse_data();
                    flag_override_cell(current_position, current_stage);
                    advance_position();
                } else {
                    e4PtAlert('Invalid clearance measurement');
                }
            } else {
                e4PtAlert('Please enter name and SSO');
            }
        } else {
            e4PtAlert("Please certify the manual clearance override");
        }
    }

    function highlight_cell(hi_position, hi_stage) {
        console.log('@highlight_cell: pos: ' + hi_position, '; stage: ', hi_stage);
        // first un-highlight all cells.
        let stages = current_frame_data['stage'];
        for (stage_index = 0; stage_index < stages.length; stage_index++) {
            let stage = stages[stage_index];
            let positions = current_frame_data['position'][stage];
            for (position_index = 0; position_index < positions.length; position_index++) {
                let el_id = positions[position_index] + stages[stage_index];
                el_id = el_id.replace(/\s+/g, '_');
                document.getElementById(el_id).classList.remove("table-primary", "border-primary", "border-2");
                document.getElementById(el_id).classList.add("border-secondary");
            }
        }
        // now highlight the cell of interest.
        el_id = hi_position+hi_stage;
        el_id = el_id.replace(/\s+/g, '_');
        document.getElementById(el_id).classList.remove("border-secondary");
        document.getElementById(el_id).classList.add("table-primary", "border-primary", "border-2");
    }
    
    function flag_override_cell(hi_position, hi_stage) {
        console.log('@flag_override_cell: pos: ' + hi_position, '; stage: ', hi_stage);
        // first un-highlight all cells.
        let stages = current_frame_data['stage'];
        for (stage_index = 0; stage_index < stages.length; stage_index++) {
            let stage = stages[stage_index];
            let positions = current_frame_data['position'][stage];
            for (position_index = 0; position_index < positions.length; position_index++) {
                let el_id = positions[position_index] + stages[stage_index];
                el_id = el_id.replace(/\s+/g, '_');
                if (document.getElementById(el_id).innerHTML == "") {
                    document.getElementById(el_id).classList.remove("table-danger");
                }
            }
        }
        // now highlight the cell of interest.
        el_id = hi_position+hi_stage;
        el_id = el_id.replace(/\s+/g, '_');
        if (document.getElementById(el_id).innerHTML != "") {
            document.getElementById(el_id).classList.add("table-danger");
        }
    }

    function do_dark_reference() {
        console.log('@do_dark_reference');
        if (messaging.usesWebSocket()) {
            setIndicatorColor("yellow");
        }
        setButtonProperties($("#START_DARK_REFERENCE_BUTTON"), LABEL_DARK, 'yellow');

        // set flag to show SENSOR SETUP page on close
        fromGetData = false;
        fromDataCollectionPage = false;
        fromSensorSetupPage = true;

        startProgressBar();
        charting.clearChartData(document.getElementById('DATA_PLOT'));
        current_frame_data = [];

        messaging.sendMessage({args:[{command:'do_dark_reference'}]});
    }

    function do_mastering(reset) {
        console.log('@do_mastering: reset=' + reset);
        masteringPerformed = false;
        if (messaging.usesWebSocket()) {
            setIndicatorColor('yellow');
        }
        var cmd = {args:[{command:'do_mastering'}]};
        if (reset) {
            cmd.args[0].reset = true;
        }
        messaging.sendMessage(cmd);
    }

    function mastering_in_progress() {
        setMasterMessage("yellow","IN PROGRESS...");
        setMasterMessage2("yellow","IN PROGRESS...");
        setIndicatorColor("red");
    }

    function done_mastering() {
        console.log("@done_mastering");
        masteringPerformed = true;
        setMasterMessage("green","MASTERING COMPLETE");
        setMasterMessage2("green","MASTERING COMPLETE");
        setIndicatorColor("green");
    }

    function failed_mastering() {
        console.log('@failed_mastering');
        setMasterMessage("red","MASTERING FAILED");
        setMasterMessage2("red","MASTERING FAILED");
        setIndicatorColor("green");
    }

    function systemShutdown() {
        if (messaging.usesPlugin) {
            e4PtConfirm("Are you sure you want to exit?",
                        function(idx) {
                            if (idx === 1) {
                                messaging.sendMessage({args:[{command:'shutdown'}]});
                            }
                        });
        } else {
            messaging.sendMessage({args:[{command:'shutdown'}]});
        }
    }

    function doFileDownload() {
        messaging.sendMessage({args:[{command:'get_data_file'}]});
    }

    // alert function to work on iOS and web browser
    function e4PtAlert(msg, callback=null) {
        console.log('e4PtAlert: ' + msg);
        try{
            navigator.notification.alert(
                String(msg),            // message
                callback,               // callback
                '',                     // no title
                'OK'                    // buttonName
            );
        } catch (err) {
            alert(String(msg));
        }
    }

    // confirm function to work on iOS and web browser
    function e4PtConfirm(msg, callback) {
        console.log('e4PtConfirm: ' + msg);
        try{
            navigator.notification.confirm(
                String(msg),            // message
                callback,               // callback to invoke with index of button pressed
                '',                     // no title
                ['OK','Cancel']         // buttonLabels: 1=OK, 2=Cancel
            );
        } catch (err) {
            if (confirm(String(msg))) {
                callback(1);//OK
            } else {
                callback(2);//Cancel
            }
        }
    }

    // prompt: function (message, resultCallback, title, buttonLabels, defaultText) {
    function e4PtPrompt(msg, callback, title, buttonLabels) {
        console.log('e4PtPrompt: ' + msg);
        try {
            navigator.notification.confirm(
            String(msg),
            callback,
            String(title),
            buttonLabels
            );
        } catch (err) {
            console.log("e4PtPrompt Error: ", err);
        }
    }

    function createWebSocket() {
        
        if (messaging.usesWebSocket()) {
            return;
        }
        
        const handleReceivedMessage = function (msg) {
          console.log("e4PtSocket Message Received: " + msg.type);
          switch(msg.type) {
          case "data":
            if (!collectionAborted) {
                displayGoButton();
                console.log("Received Data Message");
                setIndicatorColor("green");
                //console.log(msg);
                processE4PtData(msg);
            } else {
                console.log("Data collection was aboreted");
            }
            break;
          case "status":
            console.log("Received Status Message: ", JSON.stringify(msg));
            if (msg.status == "acquiring") {
                setIndicatorColor("red");
                displayAbortButton();
            } else if (msg.status == "processing") {
                setIndicatorColor("blue");
                displayGoButton();
            } else if (msg.status == "done_mastering") {
              done_mastering();
            } else if (msg.status == "failed_mastering") {
              failed_mastering();
            }
            break;
          case "pong":
            console.log("Got pong. Send ping.");
                  setTimeout(function() { messaging.sendMessage({args:[{command:'ping'}]}); }, 5000);
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
        };
        
        messaging.setupWebSocket(handleReceivedMessage,
             { onopen: function() {
                 // Web Socket is connected, send data using send()
                 console.log("Connected to server");
                 setIndicatorColor("green");
                 serialConnected = true;
                },
               onclose: function() {
                  console.log("DISCONNECTED");
                  setIndicatorColor("white");
                  serialConnected = false;
                },
               onerror: function(evt) {
                  console.log("e4PtSocket error: ",evt);
                  setIndicatorColor("white");
                }});
    }

    function pluginMessage(msg) {
        console.log("@pluginMessage: msg.type = ", msg.type);
        switch(msg.type) {
            case "setting":
                console.log("Received Setting Message: ", JSON.stringify(msg));
                if (msg.varName === 'intensity_threshold') {
                    document.getElementById('THRESHOLD').value = msg.value;
                }
                break;
            case "connection":
                console.log("Received a connection mode message: ", msg.mode);
                document.getElementById('CONN_SELECTION').value = msg.mode;
                update_connection_mode(msg.mode);
                break;
            case "status":
                console.log("Received Status Message: ", JSON.stringify(msg));
                if (msg.status == "connected") {
                    setIndicatorColor("green");
                    document.getElementById("STATUS_DISPLAY").innerHTML = "Connected";
                    serialConnected = true;
                    getSensorParameters();
                } else if (msg.status == "connecting") {
                    document.getElementById("STATUS_DISPLAY").innerHTML = "Connecting";
                } else if (msg.status == 'disconnected') {
                    setIndicatorColor('white');
                    document.getElementById('STATUS_DISPLAY').innerHTML = 'Disconnected';
                    serialConnected = false;
                    if (!msg.noAlert) {
                        e4PtAlert('Controller was disconnected.');
                        // TODO: reset application/controller connection
                    }
                } else if (msg.status == "acquiring") {
                    displayAbortButton();
                    setIndicatorColor("red");
                    startProgressBar();
                } else if (msg.status == "processing") {
                    setIndicatorColor("blue");
                    displayGoButton();
                } else if (msg.status == "done_mastering") {
                    done_mastering();
                } else if (msg.status == "failed_mastering") {
                    failed_mastering();
                } else if (msg.status == "mastering_in_progress") {
                    mastering_in_progress();
                } else if (msg.status == "waiting") {
                    setIndicatorColor("yellow");
                } else if (msg.status.includes("Error:")) {
                    e4PtAlert(msg.status);
                }
                break;
            case "data":
                //resetDataCollection();
                console.log("Received Data Message");
                if (!collectionAborted) {
                    //$("#PROCESSING_PAGE").fadeIn();
                    msg.data = JSON.parse(msg.data);
                    msg.intensity = JSON.parse(msg.intensity);
                    msg.locs = JSON.parse(msg.locs);
                    msg.gaps = JSON.parse(msg.gaps);
                    msg.quality = JSON.parse(msg.quality);
                    msg.overall_avg = JSON.parse(msg.overall_avg);
                    msg.blades = JSON.parse(msg.blades);
                    msg.blade_samples_avg = JSON.parse(msg.blade_samples_avg);
                    // set to false since data came from controller
                    msg.manualOverride = false;
                    msg.overrideName = "";
                    msg.overrideSSO = "";

                    if (fromCalculateRPM) {
                        console.log('calculating RPM');
                        // TODO: already set in calculateRPM function
                        position = document.getElementById("SENSOR_POSITION").value;
                        casing_thickness = document.getElementById("CURR_CASE_THICKNESS").value;
                        if (position && casing_thickness) {
                            console.log('position:', position);
                            console.log('casing_thickness:', casing_thickness);
                            stage_details = get_stage_details(position, casing_thickness);
                            console.log(stage_details);
                            let rotor_blades = stage_details.blade_count;
                            let observed_blades = parseFloat(msg.blades);
                            console.log('rotor_blades = ' + rotor_blades + ', observed_blades = ' + observed_blades);
                            if (observed_blades > 0) {
                                let calculated_rpm = observed_blades / rotor_blades;
                                console.log('calculated_rpm = ' + calculated_rpm);
                                document.getElementById("MEASUREMENT_RPM").value = calculated_rpm.toFixed(3);
                                computedRPM = calculated_rpm;
                                selected_frame_data.RPM = calculated_rpm;
                            } else {
                                e4PtAlert('No blades observed, could not calculate RPM.');
                            }
                        } else {
                            e4PtAlert('No position or casing thickness, could not calculate RPM.');
                        }
                        setButtonProperties($("#CALCULATE_RPM_BUTTON"), LABEL_CALCULATE, 'green');
                        fromCalculateRPM = false;
                    } else {
                        processE4PtData(msg);
                    }
                } else {
                    console.log("Data collection was aborted");
                }
                $("#PROCESSING_PAGE").fadeOut();
                resetDataCollection();
                break;
            case "filename":
                console.log("Recieved Filename Message: ", msg.fname);
                downloadFileName = msg.fname;
                e4PtPrompt("Email or Upload File?", exportFile, "Get File", ["Email","Upload to Box","Cancel"]);
                break;
            case "version":
                console.log("Received version message: ", msg.version);
                document.getElementById("APP_VERSION").innerHTML = "VERSION " + msg.version;
                // executes every time menu is opened
                getSensorParameters();
                getConnectionMode();
                break;
            case "alert":
                console.log("Received an alert message: ", msg.message);
                e4PtAlert(msg.message);
                // TODO: reset if alert during collection
                break;
            case "log":
                console.log("[BACKEND]", msg.message);
                break;
            case "progress":
                console.log("Progress: ", msg.progress);
                $("#REV_PROGRESS")
                      .css("width", msg.progress + "%")
                      .attr("aria-valuenow", msg.progress)
                      .text(msg.progress + "%");
                break;
            case "sensor_params":
                console.log("Received sensor parameters message: ", msg.master_fixture_height, ", ", msg.mastering_value, ", ", msg.master_offset, ", ", msg.sensor_selection, ", ", msg.sensor_length, ", ", msg.start_measurement_range, ", ", msg.sensor_measurement_range, ", ", msg.from_controller, ", ", msg.measurement_rate, ", ", msg.intensity_threshold);
                
                sensorParamsFromController = msg.from_controller;
                if (sensorParamsFromController) {
                    sensorFromController = msg.sensor_selection;
                    sensorLengthFromController = JSON.parse(msg.sensor_length);
                    smrFromController = JSON.parse(msg.start_measurement_range);
                    sensorMRFromController = JSON.parse(msg.sensor_measurement_range);
                    setButtonProperties($("#READ_SENSOR_PARAMETERS_BUTTON"), LABEL_LOAD_PARAMS, 'blue');
                }
                
                sensorSettings.set('sensor_selection', msg.sensor_selection);
                document.getElementById("SENSOR_SELECTION").value = sensorSettings.get('sensor_selection');
                
                document.getElementById("SENSOR_LENGTH").value = sensorSettings.parseAndSetSensorValue('sensor_length', msg.sensor_length);
                
                document.getElementById("MASTER_FIXTURE_HEIGHT").value = sensorSettings.parseAndSetSensorValue('master_fixture_height', msg.master_fixture_height);
                
                document.getElementById("MASTERING_VALUE").value = sensorSettings.parseAndSetSensorValue('mastering_value', msg.mastering_value);
                
                document.getElementById("MASTER_OFFSET").value = sensorSettings.parseAndSetSensorValue('master_offset', msg.master_offset);
                
                document.getElementById("SMR").value = sensorSettings.parseAndSetSensorValue('start_measurement_range', msg.start_measurement_range);
                
                document.getElementById("SENSOR_MR").value = sensorSettings.parseAndSetSensorValue('sensor_mr', msg.sensor_measurement_range);
                
                sensorSettings.saveValuesForSensorType();
                
                //enableMasteringValuesForEditing(sensorSettings.get('sensor_selection') === 'CUSTOM' || sensorSettings.get('sensor_selection') === 'PROTOTYPE');
                
                // TODO: implement
                //document.getElementById("CALIBRATION_DATE").innerHTML = new Date().toLocaleDateString();
                
                document.getElementById("MEASUREMENT_RATE").value = JSON.parse(msg.measurement_rate).toFixed(3);
                document.getElementById("THRESHOLD").value = JSON.parse(msg.intensity_threshold).toFixed(3);
                
                getConnectionMode();
                //checkConnectionStatus();
                
                break;
            default:
                console.log("pluginMessage: Hit default case.");
                break;
        }
    }

    function authorizeSensorParamsUpdate() {
        // Prompt user for password.
        var nav = navigator.notification;
        if (nav != null) {
            // We have plugins so we're in Cordova.  Use the Cordova notification.
            navigator.notification.prompt('Please enter the password.',
                                          confirmSensorParamsPassword,
                                          'Enter Password',
                                          ['Ok','Cancel'],
                                          '');
        } else {
            // No plugins, so we must not be in Cordova. Use a standard prompt.
            let pw = window.prompt("Please enter the password.", "1");
            confirmSensorParamsPassword({"input1":pw});
        }
    }

    function confirmSensorParamsPassword(results) {
        if (results.buttonIndex > 1) {
            return;
        }
        if (results.input1 == UPDATE_SETTINGS_PASSWORD) {
            updateSensorParameters(document.getElementById("MASTER_FIXTURE_HEIGHT").value,
                                   document.getElementById("MASTERING_VALUE").value,
                                   document.getElementById("MASTER_OFFSET").value,
                                   document.getElementById("SENSOR_SELECTION").value,
                                   document.getElementById("SENSOR_LENGTH").value,
                                   document.getElementById("SMR").value,
                                   document.getElementById("SENSOR_MR").value);
        } else {
            e4PtAlert("Invalid password.");
        }
    }

    function updateSensorParameters(mfh, mval, mo, sensor, sensor_length, smr, mr) {
        // Before updating the values, make sure the user has entered valid numbers.
        let mfh_f = parseFloat(mfh);
        let mstrval_f = parseFloat(mval);
        let mo_f = parseFloat(mo);
        let sensor_length_f = parseFloat(sensor_length);
        let smr_f = parseFloat(smr);
        let mr_f = parseFloat(mr);
        // If a number is not valid, give the user a chance to try again or abort.
        if (isNaN(mfh_f) || isNaN(mstrval_f) || isNaN(mo_f) || isNaN(sensor_length_f) || isNaN(smr_f) || isNaN(mr_f)) {
            e4PtConfirm("Please enter only floating point values.\nPlease try again.", function(buttonIndex) {
                    if (buttonIndex==2) {//Cancel - This cancels and gets the previous values back.
                        getSensorParameters();
                    }
                }
            );
            return;
        }
        messaging.sendMessage({args:[{command:'set_sensor_parameters',hmf:mfh_f.toString(10),mv:mstrval_f.toString(10),mo:mo_f.toString(10),name:sensor,length:sensor_length_f.toString(10),smr:smr_f.toString(10),mr:mr_f.toString(10)}]});
        
        sensorSettings.set('sensor_selection', sensor);
        sensorSettings.set('sensor_length', sensor_length_f);
        sensorSettings.set('master_fixture_height', mfh_f);
        sensorSettings.set('master_offset', mo_f);
        sensorSettings.set('mastering_value', mstrval_f);
        sensorSettings.set('start_measurement_range', smr_f);
        sensorSettings.set('sensor_mr', mr_f);
        sensorSettings.saveValuesForSensorType();
        updateSensorHeaderMessage();
    }

    function getSensorParametersForSensorSelection(sensorType) {
        console.log("@getSensorParametersForSensorSelection: ", sensorType);
        var info = sensorSettings.getSensorType(sensorType);
        if (info && info.measured_mastering_fixture_height_mm) {
            if (sensorParamsFromController && sensorType === sensorFromController) {
                e4PtAlert("Sensor parameters were provided by the controller:\n- Measured Sensor Length\n- Start of Measure Range\n- Measurement Range");
                document.getElementById("SENSOR_LENGTH").value = sensorLengthFromController;
                document.getElementById("MASTER_FIXTURE_HEIGHT").value = sensorSettings.toInches(info.measured_mastering_fixture_height_mm).toFixed(4);
                document.getElementById("SMR").value = smrFromController;
                document.getElementById("SENSOR_MR").value = sensorMRFromController;
            } else {
                document.getElementById("SENSOR_LENGTH").value = sensorSettings.toInches(info.measured_length_mm).toFixed(4);
                document.getElementById("MASTER_FIXTURE_HEIGHT").value = sensorSettings.toInches(info.measured_mastering_fixture_height_mm).toFixed(4);
                //document.getElementById("MASTERING_VALUE").value = info.measured_mastering_value_mm.toFixed(4);
                document.getElementById("SMR").value = info.measured_start_measurement_range_mm.toFixed(4);
                //document.getElementById("SENSOR_MR").value = info.measurement_range_mm.toFixed(4);
            }
            updateMasteringValue();
            updateMasteringOffset();
        }
        
        if (sensorType === 'CUSTOM' || sensorType === 'PROTOTYPE') {
            enableMasteringValuesForEditing(true);
        } else {
            enableMasteringValuesForEditing(false);
            updateSensorParameters(
                document.getElementById("MASTER_FIXTURE_HEIGHT").value,
                document.getElementById("MASTERING_VALUE").value,
                document.getElementById("MASTER_OFFSET").value,
                document.getElementById("SENSOR_SELECTION").value,
                document.getElementById("SENSOR_LENGTH").value,
                document.getElementById("SMR").value,
                document.getElementById("SENSOR_MR").value);
        }
    }
                                                              
    function enableMasteringValuesForEditing(enabled) {
        console.log("@enableMasteringValuesForEditing: ", enabled);
        //document.getElementById("SENSOR_LENGTH").disabled = !enabled;
        //document.getElementById("MASTER_FIXTURE_HEIGHT").disabled = !enabled;
        //document.getElementById("MASTERING_VALUE").disabled = !enabled;
        //document.getElementById("SMR").disabled = !enabled;
        document.getElementById("SENSOR_PARAMS_UPDATE_BUTTON").parentNode.hidden = !enabled;
    }
    
    function updateMasteringOffset() {
        document.getElementById("MASTER_OFFSET").value = sensorSettings.calculateMasteringOffsetInches(
                            parseFloat(document.getElementById("SENSOR_LENGTH").value),
                            parseFloat(document.getElementById("MASTER_FIXTURE_HEIGHT").value),
                            parseFloat(document.getElementById("MASTERING_VALUE").value),
                            parseFloat(document.getElementById("SMR").value))
        .toFixed(4);
    }
    
    function updateMasteringValue() {
        document.getElementById("MASTERING_VALUE").value = sensorSettings.calculateMasteringValueMM(
                            parseFloat(document.getElementById("SENSOR_LENGTH").value),
                            parseFloat(document.getElementById("MASTER_FIXTURE_HEIGHT").value),
                            parseFloat(document.getElementById("SMR").value))
        .toFixed(4);
    }

    function exportDetailsFile(option) {
        let targetFolder = "data";
        let details_file_name = DETAILS_FILE_PREFIX + ".csv";
        let sn = processString(E4PTdata.serial_number);
        let fileDate = processString(E4PTdata.date);
        if ((typeof E4PTdata.serial_number !== 'undefined') || ( E4PTdata.serial_number.length > 0 )) {
            details_file_name = DETAILS_FILE_PREFIX + "_" + sn + "_" + fileDate + ".csv";
            targetFolder = cordova.file.documentsDirectory + sn;
        }
        details_file_name = targetFolder + "/" + details_file_name;
        let attachmentList = [details_file_name];
        if (option == 1) {
            console.log("Email");
            subject = APP_NAME + " Data";
            let toAddress = [];
            sendEmailWithAttachment(toAddress, subject , attachmentList);
        } else if (option == 2) {
            console.log("Upload To Box");
            for (let i=0; i<attachmentList.length; i++) {
                attachmentList[i] = attachmentList[i].replace("file://","");
            }
            uploadFileToBox(attachmentList);
        } else {
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
                if (cell.classList[j] == "table-active") {
                    console.log("exportFiles: Appending " + cell.attributes.nativeURL.value);
                    attachmentList.push(cell.attributes.nativeURL.value);
                }
            }
        }
        if (option == 1) {
            console.log("Email");
            subject = APP_NAME + " Data";
            let toAddress = [];
            sendEmailWithAttachment(toAddress, subject , attachmentList);
        } else if (option == 2) {
            console.log("Upload To Box");
            for (let i=0; i<attachmentList.length; i++) {
                attachmentList[i] = attachmentList[i].replace("file://","");
            }
            uploadFileToBox(attachmentList);
        } else {
            console.log("Cancel");
        }
        // Clear selected items.
        for (let i=0; i<tbl.rows.length; i++) {
            let row = tbl.rows[i];
            let cell = row.cells[0]; // Should only be one cell.
            cell.classList.remove("table-active");
        }
    }

    // exportFile is the callback from a prompt to email, upload or cancel. Only handles one file.
    // The returned option is 1 (email), 2 (upload) or 3 (cancel).
    function exportFile(option) {
        console.log("@exportFile: ", option);
        if (option == 1) {
            console.log("Email");
            // do something with downloadFileName
            subject = APP_NAME + " Data";
            attachmentFileName = downloadFileName;
            if (attachmentFileName.length > 0) {
                attachmentFileName = "file://" + attachmentFileName;
            } else {
                attachmentFileName = [];
            }
            let toAddress = [];
            sendEmailWithAttachment(toAddress, subject , attachmentFileName);
        } else if (option == 2) {
            console.log("Upload");
            // do something with downloadFileName
            if (downloadFileName.length == 0) {
                e4PtAlert("There is no recent file to upload.");
                return;
            }
            uploadFileToBox(downloadFileName);
        } else {
            console.log("Cancel");
        }
    }

    function sendEmailWithAttachment(toAddress, subject, attachment) {
        // Check if email is set up on this device.  If not, alert the user.
        // If so, try to send the email.
        window.plugin.email.isAvailable('mailto', function(available) {
            if (!available) {
                alert("Error: Email is not set up on this device.");
            } else {
                window.plugin.email.open({
                 to: toAddress,
                 cc: [],
                 bcc: [],
                 attachments: attachment,
                 subject: subject,
                 body: [],
                 isHtml: false
                 });
            }
        }, this);
    }

    function uploadFileToBox(fileFullPath) {
        console.log(' fileFullPath  : ' + fileFullPath);
        // Uncomment the line below when we have a provisioning profile with iCloud entitlements from the COE.
        // Until then this function does nothing.
        if (messaging.usesPlugin()) {
            window.plugins.doc_picker_plugin.uploadFileToBox(fileFullPath);
        } else if (messaging.usesWebSocket()) {
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
    function listDir(path) {
        console.log("@listDir: ", path);
        window.resolveLocalFileSystemURL(path, function (fileSystem) {
            var reader = fileSystem.createReader();
            reader.readEntries(function (entries) {
                populateFileTable(entries);
            }, function (err) {
                err = "Error processing entry: " + JSON.stringify(err);
                console.log(err);
                populateFileTable([]);
            });
        }, function (err) {
            err = "Error reading entries: " + JSON.stringify(err);
            console.log(err);
            populateFileTable([]);
        });
    }
    
    function deleteFile(dir, fileName) {
        console.log("@deleteFile: dir=" + JSON.stringify(dir) + ", fileName=" + fileName);
        dir.getFile(fileName, { create: false }, function (fileEntry) {
            console.log("fileEntry=", JSON.stringify(fileEntry));
            fileEntry.remove(function (file) {
                console.log("file removed");
            }, function (error) {
                console.log("error in deleteFile type 1: " + error.code);
            }, function () {
                console.log("error in deleteFile: file does not exist");
            });
        });
    }
    
    function deleteFolder(fileName) {
        console.log ("deleteFolder: " + fileName);
        window.resolveLocalFileSystemURL(fileName, function (dirEntry) {
            dirEntry.removeRecursively(
                console.log('successfully deleted the folder and its content'),
                //e => console.error('there was an error deleting the directory', e.toString())
            )
        });
    }
    
    //examples:
    //deleteFilesInDir(cordova.file.documentsDirectory + "data");
    //deleteFilesInDir(cordova.file.documentsDirectory + serial_number);
    function deleteFilesInDir(path) { // issue #35  This removes the files in the directory
        console.log("path = " + path);
        window.resolveLocalFileSystemURL(path, function (dir) {
            var reader = dir.createReader();
            reader.readEntries(function (fileName) {
                console.log("in deleteFilesInDir fileName = ")
                fileName.map(el => {
                    deleteFile(dir, el.name); // nativeURL.replace('file://', ''))
                })
            }, function (err) {
                console.log("Error in deleteFilesInDir type 1: " + err);
            });
        }, function (err) {
            console.log("Error in deleteFilesInDir type 2: " + err);
        });
    }

    function toggleFileSelected(fileName) {
        var table = document.getElementById("LOCAL_FILE_TABLE_BODY");
        for (var i = 0; i <  table.rows.length; i++) {
            row = table.rows[i]
            cell = row.cells[0];
            if (cell.innerHTML == fileName) {
                cell.classList.toggle("table-active");
            }
        }
    }

    function filterArray(arr, index) {
        return arr.reduce((prev, x, i) => prev.concat(i !== index ? [x] : []), []);
    }
    
    function deleteEntry(nativeURL, i) {
        console.log("@deleteEntry: nativeURL=" + nativeURL + ", i=" + i);
        var path =  nativeURL;
        var dirArr = path.split('/');
        var filename = dirArr[dirArr.length - 1];
        path = path.replace(filename, '');
        
        e4PtConfirm("Are you sure you want to delete the file " + filename + "?", function(idx) {
            if (idx == 1) {
                console.log("deleteEntry confirmed");
                window.resolveLocalFileSystemURL(path, function (dirEntry) {
                    deleteFile(dirEntry, filename);
                    console.log("updating entries");
                    window.entries = filterArray(window.entries, i);
                    populateFileTable(window.entries);
                }, function(error) {
                    console.log("Error in deleteEntry type 2: " + error);
                });
            }
        });
    }

    function populateFileTable(entries) {
        console.log("@populateFileTable: " + entries.length);
        $("#FILE_CHOOSER_PAGE").fadeIn();
        var prev_tbody = document.getElementById("LOCAL_FILE_TABLE_BODY");
        var tbody = document.createElement("tbody");
        tbody.setAttribute("id","LOCAL_FILE_TABLE_BODY");
        // Create the table body.
        window.entries = entries;
        let fileEntries = entries.filter(element => element.isFile); // ignore any non-file entries
        console.log("fileEntries: " + fileEntries.length);
        var sortedFileEntries = fileEntries.sort(function (a, b) {
            if (a.name < b.name) return -1;
            if (a.name > b.name) return 1;
            return 0;
        });
        sortedFileEntries.forEach((entry, index, array) => {
            if (entry.name == ".DS_Store") return;
            let sn = processString(E4PTdata.serial_number);
            let fileSelectFn = "toggleFileSelected(\"" + entry.name + "\")";
            let deleteEntryFn = "deleteEntry(\"" + entry.nativeURL +  "\"," + index + ")";
            var new_row = tbody.insertRow(-1);
            var cell0 = new_row.insertCell(-1);
            cell0.innerHTML = entry.name;
            cell0.setAttribute("onclick",fileSelectFn);
            cell0.setAttribute("nativeURL",entry.nativeURL);
            // apply color coding to 'final' files
            if (entry.name.startsWith(DETAILS_FILE_PREFIX)) {
                if (entry.name == E4PTdata.details_filename) {
                    cell0.classList.add("table-success");
                } else {
                    cell0.classList.add("table-warning");
                }
            } else if (entry.name.startsWith(CUSTOMER_REPORT_FILE_PREFIX)) {
                if (entry.name == E4PTdata.report_filename) {
                    cell0.classList.add("table-success");
                } else {
                    cell0.classList.add("table-warning");
                }
            } else if (entry.name.startsWith(EMAIL_FILE_PREFIX)) {
                if (entry.name == E4PTdata.email_filename) {
                    cell0.classList.add("table-success");
                } else {
                    cell0.classList.add("table-warning");
                }
            } else if (entry.name.startsWith(LOG_FILE_PREFIX)) {
                console.log("Ignoring log file");
            } else if (entry.name.startsWith(DATA_FILE_PREFIX)) {
                console.log("TODO: handle GET DATA file coloring");
            } else if (entry.name.startsWith(sn)) {
                let dataSet = E4PTdata.sets.find(o => (o.filename === sn + '/' + entry.name));
                if (typeof dataSet !== 'undefined') {
                    cell0.classList.add("table-success");
                } else {
                    cell0.classList.add("table-warning");
                }
            } else {
                console.log("Unknown file entry: ", entry);
            }
            // disabled due to performance with large amount of records
            /*var cell1 = new_row.insertCell(-1);
            cell1.classList.add("text-center");
            cell1.innerHTML = '<i class="fas fa-trash-alt fa-lg text-danger"></i>';
            //cell1.innerHTML = '<button type="button" class="btn btn-danger">DELETE</button>';
            cell1.setAttribute("onclick",deleteEntryFn);*/
            //cell1.setAttribute("nativeURL",entry.nativeURL);
        });
        prev_tbody.parentNode.replaceChild(tbody, prev_tbody);
        //sortTable('LOCAL_FILE_TABLE', 0); // not needed due to sorting of entries
        $("#FILE_CHOOSER_PAGE").fadeIn();
    }

    function populateDetailsTable() {
        console.log('@populateDetailsTable');
        writeDetailsFile();  // Write the CSV file so it will be produced at the same time as the table.
        $("#TURBINE_SETUP_PAGE").fadeOut();
        $("#DATA_DETAILS_PAGE").fadeIn();
        var prev_tbody = document.getElementById("DATA_DETAILS_TABLE_BODY");
        var tbody = document.createElement("tbody");
        tbody.setAttribute("id","DATA_DETAILS_TABLE_BODY");
        // Create the table body.
        let tmp = "";
        var sortedSets = E4PTdata.sets.sort(function (a, b) {
            let aStageArr = a.stage.split(".");
            let aStage = parseInt(aStageArr[0]);
            let aSubStage = 0;
            if (aStageArr.length > 1) {
                aSubStage = parseInt(aStageArr[1]);
            }
            aStage = (10 * aStage) + aSubStage;
            let bStageArr = b.stage.split(".");
            let bStage = parseInt(bStageArr[0]);
            let bSubStage = 0;
            if (bStageArr.length > 1) {
                bSubStage = parseInt(bStageArr[1]);
            }
            bStage = (10 * bStage) + bSubStage;

            if (aStage < bStage) {
                return -1;
            } else if (aStage > bStage) {
                return 1;
            } else {
                // compare position index for same stage/substage
                let aPosIdx = current_frame_data.position[a.stage].indexOf(a.position);
                let bPosIdx = current_frame_data.position[b.stage].indexOf(b.position);
                if (aPosIdx < bPosIdx) {
                    return -1;
                } else if (aPosIdx > bPosIdx) {
                    return 1;
                } else {
                    return 0;
                }
            }
        });
        sortedSets.forEach((entry, index, array) => {
            let clickFn = "toggleDetailsSelected(\"" + index + "\")";
            var new_row = tbody.insertRow(-1);
            var cell1 = new_row.insertCell(-1);
            cell1.setAttribute("onclick",clickFn);
            tmp = entry.stage;
            if (typeof tmp == 'undefined') tmp = "";
            cell1.innerHTML = tmp;
            var cell2 = new_row.insertCell(-1);
            cell2.setAttribute("onclick",clickFn);
            tmp = entry.position;
            if (typeof tmp == 'undefined') tmp = "";
            cell2.innerHTML = tmp;
            var cell3 = new_row.insertCell(-1);
            cell3.setAttribute("onclick",clickFn);
            cell3.innerHTML = checkValue(entry.clearance, DETAILS_PRECISION);
            if (entry.manualOverride) {
              cell3.classList.add("table-danger");
            }
            var cell4 = new_row.insertCell(-1);
            cell4.setAttribute("onclick",clickFn);
            cell4.innerHTML = checkValue(entry.max_clr, DETAILS_PRECISION);
            var cell5 = new_row.insertCell(-1);
            cell5.setAttribute("onclick",clickFn);
            cell5.innerHTML = checkValue(entry.min_clr, DETAILS_PRECISION);
            var cell6 = new_row.insertCell(-1);
            cell6.setAttribute("onclick",clickFn);
            cell6.innerHTML = checkValue(entry.med_clr, DETAILS_PRECISION);
            var cell7 = new_row.insertCell(-1);
            cell7.setAttribute("onclick",clickFn);
            cell7.innerHTML = checkValue(entry.std_clr, DETAILS_PRECISION);
        });
        prev_tbody.parentNode.replaceChild(tbody, prev_tbody);
    }

    // checkValue(val) checks a string to make sure it's a number,
    // and converts it to a string with only n decimal places.
    function checkValue(val,n) {
        if (typeof val == 'undefined') {
            val = "";
        } else {
            let tmp_f = parseFloat(val);
            if (isNaN(tmp_f)) {
                val = "";
            } else {
                val = tmp_f.toFixed(n);
            }
        }
        return val;
    }

    // writeDetailsFile() does just that.  It writes a CSV file containing
    // the details for the data collected.
    function writeDetailsFile() {
        console.log("@writeDetailsFile");
        // Construct a string containing the file contents.
        let contents = "stage,position,clearance,max_clr,min_clr,med_clr,std_clr,override,name,sso\n";
        for (let i=0; i<E4PTdata.sets.length; i++) {
            contents += E4PTdata.sets[i].stage + ","
                + E4PTdata.sets[i].position +  ","
                + checkValue(E4PTdata.sets[i].clearance, DETAILS_PRECISION) + ","
                + checkValue(E4PTdata.sets[i].max_clr, DETAILS_PRECISION) + ","
                + checkValue(E4PTdata.sets[i].min_clr, DETAILS_PRECISION) + ","
                + checkValue(E4PTdata.sets[i].med_clr, DETAILS_PRECISION) + ","
                + checkValue(E4PTdata.sets[i].std_clr, DETAILS_PRECISION) + ","
                + E4PTdata.sets[i].manualOverride + ",";
            if (E4PTdata.sets[i].manualOverride) {
                contents += E4PTdata.sets[i].overrideName + ","
                    + E4PTdata.sets[i].overrideSSO;
            } else {
                contents += ",";
            }
            contents += "\n";
        }
        let targetFolder = "data"; // default directory
        let fileName = DETAILS_FILE_PREFIX + ".csv";
        if ((typeof E4PTdata.serial_number !== 'undefined') || ( E4PTdata.serial_number.length > 0 )) {
            let sn = processString(E4PTdata.serial_number);
            targetFolder = sn;
            let fileDate = processString(E4PTdata.date);
            fileName = DETAILS_FILE_PREFIX + "_" + sn + "_" + fileDate + ".csv";
        }
        E4PTdata.details_filename = fileName;
        console.log("DETAILS FILE: ", fileName);
        addDBEntry(E4PTdata); // update filename
        writeToFile(targetFolder, fileName, contents, null);
    }


    function toggleDetailsSelected(idx) {
        let tbl = document.getElementById("DATA_DETAILS_TABLE_BODY");
        let row = tbl.rows[idx];
        let cell = row.cells[0]; // Should only be one cell.
        cell.classList.toggle("table-active");
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
    
    function deleteMultipleFiles() {
        console.log("@deleteMultipleFiles");
        let path = cordova.file.documentsDirectory + "data";
        if (fromDataCollectionPage) {
            console.log("fromDataCollectionPage");
            let sn = processString(E4PTdata.serial_number);
            path = cordova.file.documentsDirectory + sn;
        }
        console.log(path);
        let deleteList = [];
        let tbl = document.getElementById("LOCAL_FILE_TABLE_BODY");
        for (let i=0; i<tbl.rows.length; i++) {
            let row = tbl.rows[i];
            let cell = row.cells[0]; // Should only be one cell.
            for (let j=0; j<cell.classList.length; j++) {
                if (cell.classList[j] == "table-active") {
                    let dirArr = cell.attributes.nativeURL.value.split('/');
                    let filename = dirArr[dirArr.length - 1];
                    console.log("deleteMultipleFiles: Appending " + filename);
                    deleteList.push(filename);
                }
            }
        }
        
        e4PtConfirm("Are you sure you want to delete " + deleteList.length + " file(s)?", function(idx) {
            if (idx == 1) {
                console.log("deleteMultipleFiles confirmed");
                window.resolveLocalFileSystemURL(path, function (dirEntry) {
                    for (let i=0; i<deleteList.length; i++) {
                        deleteFile(dirEntry, deleteList[i]);
                    }
                    listDir(path);
                }, function(error) {
                    console.log("Error in deleteMultipleFiles: " + error);
                });
            }
        });
    }

    function multipleFileDownloadFunction() {
        console.log("@multipleFileDownloadFunction");
        let prompt = "Email or Upload Files?";
        e4PtPrompt(prompt, exportFiles, "Get File", ["Email","Upload to Box","Cancel"]);
    }

    function selectedFilesDownloadFunction() {
        let tbl = document.getElementById("LOCAL_FILE_TABLE_BODY");
        for (let i=0; i<tbl.rows.length; i++) {
            let cell = tbl.rows[i].cells[0]; // There's only one cell per row in the file lists.
        }
    }
    
    function setIndicatorColor( color ) {
        console.log("@setIndicatorColor: " + color);
        let allColors = "text-danger text-warning text-success text-primary text-light";
        let targetColor = "text-light";
        switch(color) {
          case "red":
            targetColor = "text-danger";
            break;
          case "yellow":
            targetColor = "text-warning";
            break;
          case "green":
            targetColor = "text-success";
            break;
          case "blue":
            targetColor = "text-primary";
            break;
          case "white":
            targetColor = "text-light";
            break;
          default:
            targetColor = "text-light";
        }
        $("#CONNECTION_INDICATOR")
            .removeClass(allColors)
            .addClass(targetColor);
    }

    function setMasterMessage( bgColor, txt ) {
        setSpanProperties($("#master_message"), txt, bgColor);
    }

    function setMasterMessage2( bgColor, txt ) {
        setSpanProperties($("#master_message_2"), txt, bgColor);
    }

    function processE4PtData(msg) {
      console.log("@processE4PtData");
      try {
        $.extend(E4PTdata, msg);
      } catch (err) {
        console.log(err);
      }

      try {
        update_scan_info(); // currently does nothing
        parse_data();
          
        /*if (E4PTdata.data.length > 0) {
          var d0 = E4PTdata.data[0];
          var allEqual = E4PTdata.data.every(function(d) {
            return d === d0;
          });
          if (allEqual) {
            e4PtAlert("Invalid data, all clearance values are identical: " + d0);
          }
        }*/

        document.getElementById('MEASUREMENT_RATE').value = E4PTdata.measurement_rate;
        document.getElementById('THRESHOLD').value = E4PTdata.intensity_threshold;
        
        // only display the DATA PLOT page for GET DATA or SENSOR SETUP and not from DATA COLLECTION
        if (fromGetData || fromSensorSetupPage) {
          fadeOutAll();
          $("#DATA_PLOT_PAGE").fadeIn();
          fromGetData = false;
          fromDataCollectionPage = false;
        }

        if (current_frame_data['position'] != null) {
          plot_calibrated_acquire();
        } else {
          plot_non_calibrated_acquire();
        }
        advance_position();
      } catch (error) {
        console.log(error);
      }
    }

    function requestE4PtData(acquisitionTime) {
        console.log("@requestE4PtData");
        console.log("Requesting " + acquisitionTime + " seconds of data");
        charting.clearChartData(document.getElementById('DATA_PLOT'));
        startProgressBar();

        // send_data needs args: acquisition time and casing thickness
        // Casing thickness can be zero here.
        if (messaging.usesWebSocket()) {
            setIndicatorColor("yellow");
        }
        messaging.sendMessage({args:[{command:'send_data',acquisitionTime:acquisitionTime}]});
    }

    function requestE4PtDataWithMetaData(acquisitionTime, frame, sn, stage, position, casing_thickness, spacer_thickness, master_offset, clearance_calc_selection) {
        console.log("@requestE4PtDataWithMetaData");
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
            if (typeof current_frame_data.stage_info[current_stage_type] !== 'undefined') {
                stage_details = get_stage_details(position, casing_thickness);
                num_blades = stage_details.blade_count;
                blade_width = stage_details.blade_width;
                tip_diameter = stage_details.tip_diameter;
                if (num_blades == 0) {
                    e4PtAlert("This stage and casing thickness do not match. Please check the casing thickness and try again.\nIf the casing thickness is verified, you may perform a manual drop check (do not insert the probe) and provide an override measurement.");
                    return;
                }
            } else {
                console.log('UNDEFINED STAGE INFO FOR TYPE: current_stage_type=' + current_stage_type);
            }
        } else {
            console.log('UNDEFINED STAGE INFO: frame=' + frame + ', stage=' + stage + ', position=' + position);
        }
        //charting.clearChartData(document.getElementById('DATA_PLOT'));
        charting.clearChartData(document.getElementById('DATA_PLOT2'));
        document.getElementById("DATA_PLOT2").innerHTML = "";
        if (messaging.usesWebSocket()) {
            setIndicatorColor('yellow');
        }
                
        // set flag to show DATA COLLECTION page on close, disabled to show plot2
        //fromDataCollectionPage = true;
        
        acquisitionTime = acquisitionTime.replace("rpm","");
        selected_frame_data.RPM = acquisitionTime;
        
        // ensure that UI is updated, this should occur on "acquiring" status
        displayAbortButton();
        setIndicatorColor("red");
        startProgressBar();
        
        $("#PROCESSING_PAGE").fadeIn();

        messaging.sendMessage({args:[{
            command:'send_data',
            rpms:acquisitionTime,
            serialNumber:sn,
            stage:stage,
            position:position,
            casingThickness:casing_thickness,
            spacerThickness:spacer_thickness,
            numberOfBlades:num_blades,
            tipDiameter:tip_diameter,
            bladeWidth:blade_width,
            clearanceCalculationMethod:clearance_calc_selection
        }]});
    }

    // get_stage_details find the specific information for this stage, given the frame, position,
    // and casing thickness.
    function get_stage_details(position, casing_thickness) {
        console.log('@get_stage_details: ' + position + ', ' + casing_thickness);
        var details = {};
        details["blade_width"] = 0;
        details["blade_count"] = 0;
        details["tip_diameter"] = 0;
        var stageKeys = Object.keys(current_frame_data.stage_info); // Get all the stage information names
        for (var idx in stageKeys) {
            var stageKey = stageKeys[idx];
            var stageInt = Math.floor(parseFloat(stageKeys[idx])); // Get the base stage number for this entry, ignore optional .# suffix.
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

    function update_scan_info() {
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
        } else {
            E4PTdata.minima = [];
        }
        console.log("minima: ", E4PTdata.minima.length);
        console.log("Clearance average: ", E4PTdata.clearance);
        // Only update the clearance(s) info if we have all the data to do so.
        if (current_frame_data['position'] != null) {
            let clearance_f = parseFloat(E4PTdata.clearance);
            if (clearance_f < 0) {
                e4PtAlert("The clearance is negative. This indicates a problem with the setup (i.e. the sensor is out of range).\nPlease make sure the spacer is correct and the sensor and spacer are installed properly and try again.");
            }
            if (E4PTdata.units.toUpperCase().includes("IN")) {
                clearance_f = sensorSettings.toInches(clearance_f);
                E4PTdata.clearance = clearance_f.toString(10);
                E4PTdata.max_clr = sensorSettings.toInches(parseFloat(E4PTdata.max_clr)).toString(10);
                E4PTdata.min_clr = sensorSettings.toInches(parseFloat(E4PTdata.min_clr)).toString(10);
                E4PTdata.med_clr = sensorSettings.toInches(parseFloat(E4PTdata.med_clr)).toString(10);
                E4PTdata.std_clr = sensorSettings.toInches(parseFloat(E4PTdata.std_clr)).toString(10);
            }
            update_clearance(clearance_f, E4PTdata.manualOverride);
        }

        E4PTdata.frame = document.getElementById("FRAME_SIZE").value;
        E4PTdata.serial_number = document.getElementById("SERIAL_NUMBER").value;
        E4PTdata.ambient_temperature = document.getElementById("AMBIENT_TEMPERATURE").value;
        var set = new Data_Set();
        set.stage = current_stage;
        set.position = current_position;
        set.case_thickness = document.getElementById("CURR_CASE_THICKNESS").value;
        set.clearance = E4PTdata.clearance;
        set.manualOverride = E4PTdata.manualOverride;
        set.overrideName = E4PTdata.overrideName;
        set.overrideSSO = E4PTdata.overrideSSO;
        set.state = E4PTdata.state;
        set.max_clr = E4PTdata.max_clr;
        set.min_clr = E4PTdata.min_clr;
        set.med_clr = E4PTdata.med_clr;
        set.std_clr = E4PTdata.std_clr;
        set.intensity_threshold = E4PTdata.intensity_threshold;
        set.measurement_rate = E4PTdata.measurement_rate;
        set.dateStr = E4PTdata.date;
        set.filename = E4PTdata.filename;
        set.ambient_temperature = E4PTdata.ambient_temperature;
        addOrReplaceSet(set);
        if (doDBSave) {
          addDBEntry(E4PTdata); // save the data autmatically after acquisition
        }
    }

    // addOrReplace(set) will check existing data to see if there is already data for this
    // stage & position.  If not, it will add it.  If so, it will replace it.
    function addOrReplaceSet(set) {
        console.log("@addOrReplaceSet");
        // This next line looks up any previous data set for this stage and position.  If it is not
        // found the result will be undefined.
        let priorSet = E4PTdata.sets.find(o => ((o.stage === set.stage) && (o.position === set.position)));
        if (typeof priorSet == 'undefined') {
            // There is no prior data for this set, so add this set and return.
            E4PTdata.sets.push(set);
            return;
        }
        // If prior data for this stage & position was found, replace it with this new data.
        console.log("priorSet before:  ", JSON.stringify(priorSet));
        priorSet.stage = set.stage;
        priorSet.position = set.position;
        priorSet.case_thickness = set.case_thickness;
        priorSet.clearance = set.clearance;
        priorSet.manualOverride = set.manualOverride;
        priorSet.overrideName = set.overrideName;
        priorSet.overrideSSO = set.overrideSSO;
        priorSet.state = set.state;
        priorSet.max_clr = set.max_clr;
        priorSet.min_clr = set.min_clr;
        priorSet.med_clr = set.med_clr;
        priorSet.std_clr = set.std_clr;
        priorSet.intensity_threshold = set.intensity_threshold;
        priorSet.measurement_rate = set.measurement_rate;
        priorSet.dateStr = set.dateStr;
        priorSet.filename = set.filename;
        priorSet.ambient_temperature = set.ambient_temperature;
        console.log("priorSet after:  ", JSON.stringify(priorSet));
    }

    function update_clearance(clearance, manual_clearance = false) {
        console.log("@update_clearance: clearance:", clearance, "; manual_clearance:", manual_clearance);
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
        } else {
            clearance_f = parseFloat(clearance);
        }
        var err_id = document.getElementById("CLEARANCE_ERROR");
        var err_str = "";

        if (isNaN(clearance_f)) {
            document.getElementById(el_id).innerHTML = "";
            err_id.innerHTML = err_str;
            return;
        } else if (clearance_f < -9.0) {
            document.getElementById(el_id).innerHTML = "Err";
            err_id.innerHTML = err_str;
            return;
        } else if (clearance_f == -9.994) {
            // unused
            err_str = "Error: Problem finding blade tips (3).";
        } else if (clearance_f == -9.995) {
            // clearance is NAN
            err_str = "Error: Clearance computed to NaN value.";
        } else if (clearance_f == -9.996) {
            // no samples found
            err_str = "Error: No gaps detected in data.";
        } else if (clearance_f == -9.997) {
            // unused
            err_str = "Error: No gaps detected in data.";
        } else if (clearance_f == -9.998) {
            // unused
            err_str = "Error: gaps contains all NaN values.";
        } else if (clearance_f == -9.999) {
            // unused
            err_str = "Error: Clearance computed to NaN value.";
        }

        if (E4PTdata.quality.length > 0) {
            var blades_count = 0;
            for (var i=0; i<E4PTdata.quality.length; i++) {
                if (E4PTdata.quality[i] < 1.0) {
                    blades_count += 1;
                }
            }
            if (blades_count > 0) {
                err_str = err_str + " Data for " + blades_count + " blades deviates by >0.001 in.";
                err_id.innerHTML = err_str;
            }
        }
        err_id.innerHTML = err_str;

        // reset cell in case it was previously overridden
        if (!manual_clearance) {
            document.getElementById(el_id).classList.remove("table-danger");
        }

        document.getElementById(el_id).innerHTML = clearance_f.toFixed(4);
    }

    function plot_non_calibrated_acquire() {
      console.log("@plot_non_calibrated_acquire");
      let chartConfig = charting.createChartConfig(E4PTdata.data, E4PTdata.minima);
      //chartConfig.chart.backgroundColor = 'white';
      chartConfig.chart.panning = true;
      chartConfig.chart.panKey = 'shift';
      chartConfig.chart.zoomType = 'xy';
      charting.addChartSubtitle(chartConfig, E4PTdata.date, E4PTdata.clearance, E4PTdata.blades, E4PTdata.blade_samples_avg, E4PTdata.overall_avg, null);
      charting.displayIntensityThresholdAndMeasurementRate(chartConfig, E4PTdata.measurement_rate, E4PTdata.intensity_threshold);
      let chartFilename = charting.createSavedChartFilename(E4PTdata.date.substring(2));
      charting.renderChart(chartConfig, 'DATA_PLOT', chartFilename, writeToFile);
    }

    function plot_calibrated_acquire() {
      console.log("@plot_calibrated_acquire");
      let chartConfig = charting.createChartConfig(E4PTdata.data, E4PTdata.minima);
      chartConfig.tooltip.enabled = false;
      chartConfig.series[0].name = 'Filtered ' + chartConfig.series[0].name;
      charting.addChartSubtitle(chartConfig, E4PTdata.date, E4PTdata.clearance, E4PTdata.blades, E4PTdata.blade_samples_avg, null, selected_frame_data);
      charting.displayIntensityThresholdAndMeasurementRate(chartConfig, E4PTdata.measurement_rate, E4PTdata.intensity_threshold);
      let chartFilename = charting.createSavedChartFilename(E4PTdata.date.substring(2), E4PTdata.serial_number, current_stage, current_position.substring(0,1));
      //charting.renderChart(chartConfig, 'DATA_PLOT', chartFilename, writeToFile);
      charting.renderChart(chartConfig, 'DATA_PLOT2', chartFilename, writeToFile);
    }

    function loadExternalFile(dir, filename) {
        window.resolveLocalFileSystemURL(dir, function (dirEntry) {
            dirEntry.getFile(filename, {create: false, exclusive: false}, function(fileEntry) {
                loadJSONFile(fileEntry);
            });
        }, function(error) {
            console.log(error);
        });
    }

    function loadJSONFile(fileEntry) {
        fileEntry.file(function (file) {
            var reader = new FileReader();
            reader.onloadend = function() {
                
                var data = JSON.parse(this.result);
                if (json_data_is_valid(data)) {
                    data.pouchdb_id = "";
                    
                    window.resolveLocalFileSystemURL(cordova.file.documentsDirectory, function (dirEntry) {
                        dirEntry.getDirectory(data.serial_number, {create: true}, function(subDirEntry) {
                            
                            addDBEntry(data);
                            fileEntry.moveTo(subDirEntry, file.name);
                            
                            fadeOutAll();
                            set_frame_information();
                            initializeFromDocument(data);
                            writeDetailsFile();
                            
                        }, function(error) {
                            console.log(error);
                        });
                    }, function(error) {
                        console.log(error);
                    });
                } else {
                    e4PtAlert("There is a problem with the JSON file, that has prevented it from being loaded.");
                    fileEntry.remove();
                }
            };
            reader.readAsText(file);
        }, function(error) {
            console.log(error);
        });
    }

    // TODO: unused
    function doSSO() {
      console.log("@doSSO");
      var authServerUri = SSO_AUTH_URL + "?response_type=" + SSO_RESPONSE_TYPE + "&scope=" + SSO_SCOPE + "&client_id=" + SSO_CLIENT_ID + "&redirect_uri=" + SSO_REDIRECT_URI
      var authParams = {
        response_type: SSO_RESPONSE_TYPE,
        scope: SSO_SCOPE,
        client_id: SSO_CLIENT_ID,
        redirect_uri: SSO_REDIRECT_URI
      };
      // Redirect to Authorization page.
      //var replacementUri = SSO_AUTH_URL + "?" + $.param(authParams);
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

    function addDBEntry(e4pt_data, db=local_db) {
      console.log("@addDBEntry");
      var entry = {
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
        temperature_units: e4pt_data.temperature_units,
        final: e4pt_data.final,
        date: e4pt_data.date,
        time: e4pt_data.time,
        sets: e4pt_data.sets,
        turbine_casing_thicknesses: e4pt_data.turbine_casing_thicknesses,
        alreadyOnLDB: e4pt_data.alreadyOnLDB,
        details_filename: e4pt_data.details_filename,
        report_filename: e4pt_data.report_filename,
        email_filename: e4pt_data.email_filename
        // We don't save the locs, minima, or data elements of e4pt_data because it
        // contains dense data and could overwhelm the database & browser memory.
        // We also don't save the clearance element because it is saved in the sets
        // element.
      };

      if (e4pt_data.pouchdb_id.length == 0) {
        // This is a new db entry, so get a new id.
        e4pt_data.pouchdb_id = uuidv4();
        entry._id = e4pt_data.pouchdb_id;
        db.put(entry, function callback(err, result) {
          if (!err) {
            console.log('PouchDB: Successfully added an entry!');
          }
        });
      } else {
        // This db entry exists, so just update it.
        db.get(e4pt_data.pouchdb_id, function(err, doc) {
          if (err) {
            console.log("Error getting existing document from the database.");
          } else {
            // Since we're updating this entry make sure its _id & _ref agree
            // with what's in the DB.
            entry._id = doc._id;
            entry._rev = doc._rev;
            entry.sets = e4pt_data.sets;
            db.put(entry, function callback(err, result) {
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

    function getAllDBEntries(elementID, db=local_db) {
      console.log("getAllDBEntries: ", elementID);
      db.allDocs({include_docs: true, descending: true}, function(err, docs) {
        console.log("offset: " + docs.offset + "; total_rows: " + docs.total_rows);
        redrawDataSetsUI(docs.rows, elementID);
      });
    }

    function redrawDataSetsUI(rows, elementID) {
      console.log("@redrawDataSetsUI: ", elementID);
      var prev_tbody = document.getElementById(elementID);
      var tbody = document.createElement("tbody");
      var dataSource = (elementID.includes('ARCHIVE') ? 'Archive' : 'Local');
      tbody.setAttribute("id",elementID);
      // Create the table body.
      for (var i=0; i<rows.length; i++) {
        console.log("Row: id:" + rows[i].doc._id + "; rev: " + rows[i].doc._rev);
        var new_row = tbody.insertRow(-1);
        // save the ID in a hidden column so we can get it to retrieve the data.
        // The first column is hidden.
        var cell0 = new_row.insertCell(-1);
        cell0.innerHTML = rows[i].doc._id;
        cell0.setAttribute("style","display:none;");
        // allow users to open data from both local and archive
        var clickFn = (elementID.includes('ARCHIVE') ? "loadArchiveData(\"" + rows[i].doc._id + "\")" : "loadLocalData(\"" + rows[i].doc._id + "\")");
          
        var cellb = new_row.insertCell(-1);
        var checkbox = '<input type="checkbox"' + ' class="form-check-input form-control-lg" id="checkBox' + dataSource + 'IdNum' + i.toString() + '" value="no">';
        cellb.innerHTML = checkbox;
        cellb.setAttribute("class", "text-center");

        var cell1 = new_row.insertCell(-1);
        cell1.innerHTML = rows[i].doc.frame;
        cell1.setAttribute("onclick",clickFn);
        
        var cell2 = new_row.insertCell(-1);
        cell2.innerHTML = rows[i].doc.serial_number;
        cell2.setAttribute("onclick",clickFn);

        var cell3 = new_row.insertCell(-1);
        cell3.innerHTML = rows[i].doc.customer;
        cell3.setAttribute("onclick",clickFn);
        
        var cell4 = new_row.insertCell(-1);
        cell4.innerHTML = rows[i].doc.site_name;
        cell4.setAttribute("onclick",clickFn);
        
        var cell5 = new_row.insertCell(-1);
        cell5.innerHTML = rows[i].doc.description;
        cell5.setAttribute("onclick",clickFn);
        
        var cell6 = new_row.insertCell(-1);
        cell6.innerHTML = rows[i].doc.date;
        cell6.setAttribute("onclick",clickFn);
        
        var cell7 = new_row.insertCell(-1);
        cell7.innerHTML = rows[i].doc.time;
        cell7.setAttribute("onclick",clickFn);
      }
      prev_tbody.parentNode.replaceChild(tbody, prev_tbody);
    }

    // unused
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
      tmpData1.temperature_units = "Fahrenheit";
      tmpData1.final = false;
      tmpData1.date = "Jul-04-1776";
      tmpData1.time = "13:13";
      var set1 = new Data_Set();
      set1.stage = 5;
      set1.position = "TOP";
      set1.case_thickness = 4.967;
      set1.clearance = 3.1415;
      set1.manualOverride = false;
      set1.state = "opening";
      set1.ambient_temperature = 70;
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
      tmpData2.temperature_units = "Fahrenheit";
      tmpData2.final = true;
      tmpData2.date = "Jul-24-1969";
      tmpData2.time = "20:17";
      var set2 = new Data_Set();
      set2.stage = 17;
      set2.position = "BOTTOM";
      set2.case_thickness = 4.321;
      set2.clearance = 1.4142;
      set2.manualOverride = false;
      set2.state = "closing";
      set2.ambient_temperature = 70;
      tmpData2.sets = [set2];
      addDBEntry(tmpData2);
    }
    
    function archiveSelectedDB(allFlag) {
        // This method 'removes' the objects from the pouchdb.
        // However, pouchdb retains the objects and just marks them deleted.
        // This can cause a memory buildup, but may be more sync-friendly.
        console.log ("archiveSelectedDB");
        local_db.allDocs({ include_docs: true, descending: true }, function (err, docs) {
            console.log ("archiveSelectedDB -- after the local_db.allDocs");
            for (var i = 0; i < docs.rows.length; i++) {
                cb = document.getElementById("checkBoxLocalIdNum" + i.toString());
                console.log(cb);
                if ((cb.checked) || allFlag) {
                    console.log('CHECKED');
                    var response = docs.rows[i].doc;
                    console.log(response);
                    response.pouchdb_id = "";  // setting this to an empty string will cause a new DB entry to be created.
                    addDBEntry(response, archive_db);
                    // remove it from database also
                    console.log("Removing doc: ", docs.rows[i].doc.serial_number);
                    local_db.remove(response, function (err, response) {
                        if (err) {
                            console.log("Error removing document:\n", err);
                        }
                    });
                }
            }
        });
        setTimeout(function () {
            listInternalFiles();
            e4PtAlert('Archiving complete.');
        }, 1000);
    }
    
    function unarchiveSelectedDB(allFlag) {
        // This method 'removes' the objects from the pouchdb.
        // However, pouchdb retains the objects and just marks them deleted.
        // This can cause a memory buildup, but may be more sync-friendly.
        console.log ("unarchiveSelectedDB")
        archive_db.allDocs({ include_docs: true, descending: true }, function (err, docs) {
            console.log ("unarchiveSelectedDB -- after the local_db.allDocs");
            for (var i = 0; i < docs.rows.length; i++) {
                cb = document.getElementById("checkBoxArchiveIdNum" + i.toString());
                console.log(cb);
                if ((cb.checked) || allFlag) {
                    console.log('CHECKED');
                    var response = docs.rows[i].doc;
                    console.log(response);
                    response.pouchdb_id = "";  // setting this to an empty string will cause a new DB entry to be created.
                    addDBEntry(response, local_db);
                    // remove it from database
                    console.log("Removing doc: ", docs.rows[i].doc.serial_number);
                    archive_db.remove(response, function (err, response) {
                        if (err) {
                            console.log("Error removing document:\n", err);
                        }
                    });
                }
            }
        });
        setTimeout(function () {
            listInternalFiles("ARCHIVE_DATA_TABLE_BODY", archive_db, false);
            e4PtAlert('Unarchiving complete.');
        }, 1000);
    }
    
    function clearSelectedArchive(allFlag) {
        // This method 'removes' the objects from the pouchdb.
        // However, pouchdb retains the objects and just marks them deleted.
        // This can cause a memory buildup, but may be more sync-friendly.
        console.log ("clearSelectedArchive");
        archive_db.allDocs({ include_docs: true, descending: true }, function (err, docs) {
            console.log ("clearSelectedArchive -- after the archive_db.allDocs");
            for (var i = 0; i < docs.rows.length; i++) {
                cb = document.getElementById("checkBoxArchiveIdNum" + i.toString());
                if ((cb.checked) || allFlag) {
                    console.log("Removing doc: ", docs.rows[i].doc.serial_number);
                    console.log("Removing doc index i: ", i);
                    var doc = docs.rows[i].doc;

                    // remove it from local drive
                    deleteFolder(cordova.file.documentsDirectory + docs.rows[i].doc.serial_number);

                    // remove it from database also
                    archive_db.remove(doc, function (err, response) {
                        if (err) {
                            console.log("Error removing document:\n", err);
                        }
                    });
                }
            }
        });
        setTimeout(function () {
            listInternalFiles("ARCHIVE_DATA_TABLE_BODY", archive_db, false);
        }, 1000);
    }
    
    function clearSelectedDB(allFlag) {
        // This method 'removes' the objects from the pouchdb.
        // However, pouchdb retains the objects and just marks them deleted.
        // This can cause a memory buildup, but may be more sync-friendly.
        console.log ("clearSelectedDB");
        local_db.allDocs({ include_docs: true, descending: true }, function (err, docs) {
            console.log ("clearSelectedDB -- after the local_db.allDocs");
            for (var i = 0; i < docs.rows.length; i++) {
                cb = document.getElementById("checkBoxLocalIdNum" + i.toString());
                if ((cb.checked) || allFlag) {
                    console.log("Removing doc: ", docs.rows[i].doc.serial_number);
                    console.log("Removing doc index i: ", i);
                    var doc = docs.rows[i].doc;

                    // remove it from local drive
                    deleteFolder(cordova.file.documentsDirectory + docs.rows[i].doc.serial_number);

                    // remove it from database also
                    local_db.remove(doc, function (err, response) {
                        if (err) {
                            console.log("Error removing document:\n", err);
                        }
                    });
                }
            }
        });
        setTimeout(function () {
            listInternalFiles();
        }, 1000);
    }
    
    // Not sure if we'll need this in production, but for development it could
    // be handy.
    function clearArchive() { // issue #35 ==> make this erase local files.
        // #35 ==> erasing local files first, then clearing DB.
        deleteFilesInDir(cordova.file.documentsDirectory + "data");
        if (false) {
            // This method 'removes' the objects from the pouchdb.
            // However, pouchdb retains the objects and just marks them deleted.
            // This can cause a memory buildup, but may be more sync-friendly.
            //  The 'else' statement below provides and alternate method by just
            // destroying the DB and re-creating it.  I'm not sure of the implications
            // of this on syncing, but it is a brute-force method.
            local_db.allDocs({ include_docs: true, descending: true }, function (err, docs) {
                console.log("Clearing DB");
                for (var i = 0; i < docs.rows.length; i++) {
                    console.log("Removing doc: ", docs.rows[i].id);
                    var doc = docs.rows[i].doc;
                    local_db.remove(doc, function (err, response) {
                        if (err) {
                            console.log("Error removing document:\n", err);
                        }
                    });
                }
            });
        }
        else {
            clearSelectedDB(true) // true would clear all Database, even these not selected.
            archive_db.destroy(function (err, response) {
                if (err) {
                    console.log("Error destroying archive:\n", err);
                    return;
                } else {
                    console.log("Database destroyed. Creating new empty database.");
                    archive_db = new PouchDB('e4ptarchive', { revs_limit: 1, auto_compaction: true });
                    setTimeout(function () {
                        listInternalFiles("ARCHIVE_DATA_TABLE_BODY", archive_db, false);
                    }, 1000);
                }
            });
        }
    }

    // Not sure if we'll need this in production, but for development it could
    // be handy.
    function clearDB() { // issue #35 ==> make this erase local files.\
        // #35 ==> erasing local files first, then clearing DB.
        deleteFilesInDir(cordova.file.documentsDirectory + "data");
        if (false) {
            // This method 'removes' the objects from the pouchdb.
            // However, pouchdb retains the objects and just marks them deleted.
            // This can cause a memory buildup, but may be more sync-friendly.
            //  The 'else' statement below provides and alternate method by just
            // destroying the DB and re-creating it.  I'm not sure of the implications
            // of this on syncing, but it is a brute-force method.
            local_db.allDocs({ include_docs: true, descending: true }, function (err, docs) {
                console.log("Clearing DB");
                for (var i = 0; i < docs.rows.length; i++) {
                    console.log("Removing doc: ", docs.rows[i].id);
                    var doc = docs.rows[i].doc;
                    local_db.remove(doc, function (err, response) {
                        if (err) {
                            console.log("Error removing document:\n", err);
                        }
                    });
                }
            });
        }
        else {
            clearSelectedDB(true) // true would clear all Database, even these not selected.
            local_db.destroy(function (err, response) {
                if (err) {
                    console.log("Error destroying database:\n", err);
                    return;
                } else {
                    console.log("Database destroyed. Creating new empty database.");
                    local_db = new PouchDB('e4ptdb', { revs_limit: 1, auto_compaction: true });
                    setTimeout(function () {
                        listInternalFiles();
                    }, 1000);
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

    function listInternalFiles(elementID ='LOCAL_DATA_TABLE_BODY', db=local_db) {
      console.log("listInternalFiles: ", elementID);
      getAllDBEntries(elementID, db);
    }

    // sortTable(n) is lifted straight from https://www.w3schools.com/howto/howto_js_sort_table.asp
    function sortTable(srtTable, n) {
      console.log("@sortTable");
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
        
      let cols = [];
      if (srtTable == "LOCAL_DATA_TABLE") {
         cols = ["FRAME_COL","SN_COL","CUSTOMER_COL","SITE_COL","DESC_COL","DATE_COL","TIME_COL","CHOOSE_FILES_LOCAL"];
      } else if (srtTable == "DATA_DETAILS_TABLE") {
        cols = ["STAGE_COL","POSITION_COL","CLEARANCE_COL","MAX_CLR_COL","MIN_CLR_COL","MED_CLR_COL","STD_CLR_COL"];
      } else if (srtTable == "LOCAL_FILE_TABLE") {
        cols = ["FNAME_COL"];
      } else if (srtTable == "ARCHIVED_DATA_TABLE") {
          cols = ["FRAME_COL_ARCHIVE","SN_COL_ARCHIVE","CUSTOMER_COL_ARCHIVE","SITE_COL_ARCHIVE","DESC_COL_ARCHIVE","DATE_COL_ARCHIVE","TIME_COL_ARCHIVE","CHOOSE_FILES_ARCHIVE"];
       }
       
      for (i=0; i<cols.length; i++) {
          document.getElementById(cols[i]).classList.remove("table-active");
      }
      if (n > 0) {
          document.getElementById(cols[n-1]).classList.add("table-active");
      }
    }

    function loadLocalData(id) {
      console.log("@loadLocalData: id = ", id);
      local_db.get(id, function(err, doc) {
          console.log("Row: ", doc);
          initializeFromDocument(doc);
      });
    }
    
    function loadArchiveData(id) {
      console.log("@loadArchiveData: id = ", id);
      archive_db.get(id, function(err, doc) {
          console.log("Row: ", doc);
          initializeFromDocument(doc);
      });
    }

    function initializeFromDocument(doc) {
        console.log("@initializeFromDocument");
        if (doc._id) {
            E4PTdata.pouchdb_id = doc._id;
        } else if (doc.pouchdb_id) {
            E4PTdata.pouchdb_id = doc.pouchdb_id;
        }
            
        var frm_idx = 0;
        for (frm_idx=0; frm_idx<frame_data.length; frm_idx++) {
          if (frame_data[frm_idx].frame == doc.frame) {
            break;
          }
        }
        document.getElementById("FRAME_SIZE").value = doc.frame;
        document.getElementById("FRAME_SIZE").selectedIndex = frm_idx;
        document.getElementById("CUSTOMER").value = doc.customer;
        document.getElementById("SITE").value = doc.site_name;
        document.getElementById("SERIAL_NUMBER").value = doc.serial_number;
        document.getElementById("DESCRIPTION").value = doc.description;
        document.getElementById("FRAME_DEFAULT_SENSOR").value = frame_data[frm_idx].default_sensor;
        document.getElementById("OPERATOR").value = doc.operator;
        document.getElementById("UNITS").value = doc.units;
        if (doc.units == "In") {
          document.getElementById("UNITS").selectedIndex = 0;
        } else if (doc.units == "MM") {
          document.getElementById("UNITS").selectedIndex = 1;
        }
        document.getElementById("TEMPERATURE_UNITS").value = doc.temperature_units;
        if (doc.temperature_units == "Fahrenheit") {
            document.getElementById("TEMPERATURE_UNITS").selectedIndex = 0;
        } else if (doc.temperature_units == "Celsius") {
            document.getElementById("TEMPERATURE_UNITS").selectedIndex = 1;
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
        E4PTdata.temperature_units = doc.temperature_units;
        E4PTdata.date = doc.date;
        E4PTdata.time = doc.time;
        E4PTdata.final = doc.final;
        E4PTdata.sets = doc.sets;
        if (typeof doc.turbine_casing_thicknesses !== 'undefined') {
            E4PTdata.turbine_casing_thicknesses = doc.turbine_casing_thicknesses;
        }
        if (typeof doc.details_filename !== 'undefined') {
            E4PTdata.details_filename = doc.details_filename;
        }
        if (typeof doc.report_filename !== 'undefined') {
            E4PTdata.report_filename = doc.report_filename;
        }
        if (typeof doc.email_filename !== 'undefined') {
            E4PTdata.email_filename = doc.email_filename;
        }

        current_frame_data = frame_data[frm_idx];
        current_stage_index = 0;
        current_stage = current_frame_data.stage[current_stage_index];
        current_position_index = 0;
        current_position = current_frame_data.position[current_stage][current_position_index];
        
        selected_frame_data.frameIdx = frm_idx;
        selected_frame_data.stageInfoIdx = current_stage_index;
        selected_frame_data.frameName = current_frame_data.frame;
        selected_frame_data.stageName = current_stage;
        // use index instead of name due to *.* stages
        //selected_frame_data.bladeCount = current_frame_data.stage_info[current_stage].blade_count;
        selected_frame_data.bladeCount = Object.values(current_frame_data.stage_info)[current_stage_index].blade_count;

        $("#LOCAL_DATA_PAGE").fadeOut();
        $("#ARCHIVED_DATA_PAGE").fadeOut();
          
        // Have to set up the casing thickness table before setting up
        // the data collection page because the data collection page depends
        // on the casing thicknesses.  The casing thickness are filled in in
        // a callback in an attempt to ensure the table is there before filling
        // it in.
        setupCasingThicknessTable( function() {
              // Iterate over the casing thicknesses and repopulate the table
              for (let p of Object.keys(E4PTdata.turbine_casing_thicknesses)) {
                  let ct = E4PTdata.turbine_casing_thicknesses[p];
                  if (typeof ct !== 'undefined') {
                      document.getElementById(p).value = E4PTdata.turbine_casing_thicknesses[p];
                  }
              }
          }
        );

        let ct_id = current_stage + "_" + current_position;
        document.getElementById("CURR_CASE_THICKNESS").value = E4PTdata.turbine_casing_thicknesses[ct_id];

        // Have to set up the data collection page before we can populate
        // the clearance entries in the tables.
        //var tmp = document.getElementById("FRAME_SIZE").selectedIndex;
        setup_data_collection_page(doc.date, doc.time, true);

        for (var i=0; i<doc.sets.length; i++) {
          var pos = doc.sets[i].position;
          var stg = doc.sets[i].stage;
          var clr = doc.sets[i].clearance;
          var manOvr = doc.sets[i].manualOverride;
          var clr_f = 0;
          if ((typeof clr) == "string") {
            clr_f = parseFloat(clr)
          } else {
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
          document.getElementById(el_id).innerHTML = clr_f.toFixed(4);
          if (manOvr) {
            document.getElementById(el_id).classList.add("table-danger");
          }
        }

        turbine_setup();
    }

    function json_data_is_valid(fileData) {
        return Object.keys(E4PTdata).every(function(key) {
            if (key === 'sets') {
                return fileData.sets.every(function(entry) {
                    return Object.keys(new Data_Set()).every((ds_key) => entry.hasOwnProperty(ds_key) || key === 'intensity_threshold' || key === 'measurement_rate' || key === 'dateStr' || key === 'filename');
                });
            }
            return fileData.hasOwnProperty(key) || key === 'intensity_threshold' || key === 'measurement_rate' || key === 'filename';
        });
    }
    
    function checkSensorSelection() {
        var expectedSensor = current_frame_data.default_sensor;
        var actualSensor = document.getElementById("SENSOR_SELECTION").value;
        if (expectedSensor != actualSensor) {
            e4PtPrompt("Use of incorrect sensor length may lead to failed data collection or sensor and turbine damage",setSensorSettingsForTurbine,"Sensor settings mismatch",["Keep '" + actualSensor + "' sensor settings", "Change to '" + expectedSensor + "' sensor settings"]);
        }
    }
    
    function setSensorSettingsForTurbine(option) {
        if (option === 2) {
            document.getElementById("SENSOR_SELECTION").value = current_frame_data.default_sensor;
            getSensorParametersForSensorSelection(current_frame_data.default_sensor);
            updateSensorParameters(document.getElementById("MASTER_FIXTURE_HEIGHT").value,
                                   document.getElementById("MASTERING_VALUE").value,
                                   document.getElementById("MASTER_OFFSET").value,
                                   document.getElementById("SENSOR_SELECTION").value,
                                   document.getElementById("SENSOR_LENGTH").value,
                                   document.getElementById("SMR").value,
                                   document.getElementById("SENSOR_MR").value);
        }
    }
    
    module.exports = {
        loadExternalFile:loadExternalFile,
        loadLocalData:loadLocalData,
        loadArchiveData:loadArchiveData,
        pluginMessage:pluginMessage,
        set_grid_position:set_grid_position,
        clearance_override:clearance_override,
        toggleFileSelected:toggleFileSelected,
        toggleDetailsSelected:toggleDetailsSelected,
        deleteEntry:deleteEntry,
        sortTable:sortTable
    };
});
