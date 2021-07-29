
var reportHTML;
// specify clearance measurement precision
var precision = 3;
// clearance measurement table cell styles
var overrideStyleSuffix = "Override";
var overrideFlag = false;

function generateHTMLReport(e4ptData, current_frame_data) {
  reportHTML = ""; // clear eport html page
  overrideFlag = false; // clear override status
  createPageTop();
  makePageBanner();
  makePg1InfoTable(e4ptData);
  makeCircleTables(current_frame_data["stage"], current_frame_data["position"], e4ptData);
  makePageBanner();
  makePg2Header(0, 0, 0, 0); // TODO: get values
  makePg2Table("Opening", current_frame_data["stage"], current_frame_data["position"], e4ptData);
  makePg2Table("Closing", current_frame_data["stage"], current_frame_data["position"], e4ptData);
  makeProprietaryNotice();
  createPageBottom();
  return reportHTML;
}

function makeProprietaryNotice() {
    let d = new Date();
    let yy = d.getFullYear();
    reportHTML += "<p class=\"notice\">Copyright &copy ";
    reportHTML += + yy;
    reportHTML += " General Electric Company. GE Proprietary Information and Confidential Information. All Rights Reserved.</p>";
}

function createPageTop() {
  reportHTML += "<!DOCTYPE html><html><head><meta charset=\"utf-8\">";
  reportHTML += "<meta name=\"format-detection\" content=\"telephone=no\">";
  reportHTML += "<meta name=\"viewport\" content=\"initial-scale=1, maximum-scale=1, user-scalable=no, width=device-width\">";
  reportHTML += "<link rel=\"stylesheet\" href=\"./css/report.css\"></link>";
  reportHTML += "<script type=\"text/javascript\" src=\"./js/e4pt_config.js\"></script>";
  reportHTML += "<script type=\"text/javascript\" src=\"./js/report.js\"></script>";
  reportHTML += "<title>Rotor Alignment Report</title>";
  reportHTML += "</head>";
  reportHTML += "<body>";
  reportHTML += "<div id=\"report_content\">";
}

function createPageBottom() {
  reportHTML += "</div></body></html>";
}

function makePageBanner() {
  reportHTML += "<table class=\"banner\"><tr>";
  reportHTML += "<td><img src=\"img/banner_monogram_01.png\" height=\"80\" width=\"250\" align=\"middle\"></td>";
  reportHTML += "<td><img src=\"img/banner_02.png\" height=\"40\" width=\"101\" align=\"middle\"></td>";
  reportHTML += "</tr></table><hr>";
}

