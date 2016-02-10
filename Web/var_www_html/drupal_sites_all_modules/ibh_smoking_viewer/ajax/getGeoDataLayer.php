<?php
	$data_suffix = "smokingordinances";
	$geo_suffix = "geo_id";
	$geo_table = "geo_" . $geo_suffix . "s";
	$geo_field = $geo_suffix;
	$geo_name = "name";

	$center = explode(",",$_REQUEST["c"]);
	$center_lat = floatval($center[1]);
	$center_lng = floatval($center[0]);
	$radius = floatval($_REQUEST["r"]);
	$is_expand_only = false;
	$wherenotprev = "";
	if ($_REQUEST["d"] && preg_match("/^[0-9,]+$/",$_REQUEST["d"])) {
		$is_expand_only = true;
		$wherenotprev = " AND data_$data_suffix.$geo_field NOT IN (" . rtrim($_REQUEST["d"],",") . ")";
	}
	if ($_REQUEST["p"] && preg_match("/^[0-9A-z_,]+$/",$_REQUEST["d"])) {

	}

	$con = mysqli_connect("can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com","admin","roan2[twangs","epidemiology") or die("Error " . mysqli_error($con));

	$query = "SELECT data_$data_suffix.*, $geo_table.$geo_name AS geo_name, $geo_table.$geo_name AS name, $geo_table.$geo_field AS geo_field, ASTEXT($geo_table.polygons) AS polygons FROM data_$data_suffix INNER JOIN $geo_table ON data_$data_suffix.$geo_field = $geo_table.$geo_field WHERE INTERSECTS(GeomFromText(astext($geo_table.polygons)), BUFFER(GeomFromText('POINT($center_lat $center_lng)'), $radius))";
	
	if ($is_expand_only) {
		$query .= $wherenotprev;
	}

	$query .= " GROUP BY $geo_field";

	$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con) . "\n\n$query");

	$geojson = array(
	    'type'      => 'FeatureCollection',
	    'features'  => array()
	 );

	while($row = mysqli_fetch_assoc($results)) {
		
		$polygoncoords = json_decode("[" . str_replace(array(","," ","(",")"),array("],[",",","[","]"),substr($row["polygons"],strlen("MULTIPOLYGON"))) . "]");
		
		unset($row["polygons"]);
		
		$feature = array(
			'type' => 'Feature',
			'properties' => $row,
			'geometry' => array(
				'type' => 'MultiPolygon',
				'coordinates' => $polygoncoords
			)
		);
		array_push($geojson['features'], $feature);
	} 
	
	if (!$is_expand_only) {
		$query = "SELECT * FROM labels_$data_suffix";

		$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));

		$labels = array();

		while($row = mysqli_fetch_assoc($results)) {		
			$label = array(
				'label' => $row["label"],
				'color' => $row["color"]
			);
			$labels[$row["id"]] = $label;
		}

		$query = "SELECT column_name FROM information_schema.columns WHERE table_schema = 'epidemiology' AND table_name = 'data_$data_suffix' AND LENGTH(column_key) = 0";

		$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));	
		$columns = array();	
		while($row = mysqli_fetch_assoc($results)) {		
			$columns[$row["column_name"]] = ucwords(str_replace("_"," ",$row["column_name"]));
		}

		$return = array(
			'geojson' => $geojson,
			'labels' => $labels,
			'columns' => $columns
		);
	}	
	else {
		$return = $geojson;
	}
	
	header('Content-type: application/json');
	echo json_encode($return, JSON_NUMERIC_CHECK);

	mysqli_close($con);

?>
