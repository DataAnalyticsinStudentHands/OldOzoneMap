<?php
	//initialize connection to epidemiology database on RDS instance
	$con = mysqli_connect("can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com","admin","roan2[twangs","epidemiology") or die("Error " . mysqli_error($con));
	
	$geo_suffix = $_REQUEST["gs"] ?: "zipcode";
	$geo_table = "geo_" . $geo_suffix . "s";
	$geo_name = "name";
	
	$markers_select = "CONCAT('[',";
	$markers_select .= "GROUP_CONCAT(CONCAT('[',";
	$markers_select .= "REPLACE(REPLACE(REPLACE(ASTEXT($geo_table.centroid),'POINT(',''),')',''),' ',',')";	
	
	$markers_select .= ",']') SEPARATOR ',')";
	$markers_select .= ",']')";

	//set the center and radius of the area a polygon must lie within/intersect to be returned
	//this is passed by the js, but has values to default to
	$center = explode(",",$_REQUEST["c"] ?: "29.76,-95.36");
	$center_lat = floatval($center[1]);
	$center_lng = floatval($center[0]);
	$radius = floatval($_REQUEST["r"]) ?: .8;
	
	//initialize variable for storing extra WHERE conditions
	$where = "";
	
	$group = "GROUP BY $geo_table.$geo_suffix";
	
	//main  polygon query
	$query = "SELECT $geo_table.$geo_name AS geo_name, $geo_table.$geo_suffix AS geo_field, ASTEXT($geo_table.polygons) AS polygons, $markers_select AS markers FROM $geo_table WHERE INTERSECTS(GeomFromText(astext($geo_table.polygons)), BUFFER(GeomFromText('POINT($center_lat $center_lng)'), $radius)) $where $group";
	
	$debug["sql query"] = $query;
	
	$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con) . "\n\n$query");

	$geojson = array(
	    'type'      => 'FeatureCollection',
	    'features'  => array()
	 );

	while($row = mysqli_fetch_assoc($results)) {
		
		$polygoncoords = json_decode("[" . str_replace(array(","," ","(",")"),array("],[",",","[","]"),substr($row["polygons"],strlen("MULTIPOLYGON"))) . "]");		
		unset($row["polygons"]);
				
		$markers = json_decode($row["markers"]);
		unset($row["markers"]);
		
		$row["count"] = 0;
		
		$feature = array(
			'type' => 'Feature',
			'properties' => $row,
			'geometry' => array(
				'type' => 'MultiPolygon',
				'coordinates' => $polygoncoords,
				'markers' => $markers
			)
		);
		$geojson['features'][$row['geo_name']] = $feature;
	} 
	
	$return = array(
		'geojson' => $geojson,
		'debug' => $debug
	);
	
	header('Content-type: application/json');
	echo json_encode($return);

	mysqli_close($con);

?>