function makePg1InfoTable(data) {
  reportHTML += "<table class=\"header\"><tr>";
  reportHTML += "<td class=\"hCell\">Customer</td><td class=\"hCell\" id=\"customer\">";
  reportHTML += data["customer"];
  reportHTML += "</td><td class=\"hCell\">Site</td><td class=\"hCell\" id=\"site\">";
  reportHTML += data["site_name"];
  reportHTML += "</td><td class=\"hCell\">Frame Size</td><td class=\"hCell\" id=\"frame\">";
  reportHTML += data["frame"];
  reportHTML += "</td></tr><tr><td class=\"hCell\">Date</td><td class=\"hCell\" id=\"date\">";
  reportHTML += data["date"];
  reportHTML += "</td><td class=\"hCell\">Turbine S/N</td><td class=\"hCell\" id=\"serial_number\">";
  reportHTML += data["serial_number"];
  reportHTML += "</td><td class=\"hCell\">Prepared By</td><td class=\"hCell\" id=\"preparer\">";
  reportHTML += data["operator"];
  reportHTML += "</td></tr><tr><td class=\"hCell\">FSR #</td><td class=\"hCell\" id=\"fsr\"></td>";
  reportHTML += "<td class=\"hCell\">Sketches Enclosed?</td><td class=\"hCell\" id=\"sketches\"></td>";
  reportHTML += "<td class=\"hCell\">Measurement Units</td><td class=\"hCell\" id=\"units\">";
  reportHTML += data["units"];
  reportHTML += "</td></tr><tr><td class=\"hCell\">Clearance Diagram Drw Number</td><td class=\"hCell\"></td>";
  reportHTML += "<td class=\"hCell\"></td><td class=\"hCell\"></td>";
  reportHTML += "<td class=\"hCell\">Photos Attached?</td><td class=\"hCell\" id=\"photos\"></td></tr>";
  if (containsManualOverride(data)) {
    reportHTML += "<tr><td class=\"hCellOverride\" colspan=\"2\">Some clearance values were entered manually</td><td class=\"hCellOverride\" colspan=\"4\">"
    var overrideCount = 0;
    for (var i=0; i<data.sets.length; i++) {
      if (data.sets[i].manualOverride) {
        var stateStr = data.sets[i].state.toUpperCase();
        stateStr = stateStr.charAt(0);
        var stageStr = data.sets[i].stage.toString();
        var positionStr = data.sets[i].position.toUpperCase();
        positionStr = abbreviated_position(positionStr);
        if (overrideCount > 0) {
          reportHTML += ", ";
        }
        reportHTML += stateStr + "-" + stageStr + "-" + positionStr;
        overrideCount++;
      }
    }
    reportHTML += "</td></tr>";
  }
  reportHTML += "</table>";
}

