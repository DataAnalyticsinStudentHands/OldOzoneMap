#!/usr/bin/php
<?php
    $toolsPath="/var/www/html/test/ozonemaps/api/tools";
    if (empty($argv)) {
        echo "To be executed in server cli";
        exit(0);
    }
    //$timestamp = 1335848400; //May 1, 2012
    //$last = 1337489940;      // May 19, 2012
    $timestamp = 1333256400;    // April 1, 2012
    $last = 1335848340;         // April 30, 2012

    $step = 300;             // 5 minutes

    $counter = 0;
    while ($timestamp < $last) {
        echo("$toolsPath/calculategrid.php $timestamp -1 0\n");
        system("$toolsPath/calculategrid.php $timestamp -1 0");
        echo("$toolsPath/calculategrid.php $timestamp -1 4\n");
        system("$toolsPath/calculategrid.php $timestamp -1 4");
        $timestamp += $step;
        $counter++;
        //if ($counter >= 10) {
            // testing
        //    break;
        //}
    }

    echo "done!! $counter data points\n";
?>
