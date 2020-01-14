
var reportHTML;

function generateHTMLReport(e4ptData, current_frame_data) {
  reportHTML = ""; // Clear any previous report html page.
  reportHTML = createPageTop();
  makePageBanner();
  makePg1InfoTable(e4ptData);
  makeCircleTables(current_frame_data["stage"], current_frame_data["position"]);
  closePg1();
  makePageBanner();
  makePg2Header(0, 0, 0, 0);
  makePg2Table("Opening", current_frame_data["stage"], current_frame_data["position"], e4ptData);
  makePg2Table("Closing", current_frame_data["stage"], current_frame_data["position"], e4ptData);
  reportHTML = reportHTML + "</div></body></html>";
  return reportHTML;
};

function createPageTop() {
  reportHTML = "<!DOCTYPE html><html><head><meta charset=\"utf-8\">";
  reportHTML = reportHTML + "<meta name=\"format-detection\" content=\"telephone=no\">";
  reportHTML = reportHTML + "<meta name=\"viewport\" content=\"initial-scale=1, maximum-scale=1, user-scalable=no, width=device-width\">";
  reportHTML = reportHTML + "<link rel=\"stylesheet\" href=\"./css/report.css\"></link>";
  reportHTML = reportHTML + "<script type=\"text/javascript\" src=\"./js/e4pt_config.js\"></script>";
  reportHTML = reportHTML + "<script type=\"text/javascript\" src=\"./js/report.js\"></script>";
  reportHTML = reportHTML + "<title>Rotor Alignment Report</title>";
  reportHTML = reportHTML + "</head>";
  reportHTML = reportHTML + "<body>";
  reportHTML = reportHTML + "<div id=\"report_content\">";
  return reportHTML;
}

function makePageBanner() {
  reportHTML = reportHTML + "<table class=\"banner\" style=\"width:100%;\"><tr><td>";
  reportHTML = reportHTML + "<img src=\"img/banner_monogram_01.png\" height=\"80\" width=\"250\" align=\"middle\"></td>";
  reportHTML = reportHTML + "<td><img src=\"img/banner_02.png\" height=\"40\" width=\"101\" align=\"middle\"></td></tr></table><hr>";
};

function makePg1InfoTable(e4ptData) {
  reportHTML = reportHTML + "<table class=\"header\" style=\"width:100%\"><tr><td class=\"hcell\">Customer:</td><td class=\"hcell\" id=\"customer\">";
  reportHTML = reportHTML + e4ptData["customer"];
  reportHTML = reportHTML + "</td><td class=\"hcell\">Site:</td><td class=\"hcell\" id=\"site\">";
  reportHTML = reportHTML + e4ptData["site_name"];
  reportHTML = reportHTML + "</td><td class=\"hcell\">Frame Size:</td><td class=\"hcell\" id=\"frame\">";
  reportHTML = reportHTML + e4ptData["frame"];
  reportHTML = reportHTML + "</td></tr><tr><td class=\"hcell\">Date:</td><td class=\"hcell\" id=\"date\">";
  reportHTML = reportHTML + e4ptData["date"];
  reportHTML = reportHTML + "</td><td class=\"hcell\">Turbine S/N:</td><td class=\"hcell\" id=\"serial_number\">";
  reportHTML = reportHTML + e4ptData["serial_number"];
  reportHTML = reportHTML + "</td><td class=\"hcell\">Prepared By:</td><td class=\"hcell\" id=\"preparer\">";
  reportHTML = reportHTML + e4ptData["operator"];
  reportHTML = reportHTML + "</td></tr><tr><td class=\"hcell\">FSR #:</td><td class=\"hcell\" id=\"fsr\"></td>";
  reportHTML = reportHTML + "<td class=\"hcell\">Sketches Enclosed?</td><td class=\"hcell\" id=\"sketches\"></td>";
  reportHTML = reportHTML + "<td class=\"hcell\">Measurement Units</td><td class=\"hcell\" id=\"units\">";
  reportHTML = reportHTML + e4ptData["units"];
  reportHTML = reportHTML + "</td></tr><tr><td class=\"hcell\">Clearance Diagram Drw Number</td><td class=\"hcell\"></td>";
  reportHTML = reportHTML + "<td class=\"hcell\"></td><td class=\"hcell\"></td>";
  reportHTML = reportHTML + "<td class=\"hcell\">Photos Attached?</td><td class=\"hcell\" id=\"photos\"></td></tr></table>";
};