function makeCircleTables(stages, positions, data) {
  reportHTML += "<br>";
  reportHTML += "<center>";
  reportHTML += "<table>";
  var td_idx = 0;
  for (var j=0; j<stages.length; j++) {
    if ((td_idx % 2) == 0) {
      reportHTML += "<tr>";
    }
    // horizontal spacing between stages
    if ((td_idx % 2) == 1) {
      reportHTML += "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>";
    }
    reportHTML += "<td><table>";
    reportHTML += "<tr><td></td><td></td><td></td><td class=\"cCell0\">Probe Hole Check</td><td></td><td></td><td></td></tr>";
    
    // Opening TOP
    var tip_clr = get_tip_clearance("opening", stages[j], "top", data);
    reportHTML += "<tr><td></td><td></td><td>O</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OT_" + stages[j] + "\">" + tip_clr.clearance + "</td><td></td><td></td><td></td></tr>";
    
    // Opening TOP LEFT, Closing TOP, Opening TOP RIGHT
    tip_clr = get_tip_clearance("opening", stages[j], "top left", data);
    reportHTML += "<tr><td>O</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OTL_" + stages[j] + "\">" + tip_clr.clearance +"</td>";
    tip_clr = get_tip_clearance("closing", stages[j], "top", data);
    reportHTML += "<td>C</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CT_" + stages[j] + "\">" + tip_clr.clearance + "</td>";
    tip_clr = get_tip_clearance("opening", stages[j], "top right", data);
    reportHTML += "<td>&nbsp;&nbsp;</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OTR_" + stages[j] + "\">" + tip_clr.clearance + "</td><td>O</td></tr>";
    
    // Closing TOP LEFT, Closing TOP RIGHT
    tip_clr = get_tip_clearance("closing", stages[j], "top left", data);
    reportHTML += "<tr><td>C</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CTL_" + stages[j] + "\">" + tip_clr.clearance + "</td>";
    tip_clr = get_tip_clearance("closing", stages[j], "top right", data);
    reportHTML += "<td></td><td></td><td></td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CTR_" + stages[j] + "\">" + tip_clr.clearance + "</td><td>C</td></tr>";
      
    // Circle
    var circleRows = 14; // even number, circle height
    var paddingOffset = 4; // top/bottom padding offset for even spacing
    reportHTML += "<tr><td></td><td></td><td></td>";
    reportHTML += "<td class=\"circleCell\" id=\"stageCell_" + stages[j] + "\" rowspan=\"" + (circleRows+1) + "\"><b>Stage " + stages[j] + " Clearance</b></td>";
    reportHTML += "<td></td><td></td><td></td></tr>";
      
    // top padding
    for (var k=0; k<(((circleRows-2)/2)+paddingOffset); k++) {
      reportHTML += "<tr><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
    }
    
    // Opening LEFT, Opening RIGHT
    tip_clr = get_tip_clearance("opening", stages[j], "left", data);
    reportHTML += "<tr><td>O</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OL_" + stages[j] + "\">" + tip_clr.clearance + "</td><td></td>";
    tip_clr = get_tip_clearance("opening", stages[j], "right", data);
    reportHTML += "<td></td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OR_" + stages[j] + "\">" + tip_clr.clearance + "</td><td>O</td></tr>";
      
    // Closing LEFT, Closing RIGHT
    tip_clr = get_tip_clearance("closing", stages[j], "left", data);
    reportHTML += "<tr><td>C</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CL_" + stages[j] + "\">" + tip_clr.clearance + "</td><td></td>";
    tip_clr = get_tip_clearance("closing", stages[j], "right", data);
    reportHTML += "<td></td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CR_" + stages[j] + "\">" + tip_clr.clearance + "</td><td>C</td></tr>";
                     
    // bottom padding
    for (var k=0; k<(((circleRows-2)/2)-paddingOffset); k++) {
      reportHTML += "<tr><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
    }
    
    // Opening BOTTOM LEFT, Opening BOTTOM RIGHT
    tip_clr = get_tip_clearance("opening", stages[j], "bottom left", data);
    reportHTML += "<tr><td>O</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OBL_" + stages[j] + "\">" + tip_clr.clearance + "</td>";
    tip_clr = get_tip_clearance("opening", stages[j], "bottom right", data);
    reportHTML += "<td></td><td></td><td></td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OBR_" + stages[j] + "\">" + tip_clr.clearance + "</td><td>O</td></tr>";
    
    // Closing BOTTOM LEFT, Opening BOTTOM, Closing BOTTOM RIGHT
    tip_clr = get_tip_clearance("closing", stages[j], "bottom left", data);
    reportHTML += "<tr><td>C</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CBL_" + stages[j] + "\">" + tip_clr.clearance + "</td>";
    tip_clr = get_tip_clearance("opening", stages[j], "bottom", data);
    reportHTML += "<td>O</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"OB_" + stages[j] + "\">" + tip_clr.clearance + "</td>";
    tip_clr = get_tip_clearance("closing", stages[j], "bottom right", data);
    reportHTML += "<td></td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CBR_" + stages[j] + "\"></td>" + tip_clr.clearance + "<td>C</td></tr>";

    // Closing BOTTOM
    tip_clr = get_tip_clearance("closing", stages[j], "bottom", data);
    reportHTML += "<tr><td></td><td></td><td>C</td><td class=\"cCell2" + tip_clr.styleSuffix + "\" id=\"CB_" + stages[j] + "\">" + tip_clr.clearance + "</td><td></td><td></td><td></td></tr>";

    reportHTML += "</table></td>";

    td_idx += 1;

    if (((td_idx % 4) == 0) || (j == stages.length-1)) {
      reportHTML += "</tr></table></center><br><br>";
      closePg1();
      if (j < stages.length-1) {
        reportHTML += "<center><table>"
      };
    } else if ((td_idx % 2) == 0) {
      reportHTML += "</tr>";
      // padding between rows
      for (var k=0; k<8; k++) {
        reportHTML += "<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
      }
    }
  }
}
                      
function closePg() {
  makeProprietaryNotice();
  reportHTML += "<hr class=\"break_line\">";
}
                      
function closePg1() {
  reportHTML += "<p class=\"pText0\">All axial clearances are measured with rotor against the loaded thrust face. Refer to EM5260 to confirm rotor position.</p>";
  closePg();
}

