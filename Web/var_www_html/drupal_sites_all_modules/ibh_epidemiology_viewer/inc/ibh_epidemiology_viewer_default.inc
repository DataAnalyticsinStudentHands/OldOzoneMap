<?php

/*
* @file
* Default Setup of the IBH Epidemiology Viewer.
*/

/*
* function ibh_epidemiology_viewer_default
*/
function ibh_epidemiology_viewer_default(){
	$path = drupal_get_path('module', 'ibh_epidemiology_viewer');
	
	drupal_add_library('system','ui');
	drupal_add_library('system','ui.autocomplete');
	
	drupal_add_js($path . '/scripts/rainbowvis.js');
	drupal_add_js('http://maps.googleapis.com/maps/api/js?sensor=false&libraries=geometry', 'external');
	drupal_add_js($path . '/scripts/gmap3.min.js');
	drupal_add_js($path . '/scripts/jquery.ui.touch-punch.min.js');
	drupal_add_js($path . '/scripts/geojson.js');
	drupal_add_js($path . '/scripts/infobox.min.js');
	drupal_add_js($path . '/scripts/jquery.csv-0.71.min.js');
	drupal_add_js($path . '/scripts/ibh-epidemiology-viewer.js');
	
	drupal_add_css($path . '/styles/main.css');
	drupal_add_css($path . '/styles/epidemiology.css');
	
	return theme('ibh-epidemiology-viewer', $vars);
}

?>