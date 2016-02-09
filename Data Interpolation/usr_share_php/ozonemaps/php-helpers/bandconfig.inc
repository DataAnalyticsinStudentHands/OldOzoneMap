<?php
/**
 * configuration file for setting custom regions of ozone. Each value in the
 * following array acts as the upper limit of ozone values in ppbv for that
 * region.
 * The return statement should be retained because this file is inclded
 * else where.
 *
 * Sample Entry:
   return array(array(32.5, 37.5, 42.5, 70, 75, 80, 107.5, 112.5, 117.5,
                145, 150, 155, 220, 225, 230, 370, 375, 380));
 *
 *
**/
return array(
    array(60, 75, 95, 115, 135),
    array(57, 62, 72, 78, 93, 98, 113, 118, 132, 137),
    array(59, 61, 74, 76, 94, 96, 114, 116, 134, 136),
    array(20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130, 135, 140),
    array(20, 25, 30, 35, 40, 45, 50, 55, 59, 60, 61, 65, 70, 74, 75, 76, 80, 85, 90, 94, 95, 96, 100, 105, 110, 114, 115, 116, 120, 125, 130, 134, 135, 136, 140),
);
?>
