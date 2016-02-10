(function ($) {
var moduleBase = 'sites/all/modules/ibh_smoking_viewer/';
var ibhSmokingViewer = {

  firstWindowLoad : true,
  firstPlay : true,
  isDeeplink : false,

  moduleBase : moduleBase,

  // displayMode 1 is load all drawn polygons into memory, then show/hide
  // displayMode 2 is JIT draw then destroy.
  displayMode : 1,

  baseApiUrl : '/',
  
  lowerBoundHour : 6,
  upperBoundHour : 22,
  defaultTimeSpan: 3600,
  
  inactiveUI : {opacity:0.25, cursor:'default'},
  activeUI : {opacity:1, cursor:'pointer'},
  scubberExpanded : false,

  searchContainer : null,
  searchToggle : null,
  searchAddress : null,
  searchButton : null,
  
  defaultSearchVal : "Search Houston Address",
  
  gradientIndex : [],
  centerLat: 29.76,
  centerLng: -95.36,

  gMap : null,
  deviceAgent : null,
  iPadiPhone : false,

  defaultZoomLevel : 10,
  zoomLevel : 10,

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

  GeoDataLayer: null,
  GeoDataLabels: null,

  GeoDataAjaxThread: null,

  infoWindow: new InfoBox({
	content: "",
	closeBoxURL:  moduleBase + "/images/x-white.png",
	enableEventPropagation: false,
	disableAutoPan: false,
	alignBottom: true,
	infoBoxClearance: new google.maps.Size(1, 1),
	pixelOffset: new google.maps.Size(-90, -12),
	pane: "floatPane"
  }),

  initialize : function() {
    
    this.displayMode = 2;

    this.gMap = $("#gMap");
    $('body').prepend("<div id='target'></div>");

    this.deviceAgent = navigator.userAgent.toLowerCase();
    this.iPadiPhone = this.deviceAgent.match(/(iphone|ipod|ipad)/);

    this.initTooltip();
    this.initTooltipRight();
    //this.initVerticalColorLegend();  
    this.initGMap();

    if (this.iPadiPhone) {
      this.initMobile();
    }
    else {
      this.initNonMobile();    
    }

    this.initColorGradient();
	this.initSearch();
    this.initAutocomplete();
    this.initLoadAnimation();
    this.initStage();
    this.initResize();
    this.initFooterToggles();
    this.initMapTypeAndZoom();
    this.initMobileOverrides();
    this.initHelp();
  },
  
  initMobile : function() {
    var html = '';
    $("#footer-ui").append(html);
  },

  initNonMobile : function() {
    var html = '';
    $("#footer-ui").append(html);
  },

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
    $('body').append('<div id="smoking-tooltip"><div id="smoking-tooltip-content"></div>');
    this.tooltip = $('#smoking-tooltip');
    this.tooltipContent = $('#smoking-tooltip-content');
  },
  
  initTooltipRight: function() {
    $('body').append('<div id="smoking-tooltip-right"><div id="smoking-tooltip-content-right"></div>');
    this.tooltipRight = $('#smoking-tooltip-right');
    this.tooltipContentRight = $('#smoking-tooltip-content-right');
  },
  
  initGMap : function() {	
    this.gMap.gmap3({
      action: 'init',
      options : {
        center:[ibhSmokingViewer.centerLat,ibhSmokingViewer.centerLng]
      },
      onces: {
        bounds_changed: function(){
          $(this).gmap3({
            action:'getBounds',
            callback: function () {
				ibhSmokingViewer.initGeoData();				
            }
          });
        }
      }
    },
    { 
      action: 'setOptions', args:[{
        zoom:ibhSmokingViewer.zoomLevel,
        scrollwheel:false,
        disableDefaultUI:true,
        disableDoubleClickZoom:false,
        draggable:true,
        mapTypeId:google.maps.MapTypeId.ROADMAP,
        mapTypeControl:false,
        mapTypeControlOptions: {
          style: google.maps.MapTypeControlStyle.DROPDOWN_MENU,
          position: google.maps.ControlPosition.LEFT_BOTTOM,
        }, 
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
        }
      }]
	});
  },

	initSearch : function() {
		this.searchButton = $("#searchButton");
		this.searchButton.bind("click", function() {
			ibhSmokingViewer.gMap.gmap3({
				action:'getAddress',
				address: ibhSmokingViewer.searchAddress.val() + "Houston, TX",
				callback:function(results){
					console.log("callback: ",results);
					if (!results) return;
					var map = ibhSmokingViewer.gMap.gmap3('get');
					var marker = new google.maps.Marker ({
						map: map, 
						position: results[0].geometry.location
					});
					map.setCenter(results[0].geometry.location);
					map.setZoom(13);
				}
			});
		});
	},

	initAutocomplete : function() {
		this.searchContainer = $('#searchInput');
		var t = this.defaultSearchVal;
		this.searchAddress = $("#address");
		this.searchAddress.val(t);
		$(this.searchAddress).bind('focus', function () {
			if ($(this).attr('value') == t) {
				$(this).attr('value', '');
			}
		});
		$(this.searchAddress).bind('blur', function () {
			if ($(this).attr('value') == '') {
				$(this).attr('value', t);
			}
		});
    
		this.searchAddress.autocomplete({
			position: { my: "left bottom", at: "left top", collision: "flip" },
			source: function( request, response ) {
				console.log(request, response);
				ibhSmokingViewer.gMap.gmap3({
					action:'getAddress',
					address: request.term + "Houston, TX",
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
				var map = ibhSmokingViewer.gMap.gmap3('get');
				latlng = ui.item.latlng;
				var marker = new google.maps.Marker ({
					map: map, 
					position: ui.item.latlng
				});
				map.setCenter(ui.item.latlng);
				map.setZoom(13);
			},
			autoFocus: true,
			appendTo: this.searchContainer
		});
	},
	
	initGeoData: function() {
		this.getGeoData();
		var map = this.gMap.gmap3('get');		
		google.maps.event.addListener(map, 'zoom_changed', function() {
			ibhSmokingViewer.expandGeoDataLayer();
			ibhSmokingViewer.redrawGeoDataLayer();
		});
		google.maps.event.addListener(map, 'bounds_changed', function() {
			//ibhSmokingViewer.redrawGeoDataLayer();
		});
		google.maps.event.addListener(map, 'dragend', function() {
			ibhSmokingViewer.expandGeoDataLayer();
			ibhSmokingViewer.redrawGeoDataLayer();
		});
	},
	
	expandGeoDataLayer: function() {
		var map = this.gMap.gmap3('get');
		var center = map.getCenter();
		center = center.lat() + "," + center.lng();
		var radius = map.getBounds().toSpan();
		radius = Math.max(radius.lat(),radius.lng())*.5;
		var prevdata = [];
		for (var i in ibhSmokingViewer.GeoDataLayer.shapes) {
			prevdata.push(ibhSmokingViewer.GeoDataLayer.shapes[i].prop["geo_id"]);
		} 
		prevdata = prevdata.join(",");
		if (this.GeoDataAjaxThread) 
			this.GeoDataAjaxThread.abort();
		this.GeoDataAjaxThread  = $.ajax({
			type: "GET",
			url: moduleBase + 'ajax/getGeoDataLayer.php',
			data: 'c=' + center + '&r=' + radius + '&d=' + prevdata,
			success: function(data) {			
				ibhSmokingViewer.GeoDataLayer.shapes = ibhSmokingViewer.GeoDataLayer.shapes.concat(GeoJSON({
					bounds: map.getBounds(),
					googleMap: map,
					JSONSrc: data,
					polygonOptionsCallback: function(props){
						return {
							fillColor: '#000000',
							strokeColor: '#000000',
							strokeWeight: 0.01,
							strokeOpacity: 0,
							fillOpacity: .3,
							zIndex: 10
						};
					},
					polygonEventsCallback: ibhSmokingViewer.initGeoDataLayerPolygonBindings,
					onError: function(index,message){
						alert('Error: ' + message);
					}
				}).shapes);
				ibhSmokingViewer.GeoDataLayer.hide();
				ibhSmokingViewer.updateGeoDataLayer();
				ibhSmokingViewer.redrawGeoDataLayer();
			}
		});
	},
	
	initGeoDataLabels: function(data) {
		console.log(data);
		this.GeoDataLabels = data;
		// this.GeoDataLabels = {
		// 	0: {label: "Unregulated", color: ""}, 
		// 	1: {label: "No Coverage", color: "#008000"}, 
		// 	2: {label: "Limited", color: "#FFFF00"}, 
		// 	3: {label: "Mixed", color: "#FFA500"}, 
		// 	4: {label: "Moderate", color: "#FF4500"}, 
		// 	5: {label: "100% Smoke Free", color: "#8B0000"}};
	},
	
	initSelect: function(data) {
		var selectElem = $("#select");
		selectElem.empty();
		$.each(data, function(key, value) {
			selectElem.append($("<option></option>")
		     .attr("value", key).text(value));
		});
	},
  
	getGeoData: function() {
		var map = this.gMap.gmap3('get');
		var center = map.getCenter();
		center = center.lat() + "," + center.lng();
		var radius = map.getBounds().toSpan();
		radius = Math.max(radius.lat(),radius.lng())*.5;
		$.get(moduleBase + 'ajax/getGeoDataLayer.php?c=' + center + '&r=' + radius, function(data) {			
			ibhSmokingViewer.initGeoDataLabels(data.labels);
			ibhSmokingViewer.initSelect(data.columns);
			ibhSmokingViewer.initGeoDataLayer(data.geojson);
			ibhSmokingViewer.updateGeoDataLayer();
			ibhSmokingViewer.redrawGeoDataLayer();
		});
	},
	
	updateGeoDataLayer: function() {
		var selectValue = $("#select").val();
		var numberOfShapes = this.GeoDataLayer.shapes.length;		
		for(var i = 0; i < numberOfShapes; i++) {
			var lengthOfThisShape = this.GeoDataLayer.shapes[i].shapes.length;
			for( var j = 0; j < lengthOfThisShape; j++ ) {
				var polygonValue = parseInt(this.GeoDataLayer.shapes[i].prop[selectValue]);
				polygonColor = this.GeoDataLabels[polygonValue].color;
				this.GeoDataLayer.shapes[i].shapes[j].fillColor = polygonColor;
				this.GeoDataLayer.shapes[i].shapes[j].strokeColor = polygonColor;
				this.GeoDataLayer.shapes[i].shapes[j].update();
			}
		}
	},
	
	redrawGeoDataLayer: function() {
		var numberOfShapes = this.GeoDataLayer.shapes.length;
		var map = this.gMap.gmap3('get');
		for(var i = 0; i < numberOfShapes; i++) {
			var shapeBounds = this.GeoDataLayer.shapes[i].getBounds();
			if(map.getBounds().intersects(shapeBounds))
				this.GeoDataLayer.shapes[i].show();
			else 
				this.GeoDataLayer.shapes[i].hide();
		}
	},
	
	initGeoDataLayerPolygonBindings: function(polygonpiece, index, styles, properties) {
		google.maps.event.addListener(polygonpiece,'mousemove', function(){
			polygonpiece.strokeWeight = 1;
			polygonpiece.fillOpacity = .5;
			polygonpiece.update();
		});
		google.maps.event.addListener(polygonpiece,'mouseout', function(){
			polygonpiece.strokeWeight = styles.strokeWeight;
			polygonpiece.fillOpacity = styles.fillOpacity;
			polygonpiece.update();
		});
		google.maps.event.addListener(polygonpiece,'click', function(e)
		{
			var selectValue = $("#select").val();
			var html = '<h3 style="border-top-color: ' + polygonpiece.fillColor + ';">' + properties["name"] + '</h3>' + '<p>' +  ibhSmokingViewer.GeoDataLabels[parseInt(properties[selectValue])].label + '</p>';
			
			//$("#tooltip").hide().html(html).css({top: e.Ra.clientY-60, left: e.Ra.clientX-75}).show();		
			ibhSmokingViewer.infoWindow.close();
			ibhSmokingViewer.infoWindow.setContent(html);		
			ibhSmokingViewer.infoWindow.setPosition(e.latLng);
			ibhSmokingViewer.infoWindow.open(ibhSmokingViewer.gMap.gmap3('get'));
		});
	},
	
	initGeoDataLayer: function(json_data) {
		var map = this.gMap.gmap3('get');
		$("#select").bind("change", function() { 
			ibhSmokingViewer.infoWindow.close();
			ibhSmokingViewer.updateGeoDataLayer(); 
		});
		this.GeoDataLayer = GeoJSON({
			bounds: map.getBounds(),
			googleMap: map,
			JSONSrc: json_data,
			polygonOptionsCallback: function(props){
				// default styling for the polygons
				return {
					fillColor: '#000000',
					strokeColor: '#000000',
					strokeWeight: 0.01,
					strokeOpacity: 0,
					fillOpacity: .3,
					zIndex: 10
				};
			},
			polygonEventsCallback: ibhSmokingViewer.initGeoDataLayerPolygonBindings,
			onError: function(index,message){
				alert('Error: ' + message);
			}
		});
		this.GeoDataLayer.hide();
	},
	
  getSmokingInfo: function(smokingLevel){
    
    if (smokingLevel == -1) {
      return this.aqiIndexNoReading;
    }
  
    var r = null;
    for (x in ibhSmokingViewer.aqiIndex) {
      if (Number(smokingLevel) >= x){
        r = ibhSmokingViewer.aqiIndex[x];
      }
      else {
        break;
      }
    }
    return r;
  },

  
  initLoadAnimation : function() {
    $(window).load(function(){
      ibhSmokingViewer.firstWindowLoad = false;
      $('#loading').fadeOut(500);
	});  
  },
 
  initStage : function() {
	this.mainBox = $('#main');
	this.pageBox = $(".pageContent"); 
	
	//CLOSE MAIN DIV
	$("#closeBox").live('click', function(){
	  ibhSmokingViewer.mainBox.fadeOut(400);
	  ibhSmokingViewer.pageBox.animate({top:"0px"},600);
	  return false;
    });
    
    //OPEN MAIN DIV
    this.pageBox.live('click', function(){
      $(this).animate({top:"40px"},600);
      ibhSmokingViewer.mainBox.fadeIn(400);
      return false;
    });  
  },


  initFooterToggles : function() {
    
    var sidebarToggle = $('.sidebarToggle');
    var sidebar = $('#sidebar');
  
    sidebarToggle.click(function(){
      sidebar.slideToggle(400);
      sidebarToggle.toggleClass('open');
      return false;
    });

    this.searchToggle = $('.searchToggle');
    this.searchWrapper = $('#searchGMap-wrapper');
    
    this.searchToggle.click(function(){
      ibhSmokingViewer.searchWrapper.slideToggle(400);
      ibhSmokingViewer.searchToggle.toggleClass('open');
      return false;
    });
  },
  
  
  initResize: function() {
	this.containerHeight = $(window).height() - 42;
	this.gMap.css({height:this.containerHeight, width:"100%"});
	this.marker = $('.marker');
	$(window).resize(function() {
	  ibhSmokingViewer.containerHeight = $(window).height() - 42;
	  ibhSmokingViewer.gMap.css({height:ibhSmokingViewer.containerHeight});
	});  
  },

  legendLabelReset: function() {
    clearTimeout(this.legendLabelTimeout);
    ibhSmokingViewer.legendLabelInit();
  },

  legendLabelInit: function() {
    ibhSmokingViewer.legendLabelTimeout = setTimeout(function() { ibhSmokingViewer.legendLabelHide(); }, ibhSmokingViewer.legendLabelHideSpeed);
  },
  
  reset: function() {
      // markers are placed through gmap3.
      this.gMap.gmap3({action:'clear'});
    
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
  },

  initMapTypeAndZoom: function() { 

    var map = this.gMap.gmap3("get");
    
    var controlDiv = document.createElement('div');
    controlDiv.style.index = -5000;
    map.controls[google.maps.ControlPosition.TOP_LEFT].push(controlDiv);    
    
    var html = '';
    html += '<div id="mapTypeContainer"><div id="mapTypeContainerInner">';
    html += '<div id="mapType" title="Map Type" class="satellite"></div>';
    html += '</div></div>';

    $(controlDiv).append(html);

    this.mapstyle = $("#mapStyle");
    this.mapstylecontainer = $("#mapStyleContainer");

    $(".roadmap").live('click',function(){
      ibhSmokingViewer.gMap.gmap3({action: 'setOptions', args:[{mapTypeId:'roadmap'}]},
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
      ibhSmokingViewer.mapstyle.toggleClass('satellite');
    });
    $(".satellite").live('click',function(){
      ibhSmokingViewer.gMap.gmap3({action: 'setOptions', args:[{mapTypeId:'hybrid'}]}); //hybrid, satellite, roadmap, terrain
      $(this).removeClass('satellite').addClass('roadmap');
      ibhSmokingViewer.mapstyle.toggleClass('satellite');
    });
  },

  initMobileOverrides: function() {

    if (this.iPadiPhone) {
      function windowSizes(){
        var headerHeight = $("#header").height(),
        headerSpacing = headerHeight + 35,
        windowHeight = $(window).height(),
        footerSpacing = 75,
        mainHeight = windowHeight - headerSpacing - footerSpacing - 40;
        if(ibhSmokingViewer.mainBox.outerHeight() > mainHeight) {
          ibhSmokingViewer.mainBox.css({height:mainHeight,overflow:"auto"});
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
      max: ibhSmokingViewer.maxAqiIndex,
      value: 10,
      animate: true,
      change: function( event, ui ) {
      //  $( "#amount" ).val( ui.value );
        ibhSmokingViewer.skipOneContourAnim();
        var data = ibhSmokingViewer.getSmokingInfo(ui.value);
        if (ibhSmokingViewer.colorLegendLabel) {
          var ts = ibhSmokingViewer.animSlider.slider("value");
          var time = ibhSmokingViewer.convertTimestamp(ts, true);
          var html = '';
          html += '<div class="number">' + ui.value + '</div>';
          html += '<div class="desc">' + data.title.toUpperCase() + '<br /><span class="time">Range: ' + data.span + '</span>';
          html += '<br /><span class="time">Updated: ' + time + '</span></div>';          
          ibhSmokingViewer.colorLegendHtml.html('<div>' + html + '</div>');
          ibhSmokingViewer.colorLegendLabel.css({borderRight:'8px solid #' + data.color});
          
          ibhSmokingViewer.colorLegendHandle.show();
          
          ibhSmokingViewer.legendLabelReset();
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
  
  initHelp: function() {
    this.help1 = $('#help-1');
    $('#help-info').hover(
      function(){
        var offset = $(this).offset();
        var top = offset.top + 5;
        var left = offset.left - 188;
        //var left = offset.left - 50;
        ibhSmokingViewer.tooltipContentRight.html('<div>Show Air Quality Index chart</div>');
        ibhSmokingViewer.tooltipRight.css({top:top,left:left}).show();
      },
      function() {
        ibhSmokingViewer.tooltipRight.hide();    
      }
    );
    $('#help-info').click(function(){
      if (ibhSmokingViewer.appAlert) {
        if ($(ibhSmokingViewer.appAlert).dialog( "isOpen" )) {
          $(ibhSmokingViewer.appAlert).dialog("close");
        }
        else {
          ibhSmokingViewer.showHelp1();        
        }   
      }
      else {
        ibhSmokingViewer.showHelp1();        
      }
    });
  
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

    var smokingDataInfo = this.getSmokingInfo(labels[lbl]['max']);
    var opacity = smokingDataInfo.opacity;

     // Color by span.
//     var strokeColor = '#' + smokingDataInfo.color;
//     var fillColor = '#' + smokingDataInfo.color;
    
    // Color by gradient.
    
    var strokeColor = '#' + ibhSmokingViewer.gradientIndex[labels[lbl]['max']];
    var fillColor = '#' + ibhSmokingViewer.gradientIndex[labels[lbl]['max']];

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
      ibhSmokingViewer.skipOneContourAnim();
      ibhSmokingViewer.colorLegend.slider('value', middle);
    });
    
    if (!this.firstWindowLoad && ibhSmokingViewer.displayMode != 2) {
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
 
    var smokingDataInfo = this.getSmokingInfo(labels[lbl]['max']);
    var opacity = smokingDataInfo.opacity;
    
     // Color by span.
//     var strokeColor = '#' + smokingDataInfo.color;
//     var fillColor = '#' + smokingDataInfo.color;
    
    // Color by gradient.
    
    var strokeColor = '#' + ibhSmokingViewer.gradientIndex[labels[lbl]['max']];
    var fillColor = '#' + ibhSmokingViewer.gradientIndex[labels[lbl]['max']];

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
      ibhSmokingViewer.skipOneContourAnim();
      ibhSmokingViewer.colorLegend.slider('value', middle);
    });
    
    if (!this.firstWindowLoad && ibhSmokingViewer.displayMode != 2) {
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
  }
};

Drupal.behaviors.ibhSmokingViewer = Drupal.behaviors.ibhSmokingViewer || {};

Drupal.behaviors.ibhSmokingViewer.attach = function (context) {
  $('body:not(.smoking-viewer-processed)', context).addClass('smoking-viewer-processed').each(function() {
    ibhSmokingViewer.initialize();
    return false; // Break the each loop.
  });
};

})(jQuery);
function count(array) {
	var c = 0;
	for (i in array)
		if (array[i] != undefined)
			c++;
	return c;
}
