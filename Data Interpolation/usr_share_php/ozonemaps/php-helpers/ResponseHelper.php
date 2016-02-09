<?php
require_once('BSplineHelper.php');
class ResponseHelper {
    const LV_TRUE = 500;
    const LV_FALSE = 1000;

    public function getResponseObject($contourLines, $timestamp, $bandHelper) {
        $responseObject = array();
        $identity = false;
        $bSplineHelper = new BSplineHelper($identity);
        // contourLines[1] has the information of labels. So, ignore if response
        // has size 1, it means there is no contour
        if (empty($contourLines) || count($contourLines) == 1) {
            $responseObject['status'] = array(
                'type' => 'fail',
                'message' => "No data for timestamp $timestamp"
            );
        } else {
            $n = count($contourLines) - 1;
            $responseObject['status'] = array(
                'type' => 'success',
                'message' => "$n contour lines for $timestamp (tentative msg)"
            );

            // integer labels and what they mean
            $responseObject['labels'] = $bandHelper->getDesc(); //include('../labels.inc');

            $indexes = $contourLines[$n];
            for ($i=0; $i<$n; $i++) {
                $regionId = intval($indexes[$i][0]);
                if ($regionId > 0) {
                    $responseObject['data'][] = array(
                        'label_id' => $regionId,
                        'polygon' => $bSplineHelper->getBSpline($contourLines[$i])
                    );
                } else {
                    $isLargest = false;
                    $li = count($contourLines[$i]) - 1;
                    $lastItem = $contourLines[$i][$li];

                    if ($lastItem[0] == self::LV_TRUE) {
                        unset($contourLines[$i][$li]);
                        $isLargest = true;
                    } elseif ($lastItem[0] == self::LV_FALSE) {
                        unset($contourLines[$i][$li]);
                        $isLargest = false;
                    }

                    $responseObject['valley'][] = array(
                        'label_id' => abs($regionId),
                        'isLargest' => $isLargest,
                        'polygon' => $bSplineHelper->getBSpline($contourLines[$i])
                    );
                }
            }
            $responseObject['timestamp'] = $timestamp;
        }

        // send appropriate json response
        return $responseObject;
    }
}
?>
