<?php
	include_once('ozonemaps/php-helpers/db.php');
	$dbManager = new DBManager();
	$link = $dbManager->getDataBaseLink(true);
	if (!$link) {
        error_log('Error connecting to database: ' . mysql_error());
        die ('Error connecting to database');
    }
    if (!$dbManager->selectOzoneDB($link)) {
        error_log ('Error selecting ozone database: ' . mysql_error());
        die ('Error selecting ozone database');
    }
	
	$im = imagecreatetruecolor(124, 154);
	$gradient = array();
	
	for ($i = 0; $i < 256; $i++) {
		$gradient[$i] = imagecolorallocate($im, $i, $i, $i);
	}
	
	echo "\n";
	
	for ($epoch = 1363038900; $epoch <= 1388538600; $epoch += 300) {
		echo "\r$epoch";
		$sql = "select * from interpolation_step01_2013 where epoch = $epoch";
	    $result = mysql_query($sql, $link);
		while ($row = mysql_fetch_assoc($result)) {
			imagesetpixel($im, $row['lngindex'], 153-$row['latindex'], $gradient[min(255,max(255-$row["o3"],0))]);
		}
		imagepng($im,"bw_png/$epoch.png",0);
	}
?>