function makePg2Header(compressorSpacerLengthOpening, compressorSpacerLengthClosing, turbineSpacerLengthOpening, turbineSpacerLengthClosing) {
  reportHTML += "<table><tr><td></td><td class=\"cCell1\">Opening</td><td class=\"cCell1\">Closing</td><td></td></tr><tr>";
  reportHTML += "<td class=\"cCell1\">Length of Compressor Spacer Cylinder</td><td class=\"cCell2\">";
  reportHTML += compressorSpacerLengthOpening;
  reportHTML += "</td><td class=\"cCell2\">";
  reportHTML += compressorSpacerLengthClosing;
  reportHTML += "</td><td class=\"cCell1\">Left and Right are viewed looking in the direction of air flow (toward the exhaust)</td></tr>";
  reportHTML += "<tr><td class=\"cCell1\">Length of Turbine Spacer Cylinder</td><td class=\"cCell2\">";
  reportHTML += turbineSpacerLengthOpening;
  reportHTML += "</td><td class=\"cCell2\">";
  reportHTML += turbineSpacerLengthClosing;
  reportHTML += "</td><td></td></tr></table>";
  reportHTML += "<br>";
}

function makePg2Table(state, stages, positions, data) {
  // Get only the unique positions as they will be enumerated in the header
  var allPositions = [];
  for (var j=0; j<stages.length; j++) {
    pos = positions[stages[j]];
    for (var i=0; i<pos.length; i++) {
      allPositions.push(pos[i]);
    }
  }
  var uniquePositions = allPositions.filter(onlyUnique);

  // We need to break the tables into groups no more
  // than 4 position columns wide. Otherwise they over-run
  // the page.  So here we count how many we need.
  // Ultimately there will probably only be one or two groups.
  let posCount = uniquePositions.length;
  let tCount = 0;  // This is the number of tables we'll need.
  let positionGroups = [];
  while (posCount > 0) {
    let group = uniquePositions.slice(tCount*4,(tCount*4)+4);
    positionGroups.push(group);
    tCount += 1;
    posCount -= 4;
  }

  // Line of text
  reportHTML += "<p class=\"pText0\">";
  reportHTML += state + " Clearances";

    for (let k=0; k<tCount; k++) {

        uniquePositions = positionGroups[k];

        // Table Headers
        reportHTML += "<table class=\"header\">";
        reportHTML += "<th colspan=\"1\" class=\"tCell1\">Stage</th>";
        for (var i=0; i<uniquePositions.length; i++) {
            reportHTML += "<th colspan=\"3\" class=\"tCell1\">";
            reportHTML += uniquePositions[i];
            reportHTML += "</th>";
        }

        // Table Sub-headers
        reportHTML += "<tr><td class=\"tCell1\"></td>";
        for (var i=0; i<uniquePositions.length; i++) {
            reportHTML += "<td class=\"tCell1\">Measured Dimension</td>";
            reportHTML += "<td class=\"tCell1\">Dimension Stamped on Casing</td>";
            reportHTML += "<td class=\"tCell1\">Tip Clearance</td>";
        }
        reportHTML += "</tr>";

        // Per-stage clearance data
        for (let j=0; j<stages.length; j++) {
            reportHTML += "<tr>";
            var id = state.charAt(0) + "_stg_" + stages[j]; // e.g. "O_stg_1", "C_stg_6"
            reportHTML += "<td class=\"tCell1\" id=\"" + id + "\">";
            reportHTML += stages[j];
            reportHTML += "</td>";
            pos = positions[stages[j]];
            for (let i=0; i<uniquePositions.length; i++) {
                if (Object.values(pos).includes(uniquePositions[i])) {
                    var tip_clearance = get_tip_clearance(state, stages[j], uniquePositions[i], data);
                    var case_thickness = get_casing_thickness(state, stages[j], uniquePositions[i], data);
                    console.log("Stage: ", stages[j], " Position: ", uniquePositions[i], " Clearance: ", JSON.stringify(tip_clearance));
                    id = state.charAt(0) + "_md_" + stages[j] + "_" + abbreviated_position(uniquePositions[i]); // e.g. "O_md_1_L", "C_md_6_BR"
                    reportHTML += "<td class=\"tCell2\" id=\"" + id + "\">";
                    reportHTML += "";  // TODO: measured dimension, figure out how to get this data later
                    reportHTML += "</td>";
                    id = state.charAt(0) + "_dsc_" + stages[j] + "_" + abbreviated_position(uniquePositions[i]); // e.g. "O_dmc_1_L", "C_dmc_6_BR"
                    reportHTML += "<td class=\"tCell2\" id=\"" + id + "\">";
                    reportHTML += case_thickness;
                    reportHTML += "</td>";
                    id = state.charAt(0) + "_tc_" + stages[j] + "_" + abbreviated_position(uniquePositions[i]); // e.g. "O_tc_1_L", "C_tc_6_BR"
                    reportHTML += "<td class=\"tCell2" + tip_clearance.styleSuffix + "\" id=\"" + id + "\">";
                    reportHTML += tip_clearance.clearance;
                    reportHTML += "</td>";
                }
                else {
                    reportHTML += "<td class=\"tCell2\"></td><td class=\"tCell2\"></td><td class=\"tCell2\"></td>";
                }
            }
            reportHTML += "</tr>";
        }
        reportHTML += "</table>";
        if ((k != tCount-1) || (state == "Opening")) {
            reportHTML += "<br>";
        }
        // add page break after 2 Opening tables
        if (k == 1 && state == "Opening") {
          closePg();
        }
    }
}

