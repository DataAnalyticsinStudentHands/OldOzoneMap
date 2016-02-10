<!--[if lte IE 7]>
<style type="text/css">
#searchGMap-content.searching,
#timestamp-controls,
#searchGMap-content {
  background:transparent;
  background-image:url(/sites/all/modules/ibh_ozone_viewer/images/bkg_timestampcontrols_ie7.png);
  zoom: 1;
}
#header {
  background:transparent;
  background-image:url(/sites/all/modules/ibh_ozone_viewer/images/bkg_header_ie7.png);
  zoom: 1;
}
</style>
<![endif]-->

<div id="gMap"></div>

  <div id="help-info"></div>
  <div id="help-1" style="display:none;">
  <table class="help-1" cellspacing="4" cellpadding="5" border="0"  bgcolor="#000000" style="color:#fff; font-weight:bold; margin:0; background-color:#000000;">
  <tr>
  <td colspan="3" style="background-color:#000;" border="0"><div style="background-image:url('/sites/all/modules/ibh_ozone_viewer/images/question.png'); background-repeat: no-repeat; padding-left:55px; min-height:45px;">Ozone level markers display the level at locations that are common landmarks for local residents. Searching for an address will add a marker at that location.</div></td>
  </tr>
  <tr>
  <td colspan="2" bgcolor="#D9D8D5" style="color:#000; text-align:center;">Air Quality Index Values<br /><span style="font-size:10px;">(ozone parts per billion)</span></td>
  <td bgcolor="#D9D8D5" style="color:#000;">Levels of Health Concern.</td>
  </tr>
  <tr>
  <td bgcolor="#451427" width="54" valign="top" style="text-align:right;">136+</td>
  <td bgcolor="#451427" width="100" valign="top">HAZARDOUS</td>
  <td bgcolor="#451427" width="455" valign="top">Health alert: everyone may experience more serious health effects.</td>
  </tr>
  <tr>
  <td bgcolor="#9A1E51" valign="top" style="text-align:right;">116-135</td>
  <td bgcolor="#9A1E51" valign="top">VERY UNHEALTHY</td>
  <td bgcolor="#9A1E51" valign="top">Health warnings of emergency conditions.</td>
  </tr>
  <tr>
  <td bgcolor="#B8212B" valign="top" style="text-align:right;">96-115</td>
  <td bgcolor="#B8212B" valign="top">UNHEALTHY</td>
  <td bgcolor="#B8212B" valign="top">Everyone may begin to experience health effects.</td>
  </tr>
  <tr>
  <td bgcolor="#EE5828" valign="top" style="text-align:right;">77-95</td>
  <td bgcolor="#EE5828" valign="top">WARNING</td>
  <td bgcolor="#EE5828" valign="top">General public not likely to be affected; People sensitive to air pollution may experience health effects.</td>
  </tr>
  <tr>
  <td bgcolor="#F6EC26" valign="top" style="color:#000; text-align:right;">61-76</td>
  <td bgcolor="#F6EC26" valign="top" style="color:#000;">MODERATE</td>
  <td bgcolor="#F6EC26" valign="top" style="color:#000;">Air quality is acceptable; Moderate health concern for people unusually sensitive to air pollution.</td>
  </tr>
  <tr>
  <td bgcolor="#3FAE4A" valign="top" style="text-align:right;">0-60</td>
  <td bgcolor="#3FAE4A" valign="top">GOOD</td>
  <td bgcolor="#3FAE4A" valign="top">Air quality is considered satisfactory, air pollution poses little or no risk. If you are seeing an all green box, this means there are low ozone levels. To view the value in a certain area, click on the map. Ozone level markers give a more precise value for a specific location.</td>
  </tr>
  </table>
  </div>

  <div id="color-legend-wrapper">
    <div id="color-legend"></div>
  </div>

  <div id="header" class="<?php print $secondary_menu ? 'with-secondary-menu': 'without-secondary-menu'; ?>"><div class="section clearfix">

    <?php if ($logo): ?>
      <a href="<?php print $front_page; ?>" title="<?php print t('Home'); ?>" rel="home" id="logo">
        <img src="<?php print $logo; ?>" alt="<?php print t('Home'); ?>" />
      </a>
    <?php endif; ?>

    <?php if ($site_name || $site_slogan): ?>
      <div id="name-and-slogan"<?php if ($hide_site_name && $hide_site_slogan) { print ' class="element-invisible"'; } ?>>

        <?php if ($site_name): ?>
          <?php if ($title): ?>
            <div id="site-name"<?php if ($hide_site_name) { print ' class="element-invisible"'; } ?>>
              <strong>
                <a href="<?php print $front_page; ?>" title="<?php print t('Home'); ?>" rel="home"><span><?php print $site_name; ?></span></a>
              </strong>
            </div>
          <?php else: /* Use h1 when the content title is empty */ ?>
            <h1 id="site-name"<?php if ($hide_site_name) { print ' class="element-invisible"'; } ?>>
              <a href="<?php print $front_page; ?>" title="<?php print t('Home'); ?>" rel="home"><span><?php print $site_name; ?></span></a>
            </h1>
          <?php endif; ?>
        <?php endif; ?>

        <?php if ($site_slogan): ?>
          <div id="site-slogan"<?php if ($hide_site_slogan) { print ' class="element-invisible"'; } ?>>
            <?php print $site_slogan; ?>
          </div>
        <?php endif; ?>

      </div> <!-- /#name-and-slogan -->
    <?php endif; ?>

    <?php print render($page['header']); ?>

    <?php if ($main_menu): ?>
      <div id="main-menu-ibreathe" class="navigation">
        <?php print theme('links__system_main_menu', array(
          'links' => $main_menu,
          'attributes' => array(
            'id' => 'main-menu-links',
            'class' => array('links', 'clearfix'),
          ),
          'heading' => array(
            'text' => t('Main menu'),
            'level' => 'h2',
            'class' => array('element-invisible'),
          ),
        )); ?>
      </div> <!-- /#main-menu -->
    <?php endif; ?>

    <?php if ($secondary_menu): ?>
      <div id="secondary-menu" class="navigation">
        <?php print theme('links__system_secondary_menu', array(
          'links' => $secondary_menu,
          'attributes' => array(
            'id' => 'secondary-menu-links',
            'class' => array('links', 'inline', 'clearfix'),
          ),
          'heading' => array(
            'text' => t('Secondary menu'),
            'level' => 'h2',
            'class' => array('element-invisible'),
          ),
        )); ?>
      </div> <!-- /#secondary-menu -->
    <?php endif; ?>

