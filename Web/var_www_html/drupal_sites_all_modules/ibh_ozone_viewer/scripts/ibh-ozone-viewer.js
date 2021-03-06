(function ($) {

var ibhOzoneViewer = {

  firstWindowLoad : true,
  firstPlay : true,
  isDeeplink : false,

  // displayMode 1 is load all drawn polygons into memory, then show/hide
  // displayMode 2 is JIT draw then destroy.
  displayMode : 1,
  
  // contourJSONStorage pertains to displayMode 2
  contourJSONStorage : [],
  
  // load from flat file cache or script
  contourFlatFile : false,
  
  animationMessage: 'Click play to animate.',

//  testMode : false,
  moduleBase : 'sites/all/modules/ibh_ozone_viewer/',
  testContour : 'tests/contour-',
  testContourEndTS: 1243731600,
//  testContourNow: 1332872700,
  testMarker : 'tests/poi.js',
  testMarkerURL : 'tests/poi-data.js',

  baseApiUrl : '/',
  flatContourBaseURL: 'generatedcontour/',
  markerURL: 'ozone-viewer-api/point.php',
  contourURL: 'ozone-viewer-api/contour.php',


  contourNum : 6,
  contourRes : 300, // 5 minute resolution
  bandSchema : 4,

  contourEndTS : 1301558400,
  contourStartTS : null,

  markerEndTS : 1301558400,
  markerStartTS : null,
  markerNumber : 1,
  markerLag : 1800, // 30 minutes behind
  
  defaultTimeSpan: 3600,
  
  lowerBoundHour : 6,
  upperBoundHour : 22,
  
  animSlider: null,
  playPause : null,
  inactiveUI : {opacity:0.25, cursor:'default'},
  activeUI : {opacity:1, cursor:'pointer'},
  scubberExpanded : false,

  
//  markersStatus: null,
  markerTitles: [],
  savedMarkerLimit: 5,
  activatedMarker : null,
  markerSettings : [],
  markerSearchZoom : 11,

  getMarkerSrc : function() {
    return this.moduleBase +'images/markers/_marker-sprite-sm.png';
  },
  
  getMarkerSrcHover : function() {
    return this.moduleBase +'images/markers/_marker-sprite-lg.png';
  },

//  aqiIndex : {  0: { color: '00E400', label: 'green', opacity: 0.25,  desc: 'Good'},
//               60: { color: 'EEEE48', label: 'yellow', opacity: 0.30, desc: 'Moderate'},
//               76: { color: 'ED3308', label: 'orange', opacity: 0.29, desc: 'Warning'},
//               96: { color: 'F70A90', label: 'red', opacity: 0.3, desc: 'Unhealthy'},
//              116: { color: '7C0086', label: 'purple', opacity: 0.3, desc: 'Very Unhealthy'},
//              136: { color: '7C0000', label: 'maroon', opacity: 0.3, desc: 'Hazardous'} 
//             },

  aqiIndexNoReading : { color: '000000', label: 'black', opacity: 0.3,  desc: 'No Reading'},  
  
  // over-written in initialization by Drupal.settings value from CMS.
  aqiIndex : {  0: { color: '3FAE4A', label: 'green', opacity: 0.45, title: 'Good'},
               60: { color: 'F6EC26', label: 'yellow', opacity: 0.45, title: 'Moderate'},
               76: { color: 'EE5828', label: 'orange', opacity: 0.45, title: 'Warning'},
               96: { color: 'B8212B', label: 'red', opacity: 0.45, title: 'Unhealthy'},
              116: { color: '9A1E51', label: 'purple', opacity: 0.45, title: 'Very Unhealthy'},
              136: { color: '451427', label: 'maroon', opacity: 0.45, title: 'Hazardous'} 
             },             
  
  maxAqiIndex : 156, 

  searchContainer : null,
  searchToggle : null,
  
  defaultSearchVal : "Search Houston Address",
  
  gradientIndex : [],

  centerLat: 29.720193,
  centerLng: -95.36939,

//  centerLat: 29.351058,
//  centerLng: -95.302277,

  gMap : null,
  deviceAgent : null,
  iPadiPhone : false,

  defaultZoomLevel : 10,
  zoomLevel : 10,

  contourAnimSpeed: 1500,
  legendLabelHideSpeed: 5000,

  markerNames : [],

  polygons : [],
  markers : [],
  formattedTime : [],

  activeContourTS : null,
  contourCallbackNum : 0,

  markerCallbackNum : 0,
  currentTotalCallbackNum : 0,
  totalCallbackNum : 0,

  timeIndicator : null,

  animSlider: null,
  isPlaying: false,
  
  colorLegend : null,
  colorLegendWrapper : null,
  
  colorDataSeries: [],
  
  legendCSS : {
    position:'relative', 
    left:'50px', 
    float: 'right'
  },

  colorLegendLabel : null,
  colorLegendHtml : null,

  timelineChart : null,
  contourAjaxCalls : [], 

  initialize : function() {
    
    this.displayMode = 2;
    
    if (Drupal.settings.ibh_ozone_viewer.aqi) {
      this.aqiIndex = Drupal.settings.ibh_ozone_viewer.aqi;    
    }

    if (Drupal.settings.ibh_ozone_viewer.api_url) {
      this.baseApiUrl = Drupal.settings.ibh_ozone_viewer.api_url;    
    }

    this.flatContourBaseURL = this.baseApiUrl + this.flatContourBaseURL;
    this.markerURL = this.baseApiUrl + this.markerURL;
    this.contourURL = this.baseApiUrl + this.contourURL;

    this.gMap = $("#gMap");
    $('body').prepend("<div id='target'></div>");

    this.deviceAgent = navigator.userAgent.toLowerCase();
    this.iPadiPhone = this.deviceAgent.match(/(iphone|ipod|ipad)/);
    
    // <=IE7 gets bandschema 0.
    if ($.browser.msie && parseInt($.browser.version, 10) <= 8) {
      this.bandSchema = 0;
    }

    this.initTooltip();
    this.initTooltipRight();
    this.initDeeplink();
    this.initTimestampControls();
    // Adds .span attribute to getOzoneInfo
    this.initVerticalColorLegend();
    this.initGMap();  // this.initMarkers() as callback

    if (this.iPadiPhone) {
//      this.bandSchema = 0;
      this.initMobile();
    }
    else {
      this.initNonMobile();    
    }

    this.initLoadbar();
    this.initColorGradient();
    this.initHomeCenter();
    this.initAutocomplete();
//    this.initTooltip();
    this.initLoadAnimation();
//    this.initAccordion();
    this.initStage();
    this.initResize();
    this.initTimeIndicator();
    this.initAnimControls();
//    this.initMarkers();
    this.initFooterToggles();
    //this.initLatestContour(this.contourEndTS); //timeline takes care of this now
//    this.initMarkers();

    this.initMapTypeAndZoom();
    this.initMobileOverrides();
    this.initHelp();
	this.loadTimeline();
  },
  
  initMobile : function() {
    var html = '';
//    html += '<div title="Home" id="homeCenter">&nbsp;</div>';
//    html += '<div id="markers"></div>';
//    html += '<div id="colorLegend"></div>';
//    html += '<div class="markerNav" title="Prev" id="prevMarker">&lsaquo;</div>';
//    html += '<div class="markerNav" title="Next" id="nextMarker">&rsaquo;</div>';    
//    html += '<div id="mapTypeContainer"><div id="mapStyleContainer">';
//    html += '<div id="mapStyle" class="satellite"></div></div>';
//    html += '<div id="mapType" title="Map Type" class="roadmap"></div></div>';
//    html += '<div id="time-indicator"></div>';
    html += '<div id="slider-wrapper-wrapper"><div id="slider-wrapper"><div id="animation-slider"></div></div></div>';
    html += '<div id="playback-ui">';
    html += '<div id="backward-btn"></div>';
    html += '<div id="play-pause"></div>';
    html += '<div id="forward-btn"></div>';
    html += '</div>';

//    html += '<div class="markerNav" title="Prev" id="prevMarker">&lsaquo;</div>';
//    html += '<div id="play-pause" class="markerNav"></div>';
//    html += '<div class="markerNav" title="Next" id="nextMarker">&rsaquo;</div>'; 
    $("#footer-ui").append(html);
  },

  initNonMobile : function() {
    var html = '';
//    html += '<div title="Home" id="homeCenter">&nbsp;</div>';
//    html += '<div id="markers"></div>';
//    html += '<div id="colorLegend"></div>';
//    html += '<div class="markerNav" title="Prev" id="prevMarker">&lsaquo;</div>';
//    html += '<div class="markerNav" title="Next" id="nextMarker">&rsaquo;</div>'; 
//    html += '<div id="mapTypeContainer"><div id="mapStyleContainer"><div id="mapStyle" class="satellite"></div></div>';
//    html += '<div id="mapType" title="Map Type" class="roadmap"></div></div>';
//    html += '<div class="zoomControl" title="Zoom Out" id="zoomOut">';
//    html += '<img src="'+ this.moduleBase +'images/zoomOut.png" alt="-" />';
//    html += '</div><div class="zoomControl" title="Zoom In" id="zoomIn">';
//    html += '<img src="'+ this.moduleBase +'images/zoomIn.png" alt="+" /></div>';
//   html += '<div id="time-indicator"></div>';
//    html += '<div id="time-indicator"></div>';
    html += '<div id="slider-wrapper-wrapper"><div id="slider-wrapper"><div id="animation-slider"></div></div></div>';
    html += '<div id="playback-ui">';
    html += '<div id="backward-btn"></div>';
    html += '<div id="play-pause"></div>';
    html += '<div id="forward-btn"></div>';
    html += '</div>';

//    html += '<div class="markerNav" title="Prev" id="prevMarker">&lsaquo;</div>';
//    html += '<div id="play-pause" class="markerNav"></div>';
//    html += '<div class="markerNav" title="Next" id="nextMarker">&rsaquo;</div>'; 
    $("#footer-ui").append(html);
  },

  /*
   * Begin Loadbar Functionality
   *
   */

  initLoadbar: function() {
  
    this.loadbar = $('#o-loadbar');
    this.loadbarWrapper = $('#o-loadbar-wrapper');    
    this.loadbarMaxWidth = this.loadbarWrapper.width() - 1;

  },

  updateLoadbar: function() {
  
    if (this.totalCallbackNum==0) {
      this.loadbar.width(this.loadbarMaxWidth);
      this.loadbar.delay(1000).fadeOut();
      if (this.isPlaying) {
        this.expandScrubber();
      }
      return;
    }

    if (this.totalCallbackNum!=0) {
      this.loadbar.show();
    }

    var pixelsPerIncrement =  this.loadbarMaxWidth / this.totalCallbackNum;
    var increments = this.totalCallbackNum - this.currentTotalCallbackNum;

    var w = increments*pixelsPerIncrement;

    this.loadbar.width(w);

  },

  addTotalCallback : function() {
    this.totalCallbackNum++;
    this.currentTotalCallbackNum++;
  },

  updateTotalCallbacks : function() {

    if (this.currentTotalCallbackNum != 0) {
      this.currentTotalCallbackNum--;
    }

    if (this.currentTotalCallbackNum == 0) {
      this.totalCallbackNum = 0;
    }
    
    this.updateLoadbar();
  
  },

  /*
   *
   * End Loadbar Functionality
   */


  initColorGradient: function() {
  
    var start = false;
    var end = false;
    var startX = 0;
    var endX = 0;
    for(x in this.aqiIndex) {
      if (!start){
        start = this.aqiIndex[x].color;
        startX = x;
        continue;
      }
      if (!end) {
        end = this.aqiIndex[x].color;
        endX = x;
        
        $.extend(this.gradientIndex, this.getGradient(start, end, startX, endX));

        start = end;
        startX = endX;
        end = false;
        continue;
      }
    }
    // quick fix.
	$.extend(this.gradientIndex, this.getGradient(start, start, startX, 256));
    this.gradientIndex[this.gradientIndex.length] = '7C0000';

  },
  
  getGradient: function(start, end, startX, endX) {

    var rainbow = new Rainbow();

    rainbow.setSpectrum(start, end);

    var steps = Number(endX) - Number(startX);

    rainbow.setNumberRange(0, steps);
    
    var array = [];

    var j = Number(startX);

    for(i=0;i<steps;i++) {
      array[j] = rainbow.colourAt(i);
      j++;
    }
    
    return array;
  },
  
  initTooltip: function() {
    $('body').append('<div id="ozone-tooltip"><div id="ozone-tooltip-content"></div>');
    this.tooltip = $('#ozone-tooltip');
    this.tooltipContent = $('#ozone-tooltip-content');
  },
  
  initTooltipRight: function() {
    $('body').append('<div id="ozone-tooltip-right"><div id="ozone-tooltip-content-right"></div>');
    this.tooltipRight = $('#ozone-tooltip-right');
    this.tooltipContentRight = $('#ozone-tooltip-content-right');
  },
  
  initDeeplink: function() {

    this.contourEndTS = Drupal.settings.ibh_ozone_viewer.now;
    this.markerEndTS = Drupal.settings.ibh_ozone_viewer.now;
    this.contourStartTS = this.contourEndTS - this.defaultTimeSpan;

    if ($.address.path() == '/snapshot') {
      this.isDeeplink = true;
    } 
    
    if (this.isDeeplink) {
      
      if ($.address.parameter("t1") && $.address.parameter("t2")) {
        var end = parseInt($.address.parameter("t2"), 10);
        this.contourEndTS = end;
        this.markerEndTS = end;
        this.contourStartTS = parseInt($.address.parameter("t1"), 10); 
      }
      
      if ($.address.parameter("latlng")) {
        var latlng = $.address.parameter("latlng");
        var a = latlng.split(",");
        ibhOzoneViewer.centerLat = a[0];
        ibhOzoneViewer.centerLng = a[1];
      }

      if ($.address.parameter("z")) {
        ibhOzoneViewer.zoomLevel = parseInt($.address.parameter("z"), 10);
      }

    }
  
  },
  
  initTimestampControls: function(){

    // Initial Timestamp Settings.

    var date = new Date(this.contourEndTS*1000);
    var hours = date.getHours();
    var rewindDay = 0;
    var outOfBounds = false;

    if (hours < this.lowerBoundHour) {
      // go to yesterday.
      hours = this.upperBoundHour;
      rewindDay = 86400;
      outOfBounds = true;
    }
    else if (hours > this.upperBoundHour) {
      hours = this.upperBoundHour;
      outOfBounds = true;
    }
 
    if (outOfBounds) {
      var date2 = new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours);
      var newVal = (date2.getTime() / 1000) - rewindDay;
      this.contourEndTS = newVal;
      this.contourStartTS = newVal - this.defaultTimeSpan;
      this.markerEndTS = newVal;
    }
    else {
      date = new Date(this.contourStartTS*1000);
      hours = date.getHours();
      if (hours < this.lowerBoundHour) {
        var date3 = new Date(date.getFullYear(), date.getMonth(), date.getDate(), this.lowerBoundHour);
        this.contourStartTS = (date3.getTime() / 1000);
      }
    }
    
    var initStartDate = new Date(this.contourStartTS * 1000);
    var initEndDate = new Date(this.contourEndTS * 1000);
  
    // In minutes since midnight.
    var initStart = (initStartDate.getHours()*60) + initStartDate.getMinutes();
    var initEnd = (initEndDate.getHours()*60) + initEndDate.getMinutes();
    
    var initYear = initStartDate.getFullYear();
    var initMonth = initStartDate.getMonth() + 1;
    var initDay = initStartDate.getDate();  
  
    this.slideRange = $("#slider-range");
    this.slideTimeDisplay = $("#slider-time");
    this.refreshMapBtn = $(".refresh-map");
//    this.bandSchemaSel = $("#band-schema-select");
    
    this.timelineYear = $("#timeline-year");
    this.timelineMonth = $("#timeline-month");
    this.timelineDay = $("#timeline-day");

    var c = function(event, ui) {
      ibhOzoneViewer.slideTime(event, ui)
    }

    this.slideRange.slider({
      range: true,
      min: ibhOzoneViewer.lowerBoundHour * 60,
      max: ibhOzoneViewer.upperBoundHour * 60,
      step: ibhOzoneViewer.contourRes / 60,
      values: [initStart, initEnd],
      slide: c,
      stop: c
    });
    
    ibhOzoneViewer.slideTime();
    
//    ibhOzoneViewer.bandSchema = 0;
//    this.bandSchemaSel.change(function(){
//      ibhOzoneViewer.bandSchema = $(this).attr('value');
//    }).val(0);
    
    ibhOzoneViewer.timelineYearVal = initYear;
    this.timelineYear.change(function(){
      ibhOzoneViewer.timelineYearVal = $(this).attr('value');
    }).val(initYear);

    ibhOzoneViewer.timelineMonthVal = initMonth;
    this.timelineMonth.change(function(){
      ibhOzoneViewer.timelineMonthVal = $(this).attr('value');
    }).val(initMonth);

    ibhOzoneViewer.timelineDayVal = initDay;
    this.timelineDay.change(function(){
      ibhOzoneViewer.timelineDayVal = $(this).attr('value');
    }).val(initDay);

    this.refreshMapBtn.click(function(){

      if ($(ibhOzoneViewer.searchToggle).is(':visible')) {
        ibhOzoneViewer.searchWrapper.toggle();
        ibhOzoneViewer.searchToggle.toggleClass('open');
//        ibhOzoneViewer.searchToggle.toggle();
      }

      var year = parseInt(ibhOzoneViewer.timelineYearVal, 10);
      var month = parseInt(ibhOzoneViewer.timelineMonthVal, 10) - 1;
      var day = parseInt(ibhOzoneViewer.timelineDayVal, 10);
      var d1 = new Date(year, month, day, ibhOzoneViewer.timelineHours0Val, ibhOzoneViewer.timelineMinutes0Val);
      var d2 = new Date(year, month, day, ibhOzoneViewer.timelineHours1Val, ibhOzoneViewer.timelineMinutes1Val);    
      var startTS = d1.getTime() / 1000;
      var endTS = d2.getTime() / 1000;
      var map = $(ibhOzoneViewer.gMap).gmap3('get');
      var z = map.getZoom();
	  var center = map.getCenter();
      var latlng = center.toString();
      latlng = latlng.replace(/\s|\(|\)/g,''); 
      $.address.value('/snapshot?t1=' + startTS + '&t2=' + endTS + '&z=' + z + '&latlng=' + latlng);

      
      if (ibhOzoneViewer.firstPlay) {
        ibhOzoneViewer.playPause.click();
      }
      else {
        ibhOzoneViewer.reset();
      }

      ibhOzoneViewer.playPause.addClass('paused');      
      ibhOzoneViewer.isPlaying = false;

	  ibhOzoneViewer.updateTimeline();

    });

  },

  slideTime: function(event, ui){
    var val0 = ibhOzoneViewer.slideRange.slider("values", 0),
        val1 = ibhOzoneViewer.slideRange.slider("values", 1),
        minutes0 = parseInt(val0 % 60, 10),
        hours0 = parseInt(val0 / 60 % 24, 10),
        minutes1 = parseInt(val1 % 60, 10),
        hours1 = parseInt(val1 / 60 % 24, 10);

    ibhOzoneViewer.timelineHours0Val = hours0;
    ibhOzoneViewer.timelineHours1Val = hours1;
    ibhOzoneViewer.timelineMinutes0Val = minutes0;
    ibhOzoneViewer.timelineMinutes1Val = minutes1;

    startTime = ibhOzoneViewer.getSlideTime(hours0, minutes0);
    endTime = ibhOzoneViewer.getSlideTime(hours1, minutes1);
    ibhOzoneViewer.slideTimeDisplay.text(startTime + ' - ' + endTime);
  },
  
  getSlideTime: function(hours, minutes) {
    var time = null;
    minutes = minutes + "";
    if (hours < 12) {
        time = "AM";
    }
    else {
        time = "PM";
    }
    if (hours == 0) {
        hours = 12;
    }
    if (hours > 12) {
        hours = hours - 12;
    }
    if (minutes.length == 1) {
        minutes = "0" + minutes;
    }
    return hours + ":" + minutes + " " + time;
  },
  
  initGMap : function() {
  
//    var desaturatedStyles = [
//    {
//      featureType: "all",
//      stylers: [
//        { saturation: -60 }
//      ]
//    }
//    ];
//  
//    var desaturatedType = new google.maps.StyledMapType(desaturatedStyles, {name: "Map"});
  
    this.gMap.gmap3({
      action: 'init',
      options : {
        center:[ibhOzoneViewer.centerLat,ibhOzoneViewer.centerLng]
      },
      onces: {
        bounds_changed: function(){
          $(this).gmap3({
            action:'getBounds',
            callback: function (){
				if (ibhOzoneViewer.isDeeplink) {
					//ibhOzoneViewer.reset(); //timeline takes care of this now
				}
//              ibhOzoneViewer.initMarkers();
            }
          });
        }
      }//,
//      events: {
//        click: function(event,data){
//          var latlng = data.latLng;
//          alert(latlng);
//        }  
//      }
    },
    { 
      action: 'setOptions', args:[{
        zoom:ibhOzoneViewer.zoomLevel,
        scrollwheel:false,
        disableDefaultUI:true,
        disableDoubleClickZoom:false,
        draggable:true,
        //mapTypeId:'hybrid'
        mapTypeId:google.maps.MapTypeId.ROADMAP,
        mapTypeControl:false,
        mapTypeControlOptions: {
          style: google.maps.MapTypeControlStyle.DROPDOWN_MENU,
          position: google.maps.ControlPosition.LEFT_BOTTOM,
          //mapTypeIds: [google.maps.MapTypeId.ROADMAP, 'desaturated']
        }, 
        //panControl:false,
        panControl:true,
        panControlOptions: {
          position: google.maps.ControlPosition.LEFT_TOP
        },
        scaleControl:false,      
        streetViewControl:false,
		styles: [
			  {
			    featureType: 'landscape',
			    elementType: 'geometry.fill',
			    stylers: [
					{visibility: "off"}
			    ]
			  },
			  {
			    featureType: 'poi',
			    elementType: 'geometry.fill',
			    stylers: [
					{visibility: "off"}
			    ]
			  },
			  {
			    featureType: 'administrative',
			    elementType: 'geometry.fill',
			    stylers: [
					{visibility: "off"}
			    ]
			  }
			],
        zoomControl:true,
        zoomControlOptions: {
          position: google.maps.ControlPosition.LEFT_TOP,
          style: google.maps.ZoomControlStyle.DEFAULT
        }//,
      }]
	});

//	var map = this.gMap.gmap3("get");
	
//    var controlDiv = document.createElement('div');
//    controlDiv.style.padding = '25px';
//    controlDiv.style.index = -5000;
//   map.controls[google.maps.ControlPosition.LEFT_TOP].push(controlDiv);

    
//    map.mapTypes.set('Map', desaturatedType);
//    map.setMapTypeId('desaturated');

//    var polygonClick = google.maps.event.addListener( polygon, "click", function( event, data ) {
//    alert(data.latLng);
//    });
  },

  initHomeCenter: function() {
    $('#homeCenter').hover(
      function(){
        var offset = $(this).offset();
        var top = offset.top - 45;
        var left = offset.left + 2;
        ibhOzoneViewer.tooltipContent.html('<div>Show current</div>');
        ibhOzoneViewer.tooltip.css({top:top,left:left}).show();
      },
      function() {
        ibhOzoneViewer.tooltip.hide();    
      }
    );
    $('#homeCenter').click(function(){
      window.location.replace(window.location.pathname);
    // Changed.
//      ibhOzoneViewer.gMap.gmap3({action: 'setOptions', 
//        args:[{
//          zoom:ibhOzoneViewer.defaultZoomLevel,
//          center: new google.maps.LatLng(ibhOzoneViewer.centerLat,ibhOzoneViewer.centerLng)
//        }]});
    });
  },


//  initShowHideTowers: function(){
//    var markers = this.gMap.gmap3({
//      action:'get',
//      name:'marker',
//      all: true,
//      tag:'towers'
//    });
// 
//    var map = this.gMap.gmap3('get');
//
//    $.each(markers, function(i, marker){
//      marker.setMap( checked ? map : null);
//    });
//  },


  initAutocomplete : function() {
    this.searchContainer = $('#searchGMap-content');
    var t = this.defaultSearchVal;
  // var center = new google.maps.LatLng(ibhOzoneViewer.centerLat,ibhOzoneViewer.centerLng);
    var address = $("#address");
    address.val(t);
    $(address).bind('focus', function () {
      if ($(this).attr('value') == t) {
        $(this).attr('value', '');
      }
    });
    $(address).bind('blur', function () {
      if ($(this).attr('value') == '') {
        $(this).attr('value', t);
      }
    });
    
    address.autocomplete({
      source: function( request, response ) {
        ibhOzoneViewer.gMap.gmap3({
          action:'getAddress',
          address: request.term + ", Houston, TX",
          callback:function(results){
            if (!results) return;
            
            if (results.length > 5) {
              results.length = 5;
            }
            
            response( $.map( results, function( item ) {
              return {
                label: item.formatted_address,
                value: item.formatted_address,
                latlng: item.geometry.location
              }
            }));
          }
        });
	  },
	  select: function (event, ui) {
	    latlng = ui.item.latlng;
//	    ibhOzoneViewer.searchContainer.addClass('searching');
	    ibhOzoneViewer.loadMarkers(latlng, ui.item.label);
      },
      autoFocus: true,
      appendTo: this.searchContainer
    });
  },

//  loadJSON : function(url, callback) {
//
//    if (typeof (url) == 'undefined' || typeof (callback) != 'function') {
//      return false;
//    }
//
//    $.ajax({
//      url: url,
//      dataType : 'json',
//      success: function(data){
//        callback(data);
//      },
//      error: function(jqXHR, textStatus, errorThrown) {
//
//      }
//    });
//  },
//  
  initMarkers: function() {

//    if (!this.markersStatus){
//      this.markersStatus = $('#markers');    
//    }

//    this.markersStatus.html('<div class="markers-loading">Loading locations</div>');   

    var url =  ibhOzoneViewer.moduleBase + ibhOzoneViewer.testMarker;
    var latlng = '';


    // Built-in markers.
    
    $.ajax({
      url: url,
      dataType : 'json',
      success: function(data1,status1,jqXHR1) {
        if (data1 && status1 == 'success') {
          $(data1.data).each(function(key1, val1) {
            var key = ibhOzoneViewer.markerUniqueKey(val1.lat, val1.lng);
            ibhOzoneViewer.markerNames[key] = val1.name;
            // BACKWARDS.
            if (latlng != '') {
              latlng += ':';
            }
            latlng += val1.lng + ',' + val1.lat;
          });

          // User markers.
   
          var saved = ibhOzoneViewer.loadSavedMarkers();
          
          for (x in saved) {
            var obj = saved[x];
            var key = ibhOzoneViewer.markerUniqueKey(obj.lat, obj.lng);
            ibhOzoneViewer.markerNames[key] = obj.name;
            if (latlng != '') {
              latlng += ':';
            }
            latlng += obj.lat + ',' + obj.lng;   
          }
        
          // load all. 
          ibhOzoneViewer.loadMarkers(latlng);

        }
      }
    }); 
    
  },
  
  loadMarkers: function(latlng, defaultName) {

    var lat,lng,ts;

    if (typeof latlng == 'object') {
      for (x in latlng) {
        if (x == 'lat') {
          lat = latlng[x]();
        }
        if (x == 'lng') {
          lng = latlng[x]();
        }
      }
      // BACKWARDS.
      latlng = lat + ',' + lng + ':';
    }

//    var labels = [];

//    if (ibhOzoneViewer.testMode) {
//      url = ibhOzoneViewer.moduleBase + ibhOzoneViewer.testMarkerURL;
//    }
//    else {
      url = ibhOzoneViewer.markerURL;         
//    }

    ts = this.contourEndTS;
    
//    if (!this.isDeeplink && this.firstWindowLoad) {
//      ts = this.contourEndTS;      
//    }

    var showedAlertOnce = false;

//    for (i=0;i<=this.contourNum;i++){
    for(var i = this.contourNum; i>=0; i--) {
      ibhOzoneViewer.addMarkerCallback();
      $.ajax({
        url: url,
        dataType : 'jsonp',
        jsonpCallback: 'markerData' + ts,
        data : {
          latlng:latlng,
          type:'json',
          timestamp: ts
        },
        success: function(data){
          if (!data.status || data.status.type == 'fail') {
            if (!showedAlertOnce) {
              showedAlertOnce = true;
//              ibhOzoneViewer.alert("Not all Location data could be loaded in the selected timespan.");            
            }
            ibhOzoneViewer.searchContainer.removeClass('searching');   
//            ibhOzoneViewer.markersStatus.html('<div class="markers-failed">Location fail.</div>');
//            ibhOzoneViewer.markersStatus.empty();  
            return;
          }
          ibhOzoneViewer.addMarkers(data, defaultName);      
        },
        complete: function(jqXHR, textStatus) {
          ibhOzoneViewer.updateMarkerCallbacks();  
        }
      });
        
      ts -= ibhOzoneViewer.contourRes;
    }

  },

  updateMarker : function(settingsObj) {
  
    var markerTitle = ibhOzoneViewer.getMarkerTitle(settingsObj.key);
    
    if (markerTitle) {
      var markerTitleContents = markerTitle.find('.markerTitleContents');
      markerTitle.css({borderTop: '12px solid #' + settingsObj.color});
      markerTitleContents.html('<div>' + settingsObj.html + '</div>');   
    }

    if (typeof(this.markers[settingsObj.key]) != 'undefined') {
      this.markerMouseEvent(this.markers[settingsObj.key], settingsObj.key, false);
    }

  },

  addMarkers : function(data, defaultName){

    $(data.snapshot).each(function(k, v) {
    
      var ts = v.timestamp;
  
      if (typeof(ibhOzoneViewer.markers[ts]) != 'object'){
        ibhOzoneViewer.markers[ts] = [];      
      }
    
      $(v.data).each(function(key, val) {
        var this_key = ibhOzoneViewer.markerUniqueKey(val.lat, val.lng);
        var name = ibhOzoneViewer.markerNames[this_key];

        if (defaultName) {
          name = defaultName;
        }
        else if (!name) {
          name = val.lat + ', ' + val.lng;
        }

        var ozoneTitle, ozoneWebSafe, ozoneBorder, ozoneLevel = '';
        
        var ozoneDataInfo = ibhOzoneViewer.getOzoneInfo(val.attr.ozone_level);
        
        var opacity = ozoneDataInfo.opacity;
        
//        var hex = ibhOzoneViewer.gradientIndex[val.attr.ozone_level];
        var hex = ozoneDataInfo.color;

//        var marker = ibhOzoneViewer.moduleBase +'images/markers/marker-' + ozoneDataInfo.label + '-sm-' + val.attr.ozone_level + '.png';
//        var markerHover = ibhOzoneViewer.moduleBase +'images/markers/marker-' + ozoneDataInfo.label + '-lg-' + val.attr.ozone_level + '.png';

        var marker = ibhOzoneViewer.getMarkerSrc();
        var markerHover = ibhOzoneViewer.getMarkerSrcHover();

        ibhOzoneViewer.searchContainer.removeClass('searching');
        $("#address").val(ibhOzoneViewer.defaultSearchVal);

        if (val.attr.ozone_level != -1) {
          var r = ibhOzoneViewer.hexToR('#'+hex);
          var g = ibhOzoneViewer.hexToG('#'+hex);
          var b = ibhOzoneViewer.hexToB('#'+hex);
          ozoneBorder ='border: 2px solid #'+ hex+';';
          ozoneBkg = 'background: rgba('+ r +','+ g +','+ b +','+ opacity +');';
          ozoneTitle = ozoneDataInfo.title;  
          ozoneLevel = val.attr.ozone_level;
        }
        else {
           
//          if (defaultName) {
//            ibhOzoneViewer.alert("Ozone levels are not available for this search. Current coverage includes Houston and the surrounding area.");
//          }
         // This is a failed search.
         // ibhOzoneViewer.alert("There is no data currently available for this location. Please visit the <a href='http://www.tceq.texas.gov/airquality/monops'>TCEQ</a> to view the ozone level in your area.");
          if (defaultName) {
            ibhOzoneViewer.alert("Ozone levels are not available for this search. Our current coverage includes Houston and the surrounding area. Please visit the <a href='http://www.tceq.texas.gov/airquality/monops' target='_blank'>TCEQ towers</a> in your area.");          
          }
          return true; // continue;

        }
        
        var time = ibhOzoneViewer.convertTimestamp(ts, true);
    
        var html = '';
        html += '<div class="markerHtml">@ ' + name + ' <div>' + ozoneTitle.toUpperCase() + '</div></div>';
        html += '<div class="markerUpdated">UPDATED: ' + time + '</div>';
        
        var settingsObj = {
          key: this_key,
          ozoneLevel: val.attr.ozone_level,
          lat: val.lat,
          lng: val.lng,
          name: name,
          label_id : val.label_id,
//          html: '<div class="ozone-values"><div class="ozone-value" style="' + ozoneBorder + ozoneBkg + '">' + ozoneLevel + '</div><div class="ozone-label" style="' + ozoneBorder + ozoneBkg + '">' + ozoneTitle + '</div></div>',
          html: html,
          title: ozoneTitle,
          color: hex,
          ts: ts,
          marker: marker,
          markerHover: markerHover
        };
        
//        if (defaultName && val.attr.ozone_level == -1) {
          // This is a failed search.
//          ibhOzoneViewer.alert("There is no data currently available for this location. Please visit the <a href='http://www.tceq.texas.gov/airquality/monops'>TCEQ</a> to view the ozone level in your area.");
//          ibhOzoneViewer.alert("Ozone levels are not available for this search. Our current coverage includes Houston and the surrounding area. Please visit the <a href='http://www.tceq.texas.gov/airquality/monops'>TCEQ towers</a> in your area.");
//        }
//        else 
        if (defaultName) {
          // Successful search.
          ibhOzoneViewer.saveMarker(settingsObj);
        }
        ibhOzoneViewer.addMarker(settingsObj, defaultName);
        // <img width="95" height="95" src="images/thumbs/iguazu.jpg" alt="" />
      });
    });
  },
  
  
  addMarker : function(settingsObj, activate){

    var map;

    if (typeof(settingsObj) != 'object') {
      return;
    }
 
    if (typeof(activate) == 'undefined') {
      activate = false;
    }

    if (typeof(this.markerSettings[settingsObj.ts]) == 'undefined') {
      this.markerSettings[settingsObj.ts] = [];
    }

    this.markerSettings[settingsObj.ts].push(settingsObj);
    
    if (typeof(this.markers[settingsObj.key]) != 'undefined') {
      if (activate) {
         var latlng = new google.maps.LatLng(settingsObj.lat,settingsObj.lng);
         ibhOzoneViewer.gMap.gmap3({
            action:'panTo',
            args:[latlng]
         });
         map = ibhOzoneViewer.gMap.gmap3('get');          
         map.setZoom(ibhOzoneViewer.markerSearchZoom);
      }
      return;
    }

//    if (this.markerNumber == 1) {
//      this.markersStatus.empty();
//    }
    
//    var i = this.markerNumber++;
//    var name = settingsObj.name;
//    var link = "";
//    var excerpt = "";
//    var title = settingsObj.title;
//    var pin = settingsObj.pin;
//    var lati = settingsObj.lat;
//    var longi = settingsObj.lng;
//    var ts = settingsObj.ts;
//    var color = settingsObj.color;
    
//    var level = settingsObj.ozoneLevel;
    
//    var markerNormal = settingsObj.marker;
//    var markerHover = settingsObj.markerHover;
    
    var num = Number(settingsObj.ozoneLevel);
    
    if (num > 155) {
      num = 155; // max+
    }

    var spriteXPos = (68*num) - 68;
    
    var markerNormalIcon = new google.maps.MarkerImage(settingsObj.marker, new google.maps.Size(68, 68), new google.maps.Point(spriteXPos, 0));
    var markerHoverIcon = new google.maps.MarkerImage(settingsObj.markerHover, new google.maps.Size(68, 68), new google.maps.Point(spriteXPos, 0));    

    this.gMap.gmap3({
      action : 'addMarker',
      lat:settingsObj.lat,
      lng:settingsObj.lng,
      options: {
//        icon: new google.maps.MarkerImage(markerNormal),
        icon: markerNormalIcon,
        animation: null
      },
      events:{
        mouseover: function(marker){
//          ibhOzoneViewer.contourAnimReset();

          ibhOzoneViewer.contourAnimClear();

          ibhOzoneViewer.markerMouseEvent(marker, settingsObj.key, true);
          
          ibhOzoneViewer.gMap.css({cursor:'pointer'});
          
//          $('#markerTitle'+i+'').fadeIn({ duration: 200, queue: false }).animate({top:"8px"},{duration:200,queue:false});

          var markerTitle = ibhOzoneViewer.getMarkerTitle(settingsObj.key);
          if (markerTitle) {
            markerTitle.show();
            var curPos = markerTitle.offset();
            var curTop = curPos.top;
            var height = markerTitle.height();
            var screenHeight = $(window).height();
            var lowerBounds = curTop + height + 30;
            if (lowerBounds > screenHeight) {
              var n = (-1*height) - 87;
              markerTitle.css({top: n}); //,{duration:120,queue:false});                
            }
            else {
              markerTitle.css({top:8}); //,{duration:120,queue:false});              
            }
          }
//          $('.markerInfo').removeClass('activeInfo smallInfo').hide();
//          
//          ibhOzoneViewer.colorLegendWrapper.css(ibhOzoneViewer.legendCSS);
//          $('#markerInfo'+i).append(ibhOzoneViewer.colorLegendWrapper).addClass('activeInfo').show();
//          ibhOzoneViewer.colorLegend.redraw();
//          $('.marker').removeClass('activeMarker');
//          $('#marker'+i).addClass('activeMarker');
//    //      ibhOzoneViewer.activateMarker(settingsObj);
        },
        mouseout: function(marker){

          ibhOzoneViewer.contourAnimInit();
          
          ibhOzoneViewer.markerMouseEvent(marker, settingsObj.key, false);
          
          ibhOzoneViewer.gMap.css({cursor:'default'});

          // $('#markerTitle'+i+'').stop(true,true).fadeOut(200,function(){jQuery(this).css({top:"20px"})});
          var markerTitle = ibhOzoneViewer.getMarkerTitle(settingsObj.key);
          if (markerTitle) {
            markerTitle.hide().css({top:20});
          }
        
        }//,
        // click: function(marker){window.location = link}
      },
      callback: function(marker){

        ibhOzoneViewer.gMap.gmap3({
          action:'addOverlay',
          content: '<div id="markerTitle'+settingsObj.key+'" class="markerTitle" style="border-top: 12px solid #' + settingsObj.color + ';"><div class="markerTitleContents">'+settingsObj.html+'</div></div>',
          latLng: marker.getPosition()
        });

//        marker.setVisible(false);

        ibhOzoneViewer.markers[settingsObj.key] = marker;  

 //       ibhOzoneViewer.markerSettings[settingsObj.ts].push(settingsObj);  

         // do this once.
        if (activate && (ibhOzoneViewer.activatedMarker != name)) {
           
          ibhOzoneViewer.activatedMarker = settingsObj.name;
          ibhOzoneViewer.nextContourTS = settingsObj.ts;
           
          ibhOzoneViewer.gMap.gmap3({
            action:'panTo',
            args:[marker.position]
          });
          
          map = ibhOzoneViewer.gMap.gmap3('get');
          map.setZoom(ibhOzoneViewer.markerSearchZoom);

        }
      }
    });
  },

  addMarkerCallback : function() {
    this.markerCallbackNum++;
    this.addTotalCallback();
  },
  
  updateMarkerCallbacks: function() {

    if (this.markerCallbackNum != 0) {
      this.markerCallbackNum--;
      this.updateTotalCallbacks();
    }

//    if (this.markerCallbackNum == 0) {}
  },

  
  getMarkerTitle: function(key) {
    if (typeof(this.markerTitles[key]) == 'undefined') {
      var element = $('#markerTitle'+key);
      if (element.length > 0) {
        this.markerTitles[key] = element;
        return element; 
      }
      else {
        return false;
      }
    }
    return this.markerTitles[key];
  },

  markerMouseEvent: function(marker, key, mouseOver) {

    for (x in this.markerSettings[this.activeContourTS]) {
      if (this.markerSettings[this.activeContourTS][x].key == key) {

        var markerSrc;
        
        if (mouseOver) {
          markerSrc = this.getMarkerSrcHover();
        }
        else {
          markerSrc = this.getMarkerSrc();
        }
        
        var num = Number(this.markerSettings[this.activeContourTS][x].ozoneLevel);
        
        if (num > 155) {
          num = 155; // max+
        }
        
        var spriteXPos = (68*num) - 68;
        var icon = new google.maps.MarkerImage(markerSrc, new google.maps.Size(68, 68), new google.maps.Point(spriteXPos, 0));
        marker.setIcon(icon);
        
        break;
      }
    }

  },

  markerUniqueKey: function(lat, lng) {
    var key = Math.ceil(Math.abs((Number(lat) + Number(lng))*10000000));
    return key;   
  },
  
  saveMarker: function(settingsObj){
  
    var saved = this.getCookie('savedmarkers');
    
    var array = [];
    
    if (typeof(saved)!='undefined'){
      array = saved.split('|');    
    }
    
    var isNew = true;

    if (array.length >= this.savedMarkerLimit) {
      array.length = this.savedMarkerLimit;
    }

    for(i in array){
      var check = array[i].split('_');
      if (Number(settingsObj.lat) == Number(check[0]) && Number(settingsObj.lng) == Number(check[1])) {
        isNew = false;
        array[i] = settingsObj.lat + '_' + settingsObj.lng + '_' + settingsObj.name;
      }
    }

    if (isNew) {
      array.unshift(settingsObj.lat + '_' + settingsObj.lng + '_' + settingsObj.name);      
    }

    saved = array.join('|');

    this.setCookie('savedmarkers', saved, 365, "/");

  },

  loadSavedMarkers: function(){
  
    var saved = this.getCookie('savedmarkers');
    var values = [];
    
    if (typeof(saved) != 'undefined') {
      var array = saved.split('|');
      
     // alert(array.length);

      for(x in array) {
        var check = array[x].split('_');
        
        var lat = check.shift();
        var lng = check.shift();
        var name = check.join('_');
        values.push({
          lat: lat,
          lng: lng,
          name: name          
        });
      }      
    }
    
    return values;
  },
  
//  activateMarker: function(settingsObj, center) {
//  
//    if (typeof(settingsObj) != 'object') {
//      return;
//    }
//
//    var lati = settingsObj.lat;
//    var longi = settingsObj.lng;
//  
//    var todo = {action:'clear'};
//    todo['tag'] = ['activeMarker'];
//    this.gMap.gmap3(todo);
//    
//    var pin = false;
//
//    for (x in ibhOzoneViewer.aqiIndex) {
//      if (Number(settingsObj.ozoneLevel) >= x){
//        pin = ibhOzoneViewer.moduleBase +'images/pin-halo-'+ ibhOzoneViewer.aqiIndex[x].label +'.png';
//      }
//      else {
//        break;
//      }
//    }
//
//    if (!pin) {
//      return;
//    }
//
//    this.gMap.gmap3({
//      action : 'addMarker',
//      lat:lati,
//      lng:longi,
//      options: {
//        icon: new google.maps.MarkerImage(pin)
//      },
//      callback: function(marker) {
//        marker.setZIndex(999999);
//        if (center){
//          ibhOzoneViewer.gMap.gmap3({
//            action:'panTo',
//            args:[marker.position]
//          });
//        }
//      },
//      tag:'activeMarker'
//    });
//  },
  
  getOzoneInfo: function(ozoneLevel){
    
    if (ozoneLevel == -1) {
      return this.aqiIndexNoReading;
    }
  
    var r = null;
    for (x in ibhOzoneViewer.aqiIndex) {
      if (Number(ozoneLevel) >= x){
        r = ibhOzoneViewer.aqiIndex[x];
      }
      else {
        break;
      }
    }
    return r;
  },


//  addTower : function(jQuerythis, i, title, link, excerpt, lati, longi, img){
//    jQuerythis.gmap3({
//      action : 'addMarker',
//      lat:lati,
//      lng:longi,
//      tag:'tower',
//      options: {
//        icon: new google.maps.MarkerImage(this.moduleBase +'images/pin.png')
//      },
//      events:{
//        mouseover: function(marker){
//          jQuerythis.css({cursor:'pointer'});
//          $('#markerTitle'+i+'').fadeIn({ duration: 200, queue: false }).animate({bottom:"32px"},{duration:200,queue:false});
//          $('.markerInfo').removeClass('activeInfo').hide();
//          $('#markerInfo'+i+'').addClass('activeInfo').show();
//          $('.marker').removeClass('activeMarker');
//          $('#marker'+i+'').addClass('activeMarker');
//        },
//        mouseout: function(){
//          jQuerythis.css({cursor:'default'});
//          $('#markerTitle'+i+'').stop(true,true).fadeOut(200,function(){$(this).css({bottom:"0"})});
//        }//,
//        // click: function(marker){window.location = link}
//      },
//      callback: function(marker){
//        jQuerythis.gmap3({
//          action:'addOverlay',
//          content: '<div id="markerTitle'+i+'" class="markerTitle">'+title+'<span style="display:block">'+img+'</span></div>',
//          latLng: marker.getPosition()
//        });
//      }
//    });
//  },
// 
  
//  initTooltip : function() {
//
//    // Tooltip from CSS Globe written by Alen Grakalic (http://cssglobe.com)
//    this.tooltip = function(){
//      xOffset = -10;yOffset = 10;
//      $(".tooltip").hover(function(e){
//        this.t = this.title;
//        this.title = "";
//        $("body").append("<p class='itooltip'>"+ this.t +"</p>");
//        $(".itooltip")
//        .css("top",(e.pageY - xOffset) + "px")
//        .css("left",(e.pageX + yOffset) + "px")
//        .fadeIn(500);},function(){
//          this.title = this.t; 
//          $(".itooltip").remove();
//        });
//        $("a.tooltip")
//        .mousemove(function(e){
//          $(".itooltip").css("top",(e.pageY - xOffset) + "px")
//          .css("left",(e.pageX + yOffset) + "px");
//        });
//      };
//  },
  
  initLoadAnimation : function() {
    //LOADING ANIMATION
//    $('#loading').activity({segments: 12, width:5.5, space: 6, length: 13, color: '#fff'});
    $(window).load(function(){
      ibhOzoneViewer.firstWindowLoad = false;
      $('#loading').fadeOut(500);
      //TOP AREA SPACING STUFF
    //  var headerHeight = $("#header").height(),
    //  headerSpacing = headerHeight + 35;
//		jQuery("#dropmenu > li > a, #description").css({lineHeight:headerHeight+"px"});
//		jQuery("#dropmenu > li > ul").css({top:headerHeight+"px"});
	//	$("#content-viewer").css({paddingTop:headerSpacing+"px"});	
	//	$('#header').fadeIn(300, function(){
	//	  if (ibhOzoneViewer.playPause) {
	        // delay 5 seconds
	//      $('body').animate({backgroundColor:'#fff'}, 5000, function(){
	//	    ibhOzoneViewer.playPause.click();		        
	//      });
 
	//	  }
	//	});
	});  
  },

//  initAccordion : function() {
//    //ACCORDION TOGGLES	
//    $('.toggleButton').click(function(){
//      $(".toggleButton").not(this).removeClass('opened').next().slideUp(400);
//      $(".toggleButton").not(this).children('span').html("+");
//      $(this).toggleClass('opened').next().slideToggle(400);
//      $('.opened').children('span').html("&times;");
//      $(this).not('.opened').children('span').html("+");
//      $("html,body").animate({scrollTop:0},400);
//      $('body.page .entry').slideToggle(400);
//    }).hover(function(){
//      $(this).stop(true,true).animate({paddingLeft:"10px",backgroundColor:'#99b3cc', color:'#000'},300);
//    },function(){
//      $(this).stop(true,true).animate({paddingLeft:"8px",backgroundColor:'#333',color:'#fff'},300);
//    });
//  },
  
  initStage : function() {
	this.mainBox = $('#main');
	this.pageBox = $(".pageContent"); 
	
	//CLOSE MAIN DIV
	$("#closeBox").live('click', function(){
	  ibhOzoneViewer.mainBox.fadeOut(400);
	  ibhOzoneViewer.pageBox.animate({top:"0px"},600);
	  return false;
    });
    
    //OPEN MAIN DIV
    this.pageBox.live('click', function(){
      $(this).animate({top:"40px"},600);
      ibhOzoneViewer.mainBox.fadeIn(400);
      return false;
    });  
  },


  initFooterToggles : function() {
    
    var sidebarToggle = $('.sidebarToggle');
    var sidebar = $('#sidebar');
  
    sidebarToggle.click(function(){
      sidebar.slideToggle(400);
      sidebarToggle.toggleClass('open');
//      sidebarToggle.toggle();
      return false;
    });

    this.searchToggle = $('.searchToggle');
    this.searchWrapper = $('#searchGMap-wrapper');
    
    this.searchToggle.click(function(){
      ibhOzoneViewer.searchWrapper.slideToggle(400);
      ibhOzoneViewer.searchToggle.toggleClass('open');
//      ibhOzoneViewer.searchToggle.toggle();
      return false;
    });
  },
  
  
  initResize: function() {
	this.containerHeight = $(window).height() - 42;
	this.gMap.css({height:this.containerHeight, width:"100%"});
	this.marker = $('.marker');
	$(window).resize(function() {
	  ibhOzoneViewer.containerHeight = $(window).height() - 42;
	  ibhOzoneViewer.gMap.css({height:ibhOzoneViewer.containerHeight});
	});  
  },
  
  initTimeIndicator: function() {
    this.timeIndicator = $('#time-indicator');
  },
  
  initContour: function(){
    
    var url = this.contourURL;
    var ts = this.contourStartTS;

//    if (this.firstWindowLoad) {
//      this.contourNum = 0;
//      this.timeIndicator.html('<span>' + this.convertTimestamp(ts, false) + '</span>');
//    }
//    else {
      // Set in UI
      this.timeIndicator.html('<span>Loading...</span>');
      this.contourNum = Math.floor((this.contourEndTS - this.contourStartTS) / this.contourRes);    
//    }
  
  //  if (this.testMode) {
      // start from the beginning of the animation.
  //    this.contourStartTS = this.testContourEndTS - (this.contourNum*this.contourRes);
  //    this.contourEndTS = this.testContourEndTS;
  //  }
  //  else {
  //    this.contourStartTS = this.contourEndTS - (this.contourNum*this.contourRes);
  //  }


    
//    if (!this.isDeeplink && this.firstWindowLoad) {
//      ts = this.contourEndTS;      
//    }

    this.contourCallbackNum = 0;

//    $.doTimeout('nextContour', ibhOzoneViewer.contourAnimSpeed, function() {
//      ibhOzoneViewer.updateContourAnim();
//    });
    this.contourAnimReset();
    
    for (i=0;i<=this.contourNum;i++){
      
//      if (this.testMode) {
//        url = this.moduleBase + this.testContour + ts + '.js';
//      //  url = this.contourURL + 'timestamp=' + ts;
//      }
//      else {
        // obj.url = /path/to/api/function
//      url = this.contourURL;
//      }

      var data = {
        type: 'jsonp',
        timestamp: ts,
        bandschema: this.bandSchema
      }

      if (this.contourFlatFile) {

        var date = new Date(ts*1000);

        url = this.flatContourBaseURL 
          + date.getFullYear() + '/'
          + ('0' + (date.getMonth()+1)).slice(-2) + '/'
          + ('0' + date.getDate()).slice(-2) + '/'
          + ts
          + '_bs'
          + this.bandSchema
          + '.js';
        
         data = {};
      }

      this.updateAnimControls();
      this.loadContours(url, ts, data);
      ts += this.contourRes;

    }
  },

  
  // Recurse from present until valid json response.
  
  initLatestContour: function(timestamp){

    ibhOzoneViewer.contourEndTS = timestamp;
    
    var url = this.contourURL;
    var ts = timestamp;
    
    this.contourNum = 0;
    this.contourCallbackNum = 2;

    this.contourAnimReset();

    var data = {
      type: 'jsonp',
      timestamp: ts,
      bandschema: this.bandSchema
    }

    if (this.contourFlatFile) {

      var date = new Date(ts*1000);

      url = this.flatContourBaseURL 
        + date.getFullYear() + '/'
        + ('0' + (date.getMonth()+1)).slice(-2) + '/'
        + ('0' + date.getDate()).slice(-2) + '/'
        + ts
        + '_bs'
        + this.bandSchema
        + '.js';
      
       data = {};
    }

    this.updateAnimControls();
    
    var callback = function(data){
      if (!data.status || data.status.type != 'success') {
      //  var nextTS = data.timestamp - ibhOzoneViewer.contourRes;
        var nextTS = ibhOzoneViewer.contourEndTS - ibhOzoneViewer.contourRes;
        ibhOzoneViewer.initLatestContour(nextTS);
      }
      else {
        ibhOzoneViewer.initMarkers();
        ibhOzoneViewer.contourCallbackNum = 1;
        ibhOzoneViewer.updateContourCallbacks();
        ibhOzoneViewer.timeIndicator.html('<span>' + ibhOzoneViewer.convertTimestamp(ibhOzoneViewer.contourEndTS, false) + '</span>');
      }
    };
    
    this.loadContours(url, ts, data, callback);

  },

  loadContours: function(url, ts, data, callback) {
	if (!this.contourAjaxCalls[ts] && !this.contourJSONStorage[ts]) {
 	    this.addContourCallback();
	    this.contourAjaxCalls.push($.ajax({
	      url: url,
	      dataType : 'jsonp',
	      jsonpCallback: 'contourData' + ts,
	      data: data,
	      success: function(data){
	        if (typeof(callback) == 'function') {
	          callback(data);
	        }
	        if (data.status && data.status.type == 'success') {

	          var ts = data.timestamp;
	          var time = ibhOzoneViewer.convertTimestamp(ts, false); 
	          ibhOzoneViewer.formattedTime[ts] = time;

	          if (ibhOzoneViewer.displayMode == 1) {
	            ibhOzoneViewer.drawPolygons(data);
	          }
	          else if (data.status.type != 'fail') {
	            ibhOzoneViewer.contourJSONStorage[ts] = data;
	          }
	        }
	      },
	      complete: function(jqXHR, textStatus) {
	        ibhOzoneViewer.updateContourCallbacks();		
			ibhOzoneViewer.contourAjaxCalls.splice(ts,1);
	      },
		  error: function(jqXHR, textStatus) {
			console.log("contour" + ts + " aborted");
		  }
	    }));
	}
  },
  
  initAnimControls: function(){
    this.animSlider = $('#animation-slider');
    this.playPause = $('#play-pause');

    $(this.playPause).hover(
      function(){
        var offset = $(this).offset();
        var top = offset.top - 45;
        var left = offset.left + 2;
        if (!ibhOzoneViewer.isPlaying) {
          ibhOzoneViewer.tooltipContent.html('<div>Click to animate</div>');
          ibhOzoneViewer.tooltip.css({top:top,left:left}).show();
        }
//        else {
//          ibhOzoneViewer.tooltipContent.html('<div>Click to pause</div>');        
//        }

      },
      function() {
        ibhOzoneViewer.tooltip.hide();    
      }
    );


    this.fwdBtn = $('#forward-btn');
    this.bkwdBtn = $('#backward-btn');

//    this.playPause.hide();

    this.fwdBtn.css(this.inactiveUI);
    this.bkwdBtn.css(this.inactiveUI);
 
    this.fwdBtn.click(function(){
      if (ibhOzoneViewer.firstPlay) {
        return;
      }
      ibhOzoneViewer.playPause.addClass('paused');
      ibhOzoneViewer.isPlaying = false;
      ibhOzoneViewer.updateContourAnim(true); 
    });

    this.bkwdBtn.click(function(){
      if (ibhOzoneViewer.firstPlay) {
        return;
      }
      ibhOzoneViewer.playPause.addClass('paused');
      ibhOzoneViewer.isPlaying = false; 
      ibhOzoneViewer.updateContourAnim(true, true); 
    });
   
    this.playPause.addClass('paused'); 
    
    this.playPause.click(function(){
      ibhOzoneViewer.tooltip.hide();
      $(this).unbind('mouseenter').unbind('mouseleave')
      if (ibhOzoneViewer.firstPlay) {
        ibhOzoneViewer.isPlaying = true;
        ibhOzoneViewer.firstPlay = false;
        ibhOzoneViewer.playPause.removeClass('paused');
        ibhOzoneViewer.animSlider.slider('value', ibhOzoneViewer.contourStartTS);
        ibhOzoneViewer.reset();
      }
      else if ($(this).is('.paused')) {
        $(this).removeClass('paused');
        ibhOzoneViewer.isPlaying = true;
        ibhOzoneViewer.expandScrubber();
        ibhOzoneViewer.updateContourAnim();
      }
      else {
        $(this).addClass('paused');      
        ibhOzoneViewer.isPlaying = false;
      }
    });
    
    $('#animation-slider .ui-slider-handle').mousedown(function(){
      ibhOzoneViewer.isScrubbing = true;
      ibhOzoneViewer.skipOneContourAnim();
    });
    $('body').mouseup(function(){
      ibhOzoneViewer.isScrubbing = false;
      ibhOzoneViewer.skipOneContourAnim();
    });
  },
  
  updateAnimControls: function(){
    this.animSlider.slider({
      value: ibhOzoneViewer.contourStartTS,
      min: ibhOzoneViewer.contourStartTS,
      max: ibhOzoneViewer.contourEndTS,
      step: ibhOzoneViewer.contourRes,
      animate: false,
      slide: function(event, ui) {
        ibhOzoneViewer.nextContourTS = ui.value;
        ibhOzoneViewer.updateContourAnim(false);
      },
      stop: function(event, ui) {
        ibhOzoneViewer.nextContourTS = ui.value;
        ibhOzoneViewer.updateContourAnim(true);
      }
	});
  },
  
  addContourCallback : function() {
    this.contourCallbackNum++;
    this.addTotalCallback();
  },
  
  updateContourCallbacks: function() {

    if (this.contourCallbackNum != 0) {
      this.contourCallbackNum--;
      this.updateTotalCallbacks();
    }
    
    if (this.displayMode == 2) {
      this.contourJSONStorage = this.sortObj(this.contourJSONStorage);       
    }
    else {
      this.polygons = this.sortObj(this.polygons);    
    }

    if (this.contourCallbackNum == 0 && !this.isPlaying) {
      this.updateContourAnim(true);
    }

  },

  contourAnimReset: function() {
    clearTimeout(ibhOzoneViewer.contourTimeout);
    ibhOzoneViewer.contourAnimInit();
  },

  contourAnimClear: function() {
    clearTimeout(ibhOzoneViewer.contourTimeout);
  },

  contourAnimInit: function() {
    ibhOzoneViewer.contourTimeout = setTimeout(function() { ibhOzoneViewer.updateContourAnim(); }, ibhOzoneViewer.contourAnimSpeed);
  },

  legendLabelReset: function() {
    clearTimeout(this.legendLabelTimeout);
    ibhOzoneViewer.legendLabelInit();
  },

//  legendLabelClear: function() {
//    clearTimeout(ibhOzoneViewer.legendLabelTimeout);
//  },

  legendLabelInit: function() {
    ibhOzoneViewer.legendLabelTimeout = setTimeout(function() { ibhOzoneViewer.legendLabelHide(); }, ibhOzoneViewer.legendLabelHideSpeed);
  },
  
  reset: function() {
  
    var year = parseInt(ibhOzoneViewer.timelineYearVal, 10);
    var month = parseInt(ibhOzoneViewer.timelineMonthVal, 10) - 1;
    var day = parseInt(ibhOzoneViewer.timelineDayVal, 10);
    
    var d1 = new Date(year, month, day, ibhOzoneViewer.timelineHours0Val, ibhOzoneViewer.timelineMinutes0Val);
    var d2 = new Date(year, month, day, ibhOzoneViewer.timelineHours1Val, ibhOzoneViewer.timelineMinutes1Val);    

    var startTS = d1.getTime() / 1000;
    var endTS = d2.getTime() / 1000;
   
    if (endTS > Drupal.settings.ibh_ozone_viewer.now) {
      var d3 = new Date(Drupal.settings.ibh_ozone_viewer.now*1000);
      var now = d3.toLocaleString();
      ibhOzoneViewer.alert("Please choose time before " + now);
    }
    else {
      this.contourStartTS = startTS;
      this.contourEndTS = endTS;
      this.markerEndTS = endTS;
      this.markerNumber = 1;
      this.activeContourTS = null;

      // markers are placed through gmap3.
      this.gMap.gmap3({action:'clear'});
      $('.markerTitle').remove();      
      this.markerTitles = [];
      this.markerSettings = [];
      this.markers = [];
    
      // Polygons not placed with gmap3.
      for(x in this.polygons) {
        for(y in this.polygons[x]) {
          if (this.polygons[x][y]) {
            this.polygons[x][y].setMap(null);
          }
        }
      }
      this.polygons = [];
      this.contourJSONStorage = [];

      this.initContour();
      this.initMarkers();

    }

  },
  
  skipOneContourAnim: function() {
  
    ibhOzoneViewer.contourAnimReset();
//    $.doTimeout('nextContour', 0, function(){});
    
//    $.doTimeout('nextContour', ibhOzoneViewer.contourAnimSpeed, function() { 
//      ibhOzoneViewer.updateContourAnim();
//    });
  },
  
  expandScrubber : function() {
    if (!this.scubberExpanded) {
      this.scubberExpanded = true;
      $('#slider-wrapper-wrapper').delay(600).animate({width:205}, 600, function(){
        ibhOzoneViewer.fwdBtn.css(ibhOzoneViewer.activeUI).addClass('active');
        ibhOzoneViewer.bkwdBtn.css(ibhOzoneViewer.activeUI).addClass('active');
      });    
    }
  },
  
  updateContourAnim: function(force, bkwd){    

    if (!ibhOzoneViewer.isPlaying && !ibhOzoneViewer.isScrubbing && !force) {
      return;
    }

    // this.skipOneContourAnim is performance refinement. Because the contour show/hide 
    // event is so brutal with video memory, it is useful to cancel contour transition
    // for a single cycle such that other animations (like the color legend)
    // can be smooth.
    
//    if (this.skipOneContourAnim) {
//      this.skipOneContourAnim = false;
//      $.doTimeout('nextContour', ibhOzoneViewer.contourAnimSpeed, function() { 
//        ibhOzoneViewer.updateContourAnim();
//      });
//      return;
//    }

    var oldActiveContourTS = ibhOzoneViewer.activeContourTS;

    // get next
    var getNext = false;
    var next = false;
    var first = false;
    var loading = false;
    var getPrevious = false;
    
    var stored = [];

    if (ibhOzoneViewer.displayMode == 2) {
      stored = ibhOzoneViewer.contourJSONStorage;
    }
    else {
      stored = ibhOzoneViewer.polygons;
    }

    
    if (ibhOzoneViewer.nextContourTS) {
      next = ibhOzoneViewer.nextContourTS;
      ibhOzoneViewer.nextContourTS = null;
    }
    else {
      for (key in stored){
        if (!first) {
          first = key;
        }
        if (getNext) {
          next = key;
          break;
        }
        if (key == ibhOzoneViewer.activeContourTS) {
          previous = getPrevious;
          getNext = true;
        }
        getPrevious = key;
      }
      // Problem with clearing last contour when refreshing map.
      // Problem with having scrubber wait for unloaded timestamps.
      // Scrubber step should indicate full length.
      if (!this.activeContourTS) {
        next = first;
      }
      else if (!next) {
        next = first;
      }
      
      if (bkwd) {
        if (previous) {
          next = previous;
        }
      }
    }

    if (stored[next]) {
      ibhOzoneViewer.activeContourTS = next;    
    }
      
    ibhOzoneViewer.updateTimeIndicator(loading);
    
    ibhOzoneViewer.animSlider.slider("value", next);

//    var fix = setTimeout(function() {
//    for (key in ibhOzoneViewer.markers){
//      ibhOzoneViewer.updateMarker(ibhOzoneViewer.markerSettings[ibhOzoneViewer.activeContourTS]);
//    }    
//    }, 400);


    for (key in ibhOzoneViewer.markerSettings[ibhOzoneViewer.activeContourTS]){
      ibhOzoneViewer.updateMarker(ibhOzoneViewer.markerSettings[ibhOzoneViewer.activeContourTS][key]);
    } 

    for (key in ibhOzoneViewer.polygons[oldActiveContourTS]){
      if (ibhOzoneViewer.displayMode == 2) {
        if (ibhOzoneViewer.polygons[oldActiveContourTS][key]) {
          ibhOzoneViewer.polygons[oldActiveContourTS][key].setMap(null);
          ibhOzoneViewer.polygons[oldActiveContourTS][key] = null;        
        }
      }
      else {
        ibhOzoneViewer.polygons[oldActiveContourTS][key].setVisible(false);
      }
    }

    if (ibhOzoneViewer.displayMode == 2) {
      if (stored[next]) {
        ibhOzoneViewer.drawPolygons(stored[next]);
      }
    }
    else {
      for (key in ibhOzoneViewer.polygons[ibhOzoneViewer.activeContourTS]){
        ibhOzoneViewer.polygons[ibhOzoneViewer.activeContourTS][key].setVisible(true);
      }
    }




//    for (key in ibhOzoneViewer.markers[ibhOzoneViewer.activeContourTS]){
//       var t = ibhOzoneViewer.markers[ibhOzoneViewer.activeContourTS][key];
//       ibhOzoneViewer.markers[ibhOzoneViewer.activeContourTS][key].setVisible(true);
//    }
    


    if (!ibhOzoneViewer.isScrubbing) {
//      $.doTimeout('nextContour', ibhOzoneViewer.contourAnimSpeed, function() { 
//        ibhOzoneViewer.updateContourAnim();
//      });
      ibhOzoneViewer.contourAnimReset();
    }
  },
  
  updateTimeIndicator: function(loading) {
    if (!loading) {
      this.timeIndicator.html('<span>' + ibhOzoneViewer.formattedTime[ibhOzoneViewer.activeContourTS] + '</span>');    
    }
    else {
      this.timeIndicator.html('<span>Loading...</span>');       
    }
  },
  
//  initMarkers : function() {
//  
//    this.gMap.css({height:this.containerHeight, width:"100%"});
//    
//    $('#nextMarker').live('click', function(){
//      var activeMarker = $('.activeMarker');
//      var marker;
//      if(activeMarker.is(':not(:last-child)')){
//        activeMarker.removeClass('activeMarker');
//        marker = activeMarker.next('.marker');
//        marker.addClass('activeMarker');
//      } else {
//        activeMarker.removeClass('activeMarker');
//        marker = $('.marker:first-child');
//        marker.addClass('activeMarker');
//      }
//      $('.activeInfo').removeClass('activeInfo').hide();
//      marker.siblings('.marker').removeClass('activeMarker');
//      ibhOzoneViewer.colorLegendWrapper.css(ibhOzoneViewer.legendCSS);
//      marker.addClass('activeMarker').children('.markerInfo').addClass('activeInfo').append(ibhOzoneViewer.colorLegendWrapper).stop(true, true).show();
//      ibhOzoneViewer.activateMarker(marker.data('settingsObj'), true);
//      $("#target").show();
//    });
//    
//    $('#prevMarker').live('click', function(){
//      var activeMarker = $('.activeMarker');
//      var marker;
//      if(activeMarker.is(':not(:first-child)')){
//        activeMarker.removeClass('activeMarker');
//        marker = activeMarker.prev('.marker');
//        marker.addClass('activeMarker');
//      }
//      else {
//        activeMarker.removeClass('activeMarker');
//        marker = $('.marker:last-child');
//        marker.addClass('activeMarker');
//      }
//      $('.activeInfo').removeClass('activeInfo').hide();
//      marker.siblings('.marker').removeClass('activeMarker');
//      ibhOzoneViewer.colorLegendWrapper.css(ibhOzoneViewer.legendCSS);
//      marker.addClass('activeMarker').children('.markerInfo').addClass('activeInfo').append(ibhOzoneViewer.colorLegendWrapper).stop(true, true).show();
//      ibhOzoneViewer.activateMarker(marker.data('settingsObj'), true);
//      $("#target").show();
//    });
//    //HOVER
//
////    marker.live('mouseover', function(){
////      $('.activeInfo').removeClass('activeInfo').hide();
////      $(this).siblings('.marker').removeClass('activeMarker');
////      $(this).addClass('activeMarker').children('.markerInfo').addClass('activeInfo').stop(true, true).show();
////      $("#target").show();
////    });
////    //TARGET HOVER
////    $("#target").live('mouseover',function(){
////      $(this).hide();
////    });
//
//  },

  initMapTypeAndZoom: function() { 

    var map = this.gMap.gmap3("get");
    
    var controlDiv = document.createElement('div');
    controlDiv.style.index = -5000;
    map.controls[google.maps.ControlPosition.TOP_LEFT].push(controlDiv);    
    
    var html = '';
    html += '<div id="mapTypeContainer"><div id="mapTypeContainerInner">';
    //html += '<div id="mapType" title="Map Type" class="roadmap"></div>';
    html += '<div id="mapType" title="Map Type" class="satellite"></div>';
    html += '</div></div>';
/*
    html += '<div class="zoomControl" title="Zoom Out" id="zoomOut">';
    html += '<img src="'+ this.moduleBase +'images/zoomOut.png" alt="-" />';
    html += '</div><div class="zoomControl" title="Zoom In" id="zoomIn">';
    html += '<img src="'+ this.moduleBase +'images/zoomIn.png" alt="+" /></div></div></div>';
*/

    $(controlDiv).append(html);

    this.mapstyle = $("#mapStyle");
    this.mapstylecontainer = $("#mapStyleContainer");
//    this.maptype = $("#mapType");

    $(".roadmap").live('click',function(){
      ibhOzoneViewer.gMap.gmap3({action: 'setOptions', args:[{mapTypeId:'roadmap'}]},
	{
      action: 'setStyledMap',
      styledmap:{
        id: 'desaturated1',
        style: [{
          stylers: [
            { saturation: -60 }
          ]
	    }],
	    options:{
	      name: 'Desaturated'
        }
      }
	}); //hybrid, satellite, roadmap, terrain
      $(this).removeClass('roadmap').addClass('satellite');
      ibhOzoneViewer.mapstyle.toggleClass('satellite');
    });
    $(".satellite").live('click',function(){
      ibhOzoneViewer.gMap.gmap3({action: 'setOptions', args:[{mapTypeId:'hybrid'}]}); //hybrid, satellite, roadmap, terrain
      $(this).removeClass('satellite').addClass('roadmap');
      ibhOzoneViewer.mapstyle.toggleClass('satellite');
    });

/*
    $('#zoomIn').live('click', function(){
      ibhOzoneViewer.zoomLevel += 1;
      ibhOzoneViewer.gMap.gmap3({action: 'setOptions', args:[{zoom:ibhOzoneViewer.zoomLevel}]});
    });
    $('#zoomOut').live('click', function(){
      ibhOzoneViewer.zoomLevel -= 1;
      ibhOzoneViewer.gMap.gmap3({action: 'setOptions', args:[{zoom:ibhOzoneViewer.zoomLevel}]});
    });
*/
    
  },

  initMobileOverrides: function() {

    if (this.iPadiPhone) {
      function windowSizes(){
        var headerHeight = $("#header").height(),
        headerSpacing = headerHeight + 35,
        windowHeight = $(window).height(),
        footerSpacing = 75,
        mainHeight = windowHeight - headerSpacing - footerSpacing - 40;
        if(ibhOzoneViewer.mainBox.outerHeight() > mainHeight) {
          ibhOzoneViewer.mainBox.css({height:mainHeight,overflow:"auto"});
        }
      }

      windowSizes();

      $(window).resize(function() {
        windowSizes();
      });

      $('.toggleButton').click(function(){
        windowSizes();
      });

      $('body').addClass('iPad');

	}

  },

  initVerticalColorLegend: function() {

    this.colorLegend = $("#color-legend");

    var clHeight = this.colorLegend.height();
  
    this.colorLegend.slider({
      orientation: "vertical",
      range: "min",
      min: 0,
      max: ibhOzoneViewer.maxAqiIndex,
      value: 10,
      animate: true,
      change: function( event, ui ) {
      //  $( "#amount" ).val( ui.value );
        ibhOzoneViewer.skipOneContourAnim();
        var data = ibhOzoneViewer.getOzoneInfo(ui.value);
        if (ibhOzoneViewer.colorLegendLabel) {
          var ts = ibhOzoneViewer.animSlider.slider("value");
          var time = ibhOzoneViewer.convertTimestamp(ts, true);
          var html = '';
          html += '<div class="number">' + ui.value + '</div>';
          html += '<div class="desc">' + data.title.toUpperCase() + '<br /><span class="time">Range: ' + data.span + '</span>';
          html += '<br /><span class="time">Updated: ' + time + '</span></div>';          
          ibhOzoneViewer.colorLegendHtml.html('<div>' + html + '</div>');
          ibhOzoneViewer.colorLegendLabel.css({borderRight:'8px solid #' + data.color});
          
          ibhOzoneViewer.colorLegendHandle.show();
          
          ibhOzoneViewer.legendLabelReset();
//          $.doTimeout('hideLabel', 5000, function() { 
//            ibhOzoneViewer.colorLegendHandle.hide();
//          });
        }
      }
    });
    
    // add the label.
    this.colorLegendHandle = $('#color-legend .ui-slider-handle');
    this.colorLegendHandle.append('<div id="color-legend-label"><div id="color-legend-html"></div></div>');
    this.colorLegendLabel = $('#color-legend-label');
    this.colorLegendHtml = $('#color-legend-html');
    
    // add the track.
    var start,startX,startD,end,endX;
 
	var cssObj = {
	  position: 'absolute',
	  left:0,
	  borderBottom:'1px solid #fff',
	  borderLeft:'1px solid #fff',
	  borderRight:'1px solid #fff',
	  width:13
	} 
    
    for(x in this.aqiIndex) {
      if (!start){
        start = this.aqiIndex[x].color;
//        startD = this.aqiIndex[x].title;
        startX = x;
        continue;
      }
      if (!end) {
        end = this.aqiIndex[x].color;
        endX = Number(x);

        this.aqiIndex[startX].span = '' + startX + '-' + endX;

        var ratio = (endX - startX) / this.maxAqiIndex;
 
        var bottom = Math.ceil((startX * clHeight) / this.maxAqiIndex);
 
        var h = Math.ceil(clHeight * ratio) + 4; // magic number fix, sorry.
        
        cssObj.height = h;
        cssObj.backgroundColor = '#'+start;
        cssObj.bottom = bottom + 'px';
        
        $('<div>').css(cssObj).appendTo(this.colorLegend);

        start = end;
        startX = endX;
//        startD = this.aqiIndex[x].title;
        end = false;
        continue;
      }
    }

    var bottom = Math.ceil((startX * clHeight) / this.maxAqiIndex);

    this.aqiIndex[startX].span = '' + startX + '-' + endX;
    
    cssObj.borderTop = '1px solid #fff';
    cssObj.height = h;
    cssObj.backgroundColor = '#'+start;
    cssObj.bottom = bottom + 'px';
	
	$('<div>').css(cssObj).appendTo(this.colorLegend);

  },
  
  legendLabelHide: function() {
    this.colorLegendHandle.hide();  
  },
 
  
//  initColorLegend: function() {
//    
//    this.colorLegendWrapper = $('#colorLegend');
//    
//    var dataSeries = [];
//    var start,startX,end,endX,name;
//    
//    
//    for(x in this.aqiIndex) {
//      if (!start){
//        start = this.aqiIndex[x].color;
//        startD = this.aqiIndex[x].title;
//        startX = x;
//        continue;
//      }
//      if (!end) {
//        end = this.aqiIndex[x].color;
//        endX = Number(x);
//
//        name = startD + ' <p>('+startX+'-'+endX+')</p>'; 
//
//        var thisObj = {
//          name: name,
//          data: [40],
//          color: '#'+start,
//          type:'column',
//          dataLabels: {
//            formatter: function() {
//	          return name;
//            }
//          }
//        }
//        
//        ibhOzoneViewer.pushToSeries(name, startD,[50],'#'+start,startX,endX);
//
//        start = end;
//        startX = endX;
//        startD = this.aqiIndex[x].title;
//        end = false;
//        continue;
//      }
//    }
//
//    name = startD + ' <p>('+startX+'+)</p>'; 
//
//    thisObj = {
//      name: name,
//      data: [40],
//      color: '#'+start,
//      type:'column',
//      dataLabels: {
//        formatter: function() {
//	      return startX + '+';
//        }
//      }
//    }
//
//    ibhOzoneViewer.pushToSeries(name, startD,[50],'#'+start,startX,'+');
//    
//    this.colorLegend = new Highcharts.Chart({
//      chart: {
//        renderTo: 'colorLegend',
//        type: 'column',
//        backgroundColor: null,
//        marginTop:5,
//        marginRight:0,
//        marginBottom:0,
//        marginLeft:0,
//        spacingTop:0,
//        spacingRight:0,
//        spacingBottom:0,
//        spacingLeft:0
//      },
//      title: {
//        text: null
//      },
//      xAxis: {
//        title: {
//          text: null
//        },
//        categories: ['Ozone Level'],
//        endOnTick: false,
//        maxPadding: 0,
//        minPadding:0
//      },
//      yAxis: {
//        allowDecimals: false,
//        min: 0,
//        title: {
//          text: null
//        },
//        endOnTick: false,
//        maxPadding: 0.05,
//        minPadding:0,
//        minorTickInterval: null,
//        tickWidth: 0,
//        tickInterval : 1000,
//        reversed: false
//      },
//      credits: {
//        enabled: false
//      },
//      tooltip: {
//        formatter: function() {
//          return '<b>'+ this.x +'</b><br/>'+
//          this.series.name;
//        }
//      },
//      plotOptions: {
//        column: {
//          stacking: 'normal',
//          dataLabels: {
//            enabled: true,
//            color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white'
//          }
//        }
//      },
//
//      legend: {
//        enabled: false
//      },
//      series: ibhOzoneViewer.getSeries().reverse()
//    });
//  },
//
//  pushToSeries: function(name,desc,data,color,min,max) {
//    
//    var thisObj = {
//          name: name,
//          data: data,
//          color: color,
//          type:'column',
//          dataLabels: {
//            formatter: function() {
//	          return ibhOzoneViewer.truncate(desc,15,true);
//            }
//          }
//        }
//  
//    this.colorDataSeries.push(thisObj);
//  },
//  
//  getSeries: function() {
//    return this.colorDataSeries;
//  },
 
//  initDrag: function() {
//    if (!this.iPadiPhone) {
//
////      this.mainBox.draggable({ handle:"#handle",opacity: 0.8}).resizable();
////      this.mainBox.prepend("<div id='moveNotice'></div>");
////      $("#handle").hover(function(){
////        $("#moveNotice").stop(true,true).fadeIn(200);
////      },function(){
////        $("#moveNotice").stop(true,true).fadeOut(200);
////      });
//
//    }
//  },
  
  initHelp: function() {
    this.help1 = $('#help-1');
    $('#help-info').hover(
      function(){
        var offset = $(this).offset();
        var top = offset.top + 5;
        var left = offset.left - 188;
        //var left = offset.left - 50;
        ibhOzoneViewer.tooltipContentRight.html('<div>Show Air Quality Index chart</div>');
        ibhOzoneViewer.tooltipRight.css({top:top,left:left}).show();
      },
      function() {
        ibhOzoneViewer.tooltipRight.hide();    
      }
    );
    $('#help-info').click(function(){
      if (ibhOzoneViewer.appAlert) {
        if ($(ibhOzoneViewer.appAlert).dialog( "isOpen" )) {
          $(ibhOzoneViewer.appAlert).dialog("close");
        }
        else {
          ibhOzoneViewer.showHelp1();        
        }   
      }
      else {
        ibhOzoneViewer.showHelp1();        
      }
    });
    
// disable initial pop up
/*
    var shown = this.getCookie('showedHelp');
    
    if (!shown) {
      ibhOzoneViewer.showHelp1();        
      this.setCookie('showedHelp', '1', 365, "/");
    }
*/
  
  },
  
  showHelp1 : function() {
    this.alert(this.help1.html(), 'Help', {});
  },
  
  // Utility functions

  drawPolygons: function(data) {
  
    // Profiling
    // var startTime = new Date();

    var ts = data.timestamp;
 
    this.polygons[ts] = [];    
 
    var contourLabels = data.labels; 

    var i = 0;

    var contourData = this.indexContourData(data);

    for (var labelID in contourData.cLines) {
      this.drawPolygon(labelID, contourData, contourLabels, ts);
    }

    
    //////
    //////  Now fill in the valleys.

    if (typeof(contourData.valleyLines) == 'undefined' || contourData.valleyLines.length == 0) {
      return;
    }

    // get the labels of valley lines
    var maxLabel = 0;
    for (var label in contourData.valleyLines) {
      if (parseInt(label) > maxLabel) {
        maxLabel=parseInt(label)
      };
    }

    for (var lbl=maxLabel; lbl > 10; lbl -= 10) {
      this.drawValley(lbl, contourData, contourLabels, ts);
    }

    // var endTime = new Date();
    // if (console && this.testMode) {
    //  console.log("Time taken for all cLines: "
    //    + (endTime.getTime() - startTime.getTime()) + " ms");
    // }

  },
  
  drawPolygon: function(lbl, contourData, labels, ts) {

    var cLines = contourData.cLines;
    var valleyLines = contourData.valleyLines;
    
    var polyPath = [];
    var points = [];
    var lat,lng;
       
    for (var i=0; i<cLines[lbl].length; i++) {
//      polyPath.push(this.bspline(cLines[lbl][i]));
      points = [];
      for (var j=0; j<cLines[lbl][i].length; j++) {
        lat = cLines[lbl][i][j][0];
        lng = cLines[lbl][i][j][1];
        points.push(new google.maps.LatLng(lat, lng));
      }       
      polyPath.push(points);
    }

    var nxt = parseInt(lbl) + 10;

    var tmp = [];

    // anticlockwise for overlying regions.
    if (typeof(cLines[nxt]) != 'undefined') {
      for (var i=cLines[nxt].length-1; i>=0; i--) {
        tmp = [];
        for (var j=cLines[nxt][i].length-1; j>=0; j--) {
          tmp.push(cLines[nxt][i][j]);
        }
//        polyPath.push(this.bspline(tmp));
        points = [];
        for (var k=0; k<tmp.length; k++) {
          lat = tmp[k][0];
          lng = tmp[k][1];
          points.push(new google.maps.LatLng(lat, lng));
        }       
        polyPath.push(points);
      }   
    }

    // anticlockwise for all valleys if any largest valley.
    // note simply making hole for valleys.  not drawing them yet.
    if (typeof(valleyLines[lbl]) != 'undefined') {
      for (var i=0; i<valleyLines[lbl].length; i++) {
        if (valleyLines[lbl][i].l) {
          tmp = [];
          for (var j=valleyLines[lbl][i].p.length-1;j>=0;j--){
            tmp.push(valleyLines[lbl][i].p[j]);
          }
          points = [];
          for (var k=0; k<tmp.length; k++) {
            lat = tmp[k][0];
            lng = tmp[k][1];
            points.push(new google.maps.LatLng(lat, lng));
          }   
          polyPath.push(points);
        }
      }
    }

    var ozoneDataInfo = this.getOzoneInfo(labels[lbl]['max']);
    var opacity = ozoneDataInfo.opacity;

     // Color by span.
//     var strokeColor = '#' + ozoneDataInfo.color;
//     var fillColor = '#' + ozoneDataInfo.color;
    
    // Color by gradient.
    
    var strokeColor = '#' + ibhOzoneViewer.gradientIndex[labels[lbl]['max']];
    var fillColor = '#' + ibhOzoneViewer.gradientIndex[labels[lbl]['max']];

    var polygon = new google.maps.Polygon({
      paths: polyPath,
      strokeColor: strokeColor,
      strokeOpacity: opacity - 0.1,
      strokeWeight: 1,
      fillColor: fillColor,
      fillOpacity: opacity
    });
    
    var map = this.gMap.gmap3('get');
    polygon.setMap(map);
    
//    google.maps.event.addListener(polygon,"mouseover",function(){
//      this.setOptions({
//        strokeOpacity: 0.7,
//        strokeWeight: 2
//      });
//    }); 

//    google.maps.event.addListener(polygon,"mouseout",function(){
//      this.setOptions({
//        strokeOpacity: opacity - 0.1,
//        strokeWeight: 1
//      });
//    });

    var middle = labels[lbl]['max'] - ((labels[lbl]['max'] - labels[lbl]['min']) / 2);
    
    google.maps.event.addListener(polygon,"click",function(){
      ibhOzoneViewer.skipOneContourAnim();
      ibhOzoneViewer.colorLegend.slider('value', middle);
    });
    
    if (!this.firstWindowLoad && ibhOzoneViewer.displayMode != 2) {
      polygon.setVisible(false);
    }
    
    this.polygons[ts].push(polygon);  

  },

  drawValley : function(lbl, contourData, labels, ts) {

    lbl = parseInt(lbl);
     
    if (lbl == 10) {
      return;
    }

    var valleyLines = contourData.valleyLines;
    
    var polyPath = [];
    var points = [];
    var lat,lng;  
  
    if (typeof(valleyLines[lbl]) == 'undefined' || valleyLines[lbl].length == 0) {
      return;
    }


    // draw the valley with color of lbl-10
    for (var i=0; i<valleyLines[lbl].length; i++) {
      points = [];
//      for (var j=0; j<valleyLines[lbl][i].length; j++) {
        // lat = valleyLines[lbl][i][j].p[0];
        // lng = valleyLines[lbl][i][j].p[1];
      for (var j=0; j<valleyLines[lbl][i].p.length; j++) {
        lat = valleyLines[lbl][i].p[j][0];
        lng = valleyLines[lbl][i].p[j][1];
        points.push(new google.maps.LatLng(lat, lng));
      }       
      polyPath.push(points);
    }

    // anticlockwise for lbl-10 for each of those that are not
    // the largest.. This type of support needs to be provided
    // by backend infrastructure
    var nxt = lbl - 10;
    for (var i=0; i<valleyLines[nxt].length; i++) {
      if (valleyLines[nxt][i].l) {
        continue;  
      }
      var tmp = [];
      for (var j=valleyLines[nxt][i].p.length-1; j>=0; j--) {
        tmp.push(valleyLines[nxt][i].p[j]);
      }
      points = [];
      for (var k=0; k<tmp.length; k++) {
        lat = tmp[k][0];
        lng = tmp[k][1];
        points.push(new google.maps.LatLng(lat, lng));
      }        
      polyPath.push(points);
    }
 
    var ozoneDataInfo = this.getOzoneInfo(labels[lbl]['max']);
    var opacity = ozoneDataInfo.opacity;
    
     // Color by span.
//     var strokeColor = '#' + ozoneDataInfo.color;
//     var fillColor = '#' + ozoneDataInfo.color;
    
    // Color by gradient.
    
    var strokeColor = '#' + ibhOzoneViewer.gradientIndex[labels[lbl]['max']];
    var fillColor = '#' + ibhOzoneViewer.gradientIndex[labels[lbl]['max']];

    var polygon = new google.maps.Polygon({
      paths: polyPath,
      strokeColor: strokeColor,
      strokeOpacity: opacity - 0.1,
      strokeWeight: 1,
      fillColor: fillColor,
      fillOpacity: opacity
    });
    
    var map = this.gMap.gmap3('get');
    polygon.setMap(map);
    
//    google.maps.event.addListener(polygon,"mouseover",function(){
//      this.setOptions({
//        strokeOpacity: 0.7,
//        strokeWeight: 2
//      });
//    }); 

//    google.maps.event.addListener(polygon,"mouseout",function(){
//      this.setOptions({
//        strokeOpacity: opacity - 0.1,
//        strokeWeight: 1
//      });
//    });

    var middle = labels[lbl]['max'] - ((labels[lbl]['max'] - labels[lbl]['min']) / 2);
    
    google.maps.event.addListener(polygon,"click",function(){
      ibhOzoneViewer.skipOneContourAnim();
      ibhOzoneViewer.colorLegend.slider('value', middle);
    });
    
    if (!this.firstWindowLoad && ibhOzoneViewer.displayMode != 2) {
      polygon.setVisible(false);    
    }
    
    this.polygons[ts].push(polygon);  

  },

  indexContourData: function(resp) {
  
    var cLines = {};
    var valleyLines = {};

    for (var lbl in resp.labels) {
        cLines[lbl] = [];
        valleyLines[lbl] = [];
    }
    
    if (typeof(resp.data) !="undefined") {
      for (var i=0; i<resp.data.length; i++) {
        lbl = resp.data[i].label_id;
        cLines[lbl].push(resp.data[i].polygon);
      }
    }

    var itr = typeof(resp.valley) !="undefined"
            ? resp.valley.length
            : 0;
    for (var i=0; i<itr; i++) {

        lbl = resp.valley[i].label_id;

	    var isLargest =
	            typeof(resp.valley[i].isLargest) != 'undefined'
	            ? resp.valley[i].isLargest
	            : false;        

        valleyLines[lbl].push({
          p: resp.valley[i].polygon,
          l: isLargest
        });

    }
    
    return {
      cLines : cLines,
      valleyLines : valleyLines
    }

  },

  /**
   * bspline
   *
   * Smooth out the polylines or polygon boundaries by adding more
   * in-between points.
   * This function has been adopted (with only slight modification)
   * from http://johan.karlsteen.com/2011/07/30/improving-google-maps
   * -polygons-with-b-splines/
  **/
  bspline: function(oneCLine) {
    var i, t, ax, ay, bx, by, cx, cy, dx, dy, lat, lon, points;

    var lats = [];
    var lons = [];
    var points = [];
//    var startTime = new Date();

    // split the oneCLine into lats and lons array. Meanwhile,
    // extend the lines by pulling last two entries to front and
    // front two entries to last.
    if (oneCLine.length == 1) {
      lats[0] = oneCLine[0][0];
      lons[0] = oneCLine[0][1];
    } else {
      lats[0] = oneCLine[oneCLine.length - 2][0];
      lons[0] = oneCLine[oneCLine.length - 2][1];
    }

    lats[1] = oneCLine[oneCLine.length - 1][0];
    lons[1] = oneCLine[oneCLine.length - 1][1];
    for (i = 0; i < oneCLine.length; i++) {
      lats[i+2] = oneCLine[i][0];
      lons[i+2] = oneCLine[i][1];
    }
    lats[i+2] = oneCLine[0][0];
    lons[i+2] = oneCLine[0][1];

    if (oneCLine.length == 1) {
      lats[i+3] = oneCLine[0][0];
      lons[i+3] = oneCLine[0][1];
    } else {
      lats[i+3] = oneCLine[1][0];
      lons[i+3] = oneCLine[1][1];
    }

    // For every point
    for (i = 2; i < lats.length - 2; i++) {
      for (t = 0; t < 1; t += 0.2) {
        ax = (-lats[i - 2] + 3 * lats[i - 1] - 3 * lats[i] + lats[i + 1]) / 6;
        ay = (-lons[i - 2] + 3 * lons[i - 1] - 3 * lons[i] + lons[i + 1]) / 6;
        bx = (lats[i - 2] - 2 * lats[i - 1] + lats[i]) / 2;
        by = (lons[i - 2] - 2 * lons[i - 1] + lons[i]) / 2;
        cx = (-lats[i - 2] + lats[i]) / 2;
        cy = (-lons[i - 2] + lons[i]) / 2;
        dx = (lats[i - 2] + 4 * lats[i - 1] + lats[i]) / 6;
        dy = (lons[i - 2] + 4 * lons[i - 1] + lons[i]) / 6;
        lat = ax * Math.pow(t + 0.1, 3) + bx * Math.pow(t + 0.1, 2) + cx * (t + 0.1) + dx;
        lon = ay * Math.pow(t + 0.1, 3) + by * Math.pow(t + 0.1, 2) + cy * (t + 0.1) + dy;
        points.push(new google.maps.LatLng(lat, lon));
      }
    }

//    var endTime = new Date();
    return points;
  },
  
  sortObj: function(arr){
    var sortedKeys = new Array();
    var sortedObj = {};
    for (var i in arr){
      sortedKeys.push(i);
    }
    sortedKeys.sort();
    
    for (var i in sortedKeys){
      sortedObj[sortedKeys[i]] = arr[sortedKeys[i]];
    }
    return sortedObj;
  },

  sortPolygons: function(arr){
    function compareLayerIds(a, b) {
      return a.label_id - b.label_id;
    }
    return arr.sort(compareLayerIds);
  },
  

  hexToR: function(h) {return parseInt((this.cutHex(h)).substring(0,2),16)},
  hexToG: function(h) {return parseInt((this.cutHex(h)).substring(2,4),16)},
  hexToB: function(h) {return parseInt((this.cutHex(h)).substring(4,6),16)},
  cutHex: function(h) {return (h.charAt(0)=="#") ? h.substring(1,7):h},
  
  truncate: function(str, n,useWordBoundary){
    var toLong = str.length>n,
        s_ = toLong ? str.substr(0,n-1) : str;
        s_ = useWordBoundary && toLong ? s_.substr(0,s_.lastIndexOf(' ')) : s_;
    return  toLong ? s_ +'...' : s_;
  },
  
  alert: function(message, title, buttons){
    if(!title) {
      title = 'Message';
    }
    if (!buttons) {
      buttons = {
        'OK':function(){
          $(this).dialog('close');
        }
	  }
    }
    
    if (!this.appAlert) {
      this.appAlert = $('<div />');
      $('body').prepend(this.appAlert);
    }
	this.appAlert.html('<div>' + message + '</div>').dialog({
		modal:false,
		title:'',
		width:650,
		zIndex:1500,
		draggable:true,
		buttons: buttons
	});
    $(document).scrollTop(0);
  },
  
  convertTimestamp: function(ts, short) {
  
    var a = new Date(ts*1000);
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var year = a.getFullYear();
    var month = months[a.getMonth()];
    var date = a.getDate();
        
    var day = month + ' ' + date + ', ' + year;
    
    if (short) {
      month = a.getMonth() + 1;
      day = '' + month + '/' + date + '/' + year.toString().slice(2);
    }

    var hour = a.getHours();
    var min = a.getMinutes();
    
    var ampm = 'AM';
    
    if (hour > 11) {
      ampm = 'PM';
    }
    
    if (hour >= 13) {
      hour -= 12;
    }
    
    var time = day + ' ' + ('0' + (hour)).slice(-2) + ':' + ('0' + (min)).slice(-2) + ' ' + ampm;  
    return time;
    
  },
  
  setCookie: function( name, value, expires, path, domain, secure ) {
    var today = new Date();
    today.setTime( today.getTime() );
    if ( expires ){
    expires = expires * 1000 * 60 * 60 * 24;
    }
    var expires_date = new Date( today.getTime() + (expires) );
    document.cookie = name + "=" + escape( value ) +
    ( ( expires ) ? ";expires=" + expires_date.toGMTString() : "" ) +
    ( ( path ) ? ";path=" + path : "" ) +
    ( ( domain ) ? ";domain=" + domain : "" ) +
    ( ( secure ) ? ";secure" : "" );
  },
  
  getCookie: function(c_name) {
    var i,x,y,ARRcookies=document.cookie.split(";");
    for (i=0;i<ARRcookies.length;i++) {
      x=ARRcookies[i].substr(0,ARRcookies[i].indexOf("="));
      y=ARRcookies[i].substr(ARRcookies[i].indexOf("=")+1);
      x=x.replace(/^\s+|\s+$/g,"");
      if (x==c_name) {
        return unescape(y);
      }
    }
  },

	updateTimeline: function() {
		var starttime = this.contourStartTS - (30*24*3600);
		var endtime = this.contourEndTS;
		var timespan = endtime-starttime;
		
		var timesegment = "m"; //month
		
		if (timespan <= 6048000) //timespan < 100 weeks
			timesegment = "w";
			
		if (timespan <= 8640000) //timespan <= 100 days
			timesegment = "d"; //days
		
		if (timespan <= 360000) //timespan <= 100 hours
			timesegment = "h"; //hour
			
		if (timespan <= 30000) //timespan <= 100 5-minute epochs
			timesegment = "e"; //epoch per 5-minute data
		
		var timeline_data_src = this.moduleBase + 'ajax/getTimelineData.php?seg=' + timesegment + '&s=' + starttime + '&e=' + endtime;
		
		var line_data = [
			{key: "hazardous", values: [] },
			{key: "very", values: [] }, 
			{key: "unhealthy", values: [] },
			{key: "warning", values: [] },
			{key: "moderate", values: [] }, 
			{key: "good", values: [] }, 
			{key: "average", values: [] },
			{key: "maximum", values: [] },
			{key: "minimum", values: [] }
		];		
		
		d3.csv(timeline_data_src, function(error, data) {
			data.forEach(function(d) {
				var date = new Date(+d.epoch*1000);
				var coeff = (parseInt(d.maximum)-parseInt(d.minimum))/parseInt(d.total);
				var good = parseInt(d.good)*coeff+parseInt(d.minimum);
				var moderate = parseInt(d.moderate)*coeff+good;
				var warning = parseInt(d.warning)*coeff+moderate;
				var unhealthy = parseInt(d.unhealthy)*coeff+warning;
				var very = parseInt(d.very)*coeff+unhealthy;
				var hazardous = parseInt(d.hazardous)*coeff+very;
				line_data[0]["values"].push({x: date, y: very, y0: hazardous});
				line_data[1]["values"].push({x: date, y: unhealthy, y0: very});
				line_data[2]["values"].push({x: date, y: warning, y0: unhealthy});
				line_data[3]["values"].push({x: date, y: moderate, y0: warning});
				line_data[4]["values"].push({x: date, y: good, y0: moderate});
				line_data[5]["values"].push({x: date, y: +d.minimum, y0: good });
				line_data[6]["values"].push({x: date, y: +d.average, y0: +d.average, max: +d.maximum, min: +d.minimum });
				// line_data[7]["values"].push({x: date, y: +d.maximum, y0: +d.maximum });
				// line_data[8]["values"].push({x: date, y: +d.minimum, y0: +d.minimum });
			});
			d3.select('#timeline-wrapper svg')
				.datum(line_data)
				.transition().duration(500)
				.call(ibhOzoneViewer.timelineChart);
		});
	},
  
	loadTimeline: function() {
		var starttime = this.contourStartTS - (30*24*3600);
		var endtime = this.contourEndTS;
		var timespan = endtime-starttime;

		var timesegment = "m"; //month
		
		if (timespan <= 6048000) //timespan < 100 weeks
			timesegment = "w";
			
		if (timespan <= 8640000) //timespan <= 100 days
			timesegment = "d"; //days
		
		if (timespan <= 360000) //timespan <= 100 hours
			timesegment = "h"; //hour
			
		if (timespan <= 30000) //timespan <= 100 5-minute epochs
			timesegment = "e"; //epoch per 5-minute data
		
		var timeline_data_src = this.moduleBase + 'ajax/getTimelineData.php?seg=' + timesegment + '&s=' + starttime + '&e=' + endtime;

		nv.addGraph(function() {
			ibhOzoneViewer.timelineChart = nv.models.lineWithFocusChart().clipEdge(false);

			ibhOzoneViewer.timelineChart
				.height2(40)
				.margin({top: 20, bottom: 20, left: 40, right: 20})
				.margin2({top: 0, bottom: 20, left: 40, right: 20})
				.showLegend(false)
				.tooltips(true)
				.interpolate("linear")
				.color([
					"rgb(104, 14, 100)",
					"rgb(198, 48, 123)", 
					"rgb(184, 33, 43)", 
					"rgb(239, 140, 32)", 
					"rgb(246, 236, 38)", 
					"rgb(41, 183, 51)", 
					"white",
					"white",
					"white"
				])
				.tooltipContent(function(key, x, y, e, graph) {
					return '<h3 style="border-color: #' + ibhOzoneViewer.gradientIndex[parseInt(e.point.max)] + '">Maximum: ' + e.point.max + '</h3><h3 style="border-color: #' + ibhOzoneViewer.gradientIndex[parseInt(y)] + '">Average: ' + y + '</h3><h3 style="border-color: #' + ibhOzoneViewer.gradientIndex[parseInt(e.point.min)] + '">Minimum: ' + e.point.min + '</h3>';
			      });

			var customTimeFormat = d3.time.format.multi([
			  [".%L", function(d) { return d.getMilliseconds(); }],
			  [":%S", function(d) { return d.getSeconds(); }],
			  ["%I:%M", function(d) { return d.getMinutes(); }],
			  ["%I %p", function(d) { return d.getHours(); }],
			  ["%a %d", function(d) { return d.getDay() && d.getDate() != 1; }],
			  ["%b %d", function(d) { return d.getDate() != 1; }],
			  ["%B", function(d) { return d.getMonth(); }],
			  ["%Y", function() { return true; }]
			]);
			
			var line_data = [
				{key: "hazardous", values: [] },
				{key: "very", values: [] }, 
				{key: "unhealthy", values: [] },
				{key: "warning", values: [] },
				{key: "moderate", values: [] }, 
				{key: "good", values: [] }, 
				{key: "average", values: [] },
				{key: "maximum", values: [] },
				{key: "minimum", values: [] }
			];


			ibhOzoneViewer.timelineChart.lines.scatter.xScale(d3.time.scale());
			ibhOzoneViewer.timelineChart.lines2.scatter.xScale(d3.time.scale());
			ibhOzoneViewer.timelineChart.lines.isArea(function(d, i) { return i%line_data.length < 6 });
			ibhOzoneViewer.timelineChart.lines2.isArea(function(d, i) { return i%line_data.length < 6 });

			ibhOzoneViewer.timelineChart.xAxis.scale(d3.time.scale())
				.tickFormat(customTimeFormat);
			
			ibhOzoneViewer.timelineChart.x2Axis.scale(d3.time.scale())
				.tickFormat(customTimeFormat);

			ibhOzoneViewer.timelineChart.yAxis
				.tickFormat(d3.format(',f'));
			
			ibhOzoneViewer.timelineChart.y2Axis
				.tickFormat(d3.format(',f'));

			d3.csv(timeline_data_src, function(error, data) {
				data.forEach(function(d) {
					var date = new Date(+d.epoch*1000);
					var coeff = (parseInt(d.maximum)-parseInt(d.minimum))/parseInt(d.total);
					var good = parseInt(d.good)*coeff+parseInt(d.minimum);
					var moderate = parseInt(d.moderate)*coeff+good;
					var warning = parseInt(d.warning)*coeff+moderate;
					var unhealthy = parseInt(d.unhealthy)*coeff+warning;
					var very = parseInt(d.very)*coeff+unhealthy;
					var hazardous = parseInt(d.hazardous)*coeff+very;
					line_data[0]["values"].push({x: date, y: very, y0: hazardous});
					line_data[1]["values"].push({x: date, y: unhealthy, y0: very});
					line_data[2]["values"].push({x: date, y: warning, y0: unhealthy});
					line_data[3]["values"].push({x: date, y: moderate, y0: warning});
					line_data[4]["values"].push({x: date, y: good, y0: moderate});
					line_data[5]["values"].push({x: date, y: +d.minimum, y0: good });
					line_data[6]["values"].push({x: date, y: +d.average, y0: +d.average, max: +d.maximum, min: +d.minimum });
					// line_data[7]["values"].push({x: date, y: +d.maximum, y0: +d.maximum });
					// line_data[8]["values"].push({x: date, y: +d.minimum, y0: +d.minimum });
				});
				d3.select('#timeline-wrapper').append("svg")
					.datum(line_data)
					.transition().duration(500)
					.call(ibhOzoneViewer.timelineChart);
		
				ibhOzoneViewer.timelineChart.customOnBrush(function() {
					var extent = ibhOzoneViewer.timelineChart.brush.extent();
					if(!ibhOzoneViewer.timelineChart.brush.empty()) {													
						var brushstarttime = Math.floor(+extent[0]/1000);
						var brushendtime = Math.floor(+extent[1]/1000);
						var map = $(ibhOzoneViewer.gMap).gmap3('get');
						var z = map.getZoom();
						var center = map.getCenter();
						var latlng = center.toString();
						latlng = latlng.replace(/\s|\(|\)/g,''); 
						$.address.value('/snapshot?t1=' + brushstarttime + '&t2=' + brushendtime + '&z=' + z + '&latlng=' + latlng);	
						verticalPosition(brushstarttime);
						ibhOzoneViewer.contourAjaxCalls.forEach(function(contour_timestamp) {
							if (contour_timestamp < brushstarttime || contour_timestamp > brushendtime) {
								ibhOzoneViewer.contourAjaxCalls[contour_timestamp].abort();
								ibhOzoneViewer.contourAjaxCalls.splice(contour_timestamp,1);
							}
						});
					}      
				});
				
				ibhOzoneViewer.timelineChart.customOnBrushData(function(d) {
					ibhOzoneViewer.loadContours(ibhOzoneViewer.contourURL, +d.epoch, { type: 'jsonp', timestamp: +d.epoch, bandschema: ibhOzoneViewer.bandSchema });
				});
				
				var vertical_focus = d3.select('#timeline-wrapper')
			  	.append("div")
			  	.attr("class", "vertical")
			  	.style("position", "absolute")
			  	.style("z-index", "1")
			  	.style("width", "1px")
			  	.style("height", "50px")
			  	.style("top", "20px")
			  	.style("left", "0px")
			  	.style("background", "#fff");

				var vertical_context = d3.select('#timeline-wrapper')
					.append("div")
					.attr("class", "vertical")
					.style("position", "absolute")
					.style("z-index", "1")
					.style("width", "1px")
					.style("height", "20px")
					.style("bottom", "20px")
					.style("left", "0px")
					.style("background", "#fff");
			    
				var verticalPosition = function(timestamp) {
					ibhOzoneViewer.nextContourTS = timestamp;
					ibhOzoneViewer.updateContourAnim(true);	
				 	var focusx = ibhOzoneViewer.timelineChart.xAxis.scale()(+timestamp*1000) + 40;
					var contextx = ibhOzoneViewer.timelineChart.x2Axis.scale()(+timestamp*1000) + 40;
				 	vertical_focus.style("left", focusx + "px");
					vertical_context.style("left", contextx + "px" );
				}
			
				ibhOzoneViewer.timelineChart.customTooltipEvent(verticalPosition);

				$('.nv-context').mouseenter(function() {
					d3.selectAll('.nvtooltip').remove();
				});
			});
			nv.utils.windowResize(ibhOzoneViewer.timelineChart.update);

			return ibhOzoneViewer.timelineChart;
		});
	}
};

Drupal.behaviors.ibhOzoneViewer = Drupal.behaviors.ibhOzoneViewer || {};

Drupal.behaviors.ibhOzoneViewer.attach = function (context) {
  $('body:not(.ozone-viewer-processed)', context).addClass('ozone-viewer-processed').each(function() {
    ibhOzoneViewer.initialize();
    return false; // Break the each loop.
  });
};

})(jQuery);
function count(array)
{
var c = 0;
for(i in array) // in returns key, not object
if(array[i] != undefined)
c++;

return c;

}
