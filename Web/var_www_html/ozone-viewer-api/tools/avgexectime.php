#!/usr/bin/php
<?php
    $bandScheme = 0;
    if (isset($argv[1])) {
        $bandScheme = intval($argv[1]);
    }
    $timestamp = 1243602000;
    $last = 1243731600;
    $step = 300;

    $count = 0;
    $totalTime = 0;
    $countHTTPSuccess = 0;
    while ($timestamp < $last) {
        if ($count % 20 == 0) {
            echo "\n";
        }
        echo $count . " ";
        $curlHandle = curl_init();
        curl_setopt($curlHandle, CURLOPT_URL, "http://ibreathe.hnet.uh.edu/test/ozonemaps/interpolation/contour_dev.php?type=html&timestamp=$timestamp&bandschema=$bandScheme");
        curl_setopt($curlHandle, CURLOPT_FRESH_CONNECT, true);
        curl_setopt($curlHandle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_setopt($curlHandle, CURLOPT_USERPWD, "guest:myguest");
        curl_setopt($curlHandle, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curlHandle, CURLOPT_TIMEOUT, 15);
        $data = curl_exec($curlHandle);
        if (curl_getinfo($curlHandle, CURLINFO_HTTP_CODE) == 200) {
            $countHTTPSuccess++;
            $parts = split("\n", $data);
            $data = $parts[0];
            $parts = split(":", $data);
            $totalTime += doubleval($parts[1]);
        }
        curl_close($curlHandle);
        $count++;
        $timestamp += $step;
        //if ($count >= 10) {
        //    break;
        //}
    }

    if ($count == 0) $count = 1; // prevent divide by zero
    echo "\nReport:\n";
    echo "Average Server Time for Contour Fetch: " . $totalTime/$count . "\n";
    echo "Total number of HTTP requests: $count\n";
    echo "Total successful HTTP requests: $countHTTPSuccess\n";
?>
