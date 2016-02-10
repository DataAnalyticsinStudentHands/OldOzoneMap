#!/usr/bin/php
<?php
$errMsg = '';
// if argument parameters empty, just redirect to index
if (empty($argv)) {
    header("Location:/test/ozonemaps/");
    exit(0);
}

date_default_timezone_set("America/Chicago"); // central time
include_once('nebula/QueryManager.php');

if (isset($argv[1]) && isset($argv[2]) && is_numeric($argv[1]) && is_numeric($argv[2])) {
    $month = intval($argv[1]);
    $year = intval($argv[2]);
    $monthDays = cal_days_in_month(CAL_GREGORIAN, $month, $year);
} else {
    $year = date('Y');
    $month = date('m');
    $monthDays = cal_days_in_month(CAL_GREGORIAN, $month, $year);
}

$monthStartEpoch = mktime(0, 0, 0, $month, 1, $year);// month values 1,2,3..
$monthEndEpoch = mktime(23, 59, 59, $month, $monthDays, $year);

echo "Timestamps: $monthStartEpoch $monthEndEpoch";
$queryManager = new QueryManager();
$allData = $queryManager->getMonthlyAvg($monthStartEpoch, $monthEndEpoch);
if ($allData === false) {
    echo $queryManager->getLastError() . "\n";
    exit(0);
}

for ($i=0; $i<count($allData['ozoneStations']); $i++) {
    echo $allData['ozoneStations'][$i][0].','.$allData['ozoneStations'][$i][1]
        .','.$allData['ozoneValues'][0][$i]."\n";
}
?>
