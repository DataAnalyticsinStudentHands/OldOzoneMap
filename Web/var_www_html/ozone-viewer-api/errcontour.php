<?php
date_default_timezone_set("America/Chicago"); // central time
require_once('http://localhost:8082/JavaBridge/java/Java.inc');
include_once('nebula/GridConfig.php');
include_once('nebula/DiscreteBandHelper.php');
include_once('nebula/ResponseHelper.php');

if (isset($_REQUEST['step']) && is_numeric($_REQUEST['step'])) {
    $stepSize = doubleval($_REQUEST['step']);
}

$callback = '';
if (!empty($_REQUEST['callback'])) {
    $callback = preg_replace('/[^][._a-zA-Z0-9]/', '', $_REQUEST['callback']);
}

/* THIS IS THE PLACE TO COPY AND REPLACE THE ERROR.
 * TODO: In future, this can be made to pick up data from log file
 * e.g.
 * $mean = 0.03;
 * $sd = 8.1;
 * $errorData = array(
 *    array('lat'=>24.01,'lng'=>-95.06,'err'=>-1.3),
 *    array('lat'=>24.01,'lng'=>-94.81,'err'=>1.3),
 * );
*/
$mean = 0.030824799771861;
$sd =  8.2215397459119;
$errorData = array(
array('lat'=>29.767778,'lng'=>-95.220556,'err'=>3.1523227157094),
array('lat'=>29.901111,'lng'=>-95.326111,'err'=>-1.0475492028042),
array('lat'=>29.8025,'lng'=>-95.125556,'err'=>-3.330358693467),
array('lat'=>30.039444,'lng'=>-95.673889,'err'=>-5.6845705942671),
array('lat'=>29.67,'lng'=>-95.128333,'err'=>4.9314107089023),
array('lat'=>29.583056,'lng'=>-95.015556,'err'=>11.975587925373),
array('lat'=>29.695833,'lng'=>-95.499167,'err'=>6.1993052439426),
array('lat'=>30.350278,'lng'=>-95.425,'err'=>-0.50945693033005),
array('lat'=>29.735,'lng'=>-95.315556,'err'=>5.9673320138165),
array('lat'=>29.520278,'lng'=>-95.3925,'err'=>-15.576781731388),
array('lat'=>29.733611,'lng'=>-95.2575,'err'=>5.6419135738253),
array('lat'=>29.828056,'lng'=>-95.284167,'err'=>-2.0219354020273),
array('lat'=>29.625556,'lng'=>-95.267222,'err'=>-10.677533050181),
array('lat'=>29.834167,'lng'=>-95.489167,'err'=>-0.80128899406423),
array('lat'=>29.623889,'lng'=>-95.474167,'err'=>0.9634820547676),
array('lat'=>29.723333,'lng'=>-95.635833,'err'=>0.69201248860064),
array('lat'=>29.752778,'lng'=>-95.350278,'err'=>2.7293573410396),
array('lat'=>29.686389,'lng'=>-95.294722,'err'=>14.007796747266),
array('lat'=>29.858611,'lng'=>-95.160278,'err'=>-1.9951046512302),
array('lat'=>29.733056,'lng'=>-94.984722,'err'=>0.32552256164833),
array('lat'=>29.920833,'lng'=>-95.068333,'err'=>-2.2303608036604),
array('lat'=>29.833056,'lng'=>-95.656944,'err'=>-1.6420805476536),
array('lat'=>29.655278,'lng'=>-95.009722,'err'=>-1.2631435010567),
array('lat'=>29.810556,'lng'=>-95.806111,'err'=>-5.8295075243668),
array('lat'=>29.961944,'lng'=>-95.235,'err'=>1.5342552372681),
array('lat'=>29.761667,'lng'=>-95.538056,'err'=>3.5576685110262),
array('lat'=>30.057778,'lng'=>-95.061389,'err'=>-1.1581515708418),
array('lat'=>29.548889,'lng'=>-95.185278,'err'=>1.437628103942),
array('lat'=>29.583333,'lng'=>-95.105,'err'=>-3.9570207612077),
array('lat'=>29.765278,'lng'=>-95.181111,'err'=>7.2800023090914),
array('lat'=>29.821389,'lng'=>-94.99,'err'=>-0.4449357072028),
array('lat'=>29.148889,'lng'=>-95.765,'err'=>-15.167996661992),
array('lat'=>29.313611,'lng'=>-95.201389,'err'=>-27.700133762404),
array('lat'=>29.402222,'lng'=>-94.946389,'err'=>-0.81810350286317),
array('lat'=>29.7175,'lng'=>-95.341389,'err'=>-7.7885850593922),
array('lat'=>29.574167,'lng'=>-95.649722,'err'=>5.9061477841335),
array('lat'=>29.387778,'lng'=>-95.041389,'err'=>2.2206798830341),
array('lat'=>30.236111,'lng'=>-95.483056,'err'=>-5.0733736094543),
array('lat'=>30.058056,'lng'=>-94.978056,'err'=>1.9917954763566),
array('lat'=>29.764444,'lng'=>-95.077778,'err'=>4.835651552672),
array('lat'=>29.043611,'lng'=>-95.472778,'err'=>23.087472993983),
array('lat'=>29.254444,'lng'=>-94.861111,'err'=>7.5752686258743)
);

