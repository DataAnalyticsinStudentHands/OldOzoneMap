(function ($) {
var moduleBase = 'sites/all/modules/ibh_epidemiology_viewer/';
var ibhEpidemiologyViewer = {

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

  GridDataSettings: {
	//center: [29.7,-95.29]
	latmin: 28.93, 
	latmax: 30.47, 
	longmin: -95.91, 
	longmax: -94.67, 
	stepsize: 0.01
  },

  GridDataLayers: [],
  GridOverlay: null,

  fileReader: null,

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

	this.initMenu();
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

  initColorGradient: function(labels) {  
    var start = false;
    var startX = 0;
    var endX = 0;
	this.gradientIndex = [];
    for(x in labels) {
      if (!start){
        start = labels[x].color.replace(/#/g,"");
        startX = x;
      }
      else {
        end = labels[x].color.replace(/#/g,"");
        endX = x;
        
        $.extend(this.gradientIndex, this.getGradient(start, end, startX, endX));
        start = end;
        startX = endX;
      }
    }
    this.gradientIndex[this.gradientIndex.length] = this.gradientIndex[this.gradientIndex.length-1];
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
    $('body').append('<div id="epidemiology-tooltip"><div id="epidemiology-tooltip-content"></div>');
    this.tooltip = $('#epidemiology-tooltip');
    this.tooltipContent = $('#epidemiology-tooltip-content');
  },
  
  initTooltipRight: function() {
    $('body').append('<div id="epidemiology-tooltip-right"><div id="epidemiology-tooltip-content-right"></div>');
    this.tooltipRight = $('#epidemiology-tooltip-right');
    this.tooltipContentRight = $('#epidemiology-tooltip-content-right');
  },
  
  initGMap : function() {	
    this.gMap.gmap3({
      action: 'init',
      options : {
        center:[ibhEpidemiologyViewer.centerLat,ibhEpidemiologyViewer.centerLng]
      },
      onces: {
        bounds_changed: function(){
          $(this).gmap3({
            action:'getBounds',
            callback: function () {
				ibhEpidemiologyViewer.initGeoData();				
            }
          });
        }
      }
    },
    { 
      action: 'setOptions', args:[{
        zoom:ibhEpidemiologyViewer.zoomLevel,
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
			ibhEpidemiologyViewer.gMap.gmap3({
				action:'getAddress',
				address: ibhEpidemiologyViewer.searchAddress.val() + "Houston, TX",
				callback:function(results){
					if (!results) return;
					var map = ibhEpidemiologyViewer.gMap.gmap3('get');
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
				ibhEpidemiologyViewer.gMap.gmap3({
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
				var map = ibhEpidemiologyViewer.gMap.gmap3('get');
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
	
	initGridData: function() {
		$("#interpolate").unbind("click").bind("click", function() {
			ibhEpidemiologyViewer.addGridDataLayer();
		});
		// $("#layers button").unbind("click").bind("click", function() {
		// 	ibhEpidemiologyViewer.overlayGridDataLayers($(this).attr("id"));
		// });
		$("#upload").unbind("click").bind("click", function() {
			ibhEpidemiologyViewer.abortUpload();
			$("#uploadfile input[type=file]").val('');
			$("#uploadfile input[type=submit]").attr('disabled','disabled');
			$("#uploadfile").css({height: 200, marginTop: -100});
			$(".popupmenu").hide();
			$("#fileprefs").hide();
			$("#uploadfile").show();
		});
		$("#uploadfile input[type=file]").unbind("change").bind("change", function(evt) {
			ibhEpidemiologyViewer.abortUpload();
			ibhEpidemiologyViewer.uploadFileHandler(evt);			
			$("#fileprefs").fadeOut();
		});
		// $("#uploadfile input[type=submit]").unbind("click").bind("click", function() {
		// 	ibhEpidemiologyViewer.processGeoDataUpload();
		// });
		// $("#fileprefs input[type=submit]").unbind("click").bind("click", function() {
		// 	ibhEpidemiologyViewer.processGeoDataUpload();
		// });
		$("#uploadfile button").unbind("click").bind("click", function() {
			$("#uploadfile").hide();
			ibhEpidemiologyViewer.abortUpload();
		});
		// $("#fileprefs button").unbind("click").bind("click", function() {
		// 	$("#fileprefs").hide();
		// });
		$("#layers :radio").unbind("change").bind("change", function() {
			ibhEpidemiologyViewer.overlayGridDataLayers();
		});
	},
	
	getLittleEndianHex: function(value) {
	  var result = [];   
	  for (var bytes = 4; bytes > 0; bytes--) {
	    result.push(String.fromCharCode(value & 255));
	    value >>= 8;
	  }
	  return result.join('');
	},
	
	generateGridDataImage: function(width, height, imgdata) {
		//http://www.worldwidewhat.net/2012/07/how-to-draw-bitmaps-using-javascript/
		var numFileBytes = this.getLittleEndianHex(width * height);
		var w = this.getLittleEndianHex(width);
		var h = this.getLittleEndianHex(height);
		
		var header =
		    'BM' +                    // Signature
		    numFileBytes +            // size of the file (bytes)*
		    '\x00\x00' +              // reserved
		    '\x00\x00' +              // reserved
		    '\x36\x00\x00\x00' +      // offset of where BMP data lives (54 bytes)
		    '\x28\x00\x00\x00' +      // number of remaining bytes in header from here (40 bytes)
		    w +                       // the width of the bitmap in pixels*
		    h +                       // the height of the bitmap in pixels*
		    '\x01\x00' +              // the number of color planes (1)
		    '\x20\x00' +              // 32 bits / pixel
		    '\x00\x00\x00\x00' +      // No compression (0)
		    '\x00\x00\x00\x00' +      // size of the BMP data (bytes)*
		    '\x13\x0B\x00\x00' +      // 2835 pixels/meter - horizontal resolution
		    '\x13\x0B\x00\x00' +      // 2835 pixels/meter - the vertical resolution
		    '\x00\x00\x00\x00' +      // Number of colors in the palette (keep 0 for 32-bit)
		    '\x00\x00\x00\x00';       // 0 important colors (means all colors are important)
		
		var datauri = 'data:image/bmp;base64,';
		if(window.btoa != undefined) {
		  datauri += btoa(header + imgdata);
		}
		else {
		  datauri += $.base64.encode(header + imgdata);
		}
		
		return datauri;
	},
	
	convertGeoDataLayerToQuadtree: function() {
		var newQuadtree = [];
		var numlevels = 4;
		var latspan = this.GridDataSettings.latmax - this.GridDataSettings.latmin;
		var longspan = this.GridDataSettings.longmax - this.GridDataSettings.longmin;
		var aggdata = $("#menuArea select#menu option:selected").data("aggregate") == 1;
		
		for (var k = 0; k < numlevels; k++) {
			newQuadtree[k] = [];			
		}
		for (var i = 0; i < this.GeoDataLayer.shapes.length; i++) {
			for (var j = 0; j < this.GeoDataLayer.shapes[i].markers.length; j++) {
				var marker_val = parseFloat(this.GeoDataLayer.shapes[i].prop[selectValue]);
				var marker_lat = this.GeoDataLayer.shapes[i].markers[j].lat() - this.GridDataSettings.latmin;
				var marker_lng = this.GeoDataLayer.shapes[i].markers[j].lng() - this.GridDataSettings.longmin;
				for (var k = 0; k < numlevels; k++) {
					var pow2 = Math.pow(2,k);
					var lat_ind = marker_lat*pow2/latspan;
					var lng_ind = marker_lng*pow2/longspan;
					if (aggdata) {
						newQuadtree[k][Math.floor(lat_ind) + pow2*Math.floor(lng_ind)]++;
					}
					else {
						//need to implement interpolation here
						newQuadtree[k][Math.floor(lat_ind) + pow2*Math.floor(lng_ind)]+=marker_val;
					}
				}
			}
		}		
	},
	
	interpolateQuadtreeToGrid: function(quadTree) {
		var newGrid = [];
		var total = 0;
		var sq_total = 0;
		var count = 0;
		var halfstep = this.GridDataSettings.stepsize*.5;
		var latspan = this.GridDataSettings.latmax - this.GridDataSettings.latmin;
		var longspan = this.GridDataSettings.longmax - this.GridDataSettings.longmin;
		
		var selectValue = $("#selectArea select#data").is(":visible") ? $("#selectArea select#data").val() : "count";
		
		for (var lat = this.GridDataSettings.latmin+halfstep; lat < this.GridDataSettings.latmax; lat+=this.GridDataSettings.stepsize) {		
			var newRow = [];
			for (var lng = this.GridDataSettings.longmin+halfstep; lng < this.GridDataSettings.longmax; lng+=this.GridDataSettings.stepsize) {
				var val_sum = 0;
				var inv_sq_dist_sum = 0;
				var cell_lat = this.GeoDataLayer.shapes[i].markers[j].lat() - this.GridDataSettings.latmin;
				var cell_lng = this.GeoDataLayer.shapes[i].markers[j].lng() - this.GridDataSettings.longmin;
				for (var k = 0; k < quadTree.length; k++) {
					var pow2 = Math.pow(2,k);
					var lat_ind = Math.floor(cell_lat*pow2/latspan);
					var lng_ind = Math.floor(cell_lng*pow2/longspan);
					for (var i = 0; i < lat_ind; i ++) {
						for (var j = 0; j < lng_ind; j++) {
							
						}
						for (var j = lng_ind + 1; j < pow2; j++) {
							
						}
					}
					for (var i = lat_ind + 1; i < pow2; i++) {
						for (var j = 0; j < lng_ind; j++) {
							
						}
						for (var j = lng_ind + 1; j < pow2; j++) {
							
						}
					}
					var sq_distance = Math.pow((this.GeoDataLayer.shapes[i].markers[j].lat()-lat),2)+Math.pow((this.GeoDataLayer.shapes[i].markers[j].lng()-lng),2);
					var inv_sq_distance = 1/sq_distance;
					inv_sq_dist_sum += inv_sq_distance;
					val_sum += parseFloat(this.GeoDataLayer.shapes[i].prop[selectValue])*inv_sq_distance;
				}
				var value;
				value = val_sum/inv_sq_dist_sum;
				count++;
				newRow.push(value);
				total+=value;
				sq_total+=value*value;
			}	
			newGrid.unshift(newRow);		
		}
		var mean = total/count;
		//http://www.strchr.com/standard_deviation_in_one_pass
		var stdev = Math.sqrt(sq_total/count - mean*mean);
		return {stdev: stdev, mean: mean, grid: newGrid};
	},
	
	interpolateGeoDataLayerToGrid: function() {
		var newGrid = [];
		var total = 0;
		var sq_total = 0;
		var count = 0;
		var halfstep = this.GridDataSettings.stepsize*.5;
		//var gridSqRadius = (Math.pow(this.GridDataSettings.latmax-this.GridDataSettings.latmin,2) + Math.pow(this.GridDataSettings.longmax-this.GridDataSettings.longmin,2));
		var gridSqRadius = Math.pow(30*halfstep,2);
		
		var selectValue = $("#selectArea select#data").is(":visible") ? $("#selectArea select#data").val() : "count";
		
		var aggdata = ($("#menuArea select#menu option:selected").data("aggregate") == 1);
		console.log(selectValue, aggdata);

		// for (var i = 0; i < this.GeoDataLayer.shapes.length; i++) {
		// 	for (var j = 0; j < this.GeoDataLayer.shapes[i].markers.length; j++) {
		// 		console.log(this.GeoDataLayer.shapes[i].markers[j].lat() + " " + this.GeoDataLayer.shapes[i].markers[j].lng());
		// 	}
		// }
		
		for (var lat = this.GridDataSettings.latmin+halfstep; lat < this.GridDataSettings.latmax; lat+=this.GridDataSettings.stepsize) {		
			var newRow = [];
			for (var lng = this.GridDataSettings.longmin+halfstep; lng < this.GridDataSettings.longmax; lng+=this.GridDataSettings.stepsize) {
				var val_sum = 0;
				var inv_sq_dist_sum = 0;
				var neg_exp_sum = 0;
				var quartic_sum = 0;
				// for (var i = 0; i < this.GeoDataLayer.shapes.length; i++) {
				// 	var distance = 1/Math.sqrt(Math.pow((this.GeoDataLayer.shapes[i].markers[0].lat()-(lat+halfstep)),2)+Math.pow((this.GeoDataLayer.shapes[i].markers[0].lng()-(lng+halfstep)),2));
				// 	val_sum += parseInt(this.GeoDataLayer.shapes[i].prop[selectValue])*distance;
				// 	dist_sum += distance;
				// }	
				for (var i in this.GeoDataLayer.shapes) {
					for (var j in this.GeoDataLayer.shapes[i].markers) {
						var sq_distance = (Math.pow((this.GeoDataLayer.shapes[i].markers[j].lat()-lat),2)+Math.pow((this.GeoDataLayer.shapes[i].markers[j].lng()-lng),2));
						var inv_sq_distance = 1/sq_distance;
						inv_sq_dist_sum += inv_sq_distance;
						neg_exp_sum += Math.exp(-this.GeoDataLayer.shapes.length*Math.sqrt(sq_distance));
						//quartic_sum += parseFloat(this.GeoDataLayer.shapes[i].prop[selectValue])*(3/(gridSqRadius*Math.PI))*Math.pow(1-Math.min(sq_distance/gridSqRadius,1),2);
						quartic_sum += parseFloat(this.GeoDataLayer.shapes[i].prop[selectValue])*Math.pow(1-Math.min(sq_distance/gridSqRadius,1),2);
						val_sum += parseFloat(this.GeoDataLayer.shapes[i].prop[selectValue])*inv_sq_distance;
					}
				}
				var value;
				if (aggdata) {
					value = neg_exp_sum;
					//value = inv_sq_dist_sum;
				}
				else {
					value = val_sum/(inv_sq_dist_sum > 0 ? inv_sq_dist_sum : 1);
				}	
				count++;
				newRow.push(value);
				total+=value;
				sq_total+=value*value;
			}	
			newGrid.unshift(newRow);		
		}
		var mean = total/count;
		//http://www.strchr.com/standard_deviation_in_one_pass
		var stdev = Math.sqrt(sq_total/count - mean*mean);
		return {stdev: stdev, mean: mean, grid: newGrid};
	},
	
	addGridDataLayer: function() {	
		if (this.GeoDataLayer) {
			$('#loading').show();
		
			var interpolation = this.interpolateGeoDataLayerToGrid();	
		
			console.log(interpolation);
		
			var imgdata = "";
		
			for (var row=interpolation.grid.length-1; row >= 0; row--) {
				for (var col=0; col<interpolation.grid[row].length; col++) {
					var value = Math.min(255,Math.max(0,Math.floor(128 + 32*(interpolation.grid[row][col]-interpolation.mean)/interpolation.stdev)));
					//linear gradient from blue to red
					/*
					imgdata += String.fromCharCode(255-value, 0, value, 128);
					*/
					
					//linear gradient from blue to green to red
					imgdata += String.fromCharCode((value >= 127.5) ? 0 : Math.abs(127.5-value)*2, Math.floor(255-Math.abs(127.5-value)*2), (value >= 127.5) ? Math.abs(127.5-value)*2 : 0, 128);
					
					//no-gradient color
					/*
					if (value < 64)
						imgdata += String.fromCharCode(255, 0, 0, 128);
					else if (value > 192)
						imgdata += String.fromCharCode(0, 0, 255, 128);				
					else
						imgdata += String.fromCharCode(0, 255, 0, 128);
					*/
				}
			}
		
			var datauri = this.generateGridDataImage(interpolation.grid[0].length, interpolation.grid.length, imgdata);
		
			var map = this.gMap.gmap3('get');
		
			newOverlay = new google.maps.GroundOverlay(datauri,
			      new google.maps.LatLngBounds(
				      new google.maps.LatLng(this.GridDataSettings.latmin, this.GridDataSettings.longmin),
				      new google.maps.LatLng(this.GridDataSettings.latmax, this.GridDataSettings.longmax)
			));
		
		
			$("#layers_list input:checked").attr("checked",0);
			var label = $("#menu option:selected").text();
			label += "<table>";
			$("#selectArea select").each(function() {
				label += "<tr><td>" + $(this).prev("label").text() + "</td><td>" + $(this).find("option:selected").text() + "</td></tr>";
			});
			label += "</table>";
			var lyr_index = this.GridDataLayers.length;
			var thumbnail = $("<img />").attr("src", datauri);
			var checkbox = $("<input type='checkbox' name='layers_menu' checked/>")
				.attr("value", lyr_index)
				.unbind("change").bind("change", function() {
					ibhEpidemiologyViewer.overlayGridDataLayers();
				});
			var spanelem = $("<span></span>").append(checkbox).append(label);
			//var labelelem = $("<label class='weight_lyr" + lyr_index + "' for='points'>100%</label>");
			var sliderelem = $("<input type='range' class='weight_lyr" + lyr_index + "' min='0' max='1' step='0.01' value='1'>")
				.unbind("mouseup").bind("mouseup", function() {
					ibhEpidemiologyViewer.overlayGridDataLayers();
				})
				.unbind("change").bind("change", function() {
					var val = sliderelem.val();
					$(thumbnail).css({opacity: val*.75 + .25});
				});;
			var listitem = $("<li></li>").append(thumbnail).append(spanelem).append("<br>").append(sliderelem);//.append(labelelem);
			$("#layers_list").append(listitem);
		
			this.GridDataLayers.push(interpolation);
		
			if (this.GeoDataLayer)
				this.GeoDataLayer.hide();
			if (this.GridOverlay)
				this.GridOverlay.setMap(null);
			this.GridOverlay = newOverlay;
			this.GridOverlay.setMap(map);
			$('#loading').fadeOut(500);	
		}
	},
	
	overlayGridDataLayers: function() {
		var method = $("#layers input:radio[name=overlay]:checked").val();
		if (this.GridDataLayers && this.GridDataLayers.length > 0) {
			$('#loading').show();
			var imgdata = "";
			for (var row=this.GridDataLayers[0].grid.length-1; row >= 0; row--) {
				for (var col=0; col<this.GridDataLayers[0].grid[row].length; col++) {
					//multi-channel representation
					if (method == "multichannel") {
						var colors = [];
						$("#layers_list input:checked").each(function () {
							var layer = $(this).val();
							var weight = parseFloat($("input.weight_lyr"+layer).val());
							value = Math.min(255,Math.max(0,weight*Math.floor(128 + 64*(ibhEpidemiologyViewer.GridDataLayers[layer].grid[row][col]-ibhEpidemiologyViewer.GridDataLayers[layer].mean)/ibhEpidemiologyViewer.GridDataLayers[layer].stdev)));
							// if (value < 64)
							// 	value = 0;
							// else if (value > 192)
							// 	value = 255;				
							// else
							// 	value = 128;
							colors.push(value);
						});
						imgdata += String.fromCharCode(
							colors[0] ? colors[0] : 0, 
							colors[1] ? colors[1] : 0,
							colors[2] ? colors[2] : 0, 
							128
						);
					}
					else if (method == "mean") {
						//var sq_total = 0;						
						var total = 0;
						var count = 0;
						var value = 0;
						$("#layers_list input:checked").each(function () {
							var layer = $(this).val();
							var weight = parseFloat($("input.weight_lyr"+layer).val());
							value = weight * (ibhEpidemiologyViewer.GridDataLayers[layer].grid[row][col]-ibhEpidemiologyViewer.GridDataLayers[layer].mean)/ibhEpidemiologyViewer.GridDataLayers[layer].stdev;
							total += value;
							//sq_total+=value*value;
							count += weight;
						});
						var mean = total/count;						
						// var stdev = Math.sqrt(Math.abs(sq_total/count - mean*mean));
						// if (method == "stdev")
						// 	value = Math.max(0,Math.min(255,Math.floor(stdev*64)));
						// else
						value = Math.min(255,Math.max(0,Math.floor(128 + 64*mean)));
						imgdata += String.fromCharCode((value >= 127.5) ? 0 : Math.abs(127.5-value)*2, Math.floor(255-Math.abs(127.5-value)*2), (value >= 127.5) ? Math.abs(127.5-value)*2 : 0, 128);
					}
					else {
						//difference map
						var layers = $("#layers_list li input:checked");
						var count = 0;
						var sq_diff = 0;
						for (lay1 = 0; lay1 < layers.length; lay1++) {
							var layer1 = $(layers[lay1]).val();
							var weight1 = parseFloat($("input.weight_lyr"+layer1).val());
							var value1 = weight1 * (ibhEpidemiologyViewer.GridDataLayers[layer1].grid[row][col]-ibhEpidemiologyViewer.GridDataLayers[layer1].mean)/ibhEpidemiologyViewer.GridDataLayers[layer1].stdev;				
							for (lay2 = lay1+1; lay2 < layers.length; lay2++) {
								var layer2 = $(layers[lay2]).val();
								var weight2 = parseFloat($("input.weight_lyr"+layer2).val());
								var value2 = weight2 * (ibhEpidemiologyViewer.GridDataLayers[layer2].grid[row][col]-ibhEpidemiologyViewer.GridDataLayers[layer2].mean)/ibhEpidemiologyViewer.GridDataLayers[layer2].stdev;
								sq_diff += Math.pow(value2-value1,2);
								count++;
							}
							
						}
						var value = Math.max(0,Math.min(255,Math.floor(64*Math.sqrt(sq_diff)/count)));
						imgdata += String.fromCharCode((value >= 127.5) ? 0 : Math.abs(127.5-value)*2, Math.floor(255-Math.abs(127.5-value)*2), (value >= 127.5) ? Math.abs(127.5-value)*2 : 0, 128);
					}
				}
			}
			var datauri = this.generateGridDataImage(this.GridDataLayers[0].grid[0].length, this.GridDataLayers[0].grid.length, imgdata);

			var map = this.gMap.gmap3('get');

			newOverlay = new google.maps.GroundOverlay(datauri,
			      new google.maps.LatLngBounds(
				      new google.maps.LatLng(this.GridDataSettings.latmin, this.GridDataSettings.longmin),
				      new google.maps.LatLng(this.GridDataSettings.latmax, this.GridDataSettings.longmax)
			));

			if (this.GeoDataLayer)
				this.GeoDataLayer.hide();
			if (this.GridOverlay)
				this.GridOverlay.setMap(null);
			this.GridOverlay = newOverlay;
			this.GridOverlay.setMap(map);
			$('#loading').fadeOut(500);
		}
	},
	
	initGeoData: function() {
		this.initGridData();
		this.getGeoData();
		var map = this.gMap.gmap3('get');		
		google.maps.event.addListener(map, 'zoom_changed', function() {
			ibhEpidemiologyViewer.expandGeoDataLayer();
			ibhEpidemiologyViewer.redrawGeoDataLayer();
		});
		google.maps.event.addListener(map, 'bounds_changed', function() {
			//ibhEpidemiologyViewer.redrawGeoDataLayer();
		});
		google.maps.event.addListener(map, 'dragend', function() {
			ibhEpidemiologyViewer.expandGeoDataLayer();
			ibhEpidemiologyViewer.redrawGeoDataLayer();
		});
	},
	
	expandGeoDataLayer: function() {
		if ($("#menuArea select#menu option:selected").data("user") != 1 && this.GeoDataLayer.shapes && this.GeoDataLayer.shapes.length > 0) {
			if (this.GridOverlay)
				this.GridOverlay.setMap(null);
			var map = this.gMap.gmap3('get');
			var center = map.getCenter();
			center = center.lat() + "," + center.lng();
			var radius = map.getBounds().toSpan();
			radius = Math.max(radius.lat(),radius.lng())*.5;
			var select_vals = "&ds=" + $("#menuArea select").val();
			$("#selectArea select").not("#data").each(function() {
				select_vals += "&s_" + $(this).attr("id") + "=" + $(this).val();
			});			
			var prevdata = [];
			for (var i in ibhEpidemiologyViewer.GeoDataLayer.shapes) {
				prevdata.push(ibhEpidemiologyViewer.GeoDataLayer.shapes[i].prop["geo_field"]);
			} 
			prevdata = prevdata.join(",");
			if (this.GeoDataAjaxThread) 
				this.GeoDataAjaxThread.abort();			
			$('#loading').show();
			this.GeoDataAjaxThread  = $.ajax({
				type: "GET",
				url: moduleBase + 'ajax/getGeoDataLayer.php',
				data: 'c=' + center + '&r=' + radius + '&d=' + prevdata + select_vals,
				success: function(data) {	
					ibhEpidemiologyViewer.GeoDataLayer.shapes = ibhEpidemiologyViewer.GeoDataLayer.shapes.concat(GeoJSON({
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
						polygonEventsCallback: ibhEpidemiologyViewer.initGeoDataLayerPolygonBindings,
						onError: function(index,message){
							alert('Error: ' + message);
						}
					}).shapes);
					ibhEpidemiologyViewer.GeoDataLayer.hide();
					ibhEpidemiologyViewer.updateGeoDataLayer();
					ibhEpidemiologyViewer.redrawGeoDataLayer();
					$('#loading').fadeOut(500);
				}
			});		
		}
	},
	
	initGeoDataLabels: function(data) {
		this.GeoDataLabels = data;
		this.initColorGradient(data);
		// this.GeoDataLabels = {
		// 	0: {label: "Unregulated", color: ""}, 
		// 	1: {label: "No Coverage", color: "#008000"}, 
		// 	2: {label: "Limited", color: "#FFFF00"}, 
		// 	3: {label: "Mixed", color: "#FFA500"}, 
		// 	4: {label: "Moderate", color: "#FF4500"}, 
		// 	5: {label: "100% Smoke Free", color: "#8B0000"}};
	},
	
	initMenu: function() {
		$("#menuArea select").bind("change", function() { 
			ibhEpidemiologyViewer.GeoDataLayer.remove();
			$("#selectArea").empty();
			ibhEpidemiologyViewer.infoWindow.close();
			ibhEpidemiologyViewer.getGeoData(false); 
		});
	},
	
	initSelect: function(data) {
		var selectArea = $("#selectArea");
		selectArea.empty();
		$.each(data, function(key, value) {
			var selectElem = $("<select></select>").attr("id", key);
			$.each(value, function(key, value) {
				selectElem.append($("<option></option>")
			     .attr("value", key).text(value));
			});	
			selectArea.append("<label>" + (key.charAt(0).toUpperCase() + key.slice(1)).replace(/_/g," ") + ":</label> ");
			selectArea.append(selectElem);
		});
		$("#selectArea select#data").bind("change", function() { 
			ibhEpidemiologyViewer.infoWindow.close();
			ibhEpidemiologyViewer.updateGeoDataLayer(); 
			ibhEpidemiologyViewer.redrawGeoDataLayer();
		});
		$("#selectArea select").not("#data").bind("change", function() { 
			ibhEpidemiologyViewer.infoWindow.close();
			ibhEpidemiologyViewer.getGeoData(true); 
		});
	},
  
	getGeoData: function(noUpdateUI) {
		var map = this.gMap.gmap3('get');
		var center = map.getCenter();
		center = center.lat() + "," + center.lng();
		var radius = map.getBounds().toSpan();
		radius = Math.max(radius.lat(),radius.lng())*.5;
		var select_vals = "&ds=" + $("#menuArea select").val();
		$("#selectArea select").not("#data").each(function() {
			select_vals += "&s_" + $(this).attr("id") + "=" + $(this).val();
		});
		if (this.GeoDataAjaxThread) 
			this.GeoDataAjaxThread.abort();
		$('#loading').show();
		this.GeoDataAjaxThread = $.get(moduleBase + 'ajax/getGeoDataLayer.php?c=' + center + '&r=' + radius + select_vals, function(data) {			
			if (data.debug)
				console.log(data.debug);
			if (!noUpdateUI)
				ibhEpidemiologyViewer.initSelect(data.menus);
			ibhEpidemiologyViewer.initGeoDataLabels(data.labels);
			ibhEpidemiologyViewer.initGeoDataLayer(data.geojson);
			ibhEpidemiologyViewer.updateGeoDataLayer();
			ibhEpidemiologyViewer.redrawGeoDataLayer();
			$('#loading').fadeOut(500);
		});
	},
	
	updateGeoDataLayer: function() {
		if (this.GeoDataLayer.shapes) {
			console.log("updateGeoDataLayer");
			if (this.GridOverlay)
				this.GridOverlay.setMap(null);
			var selectValue = $("#selectArea select#data").is(":visible") ? $("#selectArea select#data").val() : "count";	
			
			for(var i in this.GeoDataLayer.shapes) {
				if (!this.GeoDataLayer.shapes[i].prop[selectValue]) {
					this.GeoDataLayer.shapes[i].prop[selectValue] = 0;
				}
				var polygonValue = this.GeoDataLayer.shapes[i].prop[selectValue];
				polygonColor = "#" + this.gradientIndex[polygonValue];
				for( var j in this.GeoDataLayer.shapes[i].shapes) {
					this.GeoDataLayer.shapes[i].shapes[j].fillColor = polygonColor;
					this.GeoDataLayer.shapes[i].shapes[j].strokeColor = polygonColor;
					this.GeoDataLayer.shapes[i].shapes[j].update();
				}
			}
		}
	},
	
	redrawGeoDataLayer: function() {
		if (this.GeoDataLayer.shapes) {
			if (this.GridOverlay)
				this.GridOverlay.setMap(null);
			var map = this.gMap.gmap3('get');
			for(var i in this.GeoDataLayer.shapes) {
				var shapeBounds = this.GeoDataLayer.shapes[i].getBounds();
				if(map.getBounds().intersects(shapeBounds))
					this.GeoDataLayer.shapes[i].show();
				else 
					this.GeoDataLayer.shapes[i].hide();
			}
		}
	},	
	
	uploadErrorHandler: function(evt) {
		switch(evt.target.error.code) {
	      case evt.target.error.NOT_FOUND_ERR:
	        alert('File Not Found!');
	        break;
	      case evt.target.error.NOT_READABLE_ERR:
	        alert('File is not readable');
	        break;
	      case evt.target.error.ABORT_ERR:
	        break; // noop
	      default:
	        alert('An error occurred reading this file.');
	    };
	},
	
	uploadFileHandler: function(evt) {
	    // Reset progress indicator on new file selection.
	    $("#upload_progress_bar .percent").css('width','0%');

	    this.fileReader = new FileReader();
	    this.fileReader.onerror = this.uploadErrorHandler;
	    this.fileReader.onprogress = this.uploadProgress;
	    this.fileReader.onabort = function(e) {
	      alert('File read cancelled');
	    };
	    this.fileReader.onloadstart = function(e) {
	      $("#upload_progress_bar").addClass('loading');
	    };
	    this.fileReader.onload = function(e) {
		  console.log(evt.target.files[0]);
	      // Ensure that the progress bar displays 100% at the end.
	      $("#upload_progress_bar .percent").css('width','100%');
	      $("#upload_progress_bar").removeClass("loading");
		  var fileName = ibhEpidemiologyViewer.toTitleCase(evt.target.files[0].name.replace(/\.[^/.]+$/, "").replace(/[_\-\.]/g, " "));
		  console.log(fileName);
		  $("#fileprefs input#title").val(fileName);
		  
		  var fileString = e.target.result;
		  ibhEpidemiologyViewer.configGeoDataUpload($.csv.toArrays(fileString));		
	    }

	    // Read in the image file as a binary string.
	    this.fileReader.readAsText(evt.target.files[0], "UTF-8");
	},
	
	uploadProgress: function(evt) {
		// evt is an ProgressEvent.
	    if (evt.lengthComputable) {
	      var percentLoaded = Math.round((evt.loaded / evt.total) * 100);
	      // Increase the progress bar length.
	      if (percentLoaded < 100) {
		    $("#upload_progress_bar .percent").css('width', percentLoaded + '%');
	      }
	    }
	},
	
	toTitleCase: function(str)
	{
		str += "";
	    return str.replace(/\w\S*/g, function(txt){return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});
	},
	
	abortUpload: function() {
		if (this.fileReader)
			this.fileReader.abort();
	},
	
	configGeoDataUpload: function(csv_arrays) {
		$("#fileprefs table").empty();
		$("#uploadfile input[type=submit]").removeAttr('disabled');
		for (var i = 0; i < csv_arrays[0].length; i++) {
			$("#fileprefs table").append("<tr><td>" + csv_arrays[0][i] + " <small style='float: right'><em>(" + (csv_arrays[1][i] != "" ? csv_arrays[1][i] : "empty") + ")</em></small></td><td><select id='csv_col_" + i + "' data-col_id=" + i + " data-col_name='" + csv_arrays[0][i] + "'> <option value=false>unused</option> <option value='data'>data value</option> <option value='pivot'>pivot</option> <option value='zipcode' " + (csv_arrays[0][i].match(/zip/i) ? "selected" : "") + ">zipcode</option> <option value='muni'>municipality</option> <option value='snbr'>superneighborhood</option> <option value='lat' " + (csv_arrays[0][i].match(/^lat/i) ? "selected" : "") + ">latitude</option> <option value='lng' " + (csv_arrays[0][i].match(/^l[o]*ng/i) ? "selected" : "") + ">longitude</option> <option value='latlng'>(lat,lng) point</option> <option value='lnglat'>(lng,lat) point</option> <option value='polygon'>polygon</option> </select></td></tr>");
		}
		$("#uploadfile input[type=submit]").unbind("click").bind("click", function() {
			ibhEpidemiologyViewer.processGeoDataUpload(csv_arrays);
		});
		$("#uploadfile").animate({height: 350, marginTop: -175}, 500);
		$("#fileprefs").fadeIn();
	},
	
	processGeoDataUpload: function(csv_arrays) {
		$("#uploadfile").hide();
		var fileprefs = [];
		fileprefs['data'] = [];
		fileprefs['pivots'] = [];
		var menus = {data: new Object};
		var menu_count = 0;
		$("#fileprefs select").each(function() {
			var col_id = parseInt($(this).data("col_id"));
			var col_name = $(this).data("col_name");
			var col_val = $(this).val()
			switch(col_val) {
				case 'data':
					var col_name_cleaned = col_name.toLowerCase().replace(/\s+/g,"_");
					fileprefs['data'][col_name_cleaned] = col_id;
					menus['data'][col_name_cleaned] = ibhEpidemiologyViewer.toTitleCase(col_name);
					menu_count++;
					break;
				case 'pivot':
					fileprefs['pivots'][col_name] = col_id;
					break;
				case 'lat':
					fileprefs['lat'] = col_id;
					break;
				case 'lng':
					fileprefs['lng'] = col_id;
					break;
				case 'zipcode':
					fileprefs['geo_table'] = col_val;
					fileprefs['geo_col'] = col_id;
					break;
			}
		});
		
		if (menu_count == 0) {
			menus = {};
		}
				
		var dataset = $("<option data-aggregate='" + ((fileprefs["lat"] && fileprefs["lng"] && menu_count == 0) ? 1 : 0) +  "' data-user='1'></option>");
		dataset.val($("#uploadfile input#title").val().toLowerCase());
		dataset.html($("#uploadfile input#title").val().toLowerCase());
		dataset.attr("selected","selected");
		$("#menuArea select#menu").append(dataset);
		ibhEpidemiologyViewer.initSelect(menus);
		
		if (fileprefs['geo_table']) {
			if (this.GeoDataAjaxThread) 
				this.GeoDataAjaxThread.abort();
			$('#loading').show();
			this.GeoDataAjaxThread = $.get(ibhEpidemiologyViewer.moduleBase + 'ajax/getGeoPolygons.php?gs=' + fileprefs['geo_table'], function(data) {			
				if (data.debug)
					console.log(data.debug);
				var max_count = 0;
				var max_data = 0;
				var labels = {"0": {"label": null, "color": "#00FF00"}};
				for (var i = 1; i < csv_arrays.length; i++) {
					//var props = {count: 1};
					// if (menu_count == 0) {
					// 	props["count"] = 1;
					// }
					if (data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]]) {
						if (fileprefs["lat"] && fileprefs["lng"]) {							
							var markercoords = [[csv_arrays[i][fileprefs['lng']], csv_arrays[i][fileprefs['lat']]]];
							data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]].geometry.markers.push(markercoords);
						}
						data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]].properties["count"]++;
						max_count = Math.max(max_count, data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]].properties["count"]);
						for (var col_name in fileprefs['data']) {
							var col_data = csv_arrays[i][fileprefs['data'][col_name]];
							col_data = +col_data ? +col_data : 0;
							data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]].properties[col_name] = (+data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]].properties[col_name] ? +data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]].properties[col_name] : 0) + col_data;
							max_data = Math.max(max_data, data.geojson.features[csv_arrays[i][fileprefs["geo_col"]]].properties[col_name]);
						}
					}
				}
				console.log("maximums for labeling", +max_count, +max_data);
				var half_max_label = Math.floor(Math.max(+max_data, +max_count) * .5);
				labels["" + half_max_label + ""] = {"label": null, "color": "#FFFF00"};
				labels["" + (3*half_max_label) + ""] = {"label": null, "color": "#FF0000"};
				ibhEpidemiologyViewer.initGeoDataLabels(labels);
			
				ibhEpidemiologyViewer.initGeoDataLayer(data.geojson);
				ibhEpidemiologyViewer.updateGeoDataLayer();
				ibhEpidemiologyViewer.redrawGeoDataLayer();
				$('#loading').fadeOut(500);
			});
		}
		else if (fileprefs["lat"] && fileprefs["lng"]) {
			var jsonobj = {
				type: 'FeatureCollection',
				features: []
			};
			for (var i = 1; i < csv_arrays.length; i++) {
				var row_lat = parseFloat(csv_arrays[i][fileprefs['lat']]);
				var row_lng = parseFloat(csv_arrays[i][fileprefs['lng']]);
				if (row_lng <= this.GridDataSettings.longmax && row_lng >= this.GridDataSettings.longmin && row_lat <= this.GridDataSettings.latmax && row_lat >= this.GridDataSettings.latmin) {
					var props = {count: 1};
					var markercoords = [[csv_arrays[i][fileprefs['lng']], csv_arrays[i][fileprefs['lat']]]];
					var polygoncoords = [];
					for (var col_name in fileprefs['data']) {
						props[col_name] = csv_arrays[i][fileprefs['data'][col_name]];
					}
					if (menu_count == 0) {
						props["count"] = 1;
					}
			
					jsonobj.features.push({
						type: 'Feature',
						properties: props,
						geometry: {
							type: 			'MultiPolygon',
							coordinates: 	polygoncoords,
							markers: 		markercoords
						}
					});
				}
			}
		
	//		ibhEpidemiologyViewer.initGeoDataLabels(data.labels);		
			console.log("csv, json:", csv_arrays.length, jsonobj.features.length);
			ibhEpidemiologyViewer.initGeoDataLayer(jsonobj);
			//ibhEpidemiologyViewer.addGridDataLayer();
		}
		else {
			alert("No geographical data found to map.");
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
			var selectValue = $("#selectArea select#data").is(":visible") ? $("#selectArea select#data").val() : "count";
			var html = '<h3 style="border-top-color: ' + polygonpiece.fillColor + ';">' + properties["geo_name"] + '</h3>' + '<p>' +  ((ibhEpidemiologyViewer.GeoDataLabels[parseInt(properties[selectValue])] && ibhEpidemiologyViewer.GeoDataLabels[parseInt(properties[selectValue])].label) ? ibhEpidemiologyViewer.GeoDataLabels[parseInt(properties[selectValue])].label : properties[selectValue]) + '</p>';		
			ibhEpidemiologyViewer.infoWindow.close();
			ibhEpidemiologyViewer.infoWindow.setContent(html);		
			ibhEpidemiologyViewer.infoWindow.setPosition(e.latLng);
			ibhEpidemiologyViewer.infoWindow.open(ibhEpidemiologyViewer.gMap.gmap3('get'));
		});
	},
	
	initGeoDataLayer: function(json_data) {
		var map = this.gMap.gmap3('get');
		if (ibhEpidemiologyViewer.GeoDataLayer)
			ibhEpidemiologyViewer.GeoDataLayer.remove();
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
			polygonEventsCallback: ibhEpidemiologyViewer.initGeoDataLayerPolygonBindings,
			onError: function(index,message){
				alert('Error: ' + message);
			}
		});
		this.GeoDataLayer.hide();
	},
	
  getEpidemiologyInfo: function(epidemiologyLevel){
    
    if (epidemiologyLevel == -1) {
      return this.aqiIndexNoReading;
    }
  
    var r = null;
    for (x in ibhEpidemiologyViewer.aqiIndex) {
      if (Number(epidemiologyLevel) >= x){
        r = ibhEpidemiologyViewer.aqiIndex[x];
      }
      else {
        break;
      }
    }
    return r;
  },

  
  initLoadAnimation : function() {
    $(window).load(function(){
      ibhEpidemiologyViewer.firstWindowLoad = false;
      $('#loading').fadeOut(500);
	});  
  },
 
  initStage : function() {
	this.mainBox = $('#main');
	this.pageBox = $(".pageContent"); 
	
	//CLOSE MAIN DIV
	$("#closeBox").live('click', function(){
	  ibhEpidemiologyViewer.mainBox.fadeOut(400);
	  ibhEpidemiologyViewer.pageBox.animate({top:"0px"},600);
	  return false;
    });
    
    //OPEN MAIN DIV
    this.pageBox.live('click', function(){
      $(this).animate({top:"40px"},600);
      ibhEpidemiologyViewer.mainBox.fadeIn(400);
      return false;
    });  
  },


  initFooterToggles : function() {
    
    var sidebarToggle = $('.sidebarToggle');
    var sidebar = $('#sidebar');

    var layersToggle = $('.layersToggle');
    var layers = $('#layers');
  
    sidebarToggle.click(function(){
      sidebar.slideToggle(400);
      sidebarToggle.toggleClass('open');
      return false;
    });

    layersToggle.click(function(){
      layers.slideToggle(400);
      layersToggle.toggleClass('open');
      return false;
    });

    this.searchToggle = $('.searchToggle');
    this.searchWrapper = $('#searchGMap-wrapper');
    
    this.searchToggle.click(function(){
      ibhEpidemiologyViewer.searchWrapper.slideToggle(400);
      ibhEpidemiologyViewer.searchToggle.toggleClass('open');
      return false;
    });
  },
  
  
  initResize: function() {
	this.containerHeight = $(window).height() - 42;
	this.gMap.css({height:this.containerHeight, width:"100%"});
	this.marker = $('.marker');
	$(window).resize(function() {
	  ibhEpidemiologyViewer.containerHeight = $(window).height() - 42;
	  ibhEpidemiologyViewer.gMap.css({height:ibhEpidemiologyViewer.containerHeight});
	});  
  },

  legendLabelReset: function() {
    clearTimeout(this.legendLabelTimeout);
    ibhEpidemiologyViewer.legendLabelInit();
  },

  legendLabelInit: function() {
    ibhEpidemiologyViewer.legendLabelTimeout = setTimeout(function() { ibhEpidemiologyViewer.legendLabelHide(); }, ibhEpidemiologyViewer.legendLabelHideSpeed);
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
      ibhEpidemiologyViewer.gMap.gmap3({action: 'setOptions', args:[{mapTypeId:'roadmap'}]},
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
      ibhEpidemiologyViewer.mapstyle.toggleClass('satellite');
    });
    $(".satellite").live('click',function(){
      ibhEpidemiologyViewer.gMap.gmap3({action: 'setOptions', args:[{mapTypeId:'hybrid'}]}); //hybrid, satellite, roadmap, terrain
      $(this).removeClass('satellite').addClass('roadmap');
      ibhEpidemiologyViewer.mapstyle.toggleClass('satellite');
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
        if(ibhEpidemiologyViewer.mainBox.outerHeight() > mainHeight) {
          ibhEpidemiologyViewer.mainBox.css({height:mainHeight,overflow:"auto"});
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
      max: ibhEpidemiologyViewer.maxAqiIndex,
      value: 10,
      animate: true,
      change: function( event, ui ) {
      //  $( "#amount" ).val( ui.value );
        ibhEpidemiologyViewer.skipOneContourAnim();
        var data = ibhEpidemiologyViewer.getEpidemiologyInfo(ui.value);
        if (ibhEpidemiologyViewer.colorLegendLabel) {
          var ts = ibhEpidemiologyViewer.animSlider.slider("value");
          var time = ibhEpidemiologyViewer.convertTimestamp(ts, true);
          var html = '';
          html += '<div class="number">' + ui.value + '</div>';
          html += '<div class="desc">' + data.title.toUpperCase() + '<br /><span class="time">Range: ' + data.span + '</span>';
          html += '<br /><span class="time">Updated: ' + time + '</span></div>';          
          ibhEpidemiologyViewer.colorLegendHtml.html('<div>' + html + '</div>');
          ibhEpidemiologyViewer.colorLegendLabel.css({borderRight:'8px solid #' + data.color});
          
          ibhEpidemiologyViewer.colorLegendHandle.show();
          
          ibhEpidemiologyViewer.legendLabelReset();
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
        ibhEpidemiologyViewer.tooltipContentRight.html('<div>Show Air Quality Index chart</div>');
        ibhEpidemiologyViewer.tooltipRight.css({top:top,left:left}).show();
      },
      function() {
        ibhEpidemiologyViewer.tooltipRight.hide();    
      }
    );
    $('#help-info').click(function(){
      if (ibhEpidemiologyViewer.appAlert) {
        if ($(ibhEpidemiologyViewer.appAlert).dialog( "isOpen" )) {
          $(ibhEpidemiologyViewer.appAlert).dialog("close");
        }
        else {
          ibhEpidemiologyViewer.showHelp1();        
        }   
      }
      else {
        ibhEpidemiologyViewer.showHelp1();        
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

    var epidemiologyDataInfo = this.getEpidemiologyInfo(labels[lbl]['max']);
    var opacity = epidemiologyDataInfo.opacity;

     // Color by span.
//     var strokeColor = '#' + epidemiologyDataInfo.color;
//     var fillColor = '#' + epidemiologyDataInfo.color;
    
    // Color by gradient.
    
    var strokeColor = '#' + ibhEpidemiologyViewer.gradientIndex[labels[lbl]['max']];
    var fillColor = '#' + ibhEpidemiologyViewer.gradientIndex[labels[lbl]['max']];

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
      ibhEpidemiologyViewer.skipOneContourAnim();
      ibhEpidemiologyViewer.colorLegend.slider('value', middle);
    });
    
    if (!this.firstWindowLoad && ibhEpidemiologyViewer.displayMode != 2) {
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
 
    var epidemiologyDataInfo = this.getEpidemiologyInfo(labels[lbl]['max']);
    var opacity = epidemiologyDataInfo.opacity;
    
     // Color by span.
//     var strokeColor = '#' + epidemiologyDataInfo.color;
//     var fillColor = '#' + epidemiologyDataInfo.color;
    
    // Color by gradient.
    
    var strokeColor = '#' + ibhEpidemiologyViewer.gradientIndex[labels[lbl]['max']];
    var fillColor = '#' + ibhEpidemiologyViewer.gradientIndex[labels[lbl]['max']];

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
      ibhEpidemiologyViewer.skipOneContourAnim();
      ibhEpidemiologyViewer.colorLegend.slider('value', middle);
    });
    
    if (!this.firstWindowLoad && ibhEpidemiologyViewer.displayMode != 2) {
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

Drupal.behaviors.ibhEpidemiologyViewer = Drupal.behaviors.ibhEpidemiologyViewer || {};

Drupal.behaviors.ibhEpidemiologyViewer.attach = function (context) {
  $('body:not(.epidemiology-viewer-processed)', context).addClass('epidemiology-viewer-processed').each(function() {
    ibhEpidemiologyViewer.initialize();
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
