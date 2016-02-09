<?php
    class DBManager {
        private $dbHost = 'can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com';
        private $dbUser = 'admin';
        private $dbPass = '*****';
        private $dbWorker = 'ibhworker';
        private $dbWorkerPass = '*****';
        private $ozoneDB = 'ibreathedb';
        private $roLink = null;
        private $workerLink = null;

        function getDataBaseLink($ro = false) {
            if ($ro) {
                if (empty($this->roLink)) {
                    $this->roLink = mysql_connect($this->dbHost,
                        $this->dbUser,
                        $this->dbPass
                    );
                }
                return $this->roLink;
            } else {
                if (empty($this->workerLink)) {
                    $this->workerLink = mysql_connect($this->dbHost,
                        $this->dbWorker,
                        $this->dbWorkerPass
                    );
                }
                return $this->workerLink;
            }
        }

        function selectOzoneDB($link = null) {
            if (empty($link)) {
                // select read only link
                $link = $this->roLink;
            }
            return mysql_select_db($this->ozoneDB, $link);
        }

        function closeLinks() {
            if (!empty($this->roLink)) {
                mysql_close($this->roLink);
            }

            if (!empty($this->workerLink)) {
                mysql_close($this->workerLink);
            }
        }
    }
?>
