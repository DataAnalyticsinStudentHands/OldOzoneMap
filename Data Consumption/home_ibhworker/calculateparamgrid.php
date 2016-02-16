#!/usr/bin/php
<?php
ini_set("allow_url_fopen", 1);
//ini_set('memory_limit','1600M');
define("JAVA_DEBUG", 1);
define ("JAVA_PREFER_VALUES", 1);
//define("JAVA_LOG_LEVEL",2);
define("EPS1", 0.20);
$errMsg = '';
// if argument parameters empty, just redirect to index
if (empty($argv)) {
    header("Location:/ozonemaps/");
    exit(0);
} elseif (count($argv) < 4) {
    echo "Usage: " . $argv[0] . " <epoch> <param> <txnepoch> [<bandScheme>]\n";
    echo "Force: " . $argv[0] . " <epoch> <param> -1 [<bandScheme>]\n";
    exit(0);
}

date_default_timezone_set("America/Chicago"); // central time
require_once('http://localhost:8080/JavaBridgeTemplate621/java/Java.inc');
include_once('ozonemaps/php-helpers/ParamQueryManager.php');
include_once('ozonemaps/php-helpers/GridConfig.php');
include_once('ozonemaps/php-helpers/ParamContourCacheHelper.php');
include_once('ozonemaps/php-helpers/DiscreteBandHelper.php');
include_once('ozonemaps/php-helpers/ResponseHelper.php');

if (is_numeric($argv[1]) && is_numeric($argv[3])) {
    $timestamp = getBoundaryTimestamp($argv[1]);
    if (doubleval($argv[3]) == -1) {
        $txnAt = -1;
    } else {
        $txnAt = getBoundaryTimestamp($argv[3]);
    }
	$param = $argv[2];
} else {
    echo "Usage: " . $argv[0] . " <epoch> <param> <txnepoch> [<bandScheme>]\n";
    echo "Force: " . $argv[0] . " <epoch> <param> -1 [<bandScheme>]\n";
    exit(0);
}

$bandScheme = !empty($argv[4]) && is_numeric($argv[4]) ? intval($argv[4]) : 0;
$start = microtime(true);
$grid = array();
$queryTime = 0;
$bandHelper = new DiscreteBandHelper(DiscreteBandHelper::LABEL_TYPE_BAND, $bandScheme);
$ozoneBand = $bandHelper->getBand();
$bandHashMap = new Java("java.util.HashMap");
foreach($ozoneBand as $key => $val) {
    $bandHashMap->put($key, doubleval($val));
}
$gridExtentMap = new Java("java.util.HashMap");
foreach($gridExtent as $key => $val) {
    $gridExtentMap->put($key, doubleval($val));
}
$driver = new Java('LatLongInterpolation_testing.LatLngDriver', $bandHashMap, $gridExtentMap);
$driver->setWriteDebugImages(false);

$queryTime = 0;

// query based on timestamp
$readOnly = false;
// disable gzip -- TMH 2012/07/13
$useGzip = false;
// pad with JSONP -- TMH 2012/07/20
$useJSONP = true;
// keep history -- TMH 2012/08/31
$keepHistory = false;

// grid Updated time
$updatedTime = -1;

$queryManager = new QueryManager($readOnly);
$contourDataStore = new ContourCacheHelper($useGzip,$bandHelper->getSchemeId());

// Check if $txnAt for $timestamp is older than specified right now,
// then only proceed. Otherwise just exit from here
// Honour force flag if is set
$lastTxnAt = $txnAt;
if ($txnAt >= 0) {
    $lastTxnAt = $queryManager->getGridUpdatedTime($timestamp, $param);
}

if ($txnAt >= 0 && $lastTxnAt >= $txnAt) {
    echo "Grid last updated with txn stamp [$lastTxnAt],"
         . " more recent than / equal to [$txnAt]\n";
    echo "Use force write if it was intended to forcefully update data";
    exit(0);
}

$queryStart = microtime(true);
$allData = $queryManager->getDataForWindBasedInterpolation($timestamp, 6, false, $param);
if (empty($allData["{$param}Values"])) {
    echo "No data available for interpolation algorithm for $timestamp\n";
    exit(0);
}

$queryTime += microtime(true) - $queryStart;


