#!/usr/bin/php
<?php
    $apiEndPoint = "http://ibreathe.hnet.uh.edu/test/ozonemaps/api/contour.php";
    $bandScheme = 0;
    if (isset($argv[1])) {
        $bandScheme = intval($argv[1]);
    }
    $timestamp = 1335848400; //May 1, 2012
    $last = 1337489940;      // May 19, 2012
    //$last = 1336395600;         // May 7, 2012 8:00
    $step = 300;

    $count = 0;
    $totalTime = 0;
    $successCount = 0;
    $failureCount = 0;
    $noDataTs = array();
    $countHTTPSuccess = 0;
    while ($timestamp < $last) {
        if ($count % 20 == 0) {
            echo "\n";
        }
        echo $count . " ";
        $start = microtime(true);
        $curlHandle = curl_init();
        curl_setopt($curlHandle, CURLOPT_URL, "$apiEndPoint?type=json&timestamp=$timestamp&bandschema=$bandScheme");
        curl_setopt($curlHandle, CURLOPT_FRESH_CONNECT, true);
        curl_setopt($curlHandle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_setopt($curlHandle, CURLOPT_USERPWD, "guest:myguest");
        curl_setopt($curlHandle, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curlHandle, CURLOPT_TIMEOUT, 15);
        $data = curl_exec($curlHandle);
        if (curl_getinfo($curlHandle, CURLINFO_HTTP_CODE) == 200) {
            $countHTTPSuccess++;
            $totalTime += microtime(true) - $start;
            $parsedData = json_decode($data, true);
            if ($parsedData['status']['type'] == 'success') {
                $successCount++;
                if (empty($parsedData['data'])) {
                    $noDataTs[] = $timestamp;
                }
            } else {
                $failureCount++;
            }
        }
        curl_close($curlHandle);
        $timestamp += $step;
        $count++;
        //if ($count >= 10) {
        //    break;
        //}
    }

    echo "\nReport:\n";
    echo "Average Time for API call: " . $totalTime/$count . "\n";
    echo "Total number of hits: $count\n";
    echo "Total successful HTTP requests: $countHTTPSuccess\n";
    echo "Call That returned contour data: $successCount\n";
    echo "Call that didn't return contour data: $failureCount\n";
    echo "No Data count: " . count($noDataTs) . "\n";
    if (count($noDataTs) > 0) {
        foreach($noDataTs as $oneTs) {
            echo "$oneTs\n";
        }
    }
?>
