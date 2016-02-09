<?php
class BSplineHelper {
    public $identity;

    function __construct($identity=true) {
        $this->identity = $identity;
    }

    function getBSpline($oneCLine) {
        if ($this->identity) {
            return $oneCLine;
        }

        $i=0; $t=0.0; $ax=0.0; $ay=0.0; $bx=0.0; $by=0.0; $cx=0.0; $cy=0.0; $dx=0.0; $dy=0.0; $lat=0.0; $lon=0.0; $points=array();

        $lats = array();
        $lons = array();
        $points = array();
        $cLineLength = count($oneCLine);

        // split the $oneCLine into $lats and $lons array. Meanwhile,
        // extend the lines by pulling last two entries to front and
        // front two entries to last.
        if ($cLineLength == 1) {
            $lats[0] = $oneCLine[0][0];
            $lons[0] = $oneCLine[0][1];
        } else {
            $lats[0] = $oneCLine[$cLineLength - 2][0];
            $lons[0] = $oneCLine[$cLineLength - 2][1];
        }

        $lats[1] = $oneCLine[$cLineLength - 1][0];
        $lons[1] = $oneCLine[$cLineLength - 1][1];
        for ($i = 0; $i < $cLineLength; $i++) {
            $lats[$i+2] = $oneCLine[$i][0];
            $lons[$i+2] = $oneCLine[$i][1];
        }
        $lats[$i+2] = $oneCLine[0][0];
        $lons[$i+2] = $oneCLine[0][1];

        if ($cLineLength == 1) {
            $lats[$i+3] = $oneCLine[0][0];
            $lons[$i+3] = $oneCLine[0][1];
        } else {
            $lats[$i+3] = $oneCLine[1][0];
            $lons[$i+3] = $oneCLine[1][1];
        }

        // For every point
        for ($i = 2; $i < count($lats) - 2; $i++) {
            for ($t = 0.0; $t < 1; $t += 0.5) {
                $ax = (-$lats[$i - 2] + 3 * $lats[$i - 1] - 3 * $lats[$i] + $lats[$i + 1]) / 6;
                $ay = (-$lons[$i - 2] + 3 * $lons[$i - 1] - 3 * $lons[$i] + $lons[$i + 1]) / 6;
                $bx = ($lats[$i - 2] - 2 * $lats[$i - 1] + $lats[$i]) / 2;
                $by = ($lons[$i - 2] - 2 * $lons[$i - 1] + $lons[$i]) / 2;
                $cx = (-$lats[$i - 2] + $lats[$i]) / 2;
                $cy = (-$lons[$i - 2] + $lons[$i]) / 2;
                $dx = ($lats[$i - 2] + 4 * $lats[$i - 1] + $lats[$i]) / 6;
                $dy = ($lons[$i - 2] + 4 * $lons[$i - 1] + $lons[$i]) / 6;
                $lat = $ax * pow($t + 0.1, 3) + $bx * pow($t + 0.1, 2) + $cx * ($t + 0.1) + $dx;
                $lon = $ay * pow($t + 0.1, 3) + $by * pow($t + 0.1, 2) + $cy * ($t + 0.1) + $dy;
                $points[] = array($lat, $lon);
            }
        }
        return $points;
    }
}
?>
