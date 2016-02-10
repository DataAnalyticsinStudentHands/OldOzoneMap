<?php

/**
 * Menu callback; Settings administration.
 */
function ibh_epidemiology_viewer_settings() {
  $form = array();
  $aqi_object = variable_get('aqi_object', false);
  $form['aqi_object'] = array(
    '#title' => t('AQI JSON Object'),
    '#type' => 'textarea',
    '#description' => t('The AQI JSON Object. Advanced use. Do not include exteriour curly brackets ("{...}")'),
    '#default_value' => ($aqi_object) ? $aqi_object : ibh_epidemiology_viewer_default_aqi_definition(),
  );
  
  $api_url = variable_get('epidemiology_api_url', '/');
  
  $form['epidemiology_api_url'] = array(
    '#title' => t('API URL'),
    '#type' => 'textfield',
    '#description' => t('Include trailing slash.  Valid values are "/" or "http://domain.com/"'),
    '#default_value' => $api_url,
  );
  
  return system_settings_form($form);
}
