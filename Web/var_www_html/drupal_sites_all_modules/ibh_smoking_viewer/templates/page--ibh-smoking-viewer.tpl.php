<!--[if lte IE 7]>
<style type="text/css">
#searchGMap-content.searching,
#timestamp-controls,
#searchGMap-content {
  background:transparent;
  background-image:url(/sites/all/modules/ibh_smoking_viewer/images/bkg_timestampcontrols_ie7.png);
  zoom: 1;
}
#header {
  background:transparent;
  background-image:url(/sites/all/modules/ibh_smoking_viewer/images/bkg_header_ie7.png);
  zoom: 1;
}
</style>
<![endif]-->

<div id="gMap"></div>

  <div id="help-info"></div>

  <!-- <div id="color-legend-wrapper">
    <div id="color-legend"></div>
  </div> -->

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

  </div></div> <!-- /.section, /#header -->

  <div id="tooltip"></div>
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
	<section id="selectArea">
		<select id="select">
		  <!-- <option value="">Select: </option> -->
		  <option value="RES">Restaurant</option>
		  <option value="PWS">Private Work Sites</option>
		  <option value="MWS">Municipality Work Site</option>
		  <option value="BR">Bars in Restaurant</option>
		  <option value="BNR">Bars not in Restaurant</option>
		</select>
	</section>
	<section id="searchArea">
		<label id="searchLabel">Enter Address: </label>
		<div id="searchInput"><input id='address' placeholder='Start typing a place name...' type='text' /></div>
		<!-- <button class="action bluebtn" id="searchButton">
			<span class="label">Search</span>
		</button>  -->		
	</section>

	<!--WIDGET PANEL OPEN/CLOSE-->
	<span href="#" id="sidebarOpen" title="More" class="sidebarToggle">About <span class="rsaquo open"><img src="./sites/all/modules/ibh_smoking_viewer/images/arrow-bk-right.png" /></span><span class="rsaquo close"><img src="./sites/all/modules/ibh_smoking_viewer/images/arrow-bk-down.png" /></span></span>
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