#!/usr/bin/php
<?php
// if argument parameters empty, just redirect to index
if (empty($argv)) {
    header("Location:/test/ozonemaps/");
    exit(0);
} elseif (count($argv) != 2) {
    echo "Usage: " . $argv[0] . " <epoch>\n";
    exit(0);
}
date_default_timezone_set("America/Chicago"); // central time
include_once('nebula/QueryManager.php');

$queryManager = new QueryManager();

$timestamp = $argv[1];
if (is_numeric($timestamp)) {
    $month = date('m', $timestamp);
    $day = date('d', $timestamp);
    $year = date('Y', $timestamp);
    $hour = date('H', $timestamp);
    $min = date('i', $timestamp);
    $min = intval($min) - intval($min) % 5;
    $timestamp = mktime($hour, $min, 0, $month, $day, $year);
} else {
    echo "Numeric timestamp expected\n";
    exit(0);
}

$allData = $queryManager->getDataForWindBasedInterpolation($timestamp, 6);

$spc = "    ";

// ozoneStations test data
echo "{$spc}public double[][] ozoneStationTestData() {\n";
echo "{$spc}{$spc}double[][] d = {\n";
$i = 0;
$count = count($allData['ozoneStations']);
foreach($allData['ozoneStations'] as $oneLatLng) {
    $comma = ($i == $count-1) ?  '' : ',';
    echo $spc.$spc.$spc.'{'.$oneLatLng[0].','.$oneLatLng[1].'}'."$comma\n";
    $i++;
}
echo $spc.$spc.'};'."\n";
echo $spc.$spc.'return d;'."\n";
echo $spc . '}'."\n";


// Wind Stations test data
echo "{$spc}public double[][] windStationTestData() {\n";
echo "{$spc}{$spc}{$spc}double[][] d = {\n";
$i = 0;
$count = count($allData['windStations']);
foreach($allData['windStations'] as $oneLatLng) {
    $comma = ($i == $count-1) ?  '' : ',';
    echo $spc.$spc.$spc.'{'.$oneLatLng[0].','.$oneLatLng[1].'}'."$comma\n";
    $i++;
}
echo $spc.$spc.'};'."\n";
echo $spc.$spc.'return d;'."\n";
echo $spc . '}'."\n";

// Ozone values test data
echo "{$spc}public double[][] ozoneValuesTestData() {\n";
echo "{$spc}{$spc}double[][] d = {\n";
$i = 0;
$count = count($allData['ozoneValues']);
foreach($allData['ozoneValues'] as $oneTrail) {
    $comma = ($i == $count-1) ?  '' : ',';
    echo $spc.$spc.$spc.'{'.implode(',', $oneTrail).'}'."$comma\n";
    $i++;
}
echo $spc.$spc.'};'."\n";
echo $spc.$spc.'return d;'."\n";
echo $spc . '}'."\n";

// Wind speed test data
echo "{$spc}public double[][] windSpeedTestData() {\n";
echo "{$spc}{$spc}double[][] d = {\n";
$i = 0;
$count = count($allData['windSpeed']);
foreach($allData['windSpeed'] as $oneTrail) {
    $comma = ($i == $count-1) ?  '' : ',';
    echo $spc.$spc.$spc.'{'.implode(',', $oneTrail).'}'."$comma\n";
    $i++;
}
echo $spc.$spc.'};'."\n";
echo $spc.$spc.'return d;'."\n";
echo $spc . '}'."\n";

// Wind Direction test data
echo "{$spc}public double[][] windDirectionTestData() {\n";
echo "{$spc}{$spc}double[][] d = {\n";
$i = 0;
$count = count($allData['windDirection']);
foreach($allData['windDirection'] as $oneTrail) {
    $comma = ($i == $count-1) ?  '' : ',';
    echo $spc.$spc.$spc.'{'.implode(',', $oneTrail).'}'."$comma\n";
    $i++;
}
echo $spc.$spc.'};'."\n";
echo $spc.$spc.'return d;'."\n";
echo $spc . '}'."\n";
?>