function makeCircleTables(stages, positions) {
  reportHTML = reportHTML + "<table>";
  var td_idx = 0;
  for (var j=0; j<stages.length; j++) {

    if ((td_idx % 2) == 0) {
      reportHTML = reportHTML + "<tr>";
    }

    reportHTML = reportHTML + "<td><table>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td></td><td class=\"cCell0\">Probe Hole Check</td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td>O</td><td class=\"cCell2\" id=\"OT_" + stages[j] + "\"></td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "<tr><td>O</td><td class=\"cCell2\" id=\"OTL_" + stages[j] + "\"></td><td>C</td><td class=\"cCell2\" id=\"CT_";
    reportHTML = reportHTML + stages[j] + "\"></td><td></td><td class=\"cCell2\" id=\"OTR_" + stages[j] + "\"></td><td>O</td></tr>";
    reportHTML = reportHTML + "<tr><td>C</td><td class=\"cCell2\" id=\"CTL_" + stages[j] + "\"></td><td></td><td></td><td></td><td class=\"cCell2\" id=\"CTR_" + stages[j] + "\"></td><td>C</td></tr>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "<tr><td>O<br/>C</td><td class=\"cCell2\" id=\"OCL_" + stages[j] + "\"></td><td></td><td class=\"circleCell\" id=\"stageCell_1\"><b>Stage ";
    reportHTML = reportHTML + stages[j];
    reportHTML = reportHTML + " Clearance</b></td><td></td><td class=\"cCell2\" id=\"OCR_" + stages[j] + "\"></td><td>O<br/>C</td></tr>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "<tr><td>O</td><td class=\"cCell2\" id=\"OBL_" + stages[j] + "\"></td><td></td><td></td><td></td><td class=\"cCell2\" id=\"OBR_" + stages[j] + "\"></td><td>O</td></tr>";
    reportHTML = reportHTML + "<tr><td>C</td><td class=\"cCell2\" id=\"CBL_" + stages[j] + "\"></td><td>O</td><td class=\"cCell2\" id=\"OB_" + stages[j] + "\"></td><td></td><td class=\"cCell2\" id=\"CBR_" + stages[j] + "\"></td><td>C</td></tr>";
    reportHTML = reportHTML + "<tr><td></td><td></td><td>C</td><td class=\"cCell2\" id=\"CB_" + stages[j] + "\"></td><td></td><td></td><td></td></tr>";
    reportHTML = reportHTML + "</table></td>";

    td_idx += 1;

    if (((td_idx % 2) == 0) || (j == stages.length-1)) {
      reportHTML = reportHTML + "</tr>";
    }

  }
  reportHTML = reportHTML + "</table>";
};

function closePg1() {
  reportHTML = reportHTML + "<p class=\"pText0\">All axial clearances are measured with rotor against the loaded thrust face. Refer to EM5260 to confirm rotor position.</p>";
  reportHTML = reportHTML + "<hr class=\"break_line\">";
};

function makePg2Header(compressorSpacerLengthOpening, compressorSpacerLengthClosing, turbineSpacerLengthOpening, turbineSpacerLengthClosing) {
  reportHTML = reportHTML + "<table><tr><td></td><td class=\"cCell1\">Opening</td><td class=\"cCell1\">Closing</td><td></td></tr><tr>";
  reportHTML = reportHTML + "<td class=\"cCell1\">Length of Compressor Spacer Cylinder</td><td class=\"cCell2\">";
  reportHTML = reportHTML + compressorSpacerLengthOpening;
  reportHTML = reportHTML + "</td><td class=\"cCell2\">";
  reportHTML = reportHTML + compressorSpacerLengthClosing;
  reportHTML = reportHTML + "</td><td class=\"cCell1\">Left and Right are viewed looking in the direction of air flow (toward the exhaust)</td>";
  reportHTML = reportHTML + "</tr><tr><td class=\"cCell1\">Length of Turbine Spacer Cylinder</td><td class=\"cCell2\">";
  reportHTML = reportHTML + turbineSpacerLengthOpening;
  reportHTML = reportHTML + "</td><td class=\"cCell2\">";
  reportHTML = reportHTML + turbineSpacerLengthClosing;
  reportHTML = reportHTML + "</td><td></td></tr></table>";
};

