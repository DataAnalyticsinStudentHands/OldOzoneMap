<?php
	//initialize connection to epidemiology database on RDS instance
	$con = mysqli_connect("can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com","admin","roan2[twangs","epidemiology") or die("Error " . mysqli_error($con));

	//set the suffix to use for generating the data and label table names
	$data_suffix = $_REQUEST["ds"] ?: "asthmadischarges";
	
	//build the array that the UI will use to construct dropdown menus on pivot-like columns
	//the columns are designated by using the prefix "select" in the index name in the data_ table itself
	$query = "SHOW INDEXES FROM data_$data_suffix WHERE Key_name LIKE 'select%'";
	$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));
	$select_columns = array();	
	while($row = mysqli_fetch_assoc($results)) {	
		if ($row["Key_name"] == "select_date_to_year") {
			$select_columns[$row["Column_name"]] = "YEAR(" . $row["Column_name"] . ")";	
		}
		else
			$select_columns[$row["Column_name"]] = $row["Column_name"];	
	}
	
	//set the column name used for joining the data_ and geo_ tables
	//the column is designated by the index name "geo_group"
	//either the column's name or a comment on the index is used, with the latter having priority if set
	$query = "SHOW INDEXES FROM data_$data_suffix WHERE Key_name = 'geo_group'";
	$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));	
	while($row = mysqli_fetch_assoc($results)) {	
		$geo_suffix = ($row["Index_comment"] && $row["Index_comment"] != "") ? $row["Index_comment"] : $row["Column_name"];
		$geo_field = $row["Column_name"];
	}
	
	$geo_suffix = $geo_suffix ?: "zipcode";
	$geo_table = "geo_" . $geo_suffix . "s";
	$geo_name = "name";
	
	//
	$query = "SHOW INDEXES FROM data_$data_suffix WHERE Key_name LIKE 'markers%'";
	$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));
	$marker_columns = array();
	while($row = mysqli_fetch_assoc($results)) {
		// if (substr($row["Column_name"],strlen('markers_')) == 'lat_lon')	
		// 	$is_lat_lon = true;
		array_unshift($marker_columns, "data_$data_suffix." . $row["Column_name"]);
	}
	
	$markers_select = "CONCAT('[',";
	$markers_select .= "GROUP_CONCAT(CONCAT('[',";
	if (true || count($marker_columns) == 0) {
		$markers_select .= "REPLACE(REPLACE(REPLACE(ASTEXT($geo_table.centroid),'POINT(',''),')',''),' ',',')";	
	}
	else {
		$markers_select .= implode(",',',", $marker_columns);
	}
	$markers_select .= ",']') SEPARATOR ',')";
	$markers_select .= ",']')";

	//set the center and radius of the area a polygon must lie within/intersect to be returned
	//this is passed by the js, but has values to default to
	$center = explode(",",$_REQUEST["c"] ?: "29.76,-95.36");
	$center_lat = floatval($center[1]);
	$center_lng = floatval($center[0]);
	$radius = floatval($_REQUEST["r"]) ?: 0.8;
	
	//boolean to determine whether or not only new polygons need to be returned
	//otherwise all polygons as well as UI JSON will be returned
	$is_expand_only = false;
	//boolean to determine whether a count value should be returned as the only data column
	//otherwise all un-indexed columns in the data_ table should be returned
	$is_aggregated = false;
	
	//initialize variable for storing extra WHERE conditions
	$where = "";
	//used for is_aggregated = true, harmless otherwise
	$group = "GROUP BY data_$data_suffix.$geo_field";
	//default to select all data_ columns, overwritten if is_aggregated = true
	$data_select = "data_$data_suffix.*";
	
	//initialize arrays used for UI JSON returns
	$menus = array();
	$debug = array();
	
	$debug["maximum"] = array();
	$maximum = null;
	
	if ($_REQUEST["d"] && preg_match("/^[^ ']+$/",$_REQUEST["d"])) {
		$is_expand_only = true;
		$prev_data = "'" . join("','",explode(',',$_REQUEST["d"])) . "'";
		$where = " AND data_$data_suffix.$geo_field NOT IN ($prev_data)";
	}
	
	if (array_key_exists("a",$_REQUEST)) {
		$is_aggregated = true;
		$data_select = "COUNT(*) AS count";
	}
	
	//loop through all designated pivot columns (indexes prefixed "select_")
	//add where conditions, either default (first unique value) or passed as request parameter
	foreach($select_columns as $select_column => $select_sql) {
		$query = "SELECT DISTINCT($select_sql) AS $select_column FROM data_$data_suffix ORDER BY $select_sql ASC";
		$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));	
		$select_options = array();
		$where_cond = "";
		if ($is_aggregated)	
			$select_options["all"] = "All " . ucwords(str_replace("_"," ","$select_column")) . "s";
		if ($_REQUEST["s_$select_column"]) {
			if ($_REQUEST["s_$select_column"] == "all")
				$where_cond = " ";
			else 
				$where_cond = " AND $select_sql LIKE '" . $_REQUEST["s_$select_column"] . "'";
		}
		while($row = mysqli_fetch_assoc($results)) {
			$val = $row[$select_column];
			$where_cond = $where_cond ?: " AND $select_sql LIKE '$val'";		
			$select_options["$val"] = ucwords(str_replace("_"," ","$val"));
		}		
		if (count($select_options) > 1) {
			$menus[$select_column] = $select_options;		
		}	
		$where .= $where_cond ?: "";
	}

	//main data + polygon query
	$query = "SELECT $data_select, $geo_table.$geo_name AS geo_name, $geo_table.$geo_suffix AS geo_field, ASTEXT($geo_table.polygons) AS polygons, $markers_select AS markers FROM data_$data_suffix INNER JOIN $geo_table ON data_$data_suffix.$geo_field = $geo_table.$geo_suffix WHERE INTERSECTS(GeomFromText(astext($geo_table.polygons)), BUFFER(GeomFromText('POINT($center_lat $center_lng)'), $radius)) $where $group";
	
	$debug["sql query"] = $query;
	
	$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con) . "\n\n$query");

	$geojson = array(
	    'type'      => 'FeatureCollection',
	    'features'  => array()
	 );

	while($row = mysqli_fetch_assoc($results)) {
		
		$polygoncoords = json_decode("[" . str_replace(array(","," ","(",")"),array("],[",",","[","]"),substr($row["polygons"],strlen("MULTIPOLYGON"))) . "]");		
		unset($row["polygons"]);
		
		// $centroid = json_decode(str_replace(array(" ","(",")"),array(",","[","]"),substr($row["centroid"],strlen("POINT"))));
		// unset($row["centroid"]);
		
		$markers = json_decode($row["markers"]);
		unset($row["markers"]);
		
		if ($is_aggregated) {
			$maximum = ($maximum && intVal($row["count"])) ? max($maximum, intVal($row["count"])) : intVal($row["count"]);
			array_push($debug["maximum"], $maximum);
		}
		
		$feature = array(
			'type' => 'Feature',
			'properties' => $row,
			'geometry' => array(
				'type' => 'MultiPolygon',
				'coordinates' => $polygoncoords,
				//'centroid' => $centroid
				'markers' => $markers
			)
		);
		array_push($geojson['features'], $feature);
	} 
	
	if (!$is_expand_only) {	
		$labels_query = "SELECT * FROM labels_$data_suffix";
				
		if (!$is_aggregated) {
			$query = "SELECT column_name FROM information_schema.columns WHERE table_schema = 'epidemiology' AND table_name = 'data_$data_suffix' AND LENGTH(column_key) = 0";
			$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));	
			$columns = array();	
			while($row = mysqli_fetch_assoc($results)) {		
				$columns[$row["column_name"]] = ucwords(str_replace("_"," ",$row["column_name"]));
			}
			$menus["data"] = $columns;			
		}
		else {
			$labels_query = "SELECT (id*" . ($maximum ?: 1) . ") AS id, label, color FROM labels_aggregate";
		}
		
		$labels = array();
		$debug["labels_query"] = $labels_query;
		$results = mysqli_query($con, $labels_query) or die("Error " . mysqli_error($con));

		while($row = mysqli_fetch_assoc($results)) {		
			$label = array(
				'label' => $row["label"],
				'color' => $row["color"]
			);
			$labels["" . $row["id"] . ""] = $label;
		}

		$return = array(
			'geojson' => $geojson,
			'labels' => $labels,
			'menus' => $menus,
			'debug' => $debug
		);
	}	
	else {
		$return = $geojson;
	}
	
	header('Content-type: application/json');
	echo json_encode($return);

	mysqli_close($con);

?>