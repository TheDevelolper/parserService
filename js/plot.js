// add the graph canvas to the body of the webpage
var svg, tooltip;

var squareSize = 950, // Need 3000 if using plotter
	margin = {top:40, right: 40, bottom: 40, left: 40},
	width = squareSize - margin.left - margin.right,
	height = squareSize - margin.top - margin.bottom;

// setup X
var xValue = function(d) { return d.x; }, 			// data -> value
	xScale = d3.scale.linear().range([0, width]), 	// value -> display
	xMap = function(d) { return xScale(xValue(d));}, // data -> display
	xAxis = d3.svg.axis().scale(xScale).orient("bottom");
	
// setup y
var yValue = function(d) { return d["y"];},			// data -> value
	yScale = d3.scale.linear().range([height, 0]), // value -> display
	yMap = function(d) { return yScale(yValue(d)); }, // data -> display
	yAxis = d3.svg.axis().scale(yScale).orient("left");

var xMin, xMax, xRange,
    yMin, yMax, yRange;

function plot_canvas()
{
  svg = d3.select("body")
  .append("svg")
	.attr("width", squareSize)
	.attr("height", squareSize)
  .append("g")
	.attr("transform", "translate(" + margin.left + "," + margin.top + ")");  
}
 
function plot_tooltip()
{
    tooltip = d3.select("body").append("div")
	.attr("class", "tooltip")
	.style("opacity", 0);
}

function plot_resize(sqSize)
{
    squareSize = sqSize;
   	width = squareSize - margin.left - margin.right;
	height = squareSize - margin.top - margin.bottom;
    xScale = d3.scale.linear().range([0, width]);
    xAxis = d3.svg.axis().scale(xScale).orient("bottom");
    yScale = d3.scale.linear().range([height, 0]); // value -> display
	yAxis = d3.svg.axis().scale(yScale).orient("left");
}

function set_range()
{
    // Now need to find the extents of the user data
    xMin = d3.min(users, xValue) - 1;
    xMax = d3.max(users, xValue) + 3;
    yMin = d3.min(users, yValue) - 1;
    yMax = d3.max(users, yValue) + 3;
    
    xRange = xMax - xMin;
    yRange = yMax - yMin;
    
    if (yRange > xRange)
    {
        xScale.domain([xMin, xMin + yRange]); // Increase xRange
        yScale.domain([yMin, yMax]);    
    }
    else if(xRange > yRange)
    {
        xScale.domain([xMin, xMax]);
        yScale.domain([yMin, yMin + xRange]);    // Increase yRange
    }
    else
    {
        xScale.domain([xMin, xMax]);
        yScale.domain([yMin, yMax]);    
    }
}

function plot_axes()
{
  // x-axis
  svg.append("g")
      .attr("class", "x-axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis)
    .append("text")
      .attr("class", "label")
      .attr("x", width)
      .attr("y", -6)
      .style("text-anchor", "end")
      .text("X");

  // y-axis
  svg.append("g")
      .attr("class", "y-axis")
      .call(yAxis)
    .append("text")
      .attr("class", "label")
      .attr("transform", "rotate(-90)")
      .attr("y", 6)
      .attr("dy", ".71em")
      .style("text-anchor", "end")
      .text("Y");	
}

function update_axes()
{
    d3.select(".x-axis")
        .remove();
    d3.select(".y-axis")
        .remove();
    plot_axes();
}

var legend_box_width = 18;
function plot_legend()
{
    // Create legend Group
    var legend = svg.append("g")
                    .attr("class", "legend");
	var legend_entry = legend.selectAll(".legend_entry")
		.data(color.domain())
	  .enter().append("g")
		.attr("class", "legend_entry")
		.attr("transform", function(d,i) { return "translate(0,"+i*20 +")"; });

	

	// draw legend colored rectangles
	legend_entry.append("rect")
		.attr("class", "legend-rect")
		.attr("x", width - legend_box_width)
		.attr("width", legend_box_width)
		.attr("height", legend_box_width)
		.style("fill", color);		
	
	// draw legend text
	legend_entry.append("text")
		.attr("class", "legend-text")
		.attr("x", width-(legend_box_width + 6))
		.attr("y", 9)
		.attr("dy", ".35em")
		.style("text-anchor", "end")
		.text(function(d) { return d;})
}

function update_legend()
{
    d3.select(".legend")
        .remove();
    plot_legend();
}

function zoom() {
  circle.attr("transform", transform);
  text.attr("transform", transform);
}

function transform(d) {
  return "translate(" + x(d.x) + "," + y(d.y) + ")";
}

/* Colour management functions */
function Interpolate(start, end, steps, count) {
    var s = start,
        e = end,
        final = s + (((e - s) / steps) * count);
    return Math.floor(final);
}

function Color(_r, _g, _b) {
    var r, g, b;
    var setColors = function(_r, _g, _b) {
        r = _r;
        g = _g;
        b = _b;
    };

    setColors(_r, _g, _b);
    this.getColors = function() {
        var colors = {
            r: r,
            g: g,
            b: b
        };
        return colors;
    };
}