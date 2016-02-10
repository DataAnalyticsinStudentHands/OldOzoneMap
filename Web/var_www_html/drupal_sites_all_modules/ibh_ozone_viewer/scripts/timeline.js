nv.models.line = function() {
  "use strict";
  //============================================================
  // Public Variables with Default Settings
  //------------------------------------------------------------

  var  scatter = nv.models.scatter()
    ;

  var margin = {top: 0, right: 0, bottom: 0, left: 0}
    , width = 960
    , height = 500
    , color = nv.utils.defaultColor() // a function that returns a color
    , getX = function(d) { return d.x } // accessor to get the x value from a data point
    , getY = function(d) { return d.y } // accessor to get the y value from a data point
	, getY0 = function(d) { return d.y0 }
    , defined = function(d,i) { return !isNaN(getY(d,i)) && getY(d,i) !== null } // allows a line to be not continuous when it is not defined
    , isArea = function(d) { return d.area } // decides if a line is an area or just a line
    , clipEdge = false // if true, masks lines within x and y scale
    , x //can be accessed via chart.xScale()
    , y //can be accessed via chart.yScale()
    , interpolate = "linear" // controls the line interpolation
    ;

  scatter
    .size(16) // default size
    .sizeDomain([16,256]) //set to speed up calculation, needs to be unset if there is a custom size accessor	
	.pointActive(function(d) { return !isArea(d,d.series) && d.series < 9; })
	;

  //============================================================


  //============================================================
  // Private Variables
  //------------------------------------------------------------

  var x0, y0 //used to store previous scales
      ;

  //============================================================


  function chart(selection) {
    selection.each(function(data) {
      var availableWidth = width - margin.left - margin.right,
          availableHeight = height - margin.top - margin.bottom,
          container = d3.select(this);

      //------------------------------------------------------------
      // Setup Scales

      x = scatter.xScale();
      y = scatter.yScale();

      x0 = x0 || x;
      y0 = y0 || y;

      //------------------------------------------------------------


      //------------------------------------------------------------
      // Setup containers and skeleton of chart

      var wrap = container.selectAll('g.nv-wrap.nv-line').data([data]);
      var wrapEnter = wrap.enter().append('g').attr('class', 'nvd3 nv-wrap nv-line');
      var defsEnter = wrapEnter.append('defs');
      var gEnter = wrapEnter.append('g');
      var g = wrap.select('g')

      gEnter.append('g').attr('class', 'nv-groups');
      gEnter.append('g').attr('class', 'nv-scatterWrap');

      wrap.attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');

      //------------------------------------------------------------




      scatter
        .width(availableWidth)
        .height(availableHeight)

      var scatterWrap = wrap.select('.nv-scatterWrap');
          //.datum(data); // Data automatically trickles down from the wrap

      scatterWrap.transition().call(scatter);



      defsEnter.append('clipPath')
          .attr('id', 'nv-edge-clip-' + scatter.id())
        .append('rect');

      wrap.select('#nv-edge-clip-' + scatter.id() + ' rect')
          .attr('width', availableWidth)
          .attr('height', (availableHeight > 0) ? availableHeight : 0);

      g   .attr('clip-path', clipEdge ? 'url(#nv-edge-clip-' + scatter.id() + ')' : '');
      scatterWrap
          .attr('clip-path', clipEdge ? 'url(#nv-edge-clip-' + scatter.id() + ')' : '');




      var groups = wrap.select('.nv-groups').selectAll('.nv-group')
          .data(function(d) { return d }, function(d) { return d.key });
      groups.enter().append('g')
          .style('stroke-opacity', 1e-6)
          .style('fill-opacity', 1e-6);

      groups.exit().remove();

      groups
          .attr('class', function(d,i) { return 'nv-group nv-series-' + i })
          .classed('hover', function(d) { return d.hover })
          .style('fill', function(d,i){ return color(d, i) })
          .style('stroke', function(d,i){ return color(d, i)});
      groups
          .transition()
          .style('stroke-opacity', 1)
          .style('fill-opacity', .5);



      var areaPaths = groups.selectAll('path.nv-area')
          .data(function(d, i) { return isArea(d,i) ? [d] : [] }); // this is done differently than lines because I need to check if series is an area
      areaPaths.enter().append('path')
          .attr('class', 'nv-area')
          .attr('d', function(d) {
            return d3.svg.area()
                .interpolate(interpolate)
                .defined(defined)
                .x(function(d,i) { return nv.utils.NaNtoZero(x(getX(d,i))) })
                .y0(function(d,i) { return nv.utils.NaNtoZero(y(getY(d,i))) })
                .y1(function(d,i) { return nv.utils.NaNtoZero(y(getY0(d,i))) })
				//.y1(function(d,i) { return y0( y.domain()[0] <= 0 ? y.domain()[1] >= 0 ? 0 : y.domain()[1] : y.domain()[0] ) })
                //.y1(function(d,i) { return y0(0) }) //assuming 0 is within y domain.. may need to tweak this
                .apply(this, [d.values])
          });
      groups.exit().selectAll('path.nv-area')
           .remove();

      areaPaths
          .transition()
          .attr('d', function(d) {
            return d3.svg.area()
                .interpolate(interpolate)
                .defined(defined)
                .x(function(d,i) { return nv.utils.NaNtoZero(x(getX(d,i))) })
                .y0(function(d,i) { return nv.utils.NaNtoZero(y(getY(d,i))) })
                .y1(function(d,i) { return nv.utils.NaNtoZero(y(getY0(d,i))) })
                //.y1(function(d,i) { return y( y.domain()[0] <= 0 ? y.domain()[1] >= 0 ? 0 : y.domain()[1] : y.domain()[0] ) })
                //.y1(function(d,i) { return y0(0) }) //assuming 0 is within y domain.. may need to tweak this
                .apply(this, [d.values])
          });



      var linePaths = groups.selectAll('path.nv-line')
          .data(function(d,i) { return isArea(d,i) ? [] : [d.values] });
      linePaths.enter().append('path')
          .attr('class', 'nv-line')
          .attr('d',
            d3.svg.line()
              .interpolate(interpolate)
              .defined(defined)
              .x(function(d,i) { return nv.utils.NaNtoZero(x0(getX(d,i))) })
              .y(function(d,i) { return nv.utils.NaNtoZero(y0(getY(d,i))) })
          );

      linePaths
          .transition()
          .attr('d',
            d3.svg.line()
              .interpolate(interpolate)
              .defined(defined)
              .x(function(d,i) { return nv.utils.NaNtoZero(x(getX(d,i))) })
              .y(function(d,i) { return nv.utils.NaNtoZero(y(getY(d,i))) })
          );



      //store old scales for use in transitions on update
      x0 = x.copy();
      y0 = y.copy();

    });

    return chart;
  }


  //============================================================
  // Expose Public Variables
  //------------------------------------------------------------

  chart.dispatch = scatter.dispatch;
  chart.scatter = scatter;

  d3.rebind(chart, scatter, 'id', 'interactive', 'size', 'xScale', 'yScale', 'zScale', 'xDomain', 'yDomain', 'xRange', 'yRange',
    'sizeDomain', 'forceX', 'forceY', 'forceSize', 'clipVoronoi', 'useVoronoi', 'clipRadius', 'padData','highlightPoint','clearHighlights');

  chart.options = nv.utils.optionsFunc.bind(chart);

  chart.margin = function(_) {
    if (!arguments.length) return margin;
    margin.top    = typeof _.top    != 'undefined' ? _.top    : margin.top;
    margin.right  = typeof _.right  != 'undefined' ? _.right  : margin.right;
    margin.bottom = typeof _.bottom != 'undefined' ? _.bottom : margin.bottom;
    margin.left   = typeof _.left   != 'undefined' ? _.left   : margin.left;
    return chart;
  };

  chart.width = function(_) {
    if (!arguments.length) return width;
    width = _;
    return chart;
  };

  chart.height = function(_) {
    if (!arguments.length) return height;
    height = _;
    return chart;
  };

  chart.x = function(_) {
    if (!arguments.length) return getX;
    getX = _;
    scatter.x(_);
    return chart;
  };

  chart.y = function(_) {
    if (!arguments.length) return getY;
    getY = _;
    scatter.y(_);
    return chart;
  };

  chart.clipEdge = function(_) {
    if (!arguments.length) return clipEdge;
    clipEdge = _;
    return chart;
  };

  chart.color = function(_) {
    if (!arguments.length) return color;
    color = nv.utils.getColor(_);
    scatter.color(color);
    return chart;
  };

  chart.interpolate = function(_) {
    if (!arguments.length) return interpolate;
    interpolate = _;
    return chart;
  };

  chart.defined = function(_) {
    if (!arguments.length) return defined;
    defined = _;
    return chart;
  };

  chart.isArea = function(_) {
    if (!arguments.length) return isArea;
    isArea = d3.functor(_);
    return chart;
  };

  //============================================================


  return chart;
}

