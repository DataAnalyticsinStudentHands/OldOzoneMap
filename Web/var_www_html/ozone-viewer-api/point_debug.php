<?php
define("MAX_SNAPSHOTS", 10);  // 10 hours
$interval = 60*60;          // 1 hour interval (in seconds)
date_default_timezone_set("America/Chicago"); // central time
require_once('http://localhost:8082/JavaBridge/java/Java.inc');
include_once('nebula/QueryManager.php');
include_once('nebula/DiscreteBandHelper.php');
include_once('nebula/GridConfig.php');

$errMsg = '';
if (isset($_REQUEST['step']) && is_numeric($_REQUEST['step'])) {
    $stepSize = doubleval($_REQUEST['step']);
}

$timestamp = '';
if (isset($_REQUEST['timestamp']) && is_numeric($_REQUEST['timestamp'])) {
    $timestamp = getBoundaryTimestamp($_REQUEST['timestamp']);
}

// if timestamp is empty, try to find the latest using txn table
if (empty($timestamp)) {
    $timestamp = $queryManager->latestContourAvailableTime();
}

$timestamp2 = $timestamp; // initialize to $timestamp
if (isset($_REQUEST['timestamp2']) && is_numeric($_REQUEST['timestamp2'])) {
    $timestamp2 = getBoundaryTimestamp($_REQUEST['timestamp2']);
}

if ($timestamp2 < $timestamp) {
    $tmp = $timestamp;
    $timestamp = $timestamp2;
    $timestamp2 = $tmp;
}

if ($timestamp2 - $timestamp >= MAX_SNAPSHOTS*$interval) {
    $timestamp2 = $timestamp + (MAX_SNAPSHOTS-1)*$interval;
    $errMsg = "timestamp2 clipped to $timestamp2";
}

$requestType = 'json';
if (isset($_REQUEST['type'])) {
    if (strtolower($_REQUEST['type']) == 'json') {
        $requestType = 'json';
    } elseif (strtolower($_REQUEST['type']) == 'html') {
        $requestType = 'html';
    }
}

// parse lat/lng pairs
$latlon = !empty($_REQUEST['latlng'])
    ? explode(":", $_REQUEST['latlng'])
    : array();
$pointsOfInterest = array();
foreach($latlon as $oneLatLon) {
    $onePoint = explode(',', $oneLatLon);
    if (is_numeric($onePoint[0]) && is_numeric($onePoint[1])) {
        $pointsOfInterest[] = array(doubleval($onePoint[0]),
                                    doubleval($onePoint[1]));
    }
}

$bandSchema = 0;
if (!empty($_REQUEST['bandschema'])) {
    $bandSchema = intval($_REQUEST['bandschema']);
}

// Request parsing is completed.. Act according to what has been requested
if ($requestType == 'json' && empty($pointsOfInterest)) {
    sendJsonResponse(array(), $timestamp, $timestamp2,
         "No latlon specified in request");
    exit(0);
}

$bandHelper = new DiscreteBandHelper(DiscreteBandHelper::LABEL_TYPE_BAND, $bandSchema);
$ozoneBand = $bandHelper->getBand();
$bandHashMap = new Java("java.util.HashMap");
foreach($ozoneBand as $key => $val) {
    $bandHashMap->put($key, doubleval($val));
}

