<?php
$stepSize   = 0.01;
$aqiBase    = 75;

// CAUTION: Do not change these reference values.
// constant grid extent pre-calculated as max and min of all ozone stations
// These values stand as fixed size. If the calculated grid size differ
// (probably due to addition of extra stations), then few grid indices
// can be stored as negative values in the db.

	// min/max lat/lon of current stations
	// min(lat)  | max(lat)  | min(lon)   | max(lon)   |
	// 29.010833 | 30.743889 | -95.806111 | -94.787222

// new min/max lat/lon -- extend 0.1 all direction
$latmin     = 28.93;
$latmax     = 30.46;
$lngmin     = -95.91;
$lngmax     = -94.68;

// Fixed rectangular reference that covers texas area.
$gridReference = array('latmin' => $latmin, 'latmax' => $latmax,
                       'longmin' => $lngmin, 'longmax' => $lngmax);

// Actual grid extent to be interplated. This can be configured.
// This can be different than above. However, care should be taken
// that gridExtent snaps to gridReference. This can be done by ensuring
// that following gridExtent has min and max values that are derived as
// some integral offset of $step from above gridReference. e.g.
/*$gridExtent = array('latmin'=>$latmin-10*$stepSize,
                      'latmax'=>$latmax+10*$stepSize,
                      'longmin'=>$lngmin-10*$stepSize,
                      'longmax' => $lngmax+10*$stepSize);
*/
$gridExtent = array('latmin' => $latmin, 'latmax' => $latmax,
                    'longmin' => $lngmin, 'longmax' => $lngmax);
?>
