<?php

/**
 * @file
 * Default Setup of the IBH Ozone Viewer.
 */

/*
 * function ibh_ozone_viewer_default
 */
function ibh_ozone_viewer_default(){

  // return MENU_NOT_FOUND;

//<script type="text/javascript" src="scripts/jquery.min.js"></script>
//<script type="text/javascript" src="scripts/jquery-ui-1.8.13.custom.min.js"></script>
//<script type="text/javascript" src="scripts/prettyphoto.js"></script>
  $path = drupal_get_path('module', 'ibh_ozone_viewer');
  
//  drupal_add_js($path . '/scripts/jquery.dump.js');
//  drupal_add_js($path . '/scripts/jquery.dotimeout.min.js');
  drupal_add_js($path . '/scripts/jquery.address-1.4.min.js');
//  drupal_add_js($path . '/scripts/activity.js');
  drupal_add_js($path . '/scripts/rainbowvis.js');
  drupal_add_js('http://maps.googleapis.com/maps/api/js?sensor=false&libraries=geometry', 'external');
  drupal_add_js($path . '/scripts/gmap3.min.js');
  
//  drupal_add_js($path . '/scripts/highcharts/highcharts.js');
//  drupal_add_js($path . '/scripts/jquery-autocomplete.min.js');
//  drupal_add_js($path . '/scripts/jquery.autocomplete.min.js');
  drupal_add_js($path . '/scripts/jquery-ui-1.8.18.custom.min.js');
  drupal_add_js($path . '/scripts/jquery.ui.touch-punch.min.js');  
  drupal_add_js($path . '/scripts/d3.v3.min.js');
  drupal_add_js($path . '/scripts/nv.d3.js');
  drupal_add_js($path . '/scripts/ibh-ozone-viewer.js');
  drupal_add_js($path . '/scripts/timeline.js');
  drupal_add_css($path . '/styles/nv.d3.min.css');
  drupal_add_css($path . '/styles/main.css');
  drupal_add_css($path . '/styles/timeline.css');
  return theme('ibh-ozone-viewer', $vars);
}