<?php /*  <a href="http://uh.edu" target="_blank"><img id="uh-logo" src="<?php echo path_to_theme(); ?>/logo-uh.png" width="236" height="15" /></a> 
  <ul id="site-switch">
  <li><a>IBREATHE</a></li>
  <li><a class="active">CLEAN AIR NETWORK</a></li>
  </ul>
*/ ?>
  </div></div> <!-- /.section, /#header -->


  <div id="loading"></div>
  <div id="contentContainer">
    <div id="content-viewer">

  <?php if ($page['triptych_first'] || $page['triptych_middle'] || $page['triptych_last']): ?>
<div id="sidebar">
    <div id="triptych-wrapper"><div id="triptych" class="clearfix">
      <?php print render($page['triptych_first']); ?>
      <?php print render($page['triptych_middle']); ?>
      <?php print render($page['triptych_last']); ?>
    </div></div> <!-- /#triptych, /#triptych-wrapper -->
<div class="clear"></div>
</div><!--end sidebar-->
  <?php endif; ?>


<div class="clear"></div>
</div><!--end content-->
</div><!--end contentContainer-->

<div id="footer-viewer">

	<div title="Home" id="homeCenter">&nbsp;</div>
	<div id="timeline-wrapper"></div>
	<div id="footer-ui">
	    <div id="o-loadbar-wrapper"><div id="o-loadbar"></div></div>	
		<div id="searchGMap-wrapper">
		  <div id="searchGMap-content">
		    <div id="searchInput"><input type="text" id="address" size="60" /></div>
		  </div>
		  <div id="timestamp-controls">
		    <div id="timestamp-menus">
		    <?php print $timestamp_menus; ?>    
		    </div>
		    <div id="timestamp-slider">
		      <span id="slider-time"></span>
		      <div id="slider-range"></div>
		    </div>
		    <div class="refresh-map-wrapper">
		      <a class="refresh-map">Refresh Map</a>
		    </div>
		  </div>
		</div>
		<span href="#" id="searchOpen" title="More" class="searchToggle"><span>Set Time/Place: &nbsp; </span> <span id="time-indicator"></span> <span class="rsaquo open"><img src="./sites/all/modules/ibh_ozone_viewer/images/arrow-aqua-right.png" /></span><span class="rsaquo close"><img src="./sites/all/modules/ibh_ozone_viewer/images/arrow-aqua-down.png" /></span></span>
<!--		<a href="#" id="searchClose" title="Close" class="searchToggle">Set Time/Place -</a> -->
	</div>

	<!--WIDGET PANEL OPEN/CLOSE-->
	<span href="#" id="sidebarOpen" title="More" class="sidebarToggle">About <span class="rsaquo open"><img src="./sites/all/modules/ibh_ozone_viewer/images/arrow-bk-right.png" /></span><span class="rsaquo close"><img src="./sites/all/modules/ibh_ozone_viewer/images/arrow-bk-down.png" /></span></span>
<!--	<a href="#" id="sidebarClose" title="Close" class="sidebarToggle">Close</a>	-->
</div><!--end footer-->

<script type="text/javascript">
  var uvOptions = {};
  (function() {
    var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
    uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/h3JIkvQUMhCiwtBTMtVY1Q.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>