function containsManualOverride(data) {
  for (var i=0; i<data.sets.length; i++) {
    if (data.sets[i].manualOverride) {
      return true;
    }
  }
  return false;
}

function onlyUnique(value, index, self) {
  return self.indexOf(value) === index;
}

function abbreviated_position(pos) {
  if (pos == "TOP") return "T";
  if (pos == "BOTTOM") return "B";
  if (pos == "LEFT") return "L";
  if (pos == "RIGHT") return "R";
  if (pos == "TOP RIGHT") return "TR";
  if (pos == "TOP LEFT") return "TL";
  if (pos == "BOTTOM RIGHT") return "BR";
  if (pos == "BOTTOM LEFT") return "BL";
  return "";
}

function get_tip_clearance(state, stage, position, data) {
  for (var i=0; i<data.sets.length; i++) {
    if (data.sets[i].state.toUpperCase() == state.toUpperCase()) {
      var stgStr1 = data.sets[i].stage.toString();
      if (stgStr1 == stage) {
        if (data.sets[i].position.toUpperCase() == position.toUpperCase()) {
          if (typeof data.sets[i].clearance === 'string') {
            if (data.sets[i].clearance.length == 0) {
              data.sets[i].clearance = 0;
            } else {
              data.sets[i].clearance = parseFloat(data.sets[i].clearance);
            }
          }
          var clearance = data.sets[i].clearance.toFixed(precision);
          if (typeof data.sets[i].manualOverride !== 'boolean') {
            data.sets[i].manualOverride = false;
          }
          var manualOverride = data.sets[i].manualOverride;
          if (manualOverride) {
            overrideFlag = true;
          }
          return {
            clearance: clearance,
            styleSuffix: (manualOverride ? overrideStyleSuffix : ""),
          };
        }
      }
    }
  }
  return {
    clearance: "",
    styleSuffix: "",
  };
}

//
// get_casing_thickness returns the recorded casing thickness for the given
// stage and position.  The 'state' (opening or closing) is no longer considered
// as it is presumed the casing thickness does not change.s
//
function get_casing_thickness(state, stage, position, data) {
  let ct_id = stage + "_" + position; // get element id for casing thickness
  if (data.turbine_casing_thicknesses[ct_id] !== 'undefined') {
    return data.turbine_casing_thicknesses[ct_id];
  }
  return "";
}
