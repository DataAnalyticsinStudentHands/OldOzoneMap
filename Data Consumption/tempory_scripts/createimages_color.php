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
	
	$tceq = array(
			array(41,183,51),
			array(246,236,38),
			array(239,140,32),
			array(184,33,43),
			array(198,48,123),
			array(104,14,100),
			array(0,0,0)
		);
			
	for ($i = 0; $i < 60; $i++) {
	    $gradient[$i] = imagecolorallocate($im,
			((60-$i)*$tceq[0][0]+$i*$tceq[1][0])/60,
			((60-$i)*$tceq[0][1]+$i*$tceq[1][1])/60,
			((60-$i)*$tceq[0][2]+$i*$tceq[1][2])/60
		);
	}
	for ($i; $i < 76; $i++) {
		$gradient[$i] = imagecolorallocate($im,
			((76-$i)*$tceq[1][0]+($i-60)*$tceq[2][0])/16,
			((76-$i)*$tceq[1][1]+($i-60)*$tceq[2][1])/16,
			((76-$i)*$tceq[1][2]+($i-60)*$tceq[2][2])/16
		);	
	}
	for ($i; $i < 96; $i++) {
		$gradient[$i] = imagecolorallocate($im,
			((96-$i)*$tceq[2][0]+($i-76)*$tceq[3][0])/20,
			((96-$i)*$tceq[2][1]+($i-76)*$tceq[3][1])/20,	
			((96-$i)*$tceq[2][2]+($i-76)*$tceq[3][2])/20
		);
	}
	for ($i; $i < 116; $i++) {
		$gradient[$i] = imagecolorallocate($im,
			((116-$i)*$tceq[3][0]+($i-96)*$tceq[4][0])/20,
			((116-$i)*$tceq[3][1]+($i-96)*$tceq[4][1])/20,
			((116-$i)*$tceq[3][2]+($i-96)*$tceq[4][2])/20
		);
	}
	for ($i; $i < 136; $i++) {
		$gradient[$i] = imagecolorallocate($im,
			((136-$i)*$tceq[4][0]+($i-116)*$tceq[5][0])/20,
			((136-$i)*$tceq[4][1]+($i-116)*$tceq[5][1])/20,
			((136-$i)*$tceq[4][2]+($i-116)*$tceq[5][2])/20
		);
	}
	for ($i; $i < 256; $i++) {
		$gradient[$i] = imagecolorallocate($im,
			((256-$i)*$tceq[5][0]+($i-136)*$tceq[6][0])/20,
			((256-$i)*$tceq[5][1]+($i-136)*$tceq[6][1])/20,
			((256-$i)*$tceq[5][2]+($i-136)*$tceq[6][2])/20
		);
	}
	
	echo "\n";
	
	for ($epoch = 1357020000; $epoch <= 1388538600; $epoch += 300) {
		echo "\r$epoch";
		$sql = "select * from interpolation_step01_2013 where epoch = $epoch";
	    $result = mysql_query($sql, $link);
		while ($row = mysql_fetch_assoc($result)) {
			imagesetpixel($im, $row['lngindex'], 153-$row['latindex'], $gradient[min(255,max($row["o3"],0))]);
		}
		imagepng($im,"color_png/$epoch.png",0);
	}
?>
