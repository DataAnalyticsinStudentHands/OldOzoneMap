<?php
//apd_set_pprof_trace();

date_default_timezone_set("America/Chicago"); // central time
//require_once('http://localhost:8082/JavaBridge/java/Java.inc');
include_once('ozonemaps/php-helpers/QueryManager.php');
//include_once('QueryManager_testing.php');
include_once('ozonemaps/php-helpers/GridConfig.php');
include_once('ozonemaps/php-helpers/ContourCacheHelper.php');
include_once('ozonemaps/php-helpers/DiscreteBandHelper.php');
include_once('ozonemaps/php-helpers/ResponseHelper.php');

if (isset($_REQUEST['step']) && is_numeric($_REQUEST['step'])) {
    $stepSize = doubleval($_REQUEST['step']);
}

$callback = '';
if (!empty($_REQUEST['callback'])) {
    $callback = preg_replace('/[^][._a-zA-Z0-9]/', '', $_REQUEST['callback']);
}

$bandSchema = 0;
if (!empty($_REQUEST['bandschema'])) {
    $bandSchema = intval($_REQUEST['bandschema']);
}

// forece using JSONP by default
$use_jsonp = true;
// option to return JSON, instead of jsonp
if (isset($_REQUEST['forcejson']) && $_REQUEST['forcejson'] == 1) {
    $use_jsonp = false;
}

//$useGzip = true;
$useGzip = false;
$queryManager = new QueryManager();
$bandHelper = new DiscreteBandHelper(DiscreteBandHelper::LABEL_TYPE_BAND, $bandSchema);
$contourDataStore = new ContourCacheHelper($useGzip,$bandHelper->getSchemeId());
$ozoneBand = $bandHelper->getBand();
//$bandHashMap = new Java("java.util.HashMap");
//foreach($ozoneBand as $key => $val) {
//    $bandHashMap->put($key, doubleval($val));
//}

$timestamp = '';
if (isset($_REQUEST['timestamp']) && is_numeric($_REQUEST['timestamp'])) {
    $timestamp = $_REQUEST['timestamp'];
    $month = date('m', $timestamp);
    $day = date('d', $timestamp);
    $year = date('Y', $timestamp);
    $hour = date('H', $timestamp);
    $min = date('i', $timestamp);
    $min = intval($min) - intval($min) % 5;
    $timestamp = mktime($hour, $min, 0, $month, $day, $year);
}

$fetchStationData = false;
if (isset($_REQUEST['station']) && $_REQUEST['station'] == 1) {
    $fetchStationData = true;
}

// set use latest available by default -- TMH 2012/10/31
$useLatestDataWhenFail = true;
if (isset($_REQUEST['latest']) && $_REQUEST['latest'] == 1) {
    $useLatestDataWhenFail = true;
}

// if timestamp is empty, try to find the latest using txn table
if (empty($timestamp)) {
    $timestamp = $queryManager->latestContourAvailableTime();
}

$requestType = 'json';
if (isset($_REQUEST['type'])) {
    if (strtolower($_REQUEST['type']) == 'json') {
        $requestType = 'json';
    } elseif (strtolower($_REQUEST['type']) == 'html') {
        $requestType = 'html';
    }
}

$start = microtime(true);
$fsCacheDetected = false;
$responseObject = $contourDataStore->retrieveContour($timestamp);
if (!empty($responseObject)) {
    $fsCacheDetected = true;
    $responseObject = json_decode($responseObject, true);
}

$outFile = '';
$queryTime = 0;
if ($responseObject === false) {
//    require_once('http://localhost:8082/JavaBridge/java/Java.inc');
//    //require_once('/tmp/aaa.txt');
//    $bandHashMap = new Java("java.util.HashMap");
//    foreach($ozoneBand as $key => $val) {
//        $bandHashMap->put($key, doubleval($val));
//    }
//    $outFile = '/tmp/binaryout.png';
//    $driver = new Java('LatLongInterpolation.LatLngDriver', $bandHashMap);
//
//    $queryStart = microtime(true);
//    $allData = $queryManager->getDataForWindBasedInterpolation($timestamp,6,true);
//    $queryTime = microtime(true) - $queryStart;
//
//    $r = $driver->getContours(
//        $allData['ozoneStations'], $allData['windStations'],
//        $allData['ozoneValues'], $allData['windSpeed'],
//        $allData['windDirection'], $stepSize
//    );
//
//    //$r = $driver->drive();
//    $responseObject = prepareResponseObject(java_values($r), $timestamp);

/*  $grid_gen_script = '/var/www/html/test/ozonemaps/api/tools/calculategrid.php';	// grid / contour generating script
  $last_line4 = exec("/usr/bin/php $grid_gen_script $timestamp -1 4", $output0, $retval4);
  $last_line0 = exec("/usr/bin/php $grid_gen_script $timestamp -1 0", $output0, $retval0);

  if ($retval0 < 0 || $retval4 < 0) {
    echo "# Error: generating grid data for '$timestamp'\n";
    return false;
  } // if
  
  $responseObject = $contourDataStore->retrieveContour($timestamp);
  if (!empty($responseObject)) {
      $fsCacheDetected = true;
      $responseObject = json_decode($responseObject, true);
  }
*/

  if ($useLatestDataWhenFail) {
    $timestamp = $queryManager->latestContourAvailableTime($timestamp);
    $responseObject = $contourDataStore->retrieveContour($timestamp);
    if (!empty($responseObject)) {
        $fsCacheDetected = true;
        $responseObject = json_decode($responseObject, true);
    }
  }

  if ($responseObject === false) {
    //echo "# Error: no data for '$timestamp'\n";
    //return false;
    $responseObject['status'] = array(
        'type' => 'fail',
        'message' => "No data for timestamp $timestamp"
    );
  } // if

}