$writeToGridStatus = true; // true if band scheme is non zero
if ($bandHelper->getSchemeId() == 0) {
    //echo "pre-r \n";
    //echo java_inspect($driver);
    //var_dump($allData);
    //print_r(java_values($driver->gridExtent));
    $r = $driver->getGridData($allData["{$param}Stations"],
        $allData['windStations'], $allData["{$param}Values"],
        $allData['windSpeed'], $allData['windDirection'], $stepSize
    );
    //var_dump(java_invoke(0, "getValues", array($r)));
    //var_dump($driver->__call("getValues",array($r)));
    //echo $stepSize;
    //echo java_inspect($r);
    //echo "post-r\n";
    //var_dump($r);
    //print_r($r);
    //echo JAVA_PREFER_VALUES;
    //var_dump($r);
    //var_dump(java_is_null($r));
    $grid = java_values($r);
    //echo "post-r-dump\n\n";
    $queryStart = microtime(true);
    //echo "prewritegrid\n";
    $writeToGridStatus = $queryManager->writeGridToDB($grid, $timestamp,
                         $gridReference, java_values($driver->gridExtent), $param);
    if ($writeToGridStatus) {
        $paramCount = $queryManager->getGridParamCount($timestamp, $param);
        $prevCount = apc_fetch("_total{$param}_".($timestamp-300));
        if ($paramCount !== false && $prevCount !== false) {
            if ((1+EPS1)*$prevCount < $ozoneCount) {
                error_log("ERROR_METRIC: Potential spike in some monitor for time: $timestamp");
            }
            apc_store("_total{$param}_$timestamp", $ozoneCount);
        }

    }
    $queryTime += microtime(true) - $queryStart;
}
if ($writeToGridStatus && false) {
    $r = $driver->getContours(
        $allData["{$param}Stations"], $allData['windStations'],
        $allData["{$param}Values"], $allData['windSpeed'],
        $allData['windDirection'], $stepSize
    );
    $contourLines = java_values($r);
    $updatedTime = time();
    $ret = $contourDataStore->saveContour($timestamp,  getSerializedJson($contourLines, $timestamp, $updatedTime), $param, $useJSONP, $keepHistory);
    $queryManager->setGridUpdatedTime($timestamp, $param, $txnAt, $updatedTime);
    if (!$ret) {
        echo 'ERROR: ' . $contourDataStore->getLastError() . "\n";
    }
    echo "Contour Saved to file!!\n";

    // write grid data file
    //   create grid data array; same formate as output from loadGrid()
/*    if (! empty($grid)) {
      $grid_array = array();
      $grid_array['timestamp'] = $timestamp;
      $grid_array['gen_time'] = $updatedTime;
      $grid_array['gridExtent'] = $gridExtent;
      $grid_array['grid'] = $grid;

      $gridDataJSON = json_encode($grid_array);

      $ret = $contourDataStore->saveGridJSON($timestamp, $gridDataJSON, $useJSONP);
      if (!$ret) {
          echo 'ERROR: ' . $contourDataStore->getLastError() . "\n";
      }
    }
*/

    $gridData = $queryManager->loadGrid($timestamp, $gridReference, $param);

    if (empty($gridData['timestamp'])) {
      echo "# Error: No grid data available for $timestamp\n";
      exit(1);
    }

    // convert to JSON format
    $gridDataJSON = json_encode($gridData);

    $ret = $contourDataStore->saveGridJSON($timestamp, $gridDataJSON, $param, $useJSONP, $keepHistory);
    if (!$ret) {
        echo 'ERROR: ' . $contourDataStore->getLastError() . "\n";
    }

    //print_r($grid_array);

} else if (!$writeToGridStatus) {
    echo "else\n";
    echo $queryManager->getLastError();
}

$end = microtime(true);

//echo "Timestamp: $timestamp\n";
//echo "Latest txn stamp $txnAt\n";
//echo "BandScheme: " . $bandHelper->getSchemeId() . "\n";
//echo "Using step resolution $stepSize\n";
print ("Execution Time : " . ($end - $start) . "sec\n");
//print "Time taken by query manager: $queryTime sec\n";
//print "Extent\n";
//printObj(java_values($driver->gridExtent));

// Utility Functions.. Once this utility function grows large, they can be
// pinched and put to a separate file
function printObj($o) {
    echo "<pre>";
    var_dump($o);
    echo "</pre>";
}

function getBoundaryTimestamp($timestamp) {
    $month = date('m', $timestamp);
    $day = date('d', $timestamp);
    $year = date('Y', $timestamp);
    $hour = date('H', $timestamp);
    $min = date('i', $timestamp);
    $min = intval($min) - intval($min) % 5;
    $timestamp = mktime($hour, $min, 0, $month, $day, $year);
    return $timestamp;
}

function getSerializedJson($contourLines, $timestamp, $updatedTime) {
    global $bandHelper;
    global $txnAt;
    $responseHelper = new ResponseHelper();
    $responseObject = $responseHelper->getResponseObject($contourLines, $timestamp, $bandHelper);
    $responseObject['gen_time'] = $updatedTime;
    $responseObject['txnAt'] = $txnAt;

    // send appropriate json response
    return json_encode($responseObject);
}
?>
