<?php

	$con = mysqli_connect("can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com","admin","roan2[twangs","ibreathedb") or die("Error " . mysqli_error($con));
	
	$start_time = intVal($_REQUEST["s"]);
	$end_time = intVal($_REQUEST["e"]);
	$segment = $_REQUEST["seg"];
	
	$where_between = "TRUE";
	
	if ($start_time && $end_time) {
		$where_between = "epoch >= $start_time AND epoch <= $end_time";
	}

	// $query = "SELECT UNIX_TIMESTAMP(date) AS epoch, minimum, average, maximum, (o3_0_5 + o3_5_10 + o3_10_15 + o3_15_20 + o3_20_25 + o3_25_30 + o3_30_35 + o3_35_40 + o3_40_45 + o3_45_50 + o3_50_55 + o3_55_60) AS good, (o3_60_65 + o3_65_70 + o3_70_75) AS moderate, (o3_75_80 + o3_80_85 + o3_85_90 + o3_90_95) AS warning, (o3_95_100 + o3_100_105 + o3_105_110 + o3_110_115) AS unhealthy, (o3_115_120 + o3_120_125 + o3_125_130 + o3_130_135) AS very, (o3_135_140 + o3_140_145 + o3_145_150 + o3_150_155 + o3_155_160 + o3_160_plus) AS hazardous, total_cells AS total FROM aggregate_o3";
	if ($segment == "m") {
		$query = "SELECT MIN(epoch) AS epoch, MIN(minimum) AS minimum, AVG(average) AS average, MAX(maximum) AS maximum, SUM(good) AS good, SUM(moderate) AS moderate, SUM(warning) AS warning, SUM(unhealthy) AS unhealthy, SUM(very) AS very, SUM(hazardous) AS hazardous, SUM(total) AS total FROM aggregate_o3_epoch WHERE $where_between GROUP BY YEAR(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')), MONTH(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) ORDER BY YEAR(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')), MONTH(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) LIMIT 100";		
	}
	else if ($segment == "w") {
		$query = "SELECT MIN(epoch) AS epoch, MIN(minimum) AS minimum, AVG(average) AS average, MAX(maximum) AS maximum, SUM(good) AS good, SUM(moderate) AS moderate, SUM(warning) AS warning, SUM(unhealthy) AS unhealthy, SUM(very) AS very, SUM(hazardous) AS hazardous, SUM(total) AS total FROM aggregate_o3_epoch WHERE $where_between GROUP BY YEARWEEK(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) ORDER BY YEARWEEK(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) LIMIT 100";			
	}
	else if ($segment == "d") {
		$query = "SELECT MIN(epoch) AS epoch, MIN(minimum) AS minimum, AVG(average) AS average, MAX(maximum) AS maximum, SUM(good) AS good, SUM(moderate) AS moderate, SUM(warning) AS warning, SUM(unhealthy) AS unhealthy, SUM(very) AS very, SUM(hazardous) AS hazardous, SUM(total) AS total FROM aggregate_o3_epoch WHERE $where_between GROUP BY DATE(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) ORDER BY DATE(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) LIMIT 100";
	}
	else if ($segment == "h") {
		$query = "SELECT MIN(epoch) AS epoch, MIN(minimum) AS minimum, AVG(average) AS average, MAX(maximum) AS maximum, SUM(good) AS good, SUM(moderate) AS moderate, SUM(warning) AS warning, SUM(unhealthy) AS unhealthy, SUM(very) AS very, SUM(hazardous) AS hazardous, SUM(total) AS total FROM aggregate_o3_epoch WHERE $where_between GROUP BY DATE(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')), HOUR(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) ORDER BY DATE(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')), HOUR(CONVERT_TZ(FROM_UNIXTIME(epoch), '+00:00','America/Chicago')) LIMIT 100";
	}
	else {	
		$query = "SELECT * FROM aggregate_o3_epoch WHERE $where_between ORDER BY epoch ASC LIMIT 200";
	}

	$results = mysqli_query($con, $query) or die("Error " . mysqli_error($con));

	$return = array("epoch,minimum,average,maximum,good,moderate,warning,unhealthy,very,hazardous,total");

	while($row = mysqli_fetch_assoc($results)) {
		array_push($return, join(",",$row));
	}
	
	echo join($return,"\n");

	mysqli_close($con);

?>