$stationData = array();
if ($fetchStationData) {
    $queryStart = microtime(true);
    $stationData = $queryManager->getOzoneForTimestamp($timestamp);
    $queryTime += microtime(true) - $queryStart;
}

if ($fetchStationData && !empty($stationData)) {
    for ($i = 0; $i < count($stationData); $i++) {
        $o3_flag = $stationData[$i][4];
        if ($o3_flag != 'K') {
            continue;
        }
        $lat = $stationData[$i][1];
        $lng = $stationData[$i][2];
        $o3 = floor($stationData[$i][3] + 0.5);
        $siteDesc = $stationData[$i][5];
        $responseObject['station'][] = array('lat' => $lat, 'lng'=>$lng, 'o3' => $o3, 'desc' => $siteDesc);
    }
}

$end = microtime(true);

if (!$fsCacheDetected) {
    // TODO: Do we want to store the result?
}

if ($requestType == 'json') {
    header('Content-Type: text/javascript');
    $mod_timestamp = $queryManager->getGridUpdatedTime($timestamp);
    header('Last-Modified: ' . gmdate("D, d M Y H:i:s", $mod_timestamp) .' GMT');
    $now = time();
    // cache up to 5 min (at 3, 8, 13, ... min) if grid was timestamp is within 6 hours
    if ( ($now - $timestamp) < 3600 * 6) {
      $expire_timestamp = floor(($now -180 + 300) / 300) * 300 + 180;
      $max_age = 300;
    } // if
    else {  // cache up to 1 hour otherwise
      $expire_timestamp = floor(($now -180 + 3600) / 300) * 300 + 180;
      $max_age = 3600;
    } // else
    header('Cache-Control: max-age=' . $max_age);
    header('Expires: ' . gmdate("D, d M Y H:i:s", $expire_timestamp) .' GMT');
    //echo "timestamp = '$timestamp' (".date($timestamp).")". " ; mod_timestamp = '$mod_timestamp' ; now = '$now' ; expire_timestamp = '$expire_timestamp'\n";
    if (!empty($callback)) {
        echo "{$callback}(".json_encode($responseObject).')';
    }
    elseif ($use_jsonp) {
        echo "contourData$timestamp(".json_encode($responseObject).')';
    }
    else {
        echo json_encode($responseObject);
    }
    exit(0);
}

if (empty($_REQUEST['debug']) || $_REQUEST['debug'] != 1) {
    print ("Execution Time:" . ($end - $start));
    echo "\nUsing Band Schema '".$bandHelper->getSchemeId()."': "
        . implode(",", $ozoneBand);
    print "\nTime taken by query manager: $queryTime sec\n";
    exit(0);
}

include_once('ozonemaps/php-helpers/dochead.inc');

echo "<pre>Using Band Schema '".$bandHelper->getSchemeId()."' " . implode(",", $ozoneBand)
     . " (ppbv)\n";
echo "Using step resolution $stepSize\n";
print ("Execution Time : " . ($end - $start) . "sec\n");
print "Time taken for query manager: $queryTime sec\n";
print "Outfile [$outFile]";
print "</pre>";
if (!empty($outFile)) {
    $retval = 0;
    system("cp $outFile ./testout.png", $retval);
    if ($retval == 0) {
        print "<img src='testout.png' "
            ."style='position:absolute;top:10px;right:50px' />";
    }
    system("cp /tmp/binaryoutk.png ./testoutk.png", $retval);
    if ($retval == 0) {
        print "<img src='testoutk.png' "
            ."style='position:absolute;top:10px;right:150px' />";
    }
}

print '<div id="panel">
            <button id="prev" onclick="prev()">5 Min Ago</button>
            <button id="next" onclick="next()">After 5 Min</button>
            &nbsp;&nbsp;&nbsp;&nbsp;
            <button id="toggleM" onclick="toggleMarker()">Toggle Marker</button>
            <span style="display:inline-block; padding-left:20px" id="dispTime"></span>
      </div>';
print '<div id="map_canvas"></div>';
include_once('ozonemaps/php-helpers/doctail.inc');


function printObj($o) {
    echo "<pre>";
    var_dump($o);
    echo "</pre>";
}

function prepareResponseObject($contourLines, $timestamp) {
    global $bandHelper;
    $responseHelper = new ResponseHelper();
    return $responseHelper->getResponseObject($contourLines, $timestamp, $bandHelper);
}
?>
