<!--[if lte IE 7]>
<style type="text/css">
#searchGMap-content.searching,
#timestamp-controls,
#searchGMap-content {
  background:transparent;
  background-image:url(/sites/all/modules/ibh_epidemiology_viewer/images/bkg_timestampcontrols_ie7.png);
  zoom: 1;
}
#header {
  background:transparent;
  background-image:url(/sites/all/modules/ibh_epidemiology_viewer/images/bkg_header_ie7.png);
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
<div id="layers">
	<h3>Layers menu</h3>
	<div id="layers_scroll">	
		<ul id="layers_list">
		</ul>
	</div>
	<!-- <button id='multichannel'><span class="label">Multi-Channel</span></button>
	<button id='stdev'><span class="label">Std Dev</span></button>
	<button id='mean'><span class="label">Mean</span></button> -->
	<table id="overlay-types">
		<tr>
			<td><input type="radio" name="overlay" value="multichannel"> multi-channel</td>
			<td><input type="radio" name="overlay" value="difference"> difference</td>
			<td><input type="radio" name="overlay" value="mean" checked> mean</td>
		</tr>
	</table>	
</div>
<div id="uploadfile" class='popupmenu'>
	<h3>Upload a File</h3>
	<input type='file'><br>
	<div id="upload_progress_bar"><div class="percent"></div></div><br>
	<!-- <input id='delimiter' type='text' value=","> Delimiter <br>
	<input id='fieldwrapper' type='text' value='"'> Field Wrapper<br>
	<input id='linebreaker' type='text' value='\n'> Linebreak<br> -->
	<div id="fileprefs">
		<h3>Set your file preferences</h3>
		Title for Dataset: <input type='text' id='title' value=''>
		<table>
			
		</table>
		<!-- <input type='submit'> --> <!-- <button>Cancel</button> -->
	</div>
	<input type='submit'> <button>Cancel</button> 
</div>
  <?php endif; ?>


<div class="clear"></div>
</div><!--end content-->
</div><!--end contentContainer-->

<div id="footer-viewer">
	<section id="menuArea">
		<select id="menu">
		<?php
			$epi_database = array(
			    'database' => 'epidemiology',
			    'username' => 'admin', // assuming this is necessary
			    'password' => 'roan2[twangs', // assuming this is necessary
			    'host' => 'can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com',
			    'driver' => 'mysql', // replace with your database driver
			);
			Database::addConnectionInfo('epidemiology_data', 'default', $epi_database);
			db_set_active('epidemiology_data');
			$result = db_select('menu_params')
				->fields('menu_params')
				->execute();
			while ($row = $result->fetchAssoc()) {
				echo "<option value='" . $row["data_suffix"] . ($row["aggregate?"] == 1 ? "&a" : "") . "' data-aggregate=" . ($row["aggregate?"] == 1 ? 1 : 0) . ">" . $row["name"] . "</option>";
			 }
			db_set_active(); 
		?>
		</select>
	</section>
	<section id="selectArea">
		<select>
			
		</select>
	</section>
	<section id="buttonArea">
		<button id='upload'><span class="label">Upload Data</span></button>
		<button id='interpolate'><span class="label">Interpolate</span></button>
	</section>
	<section id="searchArea">
		<label id="searchLabel">Enter Address: </label>
		<div id="searchInput"><input id='address' placeholder='Start typing a place name...' type='text' /></div>
		<!-- <button class="action bluebtn" id="searchButton">
			<span class="label">Search</span>
		</button>  -->		
	</section>

 	<!--LAYERS PANEL OPEN/CLOSE-->
 	<span href="#" id="layersOpen" title="Layers" class="layersToggle">Layers <span class="rsaquo open"><img src="./sites/all/modules/ibh_epidemiology_viewer/images/arrow-bk-right.png" /></span><span class="rsaquo close"><img src="./sites/all/modules/ibh_epidemiology_viewer/images/arrow-bk-down.png" /></span></span>

	<!--WIDGET PANEL OPEN/CLOSE-->
	<span href="#" id="sidebarOpen" title="More" class="sidebarToggle">About <span class="rsaquo open"><img src="./sites/all/modules/ibh_epidemiology_viewer/images/arrow-bk-right.png" /></span><span class="rsaquo close"><img src="./sites/all/modules/ibh_epidemiology_viewer/images/arrow-bk-down.png" /></span></span>
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