nv.models.lineWithFocusChart = function() {
  "use strict";
  //============================================================
  // Public Variables with Default Settings
  //------------------------------------------------------------

  var lines = nv.models.line()
    , lines2 = nv.models.line()
    , xAxis = nv.models.axis()
    , yAxis = nv.models.axis()
    , x2Axis = nv.models.axis()
    , y2Axis = nv.models.axis()
    , legend = nv.models.legend()
    , brush = d3.svg.brush()
    ;

  var margin = {top: 30, right: 30, bottom: 30, left: 60}
    , margin2 = {top: 0, right: 30, bottom: 20, left: 60}
    , color = nv.utils.defaultColor()
    , width = null
    , height = null
    , height2 = 100
    , x
    , y
    , x2
    , y2
    , showLegend = true
    , brushExtent = null
    , tooltips = true
    , tooltip = function(key, x, y, e, graph) {
		return '<h3>' + key + '</h3>' + '<p>' +  y + ' at ' + x + '</p>'
      }
    , noData = "No Data Available."
    , dispatch = d3.dispatch('tooltipShow', 'tooltipHide', 'brush')
    , transitionDuration = 250
	, customOnBrush = function () { console.log("custom onbrush called;")}
	, customOnBrushData = function () { console.log("custom onbrushdata called;")}
	, customTooltipEvent = function (timestamp) { console.log("custom tooltip called", timestamp)};
    ;

  lines
    .clipEdge(false)
    ;
  lines2
    .interactive(false)
    ;
  xAxis
    .orient('bottom')
    .tickPadding(5)
    ;
  yAxis
    .orient('left')
    ;
  x2Axis
    .orient('bottom')
    .tickPadding(5)
    ;
  y2Axis
    .orient('left')
    ;
  //============================================================


  //============================================================
  // Private Variables
  //------------------------------------------------------------

  var showTooltip = function(e, offsetElement) {
    var left = e.pos[0], // + ( offsetElement.offsetLeft || 0 ),
        top = e.pos[1], // + ( offsetElement.offsetTop || 0),
        x = xAxis.tickFormat()(lines.x()(e.point, e.pointIndex)),
        y = yAxis.tickFormat()(lines.y()(e.point, e.pointIndex)),
        content = tooltip(e.series.key, x, y, e, chart);
	customTooltipEvent(+lines.x()(e.point, e.pointIndex)*.001);
    nv.tooltip.show([left, 30], content, null, null, offsetElement);
  };

  //============================================================


  function chart(selection) {	
    selection.each(function(data) {
      var container = d3.select(this),
          that = this;

      var availableWidth = (width  || parseInt(container.style('width')) || 960)
                             - margin.left - margin.right,
          availableHeight1 = (height || parseInt(container.style('height')) || 400)
                             - margin.top - margin.bottom - height2,
          availableHeight2 = height2 - margin2.top - margin2.bottom;

      chart.update = function() { container.transition().duration(transitionDuration).call(chart) };
      chart.container = this;


      //------------------------------------------------------------
      // Display No Data message if there's nothing to show.

      if (!data || !data.length || !data.filter(function(d) { return d.values.length }).length) {
        var noDataText = container.selectAll('.nv-noData').data([noData]);

        noDataText.enter().append('text')
          .attr('class', 'nvd3 nv-noData')
          .attr('dy', '-.7em')
          .style('text-anchor', 'middle');

        noDataText
          .attr('x', margin.left + availableWidth / 2)
          .attr('y', margin.top + availableHeight1 / 2)
          .text(function(d) { return d });

        return chart;
      } else {
        container.selectAll('.nv-noData').remove();
      }

      //------------------------------------------------------------


      //------------------------------------------------------------
      // Setup Scales

      x = lines.xScale();
      y = lines.yScale();
      x2 = lines2.xScale();
      y2 = lines2.yScale();

      //------------------------------------------------------------


      //------------------------------------------------------------
      // Setup containers and skeleton of chart

      var wrap = container.selectAll('g.nv-wrap.nv-lineWithFocusChart').data([data]);
      var gEnter = wrap.enter().append('g').attr('class', 'nvd3 nv-wrap nv-lineWithFocusChart').append('g');
      var g = wrap.select('g');

      gEnter.append('g').attr('class', 'nv-legendWrap');

      var focusEnter = gEnter.append('g').attr('class', 'nv-focus');
      focusEnter.append('g').attr('class', 'nv-x nv-axis');
      focusEnter.append('g').attr('class', 'nv-y nv-axis');
      focusEnter.append('g').attr('class', 'nv-linesWrap');

      var contextEnter = gEnter.append('g').attr('class', 'nv-context');
      contextEnter.append('g').attr('class', 'nv-x nv-axis');
      contextEnter.append('g').attr('class', 'nv-y nv-axis');
      contextEnter.append('g').attr('class', 'nv-linesWrap');
      contextEnter.append('g').attr('class', 'nv-brushBackground');
      contextEnter.append('g').attr('class', 'nv-x nv-brush');

      //------------------------------------------------------------


      //------------------------------------------------------------
      // Legend

      if (showLegend) {
        legend.width(availableWidth);

        g.select('.nv-legendWrap')
            .datum(data)
            .call(legend);

        if ( margin.top != legend.height()) {
          margin.top = legend.height();
          availableHeight1 = (height || parseInt(container.style('height')) || 400)
                             - margin.top - margin.bottom - height2;
        }

        g.select('.nv-legendWrap')
            .attr('transform', 'translate(0,' + (-margin.top) +')')
      }

      //------------------------------------------------------------


      wrap.attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');


      //------------------------------------------------------------
      // Main Chart Component(s)

      lines
        .width(availableWidth)
        .height(availableHeight1)
        .color(
          data
            .map(function(d,i) {
              return d.color || color(d, i);
            })
            .filter(function(d,i) {
              return !data[i].disabled;
          })
        );

      lines2
        .defined(lines.defined())
        .width(availableWidth)
        .height(availableHeight2)
        .color(
          data
            .map(function(d,i) {
              return d.color || color(d, i);
            })
            .filter(function(d,i) {
              return !data[i].disabled;
          })
        );

      g.select('.nv-context')
          .attr('transform', 'translate(0,' + ( availableHeight1 + margin.bottom + margin2.top) + ')')

      var contextLinesWrap = g.select('.nv-context .nv-linesWrap')
          .datum(data.filter(function(d, i) { return !d.disabled }))

      d3.transition(contextLinesWrap).call(lines2);

      //------------------------------------------------------------


      /*
      var focusLinesWrap = g.select('.nv-focus .nv-linesWrap')
          .datum(data.filter(function(d) { return !d.disabled }))

      d3.transition(focusLinesWrap).call(lines);
     */


      //------------------------------------------------------------
      // Setup Main (Focus) Axes

      xAxis
        .scale(x)
        .ticks( availableWidth / 100 )
        .tickSize(-availableHeight1, 0);

      yAxis
        .scale(y)
        .ticks( availableHeight1 / 36 )
        .tickSize( -availableWidth, 0);

      g.select('.nv-focus .nv-x.nv-axis')
          .attr('transform', 'translate(0,' + availableHeight1 + ')');

      //------------------------------------------------------------


      //------------------------------------------------------------
      // Setup Brush

      brush
        .x(x2)
        .on('brushend', function() {
            //When brushing, turn off transitions because chart needs to change immediately.
            var oldTransition = chart.transitionDuration();
            chart.transitionDuration(0); 
            onBrush();
            chart.transitionDuration(oldTransition);
        })
		.on('brush', function() {
			brushExtent = brush.empty() ? null : brush.extent();
	        var extent = brush.empty() ? x2.domain() : brush.extent();

	        //The brush extent cannot be less than one.  If it is, don't update the line chart.
	        if (Math.abs(extent[0] - extent[1]) <= 1) {
	          return;
	        }
	        dispatch.brush({extent: extent, brush: brush});
	        updateBrushBG();
		});

      if (brushExtent) brush.extent(brushExtent);

      var brushBG = g.select('.nv-brushBackground').selectAll('g')
          .data([brushExtent || brush.extent()])

      var brushBGenter = brushBG.enter()
          .append('g');

      brushBGenter.append('rect')
          .attr('class', 'left')
          .attr('x', 0)
          .attr('y', 0)
          .attr('height', availableHeight2);

      brushBGenter.append('rect')
          .attr('class', 'right')
          .attr('x', 0)
          .attr('y', 0)
          .attr('height', availableHeight2);

      var gBrush = g.select('.nv-x.nv-brush')
          .call(brush);
      gBrush.selectAll('rect')
          //.attr('y', -5)
          .attr('height', availableHeight2);
      gBrush.selectAll('.resize').append('path').attr('d', resizePath);

      onBrush();

      //------------------------------------------------------------


      //------------------------------------------------------------
      // Setup Secondary (Context) Axes

      x2Axis
        .scale(x2)
        .ticks( availableWidth / 100 )
        .tickSize(-availableHeight2, 0);

      g.select('.nv-context .nv-x.nv-axis')
          .attr('transform', 'translate(0,' + y2.range()[0] + ')');
      d3.transition(g.select('.nv-context .nv-x.nv-axis'))
          .call(x2Axis);


      y2Axis
        .scale(y2)
        .ticks( availableHeight2 / 36 )
        .tickSize( -availableWidth, 0);

      d3.transition(g.select('.nv-context .nv-y.nv-axis'))
          .call(y2Axis);

      g.select('.nv-context .nv-x.nv-axis')
          .attr('transform', 'translate(0,' + y2.range()[0] + ')');

      //------------------------------------------------------------


      //============================================================
      // Event Handling/Dispatching (in chart's scope)
      //------------------------------------------------------------

      legend.dispatch.on('stateChange', function(newState) { 
        chart.update();
      });

      dispatch.on('tooltipShow', function(e) {
        if (tooltips) showTooltip(e, that.parentNode);
      });

      //============================================================


      //============================================================
      // Functions
      //------------------------------------------------------------

      // Taken from crossfilter (http://square.github.com/crossfilter/)
      function resizePath(d) {
        var e = +(d == 'e'),
            x = e ? 1 : -1,
            y = availableHeight2 / 3;
        return 'M' + (.5 * x) + ',' + y
            + 'A6,6 0 0 ' + e + ' ' + (6.5 * x) + ',' + (y + 6)
            + 'V' + (2 * y - 6)
            + 'A6,6 0 0 ' + e + ' ' + (.5 * x) + ',' + (2 * y)
            + 'Z'
            + 'M' + (2.5 * x) + ',' + (y + 8)
            + 'V' + (2 * y - 8)
            + 'M' + (4.5 * x) + ',' + (y + 8)
            + 'V' + (2 * y - 8);
      }


      function updateBrushBG() {
        if (!brush.empty()) brush.extent(brushExtent);
        brushBG
            .data([brush.empty() ? x2.domain() : brushExtent])
            .each(function(d,i) {
              var leftWidth = x2(d[0]) - x.range()[0],
                  rightWidth = x.range()[1] - x2(d[1]);
              d3.select(this).select('.left')
                .attr('width',  leftWidth < 0 ? 0 : leftWidth);

              d3.select(this).select('.right')
                .attr('x', x2(d[1]))
                .attr('width', rightWidth < 0 ? 0 : rightWidth);
            });		
      }

      function onBrush() {
        brushExtent = brush.empty() ? null : brush.extent();
        var extent = brush.empty() ? x2.domain() : brush.extent();

        //The brush extent cannot be less than one.  If it is, don't update the line chart.
        if (Math.abs(extent[0] - extent[1]) <= 1) {
          return;
        }

		var starttime = Math.floor(+extent[0]/1000);
		var endtime = Math.floor(+extent[1]/1000);
		var timespan = endtime - starttime;
		
		var timesegment = "m"; //month
		
		if (timespan <= 6048000) //timespan < 100 weeks
			timesegment = "w";
			
		if (timespan <= 8640000) //timespan <= 100 days
			timesegment = "d"; //days
		
		if (timespan <= 360000) //timespan <= 100 hours
			timesegment = "h"; //hour
			
		if (timespan <= 30000) //timespan <= 100 5-minute epochs
			timesegment = "e"; //epoch per 5-minute data
			 
		// if (brushExtent) {
		// 	dispatch.brush({extent: extent, brush: brush});
		// 	        updateBrushBG();
		// 	// Update Context Area
		// 	g.select('.nv-context .nv-linesWrap svg').remove();
		// 	        var contextLinesWrap = g.select('.nv-context .nv-linesWrap')
		// 	            .datum(
		// 	              data
		// 	                .filter(function(d) { return !d.disabled })
		// 	                .map(function(d,i) {
		// 	                  return {
		// 	                    key: d.key,
		// 	                    values: d.values.filter(function(d,i) {
		// 	                      return lines2.x()(d,i) >= (+extent[0]-timespan*2000) && lines2.x()(d,i) <= (+extent[1]+timespan*2000);
		// 	                    })
		// 	                  }
		// 	                })
		// 	            );
		// 	        contextLinesWrap.transition().duration(transitionDuration).call(lines2);
		// 
		// 	        // Update Context Axes
		// 	        g.select('.nv-context .nv-x.nv-axis').transition().duration(transitionDuration)
		// 	            .call(x2Axis);
		// 	        g.select('.nv-context .nv-y.nv-axis').transition().duration(transitionDuration)
		// 	            .call(y2Axis);
		// }
		// 
		// extent = brush.empty() ? x2.domain() : brush.extent();
        dispatch.brush({extent: extent, brush: brush});
        updateBrushBG();
	
		var timeline_data_src = '/sites/all/modules/ibh_ozone_viewer/ajax/getTimelineData.php?seg=' + timesegment + '&s=' + starttime + '&e=' + endtime;
		var line_data = [
			{key: "hazardous", values: [] },
			{key: "very", values: [] }, 
			{key: "unhealthy", values: [] },
			{key: "warning", values: [] },
			{key: "moderate", values: [] }, 
			{key: "good", values: [] }, 
			{key: "average", values: [] },
			{key: "maximum", values: [] },
			{key: "minimum", values: [] }
		];
		
		d3.csv(timeline_data_src, function(error, data_focus) {
			data_focus.forEach(function(d) {
				var date = new Date(+d.epoch*1000);
				var coeff = (parseInt(d.maximum)-parseInt(d.minimum))/parseInt(d.total);
				var good = parseInt(d.good)*coeff+parseInt(d.minimum);
				var moderate = parseInt(d.moderate)*coeff+good;
				var warning = parseInt(d.warning)*coeff+moderate;
				var unhealthy = parseInt(d.unhealthy)*coeff+warning;
				var very = parseInt(d.very)*coeff+unhealthy;
				var hazardous = parseInt(d.hazardous)*coeff+very;
				line_data[0]["values"].push({x: date, y: very, y0: hazardous});
				line_data[1]["values"].push({x: date, y: unhealthy, y0: very});
				line_data[2]["values"].push({x: date, y: warning, y0: unhealthy});
				line_data[3]["values"].push({x: date, y: moderate, y0: warning});
				line_data[4]["values"].push({x: date, y: good, y0: moderate});
				line_data[5]["values"].push({x: date, y: +d.minimum, y0: good });
				line_data[6]["values"].push({x: date, y: +d.average, y0: +d.average, max: +d.maximum, min: +d.minimum });
				// line_data[7]["values"].push({x: date, y: +d.maximum, y0: +d.maximum });
				// line_data[8]["values"].push({x: date, y: +d.minimum, y0: +d.minimum });
				customOnBrushData(d);
			});
			
	        // Update Main (Focus)
		
			g.select('.nv-focus .nv-linesWrap svg').remove();
	
	        var focusLinesWrap = g.select('.nv-focus .nv-linesWrap')
				.append("svg")
	            .datum(line_data);
	        focusLinesWrap.transition().duration(transitionDuration).call(lines);


	        // Update Main (Focus) Axes
	        g.select('.nv-focus .nv-x.nv-axis').transition().duration(transitionDuration)
	            .call(xAxis);
	        g.select('.nv-focus .nv-y.nv-axis').transition().duration(transitionDuration)
	            .call(yAxis);

			customOnBrush();	
		});

 		//        // Update Main (Focus)
 		//         var focusLinesWrap = g.select('.nv-focus .nv-linesWrap')
 		//             .datum(
 		//               data
 		//                 .filter(function(d) { return !d.disabled })
 		//                 .map(function(d,i) {
 		//                   return {
 		//                     key: d.key,
 		//                     values: d.values.filter(function(d,i) {
 		//                       return lines.x()(d,i) >= extent[0] && lines.x()(d,i) <= extent[1];
 		//                     })
 		//                   }
 		//                 })
 		//             );
 		//         focusLinesWrap.transition().duration(transitionDuration).call(lines);
 		// 
 		// 
 		//         // Update Main (Focus) Axes
 		//         g.select('.nv-focus .nv-x.nv-axis').transition().duration(transitionDuration)
 		//             .call(xAxis);
 		//         g.select('.nv-focus .nv-y.nv-axis').transition().duration(transitionDuration)
 		//             .call(yAxis);
 		// 
 		// customOnBrush();
      }

      //============================================================
    });

    return chart;
  }


  //============================================================
  // Event Handling/Dispatching (out of chart's scope)
  //------------------------------------------------------------

  lines.dispatch.on('elementMouseover.tooltip', function(e) {
    dispatch.tooltipHide(e);
	e.pos = [e.pos[0] +  margin.left, e.pos[1] + margin.top];
	dispatch.tooltipShow(e);
  });
/*
  lines.dispatch.on('elementMouseout.tooltip', function(e) {
	dispatch.tooltipHide(e);
  });
*/

  dispatch.on('tooltipHide', function() {
    if (tooltips) nv.tooltip.cleanup();
  });

  //============================================================


  //============================================================
  // Expose Public Variables
  //------------------------------------------------------------

  // expose chart's sub-components
  chart.brush = brush;
  chart.dispatch = dispatch;
  chart.legend = legend;
  chart.lines = lines;
  chart.lines2 = lines2;
  chart.xAxis = xAxis;
  chart.yAxis = yAxis;
  chart.x2Axis = x2Axis;
  chart.y2Axis = y2Axis;

  d3.rebind(chart, lines, 'defined', 'isArea', 'size', 'xDomain', 'yDomain', 'xRange', 'yRange', 'forceX', 'forceY', 'interactive', 'clipEdge', 'clipVoronoi', 'id');

  chart.options = nv.utils.optionsFunc.bind(chart);
  
  chart.x = function(_) {
    if (!arguments.length) return lines.x;
    lines.x(_);
    lines2.x(_);
    return chart;
  };

  chart.y = function(_) {
    if (!arguments.length) return lines.y;
    lines.y(_);
    lines2.y(_);
    return chart;
  };

  chart.margin = function(_) {
    if (!arguments.length) return margin;
    margin.top    = typeof _.top    != 'undefined' ? _.top    : margin.top;
    margin.right  = typeof _.right  != 'undefined' ? _.right  : margin.right;
    margin.bottom = typeof _.bottom != 'undefined' ? _.bottom : margin.bottom;
    margin.left   = typeof _.left   != 'undefined' ? _.left   : margin.left;
    return chart;
  };

  chart.margin2 = function(_) {
    if (!arguments.length) return margin2;
    margin2 = _;
    return chart;
  };

  chart.width = function(_) {
    if (!arguments.length) return width;
    width = _;
    return chart;
  };

  chart.height = function(_) {
    if (!arguments.length) return height;
    height = _;
    return chart;
  };

  chart.height2 = function(_) {
    if (!arguments.length) return height2;
    height2 = _;
    return chart;
  };

  chart.color = function(_) {
    if (!arguments.length) return color;
    color =nv.utils.getColor(_);
    legend.color(color);
    return chart;
  };

  chart.showLegend = function(_) {
    if (!arguments.length) return showLegend;
    showLegend = _;
    return chart;
  };

  chart.tooltips = function(_) {
    if (!arguments.length) return tooltips;
    tooltips = _;
    return chart;
  };

  chart.tooltipContent = function(_) {
    if (!arguments.length) return tooltip;
    tooltip = _;
    return chart;
  };

  chart.interpolate = function(_) {
    if (!arguments.length) return lines.interpolate();
    lines.interpolate(_);
    lines2.interpolate(_);
    return chart;
  };

  chart.noData = function(_) {
    if (!arguments.length) return noData;
    noData = _;
    return chart;
  };

  // Chart has multiple similar Axes, to prevent code duplication, probably need to link all axis functions manually like below
  chart.xTickFormat = function(_) {
    if (!arguments.length) return xAxis.tickFormat();
    xAxis.tickFormat(_);
    x2Axis.tickFormat(_);
    return chart;
  };

  chart.yTickFormat = function(_) {
    if (!arguments.length) return yAxis.tickFormat();
    yAxis.tickFormat(_);
    y2Axis.tickFormat(_);
    return chart;
  };
  
  chart.brushExtent = function(_) {
    if (!arguments.length) return brushExtent;
    brushExtent = _;
    return chart;
  };

  chart.transitionDuration = function(_) {
    if (!arguments.length) return transitionDuration;
    transitionDuration = _;
    return chart;
  };

  chart.customOnBrush = function(_) {
   if (!arguments.length) return customOnBrush;
    customOnBrush = _;
    return chart;		
  }

  chart.customOnBrushData = function(_) {
   if (!arguments.length) return customOnBrushData;
    customOnBrushData = _;
    return chart;		
  }


  chart.customTooltipEvent = function(_) {
   if (!arguments.length) return customTooltipEvent;
    customTooltipEvent = _;
    return chart;	
  }

  //============================================================


  return chart;
}