function onlyUnique(value, index, self) {
    return self.indexOf(value) === index;
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

  // Line of text
  reportHTML = reportHTML + "<p class=\"pText0\">";
  reportHTML = reportHTML + state;
  reportHTML = reportHTML + "Rotor Position</p>";

  // Table Headers
  reportHTML = reportHTML + "<table class=\"header\">";
  reportHTML = reportHTML + "<th colspan=\"1\" class=\"tCell1\">Stage</th>";
  for (var i=0; i<uniquePositions.length; i++) {
      reportHTML = reportHTML + "<th colspan=\"3\" class=\"tCell1\">";
      reportHTML = reportHTML + uniquePositions[i];
      reportHTML = reportHTML + "</th>";
  }

  // Table Sub-headers
  reportHTML = reportHTML + "<tr><td class=\"tCell1\"></td>";
  for (var i=0; i<uniquePositions.length; i++) {
    reportHTML = reportHTML + "<td class=\"tCell1\">Measured Dimension</td>";
    reportHTML = reportHTML + "<td class=\"tCell1\">Dimension Stamped on Casing</td>";
    reportHTML = reportHTML + "<td class=\"tCell1\">Tip Clearance</td>";
  }
  reportHTML = reportHTML + "</tr>";

  // Per-stage clearance data
  for (var j=0; j<stages.length; j++) {
    reportHTML = reportHTML + "<tr>";
    var id = state.charAt(0) + "_stg_" + stages[j]; // e.g. "O_stg_1", "C_stg_6"
    reportHTML = reportHTML + "<td class=\"tCell1\" id=\"" + id + "\">";
    reportHTML = reportHTML + stages[j];
    reportHTML = reportHTML + "</td>";
    pos = positions[stages[j]];
    for (var i=0; i<uniquePositions.length; i++) {
      if (Object.values(pos).includes(uniquePositions[i])) {
        var tip_clearance = get_tip_clearance(state, stages[j], uniquePositions[i], data);
        var case_thickness = get_casing_thickness(state, stages[j], uniquePositions[i], data);
        console.log("Stage: ", stages[j], " Position: ", uniquePositions[i], " Clearance: ", tip_clearance);
        id = state.charAt(0) + "_md_" + stages[j] + "_" + abbreviated_position(uniquePositions[i]); // e.g. "O_md_1_L", "C_md_6_BR"
        reportHTML = reportHTML + "<td class=\"tCell2\" id=\"" + id + "\">";
        reportHTML = reportHTML + "";  // figure out how to get this data later
        reportHTML = reportHTML + "</td>";
        id = state.charAt(0) + "_dsc_" + stages[j] + "_" + abbreviated_position(uniquePositions[i]); // e.g. "O_dmc_1_L", "C_dmc_6_BR"
        reportHTML = reportHTML + "<td class=\"tCell2\" id=\"" + id + "\">";
        reportHTML = reportHTML + case_thickness;  // figure out how to get this data later
        reportHTML = reportHTML + "</td>";
        id = state.charAt(0) + "_tc_" + stages[j] + "_" + abbreviated_position(uniquePositions[i]); // e.g. "O_tc_1_L", "C_tc_6_BR"
        reportHTML = reportHTML + "<td class=\"tCell2\" id=\"" + id + "\">";
        reportHTML = reportHTML + tip_clearance;  // figure out how to get this data later
        reportHTML = reportHTML + "</td>";
      }
      else {
        reportHTML = reportHTML + "<td class=\"tCell2\"></td><td class=\"tCell2\"></td><td class=\"tCell2\"></td>";
      }
    }
    reportHTML = reportHTML + "</tr>";
  }
  reportHTML = reportHTML + "</table>";
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
}

function get_tip_clearance(state, stage, position, data) {
  for (var i=0; i<data.sets.length; i++) {
    if ( data.sets[i].state.toUpperCase() == state.toUpperCase()) {
      if ( data.sets[i].stage.toUpperCase() == stage.toUpperCase()) {
        if (data.sets[i].position.toUpperCase() == position.toUpperCase()) {
          return data.sets[i].clearance.toFixed(4);
        }
      }
    }
  }
  return "";
}

function get_casing_thickness(state, stage, position, data) {
  for (var i=0; i<data.sets.length; i++) {
    if ( data.sets[i].state.toUpperCase() == state.toUpperCase()) {
      if ( data.sets[i].stage.toUpperCase() == stage.toUpperCase()) {
        if (data.sets[i].position.toUpperCase() == position.toUpperCase()) {
          return data.sets[i].case_thickness.toFixed(4);
        }
      }
    }
  }
  return "";
}
