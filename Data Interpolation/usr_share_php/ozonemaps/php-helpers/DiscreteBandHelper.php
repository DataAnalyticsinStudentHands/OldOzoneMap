<?php

class DiscreteBandHelper {
    const LABEL_TYPE_PC     = 1;    // Percent based
    const LABEL_TYPE_BAND   = 2;    // Band based
    private $comparisonStandard = 75;
    private $bandScheme;
    private $labelType;
    private $band;
    private $desc;

    function __construct($labelType = self::LABEL_TYPE_PC, $labelBase = 75) {
        if ($labelType != self::LABEL_TYPE_PC
                 && $labelType != self::LABEL_TYPE_BAND) {
            $this->labelType = self::LABEL_TYPE_PC;
        } else {
            $this->labelType = $labelType;
        }

        $this->band = array();
        $this->desc = array();

        switch ($this->labelType) {
        case self::LABEL_TYPE_PC:
            $this->comparisonStandard = $labelBase;
            $this->initPercentBasedLabels($labelBase);
            break;
        case self::LABEL_TYPE_BAND:
            $this->initBandBasedLabels($labelBase);
            break;
        }

        $prev = 0;
        foreach ($this->band as $key => $value) {
            $this->desc[$key] = array(
                'id' => $key,
                'name' => $this->getName($value),
                'desc' => $prev.'-'.$value,
                'min' => $prev,
                'max' => $value
            );
            $prev = $value;
        }
    }

    private function initPercentbasedLabels($labelBase) {
        // key is a representation of the percent of labelBase, value is
        // actual limit of ozone value in ppbv identified by this label
        $this->band = array(
            50 => 0.5*$labelBase,
            100 => $labelBase,
            150 => 1.5*$labelBase,
            200 => 2*$labelBase,
            300 => 3*$labelBase,
            500 => 5*$labelBase
        );

    }

    private function initBandBasedLabels($bandScheme) {
        // In this case, key for each band is just nominal. The value is actual
        // ozone reading in ppbv which is limit for particular key.
        $bandConfig = include('bandconfig.inc');
        if (is_array($bandScheme)) {
            $bandConfig[] = $bandScheme;
            $bandScheme = count($bandConfig)-1; //bust array and set it as index
        } else {
            if ($bandScheme >= count($bandConfig)) {
                $bandScheme = 0;
            }
        }
        $this->bandScheme = $bandScheme;

        $key = 10;
        foreach ($bandConfig[$bandScheme] as $val) {
            $this->band[$key] = $val;
            $key += 10;
            if ($key > 300) {
                break;
            }
        }
    }

    private function getName($value) {
        $retName = '';
        $standardToCompare = $this->comparisonStandard;

        if ($value <= 0.5*$standardToCompare) {
            $retName = 'Good';
        } elseif ($value <= $standardToCompare) {
            $retName = 'Moderate';
        } elseif ($value <= 1.5*$standardToCompare) {
            $retName = 'USG';
        } elseif ($value <= 2*$standardToCompare) {
            $retName = 'Unhealthy';
        } elseif ($value <= 3*$standardToCompare) {
            $retName = 'VeryUnhealthy';
        } else {
            $retName = 'Hazardous';
        }

        return $retName;
    }

    public function getSchemeId() {
        return $this->bandScheme;
    }

    public function getLabelId($o3) {
        $label = '10';
        if (empty($this->band)) {
            return '';
        }

        foreach ($this->band as $key => $val) {
            if ($o3 <= $val) {
                $label = $key;
                break;
            }
        }
        return $label;
    }

    public function getBand() {
        return $this->band;
    }

    public function getDesc() {
        return $this->desc;
    }
}
?>