$allData = array();
$allData['ozoneStations'] = array();
$allData['ozoneValues'] = array();
$allData['windStations'] = array();
$allData['windSpeed'] = array();
$allData['windDirection'] = array();

$min = 99999; // some large value
$count1=0;
foreach ($errorData as $oneErrorData) {
    $count1++;
    $allData['ozoneStations'][] = array($oneErrorData['lat'], $oneErrorData['lng']);
    // this sets only one trail points
    $allData['ozoneValues'][0][] = $oneErrorData['err'];
    $allData['windSpeed'][0][] = -1.0;
    $allData['windDirection'][0][] = -1.0;
    if ($oneErrorData['err'] < $min) {
        $min = $oneErrorData['err'];
    }
}

$allData['windStations'] = $allData['ozoneStations'];

$bandSchema = array();
if ($min < 0) {
    $offset = abs($min);
    for ($i=0; $i < count($allData['ozoneValues'][0]); $i++) {
        $allData['ozoneValues'][0][$i] += $offset;
    }
    $bandSchema = array($offset+$mean-2*$sd, $offset+$mean-$sd, $offset+$mean, $offset+$mean+$sd, $offset+$mean+2*$sd);
} else {
    $bandSchema = array($mean-2*$sd, $mean-$sd, $mean, $mean+$sd, $mean+2*$sd);
}

$bandHelper = new DiscreteBandHelper(DiscreteBandHelper::LABEL_TYPE_BAND, $bandSchema);
$ozoneBand = $bandHelper->getBand();
$bandHashMap = new Java("java.util.HashMap");
foreach($ozoneBand as $key => $val) {
    $bandHashMap->put($key, doubleval($val));
}

$start = microtime(true);
$outFile = '';
$queryTime = 0;
$responseObject = false;
if ($responseObject === false) {
    $outFile = '/tmp/binaryout.png';
    $driver = new Java('LatLongInterpolation.LatLngDriver', $bandHashMap);

    $r = $driver->getContours(
        $allData['ozoneStations'],$allData['windStations'],
        $allData['ozoneValues'], $allData['windSpeed'],
        $allData['windDirection'], $stepSize
    );
    $responseObject = prepareResponseObject(java_values($r), '1233444000');
}

if (!empty($allData['ozoneStations'])) {
    for ($i = 0; $i < count($allData['ozoneStations']); $i++) {
        $lat = $errorData[$i]['lat'];
        $lng = $errorData[$i]['lng'];
        $o3 = $allData['ozoneValues'][0][$i];
        $siteDesc = "($lat,$lng)|{$errorData[$i]['err']}";
        $responseObject['station'][] = array('lat' => $lat,'lng'=>$lng, 'o3' => $o3, 'desc' => $siteDesc);
    }
}

$end = microtime(true);

include_once('nebula/dochead.inc');

echo "<pre>Using Band Schema '".$bandHelper->getSchemeId()."' " . implode(",", $ozoneBand) . "\n";
echo "Min value: $min\n";
echo "Mean : $mean\n";
echo "Sample standard deviation: $sd\n";
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

print '<div id="panel">
            <button id="prev" onclick="prev()">5 Min Ago</button>
            <button id="next" onclick="next()">After 5 Min</button>
            &nbsp;&nbsp;&nbsp;&nbsp;
            <button id="toggleM" onclick="toggleMarker()">Toggle Marker</button>
            <span style="display:inline-block; padding-left:20px" id="dispTime"></span>
      </div>';
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
