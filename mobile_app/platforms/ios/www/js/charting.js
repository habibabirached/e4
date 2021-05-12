if (typeof define !== 'function') {
    var define = require('./lib/amdefine')(module);
}

define(function(require, exports, module, sensorSettings) {
    require('./lib/highcharts/highcharts6_0_4');
    var sensorSettings = require('./sensor_settings');
    
    const renderChart = (chartConfig, target, chartFilename, writeToFileFunc) => {
      let html = createSavedChartHTML(chartConfig);
      let chart = Highcharts.chart(target, chartConfig);
      chart.renderer.button('Save',chart.plotWidth-10,50,function(){
            writeToFileFunc(chartFilename.substring(0,chartFilename.indexOf('_')), chartFilename, html);
            this.attr({text: 'Saved'});
            this.setState(3);
      },{fill:'black',style:{color:'white'}},{},{},{fill:'gray',style:{color:'black'}}).add();
    }
    
    const clearChartData = (chartContainer) => {
        let chart = Highcharts.charts[chartContainer.getAttribute('data-highcharts-chart')];
        if (typeof chart !== 'undefined') {
            if (chart.series)
                while(chart.series.length > 0)
                    chart.series[0].remove(true);
            if (chart.subtitle)
                chart.subtitle.hide();
            if (chart.renderer && chart.renderer.box && chart.renderer.box.children)
                for (element of chart.renderer.box.children)
                    if (element.classList && element.classList.contains('highcharts-button'))
                        element.style.visibility = 'hidden';
        }
    }
    
    const createSavedChartFilename = (dateStr, serialNumber, stageNum, position) => {
      let filename = dateStr.replace(/\s+/g, '_').replace(/:/g, '-') + '_mm.html';
      if (serialNumber && stageNum && position) {
          return serialNumber + '_' + stageNum + '_' + position + '_' + filename;
      }
      return 'data_' + filename;
    }
        
    const createSavedChartHTML = (chartConfig) => {
      return "<html><head><script src='https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js'></script><script src='https://code.highcharts.com/highcharts.js'></script><style>.COL_FL{float:left}.COL_FR{float:right}.FONT_BLACK{color:black}.FONT_RED{color:red}.FONT_TRANSPARENT{color: rgba(0, 0, 0, 0)}.highcharts-subtitle {text-align: center;width: 100%;}</style></head><body><div style='width:100%'></div><script>$(function () {$('div').highcharts(" + JSON.stringify(chartConfig) + ");});</script></body></html>";
    }
    
    const addChartSubtitle = (chartConfig, acquisition_date, overall_clearance, avg_displacement) => {
        
      let subtitle = 'Date: ' + acquisition_date + '<br>Avg. Tip Dist: ' + overall_clearance;
      if (avg_displacement) {
        if (sensorSettings.doesMeasurementExceedTolerance(avg_displacement)) {
            subtitle = '<span class="FONT_BLACK">' + subtitle + '; </span>' + '<span class="FONT_RED">Overall Avg: ' + avg_displacement + '</span>';
        }
        else {
            subtitle += ";&nbsp;Overall Avg: " + avg_displacement;
        }
      }
        
      chartConfig.subtitle.text = subtitle;
    }
    
    const displayIntensityThresholdAndMeasurementRate = (chartConfig, measurement_rate, intensity_threshold) => {
          
        chartConfig.subtitle.text = '<span class="COL_FR">Measurement Rate: ' + measurement_rate + 'kHz</span>;&nbsp;<span class="COL_FR">Intensity Threshold: ' + intensity_threshold + '%</span><br><span>' + chartConfig.subtitle.text + '</span>';
    }
    
    const createChartConfig = (displacementsArray, clearancesArray) => {
      return {
        chart: {
          spacingBottom: 0,
          spacingTop: 20,
          spacingLeft: 80,
          spacingRight: 60,
          marginBottom: 80,
          marginTop: 120,
          marginLeft: 80,
          marginRight: 40,
          backgroundColor: 'transparent',
          animation: false,
          padding: 0
        },
        boost: {
          enabled: true,
          useGPUTranslations: true,
          allowForce: true
        },
        title: { text: 'e-4Pt Acquired Data' },
        style: { fontFamily: 'Veranda' },
        subtitle: { useHTML: true },
        yAxis: {
          title: { text: 'Blade Gap' },
          labels: {
            style: { color: 'black', fontSize: 10 }
          }
        },
        xAxis: {
          title: { text: 'Index' },
          labels: {
            style: { color: 'black', fontSize: 10 }
          }
        },
        legend: { enabled: false },
        tooltip: { enabled: true, valueDecimals: 2 },
        pane: { startAngle: 0 },
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
            data: displacementsArray
          },
          {
            type: 'scatter',
            name: 'Clearance Minima',
            data: clearancesArray
          }
        ],
        responsive: {
          rules: [ { condition: { maxWidth: 1000 } } ]
        }
      };
    }

    module.exports = {
        addChartSubtitle: addChartSubtitle,
        clearChartData: clearChartData,
        createChartConfig: createChartConfig,
        createSavedChartFilename: createSavedChartFilename,
        displayIntensityThresholdAndMeasurementRate: displayIntensityThresholdAndMeasurementRate,
        renderChart: renderChart
    }
});