$queryManager = new QueryManager();
$start = microtime(true);
$grid = array();
$queryTime = 0;
$driver = new Java('LatLongInterpolation.LatLngDriver', $bandHashMap);
for ($t = $timestamp; $t <= $timestamp2; $t += $interval) {
    $queryStart = microtime(true);
    $loadedData = $queryManager->getPointData($t, $pointsOfInterest, $gridReference);
    $queryTime += microtime(true) - $queryStart;
    if (!empty($loadedData)) {
        $latlngData = array();
        // count($pointsOfInterest) should be same as count($loadedData)
        for($i=0; $i<count($pointsOfInterest); $i++) {
            $labelId = $bandHelper->getLabelId($loadedData[$i]['o3']);
            $gridPoint = $loadedData[$i]['lat'] . ':' . $loadedData[$i]['lng'];
            $latlngData[] = array(
                'label_id' => $labelId,
                'lat' => $pointsOfInterest[$i][0],
                'lng' => $pointsOfInterest[$i][1],
                'attr' => array('ozone_level' => $loadedData[$i]['o3'],
                            'exp' => $loadedData[$i]['exp'],
                            'gridpoint' => "$gridPoint")
            );
        }
        $data[] = array('timestamp' => $t, 'data' => $latlngData);
    } else {
        // query based on timestamp
        // need to do the following for each of $timestamp to $timestamp2
        $queryStart = microtime(true);
        $allData = $queryManager->getDataForWindBasedInterpolation($t, 6);
        if (empty($allData['ozoneValues'])) {
            continue;
        }
        $queryTime += microtime(true) - $queryStart;

        $r = $driver->getGridData($allData['ozoneStations'],
            $allData['windStations'], $allData['ozoneValues'],
            $allData['windSpeed'], $allData['windDirection'], $stepSize
        );
        $grid = java_values($r);
        $extent = java_values($driver->gridExtent);
        $latmin = $extent['latmin'];
        $latmax = $extent['latmax'];
        $longmin = $extent['longmin'];
        $longmax = $extent['longmax'];

        $latlngData = array();
        for($i=0; $i<count($pointsOfInterest); $i++) {
            $lat = $pointsOfInterest[$i][0];
            $lng = $pointsOfInterest[$i][1];
            $isInExtent = ($lat >= $latmin) && ($lat < $latmax)
                   && ($lng >= $longmin) && ($lng < $longmax);
            $ozoneValue = -1;
            $explanation = '';
            $gridPoint = '';
            if ($isInExtent) {
                $latIdx = floor(($lat - $latmin)/$stepSize + 0.5);
                $lngIdx = floor(($lng - $longmin)/$stepSize + 0.5);
                $ozoneValue = floor($grid[$latIdx][$lngIdx] + 0.5);
                $explanation = 'IN';
                $gridPoint = ($latmin+$latIdx*$stepSize) . ':'
                            . ($longmin+$lngIdx*$stepSize);
            } else {
                $explanation = 'lat/lng out of interpolation boundary';
            }

            $labelId = $bandHelper->getLabelId($ozoneValue);
            $latlngData[] = array(
                'label_id' => $labelId,
                'lat' => $pointsOfInterest[$i][0],
                'lng' => $pointsOfInterest[$i][1],
                'attr' => array('ozone_level' => $ozoneValue,
                            'exp' => $explanation,
                            'gridpoint' => "$gridPoint")
            );
        }
        $data[] = array('timestamp' => $t, 'data' => $latlngData);
    }
}

$end = microtime(true);
//printObj($extent);
//printObj($grid);

if ($requestType == 'json') {
    sendJsonResponse($data, $timestamp, $timestamp2, $errMsg);
    exit(0);
}

echo "<pre>Timestamp: $timestamp, Timestamp2: $timestamp2\n";
echo "Using step resolution $stepSize\n";
print ("Execution Time : " . ($end - $start) . "sec\n");
print "Time taken by query manager: $queryTime sec\n";
print "</pre>";
print "Extent<br/>";
//printObj(java_values($driver->gridExtent));
print "Points of interest<br/>";
printObj($pointsOfInterest);
print "Data<br/>";
printObj($data);


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

function sendJsonResponse($data, $timestamp, $timestamp2, $msg='') {
    global $bandHelper;
    header('Content-Type: text/javascript');

//    // add header for last-modified
//    $mod_timestamp = $queryManager->getGridUpdatedTime($timestamp);
//    header('Last-Modified: ' . gmdate("D, d M Y H:i:s", $mod_timestamp) .' GMT');
//    // add header for expires
//    $now = time();
//    // cache up to 5 min (at 3, 8, 13, ... min) if grid was timestamp is within 6 hours
//    if ( ($now - $timestamp) < 3600 * 6) {
//      $expire_timestamp = floor(($now -180 + 300) / 300) * 300 + 180;
//    } // if
//    else {  // cache up to 1 hour otherwise
//      $expire_timestamp = floor(($now -180 + 3600) / 300) * 300 + 180;
//    } // else
//    header('Expires: ' . gmdate("D, d M Y H:i:s", $expire_timestamp) .' GMT');
//    echo "timestamp = '$timestamp' (".date($timestamp).")". " ; mod_timestamp = '$mod_timestamp' ; now = '$now' ; expire_timestamp = '$expire_timestamp'\n";

    $responseObject = array();
    if (empty($data)) {
        $responseObject['status'] = array(
            'type' => 'fail',
            'message' => !empty($msg) ? $msg :"No data for timestamp $timestamp"
        );
    } else {
        $responseObject['status'] = array(
            'type' => 'success',
        );

        // integer labels and what they mean
        $responseObject['labels'] = $bandHelper->getDesc();
        $responseObject['snapshot'] = $data;
    }

    // send appropriate json response
    $callback = '';
    if (!empty($_REQUEST['callback'])) {
        $callback = preg_replace('/[^][._a-zA-Z0-9]/', '', $_REQUEST['callback']);
    }

    if (!empty($callback)) {
        echo $callback . '(' . json_encode($responseObject) . ')';
    } else {
        echo json_encode($responseObject);
    }
}
?>
