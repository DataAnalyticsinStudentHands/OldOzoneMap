<?php
date_default_timezone_set("America/Chicago"); // central time
require_once('http://localhost:8082/JavaBridge/java/Java.inc');
include_once('nebula/GridConfig.php');
include_once('nebula/DiscreteBandHelper.php');
include_once('nebula/ResponseHelper.php');
include_once('nebula/QueryManager.php');

$monthNames = array('stub', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
if (isset($_REQUEST['step']) && is_numeric($_REQUEST['step'])) {
    $stepSize = doubleval($_REQUEST['step']);
}

$callback = '';
if (!empty($_REQUEST['callback'])) {
    $callback = preg_replace('/[^][._a-zA-Z0-9]/', '', $_REQUEST['callback']);
}

$monthStartEpoch = 0;
$monthEndEpoch = 0;
$monthDays = 0;
if (!empty($_REQUEST['month']) && !empty($_REQUEST['year']) && is_numeric($_REQUEST['month']) && is_numeric($_REQUEST['year'])) {
    $year = intval($_REQUEST['year']);
    $month = intval($_REQUEST['month']);
    $monthDays = cal_days_in_month(CAL_GREGORIAN, $month, $year);
} else {
    $year = date('Y');
    $month = date('m');
    $monthDays = cal_days_in_month(CAL_GREGORIAN, $month, $year);
}
$monthStartEpoch = mktime(0, 0, 0, $month, 1, $year);// month values 1,2,3..
$monthEndEpoch = mktime(23, 59, 59, $month, $monthDays, $year);

$queryManager = new QueryManager();
$allData = $queryManager->getMonthlyAvg($monthStartEpoch, $monthEndEpoch);

$bandSchema = 4;
$bandHelper = new DiscreteBandHelper(DiscreteBandHelper::LABEL_TYPE_BAND, $bandSchema);
$ozoneBand = $bandHelper->getBand();
$bandHashMap = new Java("java.util.HashMap");
foreach($ozoneBand as $key => $val) {
    $bandHashMap->put($key, doubleval($val));
}

$start = microtime(true);
$outFile = '';
$queryTime = 0;
$outFile = '/tmp/binaryout.png';
$driver = new Java('LatLongInterpolation.LatLngDriver', $bandHashMap);

$r = $driver->getContours(
    $allData['ozoneStations'],$allData['windStations'],
    $allData['ozoneValues'], $allData['windSpeed'],
    $allData['windDirection'], $stepSize
);
$responseObject = prepareResponseObject(java_values($r), $monthStartEpoch);

if (!empty($allData['ozoneStations'])) {
    for ($i = 0; $i < count($allData['ozoneStations']); $i++) {
        $lat = $allData['ozoneStations'][$i][0];
        $lng = $allData['ozoneStations'][$i][1];
        $o3 = $allData['ozoneValues'][0][$i];
        $siteDesc = "($lat,$lng)|{$allData['ozoneValues'][0][$i]}";
        $responseObject['station'][] = array('lat' => $lat,'lng'=>$lng, 'o3' => $o3, 'desc' => $siteDesc);
    }
}

$end = microtime(true);

include_once('nebula/dochead.inc');

echo "<pre>Using Band Schema '".$bandHelper->getSchemeId()."' " . implode(",", $ozoneBand) . "\n";
print ("Execution Time : " . ($end - $start) . "sec\n");
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

print '<div id="panel">';
print '<form method="post" style="display:inline-block">';
print '<select name="month">';
foreach (array(1,2,3,4,5,6,7,8,9,10,11,12) as $m) {
    $monthName = $monthNames[$m];
    print "<option value=\"$m\">$monthName</option>";
}
print '</select>';

print '<select name="year">';
for ($y=2000; $y<=date('Y'); $y++) {
    print "<option value=$y>$y</option>";
}
print '</select>';
print '<input type="Submit" value="Submit" />';
print '</form>';
print '<button id="toggleM" onclick="toggleMarker()">Toggle Marker</button>
       <span style="display:inline-block; padding-left:20px" id="dispTime"></span>';
print  '</div>';
print '<div id="map_canvas"></div>';
include_once('nebula/doctail.inc');


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
