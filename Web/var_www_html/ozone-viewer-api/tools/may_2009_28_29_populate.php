#!/usr/bin/php
<?php
    $toolsPath="/var/www/html/test/ozonemaps/api/tools";
    if (empty($argv)) {
        echo "To be executed in server cli";
        exit(0);
    }
    $timestamp = 1237482000;    // 2009 March 19, 12:00pm
    $last = 1237507200;         // 2009 March 19, 17:00pm

    //$timestamp = 1243602000; // 2009 May 29, 08:00
    //$last = 1243731600;      // 2009 May 30, 20:00

    //$timestamp = 1244221200;    //2009 June 5, 12:00pm
    //$last = 1244250000;          //2009 June 5, 20:00

    $step = 300;             // 5 minutes

    $counter = 0;
    while ($timestamp < $last) {
        echo("$toolsPath/calculategrid.php $timestamp -1 0");
        system("$toolsPath/calculategrid.php $timestamp -1 0");
        echo("$toolsPath/calculategrid.php $timestamp -1 1");
        system("$toolsPath/calculategrid.php $timestamp -1 1");
        echo("$toolsPath/calculategrid.php $timestamp -1 2");
        system("$toolsPath/calculategrid.php $timestamp -1 2");
        echo("$toolsPath/calculategrid.php $timestamp -1 3");
        system("$toolsPath/calculategrid.php $timestamp -1 3");
        $timestamp += $step;
        $counter++;
        //if ($counter >= 10) {
            // testing
        //    break;
        //}
    }

    echo "done!! $counter data points";
?>
