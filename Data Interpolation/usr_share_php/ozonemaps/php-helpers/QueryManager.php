<?php
/*
 * This manages essential queries for accesing the ibreathe db. Since most of 
 * the queries to database will require similar tasks (e.g. looking through 
 * tables that span across calendar year, get data between particular time etc), * keeping them at one pace makes them manageable.
 */
include_once('db.php');
define ("EPS", .15);

class QueryManager {
    private $link;
    private $dbManager;
    private $lastError = '';

    function __construct($ro = true) {
        $dbManager = new DBManager();

        $this->link = $dbManager->getDataBaseLink($ro); // readonly
        if (!$this->link) {
            error_log('Error connecting to database: ' . mysql_error());
            die ('Error connecting to database');
        }
        if (!$dbManager->selectOzoneDB($this->link)) {
            error_log ('Error selecting ozone database: ' . mysql_error());
            die ('Error selecting ozone database');
        }

        $this->dbManager = $dbManager;
    }


    public function closeLink() {
        $this->dbManager->closeLinks();
    }

    public function getOzoneForTimestamp($timestamp) {
        if (!is_numeric($timestamp)) {
            $this->setLastError('Query Mgr: Invalid timestamp ' . $timestamp);
            return false;
        }

        // Identify table name/s to get data from
        $tblYear = gmdate('Y', $timestamp);
        $sql = "select epoch,lat,lon,o3,o3_flag,siteName,ibh_site_new.siteID
            from ibh_data_year_$tblYear,ibh_site_new
            where epoch=$timestamp and o3_flag='K'
            and ibh_site_new.siteID=ibh_data_year_$tblYear.siteID and ibh_site_new.region = 12";
        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: PointData Query Failed '
                . mysql_error());
            return false;
        }

        $allData = array();
        while ($line = mysql_fetch_array($result)) {
            $allData[] = array(
            $line[0], $line[1], $line[2],
            $line[3], $line[4], $line[5]);
        }
        return $allData;
    }

    /*
     * getOzoneForTimeRange
     * Get ozone data between time range
     * IN $beginTimestamp   --> reference time t1
     * IN $endTimestamp     --> reference time t2
     * OUT $allData         <-- specific format to reduce array keys
     *      allData[site1][0]=array(epoch, lat, long, o3, o3_flag, siteName)
     *      allData[site1][1]=array(epoch, lat, long, o3, o3_flag, siteName)
     *      allData[site2][0]=array(epoch, lat, long, o3, o3_flag, siteName)
     *      allData[site2][1]=array(epoch, lat, long, o3, o3_flag, siteName)
     *      etc...
     */
    public function getOzoneForTimeRange($beginTimestamp, $endTimestamp) {
        $allData = array();
        if (!is_numeric($beginTimestamp) || !is_numeric($endTimestamp)) {
            $this->setLastError('Query Mgr: Invalid timestamps [Begin:'
                . $beginTimestamp . '] [End:' . $endTimestamp . ']');
            return false;
        }

        $beginTimestamp = intval($beginTimestamp);
        $endTimestamp = intval($endTimestamp);
        if ($beginTimestamp > $endTimestamp) {
            $this->setLastError('Query Mgr: Begin Time less than End Time');
            return false;
        }

        // if too large data requested, fail.. Limit to 1 month
        if ($endTimestamp - $beginTimestamp > 31*24*60*60) {
            $this->setLastError('Query Mgr: Can not handle large date range');
            return false;
        }

        // Identify table name/s to get data from
        $beginTblYear = gmdate('Y', $beginTimestamp);
        $endTblYear = gmdate('Y', $endTimestamp);
        for ($yr = $beginTblYear; $yr <= $endTblYear; $yr++) {
            // If supplied end time was way beyond our database, simply break.
            // The last table year will generally be current year
            //error_log("Querying for year $yr");
            if ($yr > date('Y', time(0))) {
                break;
            }

            if ($yr == $beginTblYear && $yr == $endTblYear) {
                $start = $beginTimestamp;
                $end = $endTimestamp;
            } elseif ($yr == $beginTblYear) {
                $start = $beginTimestamp;
                $end = gmmktime(11, 59, 59, 12, 31, $yr); // December End
            } elseif ($yr == $endTblYear) {
                $start = gmmktime(0, 0, 0, 1, 1, $yr); // Jan Start
                $end = $endTimestamp;
            } else {
                $start = gmmktime(0, 0, 0, 1, 1, $yr);
                $end = gmmktime(11, 59, 59, 12, 31, $yr);
            }

            $sql = "select epoch,lat,lon,o3,o3_flag,siteName,ibh_site_new.siteID
                from ibh_data_year_$yr,ibh_site_new
                where epoch>$start and epoch<$end and o3_flag='K'
                and ibh_site_new.siteID=ibh_data_year_$yr.siteID and ibh_site_new.region = 12";
            $result = mysql_query($sql, $this->link);

            // combine the result to main array
            if ($result !== false) {
                while ($line = mysql_fetch_array($result)) {
                    $siteID = $line[6];
                    $allData[$siteID][] = array(
                        $line[0], $line[1], $line[2],
                        $line[3], $line[4], $line[5]);
                    unset($line);
                }
            } else {
                $this->setLastError(
                    'Query Mgr: Probable CombinedData Query Problem '
                    . mysql_error());
            }
            // Free mysql resource
            mysql_free_result($result);
        }

        return $allData;
    }

    /*
     * getOzoneForLastn
     * Get data ranging from $timestamp-$lastn till $timestamp
     * IN $timestamp    --> epoch timestamp of reference time
     * IN $lastn        --> number of seconds before reference time
     */
    public function getOzoneForLastn($timestamp, $lastn) {
        if (!is_numeric($timestamp) || !is_numeric($lastn)) {
            $this->setLastError('Query Mgr: Invalid timestamps [Timestamp:'
                . $timestamp . '] [Lastn:' . $lastn . ']');
            return false;
        }

        $beginTimestamp = intval($timestamp) - intval($lastn);
        $endTimestamp = intval($timestamp);
        return getOzoneForTimeRange($beginTimestamp, $endTimestamp);
    }

    /*
     * getOzoneForNextn
     * Get data ranging from $timestamp till $timestamp+$nextn
     * IN $timestamp    --> epoch timestamp of reference time
     * IN $nextn        --> number of seconds before reference time
     */
    public function getOzoneForNextn($timestamp, $nextn) {
        if (!is_numeric($timestamp) || !is_numeric($nextn)) {
            $this->setLastError('Query Mgr: Invalid timestamps [Timestamp:'
                . $timestamp . '] [Nextn:' . $nextn . ']');
            return false;
        }

        $beginTimestamp = intval($timestamp);
        $endTimestamp = intval($timestamp) + intval($nextn);
        return getOzoneForTimeRange($beginTimestamp, $endTimestamp);
    }


    /*
     * getDataForWindBasedInterpolation
     * Get data for a bunch of timestamps corresponding to number of trail
     * points. Only the last timestamp needs to be specified. The time stamps
     * for other trail points are calculated based on trailPoints
     * IN $timestamp
     * IN $trailPoints
     * OUT data array containing ozoneStations, windStations, ozneValues,
     *   windSpeed, windDirection
    **/
    public function getDataForWindBasedInterpolation($timestamp, $trailPoints,
                                                    $useLastAvailable = false) {
        if (!is_numeric($timestamp) || !is_numeric($trailPoints)) {
            $this->setLastError('Query Mgr: Invalid timestamp/trailPoints '
                 . "$timestamp/$trailPoints");
            return false;
        }

        if ($trailPoints >= 10) {
            // How many trail points to support to be decided, for now use 10
            $this->setLastError('Query Mgr: Supported max 10 trailpoints');
            return false;
        }

        $tblYear = gmdate('Y', $timestamp);
        $start = $timestamp - $trailPoints * 5 * 60;
        // $sql = "select ibh_site_new.siteID,epoch,lat,lon,o3,o3_flag,windspd,winddir
        //     from ibh_data_year_$tblYear,ibh_site_new
        //     where epoch>$start and epoch<=$timestamp and o3_flag='K'
        //     and ibh_site_new.siteID=ibh_data_year_$tblYear.siteID
        //     order by epoch asc";
        $sql = "select ibh_site_new.siteID,epoch,lat,lon,o3,o3_flag,windspd,winddir
            from ibh_data_year_$tblYear,ibh_site_new
            where epoch>$start and epoch<=$timestamp and o3_flag='K'
            and ibh_site_new.siteID=ibh_data_year_$tblYear.siteID and ibh_site_new.region = 12 order by epoch asc";
        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: problem executing query');
            //error_log($sql);
            return false;
        }
        if (mysql_num_rows($result) == 0 && $useLastAvailable) {
            $ret = $this->getLatestAvailableTimestamp('data');
            if ($ret !== false) {
                $timestamp = $ret;
                $tblYear = gmdate('Y', $timestamp);
                $start = $timestamp - $trailPoints * 5 * 60;
                $sql = "select ibh_site_new.siteID,epoch,lat,lon,o3,o3_flag,windspd,winddir
                    from ibh_data_year_$tblYear,ibh_site_new
                    where epoch>$start and epoch<=$timestamp and o3_flag='K'
                    and ibh_site_new.siteID=ibh_data_year_$tblYear.siteID and ibh_site_new.region = 12 order by epoch asc";
                $result = mysql_query($sql, $this->link);
                if ($result === false) {
                    $this->setLastError('Query Mgr: problem executing query');
                    return false;
                }
            } 
			else {
                return false;
            }
        }
        // cook the data right here
        $allData = array(
            'ozoneStations' => array(),
            'windStations' => array(),
            'ozoneValues' => array(),
            'windSpeed' => array(),
            'windDirection' => array(),
            'baseTimestamp' => 0
        );

        // Get all data in one array because we need to do a bit of processing
        $queryData = array();
        while($line = mysql_fetch_array($result)) {
            $queryData[] = $line;
        }

        // Find sites that have data and put them in array
        $ozoneSites = array();
        $windSites = array();
        $resultCount = count($queryData);
        for ($i = 0; $i < $resultCount; $i++) {
            $siteID = $queryData[$i][0];
            $o3_flag = $queryData[$i][5];
            $lat = doubleval($queryData[$i][2]);
            $lon = doubleval($queryData[$i][3]);
            //if ($o3_flag == 'K' && !isset($ozoneSites[$siteID])) {
			if (!isset($ozoneSites[$siteID])) {
                $ozoneSites[$siteID] = count($ozoneSites); // to know the index
                $allData['ozoneStations'][] = array($lat, $lon);
            }

            if (!isset($windSites[$siteID])) {
                $windSites[$siteID] = count($windSites);
                $allData['windStations'][] = array($lat, $lon);
            }
        }

        // initialization for wind and ozone values to -1
        $initCount = count($allData['windStations']);
        for ($i=0; $i<$initCount; $i++) {
            $allData['windSpeed'][0][$i] = -1;
            $allData['windDirection'][0][$i] = -1;
        }

        $initCount = count($allData['ozoneStations']);
        for ($i=0; $i<$initCount; $i++) {
            $allData['ozoneValues'][0][$i] = -1;
        }
        for ($i=1; $initCount>0 && $i<$trailPoints; $i++) {
            $allData['windSpeed'][$i] = $allData['windSpeed'][0];
            $allData['windDirection'][$i] = $allData['windDirection'][0];
            $allData['ozoneValues'][$i] = $allData['ozoneValues'][0];
        }

	//echo "# debug: resultCount = '$resultCount'\n";

        $processingTimestamp = null;
        $trailIndex = -1;
        //$availCount_array = array();
		$availCount = array();
        $availCountTotal = 0;
		for ($i = 0; $i < $resultCount; $i++) {
			$siteID = $queryData[$i][0];
			$epoch = $queryData[$i][1];
			$lat = $queryData[$i][2];
			$lon = $queryData[$i][3];
			$o3 = empty($queryData[$i][4]) ? -1.0 : $queryData[$i][4];
			$o3_flag = $queryData[$i][5];
			$windspd = empty($queryData[$i][6]) ? -1.0 : $queryData[$i][6];
			$winddir = empty($queryData[$i][7]) ? -1.0 : $queryData[$i][7];

			//echo "# debug: [$i] epoch = $epoch\n";

			if ($o3 != -1) {
				if (empty($availCount['T'.$epoch])) {
					$availCount['T'.$epoch] = 1;
				}
				else {
					$availCount['T'.$epoch]++;
				}
				$availCountTotal++;
			}
			if (empty($processingTimestamp) || $epoch != $processingTimestamp) {
				$trailIndex++;
				$processingTimestamp = $epoch;
			}

			if (isset($ozoneSites[$siteID])) {
				$siteIndex = $ozoneSites[$siteID];
				$allData['ozoneValues'][$trailIndex][$siteIndex]=doubleval($o3);
			}

			if (isset($windSites[$siteID])) {
				$siteIndex = $windSites[$siteID];
				$allData['windSpeed'][$trailIndex][$siteIndex]
					= doubleval($windspd);
				$allData['windDirection'][$trailIndex][$siteIndex]
					= doubleval($winddir);
			}
		}

		$validTrails = 0;
		$str_counts = '';
		foreach ($availCount as $key => $val) {
			$str_counts .= $val . ',';
			//if ($availCount[$id] >= 20) {
			if ($val >= 20) {
				$validTrails++;
			}
		}

        $allData['baseTimestamp'] = $processingTimestamp;

        // cleanup initialized -1 if no data for any trial index
        for ($i=$trailIndex+1; $i < $trailPoints; $i++) {
            unset($allData['windSpeed'][$i]);
            unset($allData['windDirection'][$i]);
            unset($allData['ozoneValues'][$i]);
        }

        //if ($availCount < 20) {
        //    error_log("ERROR_DDENSITY: Low data density in frame of $trailPoints trails for timestamp: $timestamp");
        //}
        if ($validTrails <= 2) {
            error_log("ERROR_DDENSITY: Low data density in frame of $trailPoints trails ($validTrails valid; '". rtrim($str_counts, ",") . "') for timestamp: $timestamp");
            //error_log("ERROR_DDENSITY: Low data density in frame of $trailPoints trails ($validTrails valid; '$str_counts') for timestamp: $timestamp");
	    return false;
        }

        // TODO: Commenting out error based on previous value as upper limit
        /*$li = count($allData['ozoneValues']) - 1;
        if ($li>1) {
            for ($i=0; $i<count($allData['ozoneStations']); $i++) {
                if ($allData['ozoneValues'][$li-1][$i] != -1
                        && $allData['ozoneValues'][$li][$i] != -1
                        && (1.0+EPS)*$allData['ozoneValues'][$li-1][$i]
                            < $allData['ozoneValues'][$li][$i]) {
                    error_log("ERROR_METRIC: Suspicious ozone site"
                        . " at time: $timestamp, location: "
                        . implode('|', $allData['ozoneStations'][$i])
                        . ", o3prev: " . $allData['ozoneValues'][$li-1][$i]
                        . ", o3: " . $allData['ozoneValues'][$li][$i]
                    );
                    for ($j=0; $j<=$li; $j++) {
                        $allData['ozoneValues'][$j][$i] = -1;
                    }
                }
            }
        }*/

        mysql_free_result($result);
        return $allData;
    }

    public function getMonthlyAvg($monthStartEpoch, $monthEndEpoch) {
        $tblYear = gmdate('Y', $monthStartEpoch);
        if ($monthStartEpoch > $monthEndEpoch) {
            $tmp = $monthStartEpoch;
            $monthStartEpoch = $monthEndEpoch;
            $monthEndEpoch = $tmp;
        }
        if ($monthEndEpoch - $monthStartEpoch > 31*24*60*60) {
            $this->setLastError("Query Mgr: Larger than month time span");
            return false;
        }

        $sql = "select s.siteId,s.lat,s.lon,T.A
                from
                    (select siteId, avg(o3) as A from ibh_data_year_$tblYear
                         where epoch>=$monthStartEpoch
                         and epoch<=$monthEndEpoch
                         and o3_flag='K' group by siteId
                    ) as T
                    join ibh_site_new as s on T.siteId=s.siteId
 					where ibh_site_new.region = 12";
        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: problem executing query');
            //error_log($sql);
            return false;
        }
        $allData = array(
            'ozoneStations' => array(),
            'windStations' => array(),
            'ozoneValues' => array(),
            'windSpeed' => array(),
            'windDirection' => array(),
            'baseTimestamp' => 0
        );

        while($line = mysql_fetch_array($result)) {
            $allData['ozoneStations'][] = array($line[1], $line[2]);
            $allData['ozoneValues'][0][] = $line[3];
            $allData['windSpeed'][0][] = -1.0;
            $allData['windDirection'][0][] = -1.0;
        }

        // populate wind stations but set wind values to -1. This is just to
        // counter the buggy DataScanner in interpolation class that can not
        // yet handle empty arrays
        $allData['windStations'] = $allData['ozoneStations'];
        return $allData;
    }

    /**
     * writeGridToDB
     *
     * Given a m x n grid, write it down to database table. The indices are
     * calculated based on configured grid extent and actual grid extent. So,
     * the indices can be negative if new stations have been added to the
     * system. Also, if there were fewer stations available at the time for
     * which data is interpolated, the actual grid extent can be smaller than
     * configured extent. This can cause the minimum indices to start from
     * larger value than 0. The adjustment made in this function needs to be
     * matched by point data function as well as loadGrid function.
     *
     * IN $grid - two dimensional array indexed with integer
     * IN $timestamp - the timestamp which this grid belongs to
     *               (assumed to be at a boundary of 5 mins, no validation done)
     * IN $refExt - Reference grid frame extent
     * IN $realExt - Grid Extent calculated by interpolation algorithm
    **/
    public function writeGridToDB($grid, $timestamp, $refExt, $realExt) {
        $step = 0.01;   // currently, works only for ~1km grid
        $deltaLat = floor(0.5+($realExt['latmin'] - $refExt['latmin'])/$step);
        $deltaLng = floor(0.5+($realExt['longmin'] - $refExt['longmin'])/$step);

        // if delta is smaller than step size, ignore
        if (abs($realExt['latmin'] - $refExt['latmin']) < $step) {
            $deltaLat = 0;
        }
        if (abs($realExt['longmin'] - $refExt['longmin']) < $step) {
            $deltaLng = 0;
        }

        $year = date('Y', $timestamp);
        $latIdxMax = count($grid);
        $lngIdxMax = count($grid[0]);

        // If table does not exist, create the table
        if (false === $this->checkAndCreateTable($year)) {
            return false;
        }

        // remove grid from previous entry if any
        $sql = "delete from interpolation_step01_$year where epoch=$timestamp";
        if (mysql_query($sql, $this->link) === false) {
            $this->setLastError('Query Mgr: writeGridToDB can not delete older data '
                        . mysql_error());
            return false;
        }
		
		$sql = "insert into interpolation_step01_$year values ";
		$sqlGridVals = array();
        for ($i=0; $i<$latIdxMax; $i++) {
            for ($j=0; $j<$lngIdxMax; $j++) {
                $o3val = round($grid[$i][$j]);
                // store into table.. "on duplicate" works only for mysql 5.0+
                $li = $i + $deltaLat;
                $lj = $j + $deltaLng;
                // $sql = "insert into interpolation_step01_$year
                //          values($timestamp, $li, $lj, $o3val, 0)
                //          on duplicate key update o3=$o3val";
                // $result = mysql_query($sql, $this->link);
                // if ($result === false) {
                //     $this->setLastError('Query Mgr: writeGridToDB Query Failed '
                //         . mysql_error());
                //     return false;
                // }
				array_push($sqlGridVals, "($timestamp, $li, $lj, $o3val, 0)");
            }
        }
		$sql .= join(",", $sqlGridVals) . " on duplicate key update o3=$o3val";
		$result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: writeGridToDB Query Failed '
                . mysql_error());
            return false;
        }
		$this->aggregateGridDataAtTimestamp($timestamp);
        return true;
    }

    /**
     *
    **/
    public function checkAndCreateTable($tblYear) {
        $tableName = "interpolation_step01_$tblYear";
        $mar1 = mktime(00, 00, 00, 3, 1, $tblYear); // Mar 1
        $may1 = mktime(00, 00, 00, 5, 1, $tblYear);
        $jul1 = mktime(00, 00, 00, 7, 1, $tblYear);
        $sep1 = mktime(00, 00, 00, 9, 1, $tblYear);
        $nov1 = mktime(00, 00, 00, 11, 1, $tblYear);
        $sql = "
            CREATE TABLE if not exists `$tableName` (
            `epoch` int(11) NOT NULL DEFAULT '0',
            `latindex` smallint(6) NOT NULL DEFAULT '0',
            `lngindex` smallint(6) NOT NULL DEFAULT '0',
            `o3` tinyint(3) unsigned DEFAULT '0',
            `flag` bit(1) DEFAULT NULL,
            PRIMARY KEY (`epoch`,`latindex`,`lngindex`)
        ) ENGINE=MyISAM DEFAULT CHARSET=latin1
        PARTITION BY RANGE ( epoch )
        (PARTITION m1 VALUES LESS THAN ($mar1) ENGINE = MyISAM,
        PARTITION m2 VALUES LESS THAN ($may1) ENGINE = MyISAM,
        PARTITION m3 VALUES LESS THAN ($jul1) ENGINE = MyISAM,
        PARTITION m4 VALUES LESS THAN ($sep1) ENGINE = MyISAM,
        PARTITION m5 VALUES LESS THAN ($nov1) ENGINE = MyISAM,
        PARTITION m6 VALUES LESS THAN MAXVALUE ENGINE = MyISAM);
        ";

        if(false === mysql_query($sql, $this->link)) {
			echo 'QueryMgr: checkAndCreateTable failed ' . mysql_error();
            $this->setLastError('QueryMgr: checkAndCreateTable failed ' . mysql_error());
            return false;
        }
        return true;
    }

    /**
     * getPointData
     *
     * get ozone values for specified points from m x n grid stored in db
     * as epoch,latIndex,lngIndex,o3Value tuples.
     * IN - $timestamp timestamp for which grid data is asked for
     * IN - $refGridExtent rectangle frame of configured lat and lng
     * IN - $useLatestAvailabile flag to use lastest available data
     * OUT - array of o3 values for lat/lng points with flag indicating whether
     *       the point is inside or outside actual gridExtent of interpolation
     *
    **/
    public function getPointData($timestamp, $poi, $refExt, $useLatestAvailabile = -1) {
        $ret = array();
        $step = 0.01;
        $stepName = 'step01';
        $year = date('Y', $timestamp);

        $maxMinIndexes = $this->getMaxMinIndexes($timestamp);
        if ($maxMinIndexes === false) {
          if ($useLatestAvailabile == 1) {
            $timestamp = $this->getLatestAvailableTimestamp('grid', $timestamp);
            $maxMinIndexes = $this->getMaxMinIndexes($timestamp);
            if ($maxMinIndexes === false) {
              return false;
            }
          }
          else {
            return false;
          }
        }
        $latMinIdx = $maxMinIndexes['latMinIdx'];
        $latMaxIdx = $maxMinIndexes['latMaxIdx'];
        $lngMinIdx = $maxMinIndexes['lngMinIdx'];
        $lngMaxIdx = $maxMinIndexes['lngMaxIdx'];
        $dLat = $latMaxIdx - $latMinIdx + 1; // +1 for inclusive difference
        $dLng = $lngMaxIdx - $lngMinIdx + 1;

        // calculate actual grid extent using the above information
        $latMin = $latMinIdx*$step + $refExt['latmin'];
        $latMax = $dLat*$step + $latMin;
        $lngMin = $lngMinIdx*$step + $refExt['longmin'];
        $lngMax = $dLng*$step + $lngMin;

        // foreach lat/lng in the points of interest, find the latIndex
        // and lngIndex and create a query for each of them.
        for ($i=0; $i<count($poi); $i++) {
            $lat = $poi[$i][0];
            $lng = $poi[$i][1];
            $isInExtent = ($lat >= $latMin) && ($lat < $latMax)
                   && ($lng >= $lngMin) && ($lng < $lngMax);
            if ($isInExtent) {
                // stored LatIdx and stored LngIdx
                $sLatIdx = floor(0.5+($lat - $refExt['latmin'])/$step);
                $sLngIdx = floor(0.5+($lng - $refExt['longmin'])/$step);

                // if sLatIdx and sLngIdx rounds off to just one count above
                // max indexes, set them at boundary, which are the closest
                // available data in stored grid.
                if ($sLatIdx == $latMaxIdx + 1) {
                    $sLatIdx = $latMaxIdx;
                }
                if ($sLngIdx == $latMaxIdx + 1) {
                    $sLngIdx = $lngMaxIdx;
                }
                $sql="select latindex,lngindex,o3
                    from interpolation_{$stepName}_$year
                    where epoch=$timestamp
                         and latindex=$sLatIdx
                         and lngindex=$sLngIdx";
                $result = mysql_query($sql, $this->link);
                if ($result === false) {
                    $this->setLastError('Query Mgr: getPointData Query Failed '
                        . mysql_error());
                    return false;
                }
                // there has to be exactly one line in the result at this point
                $line = mysql_fetch_array($result);
                $ret[] = array(
                    'lat' => $refExt['latmin'] + $sLatIdx*$step,
                    'lng' => $refExt['longmin'] + $sLngIdx*$step,
                    'o3' => $line[2], 'exp' => 'IN'
                );
            } else {
                $ret[] = array(
                    'lat' => 0.0, 'lng' => 0.0,
                    'o3' => -1, 'exp' => 'OUT'
                );
            }
        }
        return $ret;
    }

    /**
     * getPointData_from_json
     *
     * get ozone values for specified points from m x n grid stored in db
     * as epoch,latIndex,lngIndex,o3Value tuples.
     * IN - $timestamp timestamp for which grid data is asked for
     * IN - $refGridExtent rectangle frame of configured lat and lng (not used)
     * OUT - array of o3 values for lat/lng points with flag indicating whether
     *       the point is inside or outside actual gridExtent of interpolation
     *
    **/
    public function getPointData_from_json($timestamp, $poi) {
        $ret = array();
        $step = 0.01;
        $year = date('Y', $timestamp);
        $month = date('m', $timestamp);
        $day = date('d', $timestamp);
	$top_dir = '/mnt/ibreathe/gridData';
	$json_fname = "$top_dir/$year/$month/$day/gridData_$timestamp".".js";
	//$json_fname = "/tmp/gridJSON.1341118800.js";

	if (! file_exists($json_fname)) {
          $this->setLastError("get Point Data from JSON ($timestamp): grid JSON file not found");
	  return false;
	}

	$gridJSON_str = file_get_contents($json_fname);
	$gridJSON_str = preg_replace('/.+?({.+}).+/','$1',$gridJSON_str);
	$gridJSON = json_decode($gridJSON_str, true);

        #if ($gridJSON === false) {
        if (is_array($gridJSON) === false) {
          //echo "Error: get Point Data from JSON ($timestamp): bad JSON data<br>\n";
          $this->setLastError("get Point Data from JSON ($timestamp): bad JSON data");
          return false;
        }

        $latMin = $gridJSON['gridExtent']['latmin'];
        $latMax = $gridJSON['gridExtent']['latmax'];
        $lngMin = $gridJSON['gridExtent']['longmin'];
        $lngMax = $gridJSON['gridExtent']['longmax'];

	$latKeys = array_keys($gridJSON['grid']);
	$lngKeys = array_keys($gridJSON['grid'][0]);

	$latMinIdx = array_shift($latKeys);
	$latMaxIdx = array_pop($latKeys);
	$lngMinIdx = array_shift($lngKeys);
	$lngMaxIdx = array_pop($lngKeys);

	$gen_time = $gridJSON['gen_time'];

        //$dLat = count($gridJSON['grid']);
        //$dLng = count($gridJSON['grid'][0]);

        // foreach lat/lng in the points of interest, find the latIndex
        // and lngIndex and create a query for each of them.
        for ($i=0; $i<count($poi); $i++) {
            $lat = $poi[$i][0];
            $lng = $poi[$i][1];
            $isInExtent = ($lat >= $latMin) && ($lat < $latMax)
                   && ($lng >= $lngMin) && ($lng < $lngMax);
            if ($isInExtent) {
                // stored LatIdx and stored LngIdx
                $sLatIdx = floor(0.5+($lat - $latMin)/$step);
                $sLngIdx = floor(0.5+($lng - $lngMin)/$step);

                // if sLatIdx and sLngIdx rounds off to just one count above
                // max indexes, set them at boundary, which are the closest
                // available data in stored grid.
                if ($sLatIdx == $latMaxIdx + 1) {
                    $sLatIdx = $latMaxIdx;
                }
                if ($sLngIdx == $latMaxIdx + 1) {
                    $sLngIdx = $lngMaxIdx;
                }

                // there has to be exactly one line in the result at this point
                $value = $gridJSON['grid'][$sLatIdx][$sLngIdx];
                $ret[] = array(
                    'lat' => $latMin + $sLatIdx*$step,
                    'lng' => $lngMin + $sLngIdx*$step,
                    'o3' => $value, 'exp' => 'IN',
		    'gen_time' => $gen_time
                );
            } else {
		//echo "# debug: lat=$lat, lng=$lng ; latMin=$latMin, latMax=$latMax ; lngMin=$lngMin, lngMax=$lngMax<br>\n";
                $ret[] = array(
                    'lat' => 0.0, 'lng' => 0.0,
                    'o3' => -1, 'exp' => 'OUT',
		    'gen_time' => $gen_time
                );
            }
        } // for
        return $ret;
    }

    /**
     * loadGrid
     *
     * load m x n grid from database cache into memory.
     * IN - $timestamp timestamp for which grid is asked for
     * IN - $refGridExtent rectangle frame of configured lat and lng
     * OUT - array of real gridExtent and the 2 dimensional grid indexed from 0
    **/
    public function loadGrid($timestamp, $refGridExtent) {
        $step = 0.01;
        $year = date('Y', $timestamp);

        // get the max and min integral indexes for latitude and longitude
        $maxMinIndexes = $this->getMaxMinIndexes($timestamp);
        if ($maxMinIndexes === false) {
            return false;
        }
        $latMinIdx = $maxMinIndexes['latMinIdx'];
        $latMaxIdx = $maxMinIndexes['latMaxIdx'];
        $lngMinIdx = $maxMinIndexes['lngMinIdx'];
        $lngMaxIdx = $maxMinIndexes['lngMaxIdx'];
        $dLat = $latMaxIdx - $latMinIdx + 1; // +1 for inclusive difference
        $dLng = $lngMaxIdx - $lngMinIdx + 1;

        // calculate actual grid extent using the above information
        $latMin = $latMinIdx*$step + $refGridExtent['latmin'];
        $lngMin = $lngMinIdx*$step + $refGridExtent['longmin'];
        $realGridExtent = array(
            'latmin' => $latMin,
            'latmax' => $dLat*$step + $latMin,
            'longmin' => $lngMin,
            'longmax' => $dLng*$step + $lngMin
        );

        // now run the actual query to load the full data
        $sql="select latindex,lngindex,o3
              from interpolation_step01_$year
              where epoch=$timestamp";
        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: loadGrid Query Failed '
                . mysql_error());
            return false;
        }

        $grid = array(array()); // two dimensional array
        while ($line = mysql_fetch_array($result)) {
            $latIdx = $line[0];
            $lngIdx = $line[1];
            // array indexing seems to be really time consuming in PHP
            $grid[$latIdx - $latMinIdx][$lngIdx - $lngMinIdx] = intval($line[2]);
        }

        mysql_free_result($result);

        $gridUpdatedTime = $this->getGridUpdatedTime($timestamp);

        // return gridExtent as well as grid.. Array is returned by copy,
        // however, internally memcpy is used. So, this should not cause
        // much of performance issue
        return array('timestamp' => $timestamp, 'gen_time' => $gridUpdatedTime, 'gridExtent' => $realGridExtent, 'grid' => $grid);
    }

    /**
     * getMaxMinIndexes
     *
     * get max and min integral indexes of grid for a given timestamp. The min
     * indices can be negative if the actual grid extent used was larger than
     * the reference grid indices. This function looks only at the table that
     * stores grid data as epoch,latIndex,lngIndex,o3 tuples.
     * IN - timestamp
     * OUT - array of latMinIdx,lngMinIdx,latMaxIdx,lngMaxIdx
    **/
    private function getMaxMinIndexes($timestamp) {
        $step = 0.01;
        $stepName = 'step01';
        $year = date('Y', $timestamp);

        // first find latMinIdx, latMaxIdx, lngMinIdx, lngMaxIdx
        $sql = "select min(`latindex`) as latMinIdx,
                    min(`lngindex`) as lngMinIdx,
                    max(`latindex`) as latMaxIdx,
                    max(`lngindex`) as lngMaxIdx
                from interpolation_{$stepName}_$year where epoch=$timestamp";

        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: getMaxMinIndexes Query Failed '
                . mysql_error());
            return false;
        }

        $line = mysql_fetch_array($result);
        if (is_null($line[0]) || is_null($line[1]) || is_null($line[2]) || is_null($line[3])) {
            // no data in grid
            $this->setLastError('Query Mgr: getMaxMinIndexes not available');
            return false;
        }

        mysql_free_result($result);
        return array('latMinIdx' => $line[0],
                'lngMinIdx' => $line[1],
                'latMaxIdx' => $line[2],
                'lngMaxIdx' => $line[3]
        );
    }

    /**
     *
     * getGridOzoneCount
     *
     * Calculate sum of ozone over the grid if it is available in dataabase.
     * Otherwise return 0. This uses summation aggregation provided by mysql
     * and is thought to be faster than doing summation in PHP over double
     * dimensional grid
     *
    **/
    public function getGridOzoneCount($timestamp) {
        $tblYear = date('Y', $timestamp);
        $sql="select sum(o3)
              from interpolation_step01_$tblYear
              where epoch=$timestamp";
        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: getGridOzoneCount Query Failed '
                . mysql_error());
            return false;
        }
        $line = mysql_fetch_array($result);
        return $line[0];
    }

    /**
     *
     * getGridUpdatedTime
     *
     * Find the transaction time when grid was generated. This is different
     * than the time when grid was actually generated. The txn timestamp refers
     * to the time when fresh value was available for any of the stations for
     * a given epoch. This generally happens when station data was not
     * gathered at exact time (probably because it was in maintenance mode).
     *
    **/
    public function getGridUpdatedTime($timestamp) {
        //$sql = "select txnat from interpolation_step01_txn
        $sql = "select updatedat from interpolation_step01_txn
                where epoch=$timestamp";

        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: getGridUpdatedTime Query Failed '
                . mysql_error());
            return false;
        }
        $line = mysql_fetch_array($result);
        mysql_free_result($result);
        return intval($line[0]);
    }

    /**
     *
     * setGridUpdatedTime
     *
     * Set the txnAt value for a particular timestamp so as to mark that data
     * has been generated for txnAt transaction.
     *
     * IN - $timestamp
     * IN - $txnAt
    **/
    public function setGridUpdatedTime($timestamp, $txnAt, $now = -1) {
        // let it write -1 if $txnAt was set to -1 by force flag.
	if ($now <= 0) {
          $now = time();
	}
        $sql = "insert into interpolation_step01_txn
                 values($timestamp, $now, $txnAt)
                 on duplicate key update txnat=$txnAt";
        $result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: setGridUpdatedTime Query Failed '
                . mysql_error());
            return false;
        }
        return true;
    }

    /**
     *
     * latestContourAvailableTime
     *
     * Find the timestamp for latest available ozone data. This can be either
     * obtained from interpolation txn table, or from data table. The first
     * method always returns something unless the table is empty. The offliner
     * trigger is assumed to have populated the interpolation grid as well as
     * interpolation txn table.
    **/
    public function latestContourAvailableTime($target_timestamp = -1) {
        // Try to look into interpolation txn table first. If not available,
        // then look into data table
        // TODO: hardcoded for now
        //return 1328427600;
	$ret = $this->getLatestAvailableTimestamp('contour', $target_timestamp);
	return ($ret);
    }

    /**
     *
     * getLatestAvailableTimestamp
     *
     * Look back from given timestamp and find the timestamp where we have
     * some data. This can be made more sophisticated by searching previous
     * day if last data has not been found within last 2 hours, and then
     * continuing back in history till something is found. However, most of the
     * times, data is generally available in last few hours
     * IN $type = rawdata || grid || contour
    **/
    public function getLatestAvailableTimestamp($type = 'rawdata', $target_timestamp = -1) {
	if ($target_timestamp == -1) {
          $timestamp = time(); // now
	}
	else {
	  $timestamp = $target_timestamp;
	}
        $tblYear = gmdate('Y', $timestamp);
        $start = $timestamp - 5*60*60; // look back 5 hours, then 5^2 hours, then 5^3 till 5^5 hours back
        $end = $timestamp;
        $itrCount = 1;
        $ts = false;
        while (1) {
            switch($type) {
                case 'grid':
                case 'contour':
                    $sql = "select max(epoch)
                        from interpolation_step01_$tblYear
                        where epoch>=$start and epoch<=$end";
                break;

                case 'rawdata':
                default:
                    $sql = "select max(epoch),count(epoch)
                        from ibh_data_year_$tblYear
                        where epoch>=$start and epoch<=$end and o3_flag='K'
                        group by epoch
                        order by epoch desc limit 5";
                break;
            }
            $result = mysql_query($sql, $this->link);
            if ($result === false) {
                $this->setLastError('Query Mgr: getDataAvailableTimestamp '
                    . 'Qery Failed ' . mysql_error());
                return false;
            }
            $itrCount++;
            $ts = false;
            while ($line = mysql_fetch_array($result)) {
                $ts = $line[0];
                if (isset($line[1]) && $line[1] >= 2) {
                    // break if at least 2 stations are present for rawdata
                    break;
                }
            }

            mysql_free_result($result);
            if (!empty($ts) || $itrCount > 10) {
                break;
            }
            $end = $start - 5*60;
            $start = $end - $itrCount*$itrCount*5*60*60;
        }

        return $ts;
    }
	/**
	 * aggregateGridDataAtTimestamp
	 *
	 * Aggregate o3 data stored in grid interpolation tables and store in aggregate_o3_epoch table
	**/
	public function aggregateGridDataAtTimestamp($timestamp) {
		$tblYear = gmdate('Y', $timestamp);
		$sql = "REPLACE aggregate_o3_epoch SELECT epoch, MIN(o3) AS minimum, AVG(o3) AS average, MAX(o3) AS maximum, SUM(o3 <= 60) AS good, SUM(o3 > 60 AND o3 < 76) AS moderate, SUM(o3 >= 76 AND o3 < 96) AS warning, (o3 >= 96 AND o3 < 116) AS unhealthy, SUM(o3 >= 116 AND o3 < 136) AS very, SUM(o3 >= 136) AS hazardous, COUNT(*) AS total FROM interpolation_step01_$tblYear WHERE o3 IS NOT NULL AND epoch=$timestamp GROUP BY epoch";
		$result = mysql_query($sql, $this->link);
        if ($result === false) {
            $this->setLastError('Query Mgr: getDataAvailableTimestamp '
                . 'Qery Failed ' . mysql_error());
            return false;
        }
		return true;
	}

    /**
     *
     * getLatestTimestamp
     *
     * Find latest timestamp in DB
     * IN $type = rawdata || grid || contour
    **/
    function getLatestTimestamp($timestamp=-1, $type = 'rawdata') {
        if ($timestamp <= 0) {
	  $timestamp = time();
	}
        $tblYear = gmdate('Y', $timestamp);
        $start = $timestamp - 5*60*60; // look back 5 hours, then 5^2 hours, then 5^3 till 5^5 hours back
        $end = $timestamp;
        $itrCount = 1;
        $ts = false;
        while (1) {
            switch($type) {
                case 'grid':
                case 'contour':
                    $sql = "select max(epoch)
                        from interpolation_step01_$tblYear
                        where epoch>=$start and epoch<=$end";
                break;

                case 'validraw':
                    $sql = "select max(epoch),count(epoch)
                        from ibh_data_year_$tblYear
                        where epoch>=$start and epoch<=$end and o3 is not NULL
                        group by epoch
                        order by epoch desc limit 5";
                break;

                case 'rawdata':
                default:
                    $sql = "select max(epoch)
                        from ibh_data_year_$tblYear
                        where epoch>=$start and epoch<=$end and o3 is not NULL";
                break;
            }
            $result = mysql_query($sql, $this->link);
            if ($result === false) {
                $this->setLastError('Query Mgr: getLatestTimestamp '
                    . 'Qery Failed ' . mysql_error());
                return false;
            }
            $itrCount++;
            $ts = false;
	    //echo "# debug: sql = $sql<br>\n";
            while ($line = mysql_fetch_array($result)) {
                $ts = $line[0];
		//echo "# debug: ts = $ts<br>\n";
		if ($type == 'validraw') {
                  if (isset($line[1]) && $line[1] >= 2) {
                    // break if at least 2 stations are present for rawdata
                    break;
		  }
		}
		else {
                  if (isset($line[0])) {
                    break;
                  }
		}
            }

            mysql_free_result($result);
            if (!empty($ts) || $itrCount > 10) {
                break;
            }
            $end = $start - 5*60;
            $start = $end - $itrCount*$itrCount*5*60*60;
	    // update table name
            $tblYear = gmdate('Y', $end);
        }

        return $ts;
    }

    /**
     *
     * getDataCount
     *
     * getDataCount for a given time stamp
     * IN $type = rawdata || grid || contour
    **/
    function getDataCount($timestamp, $inst, $type = 'rawdata') {
        if (!is_numeric($timestamp)) {
            $this->setLastError('Query Mgr: getDataCount: Invalid timestamp ' . $timestamp);
            return false;
        }
        $tblYear = gmdate('Y', $timestamp);
        $count = 0;
	$flag_field = $inst.'_flag';
        switch($type) {
          case 'validraw':
		$sql = "select count(*)
			from ibh_data_year_$tblYear
			where epoch = $timestamp and $flag_field = 'K'";
          break;

          case 'rawdata':
          default:
		$sql = "select count(*)
			from ibh_data_year_$tblYear
			where epoch = $timestamp and $inst is not NULL";
          break;
        }
        $result = mysql_query($sql, $this->link);
        if ($result === false) {
	  $this->setLastError('Query Mgr: getDataCount '
		. 'Qery Failed ' . mysql_error());
	  return false;
	}
	//echo "# debug: sql = $sql<br>\n";
        while ($line = mysql_fetch_array($result)) {
          $count = $line[0];
          if (isset($line[0])) {
                    break;
          }
	}

        mysql_free_result($result);

        return $count;
    }


    public function latestGridAvailableTime() {
       return $this->latestContourAvailableTime();
    }

    private function setLastError($errMsg = '') {
        $this->lastError = $errMsg;
    }

    public function getLastError() {
        if (!empty($this->lastError)) {
            return $this->lastError;
        }
        return '';
    }
}
?>
