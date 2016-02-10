#!/usr/bin/php
<?php
$errMsg = '';
// if argument parameters empty, just redirect to index
if (empty($argv)) {
    header("Location:/test/ozonemaps/");
    exit(0);
} elseif (count($argv) < 2) {
    echo "Usage: " . $argv[0] . " <epoch>\n";
    exit(0);
}

date_default_timezone_set("America/Chicago"); // central time
require_once('http://localhost:8082/JavaBridge/java/Java.inc');
include_once('nebula/QueryManager.php');
include_once('nebula/GridConfig.php');
include_once('nebula/DiscreteBandHelper.php');

if (is_numeric($argv[1])) {
    $timestamp = getBoundaryTimestamp($argv[1]);
} else {
    echo "Usage: " . $argv[0] . " <epoch>\n";
    exit(0);
}

$bandScheme = 0;
$start = microtime(true);
$grid = array();
$bandHelper = new DiscreteBandHelper(DiscreteBandHelper::LABEL_TYPE_BAND, $bandScheme);
$ozoneBand = $bandHelper->getBand();
$bandHashMap = new Java("java.util.HashMap");
foreach($ozoneBand as $key => $val) {
    $bandHashMap->put($key, doubleval($val));
}
$driver = new Java('LatLongInterpolation.LatLngDriver', $bandHashMap);
$driver->setWriteDebugImages(false);

$queryTime = 0;

// query based on timestamp
$readOnly = true;
$queryManager = new QueryManager($readOnly);

$queryStart = microtime(true);
$trailPoints = 6;
$allData = $queryManager->getDataForWindBasedInterpolation($timestamp, $trailPoints);
if (empty($allData['ozoneValues'])) {
    echo "No data available for interpolation algorithm for $timestamp\n";
    exit(0);
}

$queryTime += microtime(true) - $queryStart;

// Interpolate grid by skipping one station at a time and check for delta
$li = count($allData['ozoneValues']) - 1;
$diff = array();
for ($st=0; $st < count($allData['ozoneStations']); $st++) {
    // copy data
    $omitStation = $allData['ozoneStations'][$st];
    $omitO3Value = $allData['ozoneValues'][$li][$st];

    // No point in comparing is station had no valid value for ozone
    if ($omitO3Value == -1) {
        continue;
    }

    $ozoneValues = $allData['ozoneValues'];
    $windSpeed = $allData['windSpeed'];
    $windDirection = $allData['windDirection'];
    for ($j=0; $j<=$li; $j++) {
        $ozoneValues[$j][$st] = -1;
    }
    echo implode(",", $ozoneValues[$li]) . "\n";
    // Do not set windSpeed and windDirection to -1.. Number of wind stations
    // reporting can be different from ozone stations. Leave wind systems as is
    $r = $driver->getGridData(
        $allData['ozoneStations'], $allData['windStations'],
        $ozoneValues, $windSpeed, $windDirection, $stepSize
    );
    $grid = java_values($r);

    // Find the value in grid closest to omitted station
    $gridExtent = java_values($driver->gridExtent);
    $latmin = $gridExtent['latmin'];
    $longmin = $gridExtent['longmin'];
    $latIdx = floor(($omitStation[0] - $latmin)/$stepSize + 0.5);
    if ($latIdx < 0) $latIdx = 0; // can go only as far as -1 due to double value rounding
    $longIdx = floor(($omitStation[1] - $longmin)/$stepSize + 0.5);
    if ($longIdx < 0) $longIdx = 0; // can go only as low as -1 due to double value rounding
    echo("{$omitStation[0]}: $latIdx, {$omitStation[1]}: $longIdx\n");
    $calculatedO3Value = $grid[$latIdx][$longIdx];
    $diff[$st] = $calculatedO3Value - $omitO3Value;
}

$end = microtime(true);
var_dump($gridExtent);
echo "Timestamp: $timestamp\n";
echo "Execution Time : " . ($end - $start) . "sec\n";
echo "Time taken by query manager: $queryTime sec\n";
$totalDiff = 0;
foreach($diff as $stationIdx => $errVal) {
    echo 'Lat: ' . $allData['ozoneStations'][$stationIdx][0]
        . ' Lng: ' . $allData['ozoneStations'][$stationIdx][1]
        . ' Diff: ' .  $errVal . "\n";
    $totalDiff += $errVal;
}

$mean = $totalDiff/count($diff);
$sqDeviation = 0;
foreach($diff as $stationIdx => $errVal) {
    $sqDeviation += ($errVal - $mean)*($errVal - $mean);
}
$sd = sqrt($sqDeviation/(count($diff)-1));
echo "Mean Error: $mean\n";
echo "Sample Standard Deviation: $sd\n";

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

?>
