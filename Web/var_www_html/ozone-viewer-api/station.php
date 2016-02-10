<?php
    $start = microtime(true);
    date_default_timezone_set("America/Chicago"); // central time
    include_once('nebula/QueryManager.php');
    include_once('nebula/DiscreteBandHelper.php');

    // Currently: take system time and round it off to lower 5 mins
    // if not specified from _REQUEST
    // In Future: return the last data available (lastn type of query), but
    // we would require to set some threshold for that. Or alternately, we
    // would need a polling algorithm that searches for last data availability
    $timestamp = time();
    $month = date('m', $timestamp);
    $day = date('d', $timestamp);
    $year = date('Y', $timestamp);
    $hour = date('H', $timestamp);
    $min = date('i', $timestamp);
    $min = intval($min) - intval($min) % 5;
    $timestamp = mktime($hour, $min, 0, $month, $day, $year);

    $requestType = 'json';
    if (isset($_REQUEST['type'])) {
        if (strtolower($_REQUEST['type']) == 'json') {
            $requestType = 'json';
        } elseif (strtolower($_REQUEST['type']) == 'html') {
            $requestType = 'html';
        }
    }

    $callback = '';
    if (!empty($_REQUEST['callback'])) {
        $callback = $_REQUEST['callback'];
    }

    $bandSchema = 0;
    if (!empty($_REQUEST['bandschema'])) {
        $bandSchema = intval($_REQUEST['bandschema']);
    }

    $bandHelper = new DiscreteBandHelper(DiscreteBandHelper::LABEL_TYPE_BAND, $bandSchema);
    $queryManager = new QueryManager();

    //db connected.. do remaining stuff
    $ozoneData = array();

    if (!empty($_REQUEST['timestamp']) && is_numeric($_REQUEST['timestamp'])) {
        $timestamp = $_REQUEST['timestamp'];
        $month = date('m', $timestamp);
        $day = date('d', $timestamp);
        $year = date('Y', $timestamp);
        $hour = date('H', $timestamp);
        $min = date('i', $timestamp);
        $min = intval($min) - intval($min) % 5;
        $timestamp = mktime($hour, $min, 0, $month, $day, $year);
    }

    $ozoneData = $queryManager->getOzoneForTimestamp($timestamp);
    if (count($ozoneData) > 0) {
        $timestamp = $ozoneData[0][0]; // epoch from data obtained from db
    }

    if (count($ozoneData) > 0) {
        $responseData = array(
            'status' => 'success',
            'labels' => $bandHelper->getDesc(),
            'timestamp' => $timestamp
        );
        for ($i = 0; $i < count($ozoneData); $i++) {
            $lat = $ozoneData[$i][1];
            $lng = $ozoneData[$i][2];
            $o3 = floor($ozoneData[$i][3] + 0.5);
            $o3_flag = $ozoneData[$i][4];
            $siteDesc = $ozoneData[$i][5];
            if ($o3_flag != 'K') {
                continue;
            }

            $label_id = $bandHelper->getLabelId($o3);
            $responseData['data'][] = array(
                'label_id' => $label_id,
                'lat' => $lat,
                'lng' => $lng,
                'flag' => $o3_flag,
                'value' => $o3,
                'site_desc' => $siteDesc
            );
        }
        // if there wasn't even a single data with K flag, status=fail
        if (empty($responseData['data'])) {
            $responseData['status'] = 'fail';
            unset($responseData['labels']);
            $responseData['message'] = 'No data with K flag';
            $responseData['data'] = $ozoneData;
        }
    } else {
        $responseData = array(
            'status' => 'fail',
            'message' => 'No data available',
            'timestamp' => $timestamp
        );
    }

    $end = microtime(true);

    if ($requestType == 'json') {
        header('Content-Type: text/javascript');
        if (!empty($callback)) {
            echo "{$callback}(".json_encode($responseData).')';
        } else {
            echo json_encode($responseData);
        }
    } else {
        echo "Total Time for script execution: " . ($end - $start);
        echo '<pre>';
        echo var_dump($responseData);
        echo '</pre>';
    }

    $queryManager->closeLink();
?>
