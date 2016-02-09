<!DOCTYPE html>
<html>
    <head>
	<title>Contour Lines for Ozone values interpolation</title>
	<style>
	    #map_canvas {
		width: 900px;
		height: 500px;
	    }
	</style>

	 <script type="text/javascript"
	     src="http://maps.googleapis.com/maps/api/js?sensor=false">
	 </script>
	<script type="text/javascript" src="../js/jquery.min.js"></script>
	<script>
	    useGoogleChartImage = true;
	</script>
	<script type="text/javascript" src="../js/marker.js"></script>
	<script type="text/javascript">
	    showMarkers = true;
	    polygonList = [];
	    colorTable = ['#ffffff','#ffffff','#010546','#071964','#0f3582',
		'#1744a0','#1f53be','#2762dc','#2f70fa','#377ffd','#3e8cfa',
		'#4599f4','#4ba4ec','#52aee0','#58b8d4','#5fc1c7','#65c9ba',
		'#6bd0ad','#70d7a0','#76dd93','#7be287','#80e77b','#86ec70',
		'#8bef66','#8ff25d','#94f654','#99f84c','#9df945','#a1fa3e',
		'#a5fb38','#a9fc32','#adfd2d','#b1fd28','#b5fd24','#b8fc1f',
		'#bcfc1d','#bffb19','#c2fa17','#c5f913','#c8f812','#cbf610',
		'#cef30e','#d0f10c','#d3ef0b','#d5ed09','#d8ec08','#dae807',
		'#dce606','#dee306','#e0e105','#e2de04','#e4db04','#e6d803',
		'#e8d503','#e9d203','#eccf02','#eccc02','#eec902','#efc601',
		'#f0c301','#f1c001','#f2bd01','#f3ba01','#f4b700','#f6b400',
		'#f7b100','#f8ad00','#f9aa00','#f9a700','#f9a400','#faa100',
		'#fa9e00','#fb9b00','#fb9800','#fb9500','#fc9300','#fc9000',
		'#fc8d00','#fc8a00','#fd8700','#fd8400','#fd8200','#fd7f00',
		'#fd7c00','#fd7a00','#fd7700','#fc7500','#fc7200','#fc7000',
		'#fc6d00','#fc6b00','#fb6900','#fb6600','#fb6400','#fa6200',
		'#fa6000','#f95d00','#f95b00','#f95900','#f95700','#f85500',
		'#f85300','#f75100','#f64f00','#f64e00','#f44c00','#f34a00',
		'#f34800','#f24700','#f14500','#f04300','#f04200','#ef4000',
		'#ee3e00','#ed3d00','#ec3b00','#ec3a00','#ec3900','#eb3700',
		'#e93600','#e83500','#e73300','#e63200','#e53100','#e42f00',
		'#e32e00','#e22d00','#e12c00','#e02b00','#df2a00','#de2900',
		'#dd2800','#dc2700','#db2600','#da2500','#d92400','#d82300',
		'#d62200','#d52100','#d41f00','#d31f00','#d21f00','#d11e00',
		'#d01d00','#cf1c00','#cd1b00','#cc1b00','#cb1a00','#ca1900',
		'#c91900','#c81800','#c71700','#c51700','#c41600','#c31400',
		'#c21400','#c11300','#c01300','#bf1300','#bd1300','#bc1200',
		'#bb1200','#ba1100','#b91100','#b81000','#b61000','#b50f00',
		'#b40f00','#b30f00','#b20e00','#b10e00','#af0d00','#ae0d00',
		'#ad0d00','#ac0c00','#ab0c00','#aa0c00','#a80b00','#a70b00',
		'#a60b00','#a50900','#a40900','#a30900','#a20800','#a10800',
		'#9f0800','#9e0800','#9d0700','#9c0700','#9b0700','#9a0700',
		'#990600','#980600','#960600','#950600','#940600','#930600',
		'#920600','#910600','#900600','#8f0600','#8e0600','#8d0500',
		'#8c0500','#8b0500','#8a0500','#890500','#880500','#870400',
		'#850400','#840400','#830400','#820400','#810400','#800400',
		'#7f0400','#7e0300','#7d0300','#7c0300','#7b0300','#7a0300',
		'#7a0300','#790300','#780300','#770300','#760300','#750200',
		'#740200','#730200','#720200','#710200','#700200','#6f0200',
		'#6e0200','#6d0200','#6c0200','#6c0200','#6b0200','#6a0200',
		'#690200','#680100','#670100','#660100','#650100','#650100',
		'#640100','#630100','#620100','#610100','#600100','#600100',
		'#5f0100','#5e0100','#5d0100','#5c0100','#5c0100'];
	    <?php
		if (!empty($timestamp)) {
		    echo "var timestamp = $timestamp;";
		    echo "var displayTimestamp = timestamp;";
		}
		if (!empty($bandHelper)) {
		    echo 'var bandScheme = ' . $bandHelper->getSchemeId() .';';
		    echo 'var bandHelper ='.json_encode($bandHelper->getDesc()).';';
		} else {
		    echo 'var bandScheme = 0;';
		}
		echo 'var respObj = ' . json_encode($responseObject) . ';';
	    ?>
	    var currentZoomLevel = 9;
	    cLines = {};
	    valleyLines = {};
	    marker = [];

	    function initialize() {
		var myLatLng = new google.maps.LatLng(29.5, -95.3);
		var myOptions = {
		    zoom: currentZoomLevel,
		    center: myLatLng,
		    mapTypeId: google.maps.MapTypeId.ROADMAP
		};

		map = new google.maps.Map(document.getElementById("map_canvas"),myOptions);
		separateData(respObj);
		drawPolygons();
		drawValleys();
		drawMarkers();
		showTimestamp(timestamp);
	    }

	    function separateData(resp) {
		cLines = {};
		valleyLines = {};
		marker = [];

                if (typeof(resp.data) == 'undefined') {
                  return;
                }

		displayTimestamp = resp.timestamp;
		bandHelper = resp.labels;

		for (var lbl in bandHelper) {
		    cLines[lbl] = [];
		    valleyLines[lbl] = [];
		}

		for (var i=0; i<resp.data.length; i++) {
		    lbl = resp.data[i].label_id;
		    cLines[lbl].push(resp.data[i].polygon);
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
		    valleyLines[lbl].push(
			{ 'p' : resp.valley[i].polygon,
			  'l' : isLargest
			}
		    );
		}

		if (typeof(resp.station) != 'undefined') {
		    for (var i=0; i<resp.station.length; i++) {
			var latLng = new google.maps.LatLng(
			    resp.station[i].lat, resp.station[i].lng
			);
			marker[i] = new MarkerObject(
			    latLng, map, resp.station[i].desc, i
			);
			var colorString = getMarkerColor(resp.station[i].o3);
			marker[i].setIcon(resp.station[i].o3, colorString);
		    }
		}
	    }

	    function getMarkerColor(o3Value) {
		var colorString = '#ffffff';
		for (var lblId in bandHelper) {
		    if (o3Value > bandHelper[lblId].min
			 && o3Value <= bandHelper[lblId].max) {
			colorString = getColor(lblId);
			break;
		    }
		}
		return colorString.substr(1, colorString.length);
	    }

	    function getColor(colorIndex) {
		var lower = bandHelper[colorIndex]['min'];
		var upper = bandHelper[colorIndex]['max'];
		var avg = parseInt((lower+upper)/2);
		// avg needs to be scaled to 0 to 255
		var o3max = 375;
		if (avg > o3max) {
		    avg = o3max;
		}
		var idx = parseInt((avg)*225/o3max);
		return colorTable[idx];
	    }

	    /*function drawPolygon(i) {
		// draw ith polygon from lines array
		var linesCount = cLines.length - 1;
		var colorIndices = cLines[linesCount];
		if (i >=0 || i<linesCount) {
		    var colorIndex = parseInt(colorIndices[i]);
		    var polyPath = bspline(cLines[i]);
		    var polygon = new google.maps.Polygon({
			paths: polyPath,
			strokeColor:'black',
			strokeOpacity: 1,
			strokeWeight: 1,
			fillColor: getColor(colorIndex),
			fillOpacity: 1,
			zIndex: i+5,
		    });
		    polygonList.push(polygon);
		    polygon.setMap(map);
		}
	    }*/

	    function drawPolygons() {
		var linesCount = cLines.length - 1;
		// Profiling
		var startTime = new Date();

		for (var lbl in cLines) {
		    drawPolygon(lbl);
		}
		var endTime = new Date();
		if (console) {
		    console.log("Time taken for all cLines: "
			+ (endTime.getTime() - startTime.getTime()) + " ms");
		}
	    }

	    function drawValleys() {
		if (typeof(valleyLines) == 'undefined') {
		    return;
		}
		// get the labels of valley lines
		var maxLabel = 0;
		for (var label in valleyLines) {
		    if (parseInt(label) > maxLabel) {maxLabel=parseInt(label)};
		}

		for (var lbl=maxLabel; lbl > 10; lbl -= 10) {
		    drawValley(lbl);
		}
	    }

	    function drawPolygon(lbl) {
		var polyPath = [];
		for (var i=0; i<cLines[lbl].length; i++) {
		    polyPath.push(bspline(cLines[lbl][i]));
		}
		// anticlockwise for all next higher labelled polygons
		var nxt = parseInt(lbl)+10;
		if (typeof(cLines[nxt]) != 'undefined') {
		    for (var i=0; i<cLines[nxt].length; i++) {
			var tmp = [];
			for (var j=cLines[nxt][i].length-1; j>=0; j--) {
			    tmp.push(cLines[nxt][i][j]);
			}
			polyPath.push(bspline(tmp));
		    }
		}

		// anticlockwise for all valleys if any largest valley
		if (typeof(valleyLines[lbl]) != 'undefined') {
		    for (var i=0; i<valleyLines[lbl].length; i++) {
			if (valleyLines[lbl][i].l) {
			    var tmp = [];
			    for (var j=valleyLines[lbl][i].p.length-1;j>=0;j--){
				tmp.push(valleyLines[lbl][i].p[j]);
			    }
			    polyPath.push(bspline(tmp));
			}
		    }
		}

		var polygon = new google.maps.Polygon({
		    paths: polyPath,
		    strokeColor: 'black',//getColor(colorIndex),
		    strokeOpacity: 1,
		    strokeWeight: 1,
		    fillColor: getColor(lbl),
		    fillOpacity: 0.6,
		});
		polygon.setMap(map);
		polygonList.push(polygon);
	    }

	    function drawValley(lbl) {
		if (lbl == 10) return;
		if (typeof(valleyLines[lbl]) == 'undefined'
			 || valleyLines[lbl].length == 0) {
		    return;
		}
		lbl = parseInt(lbl);
		var polyPath = [];

		// draw the valley with color of lbl-10
		for (var i=0; i<valleyLines[lbl].length; i++) {
		    polyPath.push(bspline(valleyLines[lbl][i].p));
		}

		// anticlockwise for lbl-10 for each of those that are not
		// the largest.. This type of support needs to be provided
		// by backend infrastructure
		var nxt = lbl - 10;
		for (var i=0; i<valleyLines[nxt].length; i++) {
		    if (valleyLines[nxt][i].l) continue;
		    var tmp = [];
		    for (var j=valleyLines[nxt][i].p.length-1; j>=0; j--) {
			tmp.push(valleyLines[nxt][i].p[j]);
		    }
		    polyPath.push(bspline(tmp));
		}
		var polygon = new google.maps.Polygon({
		    paths: polyPath,
		    strokeColor: 'black',//getColor(colorIndex),
		    strokeOpacity: 1,
		    strokeWeight: 1,
		    fillColor: getColor(lbl-10),
		    fillOpacity: 0.6,
		});

		polygon.setMap(map);
		polygonList.push(polygon);
	    }

	    function showTimestamp(ts) {
		var str = "" + ts;
		var d = new Date(ts*1000);
		str += " [" + d.toString() + "]";
		document.getElementById('dispTime').innerHTML = str;
	    }

	    /**
	     * bspline
	     *
	     * Smooth out the polylines or polygon boundaries by adding more
	     * in-between points.
	     * This function has been adopted (with only slight modification)
	     * from http://johan.karlsteen.com/2011/07/30/improving-google-maps
	     * -polygons-with-b-splines/
	    **/
	    function bspline(oneCLine) {
		var i, t, ax, ay, bx, by, cx, cy, dx, dy, lat, lon, points;

		var lats = [];
		var lons = [];
		var points = [];
		var startTime = new Date();

		for (var i=0; i<oneCLine.length; i++) {
		    lat = oneCLine[i][0];
		    lon = oneCLine[i][1];
		    points.push(new google.maps.LatLng(lat, lon));
		}
		return points; // disabling use of bspline in the frontend
		var points1 = points;
		points = [];
		
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

		var endTime = new Date();
		/*if (console) {
		    console.log("Time taken for one bspline call: "
			+ (endTime.getTime() - startTime.getTime()) + " ms");
		}*/
		return points;
		//return points1;
	    }

	    /* For testing purpose only */
	    function drawSimplePolygon(polyPath) {
		var polygon = new google.maps.Polygon({
		    paths: bspline(polyPath),
		    strokeColor: 'black',//getColor(colorIndex),
		    strokeOpacity: 1,
		    strokeWeight: 1,
		    fillColor: 'green',
		    fillOpacity: 0.6,
		});
		polygon.setMap(map);
		polygonList.push(polygon);
	      
	    }

	    function removePolygons() {
		if (typeof(polygonList)=='undefined' || polygonList.length==0) {
		    return;
		}
		for (var i=0; i < polygonList.length; i++) {
		    polygonList[i].setMap(null);
		}
		polygonList = [];
	    }

	    function drawMarkers() {
		for (var i=0; i<marker.length; i++) {
		    marker[i].setMap(map);
		}
	    }

	    function removeMarkers() {
		if (typeof (marker) == 'undefined' || marker.length == 0) {
		    return;
		}
		for (var i=0; i<marker.length; i++) {
		    marker[i].setMap(null);
		}
		//marker = [];
	    }

	    function toggleMarker() {
		if (showMarkers) {
		    showMarkers = false;
		    removeMarkers();
		} else {
		    showMarkers = true;
		    drawMarkers();
		}
		return false;
	    }

	    // Following napping function didn't work well. Since it keeps
	    // polling, this does a nasty work of causing the browser to hang
	    function takeNap(mSec) {
		var sleeping = true;
		window.setTimeout("sleeping = false", mSec);
		while (sleeping) {
		    // do no operation
		}
	    }

	    function next() {
		timestamp += 300;
		getNewPolygons();
	    }

	    function prev() {
		timestamp -= 300;
		getNewPolygons();
	    }

	    function getNewPolygons() {
		$.getJSON("contour.php",
		    {
			timestamp:timestamp,
			station:1,
			bandschema:bandScheme,
			format:'json',
			forcejson:1
		    },
		    function(resp){
			removePolygons();
			removeMarkers();
			separateData(resp);
			drawPolygons();
			drawValleys();
			drawMarkers();
			showTimestamp(timestamp);
		    }
		);
	    }
	</script>
    </head>

    <body onload="initialize()">
