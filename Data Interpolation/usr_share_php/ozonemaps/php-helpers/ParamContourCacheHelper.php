<?php
class ContourCacheHelper {
    private $zipEnabled;
    private $cacheDirectory;
    private $lastError;
    private $gzipLevel;
    private $bandSchema;

    function __construct($zipEnabled = false, $bandSchema = 0,
                $cacheDir = "/home/ibhworker/mnt/generatedcontour/",
                $cacheGridDir = "/home/ibhworker/mnt/gridData/",
		$gzLevel = 9) {
        $this->zipEnabled = $zipEnabled;
        $this->cacheDirectory = realpath($cacheDir);
        $this->cacheGridDirectory = realpath($cacheGridDir);
        $this->lastError = '';
        $this->gzipLevel = $gzLevel;
        $this->bandSchema = $bandSchema;
    }

    /*
     * saveContour: save contour JSON data file
     *   Input:
     *		$timestamp: time stamp (epoch)
     *		$contourData: contour data in JSON format
     *		$jsonp: flag for adding JSONP header
     *		$keepHistory: flag for keeping old version
     */
    public function saveContour($timestamp, $contourData, $param = "o3", $jsonp=false, $keepHistory=false) {
        $fileLoc = $this->getFileLocation($timestamp, $param);

        // need to do a system call with mkdir -p 
        // to create the directory if it doesn't exist (yyyy/mm/dd)
	$dirLoc = dirname($fileLoc);
	$tmp_fileLoc = $fileLoc . ".tmp." . getmypid();
        if (!file_exists($fileLoc)) {
	    // set dir permission to 2775
            system("mkdir -m 2775 -p " . $dirLoc);
	    // fix permission for two upper level dirs (yyyy/mm and yyyy)
	    $upperDirLoc = dirname($dirLoc);
	    chmod($upperDirLoc, 02775);
	    chmod(dirname($upperDirLoc), 02775);
        }

        $fileHandle = fopen($tmp_fileLoc, 'w+');
        if ($fileHandle === false) {
            $this->setLastError("Unable to open file '$tmp_fileLoc'");
            return false;
        }

	// add JSONP padding
	if ($jsonp == true) {
	  $contourData = "contourData". $timestamp . "(" . $contourData . ")";
	}

        $dataToWrite = '';
        if ($this->zipEnabled) {
            //$dataToWrite = gzdeflate($contourData, $this->gzipLevel);
            $dataToWrite = gzencode($contourData, $this->gzipLevel);
        } else {
            $dataToWrite = $contourData;
        }

        if (fwrite($fileHandle, $dataToWrite) === false) {
            $this->setLastError("Unable to write data to file '$tmp_fileLoc'");
            fclose($fileHandle);
            return false;
        }
        fclose($fileHandle);

	if ($keepHistory == true) {
	  if (file_exists($fileLoc)) {
	    // get file mtime
	    $mtime = filemtime($fileLoc);
	    $fileLocHistory = $fileLoc . ".old.$mtime";
	    rename($fileLoc, $fileLocHistory);
	  }
	  rename($tmp_fileLoc, $fileLoc);
	} else {
	  // copy tmp file to real file
	  $ret_copy = copy($tmp_fileLoc, $fileLoc);

	  // delete existing file
	  $ret_unlink = unlink($tmp_fileLoc);
	}

	// set file permission to 664
        chmod($fileLoc, 0664);

        return true;
    }

    public function retrieveContour($timestamp, $param = "o3") {
        $fileLoc = $this->getFileLocation($timestamp, $param);
        if (!is_file($fileLoc)) {
            $this->setLastError("File $fileLoc not available");
            return false;
        }


        ob_start();
        // readgzfile takes care of handling plain text file as well as
        // file compressed using gzencode. It writes directly to stdout, hence
        // output buffer is initialized here
        $ret = @readgzfile($fileLoc);
        $data = ob_get_clean();
        if ($data === false) {
            $this->setLastError("Can not read from file $fileLoc");
            return false;
        }

	// clean up JSONP header
	$data = preg_replace('/.+?({.+}).+/','$1',$data);

        return $data;
    }

    private function getFileLocation($timestamp, $param = "o3") {
        $month = date('m', $timestamp);
        $day = date('d', $timestamp);
        $year = date('Y', $timestamp);
        $hour = date('H', $timestamp);
        $min = date('i', $timestamp);
        //$min = intval($min) - intval($min) % 5;
        // ignoring the second value from timestamp will create 
        // a timestamp rounded off to lower one minute bound
        $timestamp = mktime($hour, $min, 0, $month, $day, $year);

        $ext = $this->zipEnabled ? '.js.gz' : '.js';
        $fileLoc = "{$this->cacheDirectory}/$param/$year/$month/$day/"
            ."{$timestamp}_bs{$this->bandSchema}$ext";
        return $fileLoc;
    }

    /*
     * saveGridJSON: save grid JSON data file
     *   Input:
     *		$timestamp: time stamp (epoch)
     *		$gridDataJSON: grid data in JSON format
     *		$jsonp: flag for adding JSONP header
     *		$keepHistory: flag for keeping old version
     */
    public function saveGridJSON($timestamp, $gridDataJSON, $param="o3", $jsonp=false, $keepHistory=false) {
        $fileLoc = $this->getGridFileLocation($timestamp, $param);

        // need to do a system call with mkdir -p 
        // to create the directory if it doesn't exist (yyyy/mm/dd)
		$dirLoc = dirname($fileLoc);
		$tmp_fileLoc = $fileLoc . ".tmp." . getmypid();
        if (!file_exists($fileLoc)) {
		    // set dir permission to 2775
	        system("mkdir -m 2775 -p " . $dirLoc);
		    // fix permission for two upper level dirs (yyyy/mm and yyyy)
		    $upperDirLoc = dirname($dirLoc);
		    chmod($upperDirLoc, 02775);
		    chmod(dirname($upperDirLoc), 02775);
        }

        $fileHandle = fopen($tmp_fileLoc, 'w+');
        if ($fileHandle === false) {
            $this->setLastError("Unable to open file '$tmp_fileLoc'");
            return false;
        }

		// add JSONP padding
		if ($jsonp == true) {
			$gridDataJSON = "gridData". $timestamp . "(" . $gridDataJSON . ")";
		}

        $dataToWrite = '';
        if ($this->zipEnabled) {
            //$dataToWrite = gzdeflate($gridDataJSON, $this->gzipLevel);
            $dataToWrite = gzencode($gridDataJSON, $this->gzipLevel);
        } else {
            $dataToWrite = $gridDataJSON;
        }

        if (fwrite($fileHandle, $dataToWrite) === false) {
			$this->setLastError("Unable to write data to file '$tmp_fileLoc'");
			fclose($fileHandle);
			return false;
        }
        fclose($fileHandle);

		if ($keepHistory == true) {
		  if (file_exists($fileLoc)) {
		    // get file mtime
		    $mtime = filemtime($fileLoc);
		    $fileLocHistory = $fileLoc . ".old.$mtime";
		    rename($fileLoc, $fileLocHistory);
		  }
		  rename($tmp_fileLoc, $fileLoc);
		} else {
		  // copy tmp file to real file
		  $ret_copy = copy($tmp_fileLoc, $fileLoc);

		  // delete existing file
		  $ret_unlink = unlink($tmp_fileLoc);
		}

		// set file permission to 664
        chmod($fileLoc, 0664);

        return true;
	}

    private function getGridFileLocation($timestamp, $param = "o3") {
        $month = date('m', $timestamp);
        $day = date('d', $timestamp);
        $year = date('Y', $timestamp);
        $hour = date('H', $timestamp);
        $min = date('i', $timestamp);
        //$min = intval($min) - intval($min) % 5;
        // ignoring the second value from timestamp will create 
        // a timestamp rounded off to lower one minute bound
        $timestamp = mktime($hour, $min, 0, $month, $day, $year);

        $ext = $this->zipEnabled ? '.js.gz' : '.js';
        $fileLoc = "{$this->cacheGridDirectory}/$param/$year/$month/$day/"
            ."gridData_{$timestamp}$ext";
        return $fileLoc;
    }

    private function setLastError($msg) {
        $this->lastError = $msg;
    }

    public function getLastError() {
        return $this->lastError;
    }
}
?>
