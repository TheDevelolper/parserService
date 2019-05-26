var parser;

// Setup global elements

// Shape Variables
var event_delta_y = 20;
var event_x = 300;
var arrow_height = 2;
var arrow_width = 10;

var node_box_half_width = 50;
var node_box_half_height = 10;
var event_box_half_width = 80;
var event_box_half_height = 8;
var state_box_half_width = 80;
var state_box_half_height = 8;

var node_box_width = 2 * node_box_half_width;
var node_box_height = 2 * node_box_half_height;
var event_box_width = 2 * event_box_half_width;
var event_box_height = 2 * event_box_half_height;
var state_box_width = 2 * state_box_half_width;
var state_box_height = 2 * state_box_half_height;
var num_events;
var num_filtered_events;
        
var max_events_per_iframe = 500;

// Band handling
var max_bands = max_events_per_iframe;
var band_height = event_delta_y;
var row_band_min_x = 10;

// Node Positioning
var num_nodes;
var num_filtered_nodes;
    
// Left most node position
var nodeMinX = event_box_half_width+2;
    
// Determine column heading positions
// X Position for Line column
var line_x = 20;
var line_width = 60;

// X Position for Date column -->
var date_x;
var date_width = 150;
var num_date;

// X Position for Tag column -->
var longest_tag_length = 3;
var tag_x, tag_width;
var num_tag;

var defaultBodyWidth = 1100;
var node_level_gap = 5;
var nodeMaxX;
var nodeDelta;
var max_nodes_per_level;
var num_node_levels;
var head_y; // max y in the hdr / title
var max_y; // max_y in the rows / body

// Update the column widths for the row panel
function recalculateColumns() {
    date_x = line_x + line_width;
    if (num_date)
    {
        tag_x = date_x + date_width;
    }
    else {
        tag_x = date_x;
    }
    
    if (num_tag) {
        //tag_width = 80;
        tag_width = (longest_tag_length * 6)+10;
        
    }
    else {
        tag_width = 0;
    }
    
    // Calculate positions for the node boxes
    var tmpNodeMaxX = defaultBodyWidth - tag_x - tag_width;
    var tmpMaxNodesPerLevel = Math.floor((tmpNodeMaxX - nodeMinX) / node_box_width);

    var tmpNumNodeLevels = Math.floor(num_filtered_nodes / tmpMaxNodesPerLevel) + 1;
    if (tmpNumNodeLevels < 4)
        nodeMaxX = tmpNodeMaxX;
    else  nodeMaxX = num_filtered_nodes * node_box_half_width;
    
    var nodeXRange = nodeMaxX - nodeMinX;
    nodeDelta = Math.floor( nodeXRange / ( num_filtered_nodes - 1 ) );
    max_nodes_per_level = Math.floor( nodeXRange / node_box_width );
    num_node_levels = Math.floor(num_filtered_nodes / max_nodes_per_level)+1;
    head_y = (num_node_levels+0.5) * node_box_height + (num_node_levels * node_level_gap);

    max_y = ((num_filtered_events+1) * event_delta_y);
}

function getNodeIdx(node) {
    var nodeArray = filtered_config;
    for (var i=0; i < nodeArray.length; i++)
    {
        if (nodeArray[i].name === node) {
            return i;
        }
    }
    return nodeArray.length;
}

function getNodeX(node) {
    var nodeIndex = getNodeIdx(node);
    return (nodeDelta* nodeIndex ) + nodeMinX;
}

function getNodeXFromIdx(i) {
    return (nodeDelta* i ) + nodeMinX;
}

function getOrigIdx(d)
{
    return d.orig_idx;
}
var sevCritical = 0,
    sevMajor = 1,
    sevMinor = 2,
    sevIntermit = 3,
    sevInfo = 4,
    sevClear = 5;
    
function getSevColour(d)
{
    switch(d.sev) {
        case sevCritical: return "red";
        case sevMajor: return "orange";
        case sevMinor: return "yellow";
        case sevIntermit: return "salmon";
        case sevInfo: return "white";
        case sevClear: return "lightgreen";
        default: return black;
    }
}

// Now start to load the processed data
var input_json = '/processed/'+ global_vars.msc_json;
var loghtml    = '/processed/' + global_vars.loghtml;
var config, filtered_config, metadata, events;

//load the external data
d3.json(input_json, function(error, data)
{
	console.log("In ready");
    console.log("Input JSON:", input_json);
    console.log("loghtml:", loghtml);
	if (error) 
	{ 
		console.log("Error: " + error);
		alert("Error: " + error)
	}
	else
	{
        console.log(data);
        metadata = data.meta_data;
		config = data.config;
        events = data.events;
        
		// Have valid data so lets view it
		plot_data();
	}
});


function sanitiseCSSName(unsafe_name) {
    var safe_name = unsafe_name.split('.').join('-');
    var safe_name = safe_name.split('@').join('-');
    var safe_name = safe_name.split(':').join('-');
    return safe_name;
}

function isNodeVisible(node) {
    var visible = true;

    // Now apply the filter based upon the node
    if (node != undefined) {
        var selector = '#N' + sanitiseCSSName(node) + '.show-node-switch';
        var node_filter = d3.select(selector);
        if (node_filter[0][0].checked == false) {
            visible = false;  
        }
    }
    return visible;    
}

function isTagVisible(tag) {
    var visible = true;

    // Now apply the filter based upon the node
    if (tag != undefined) {
        var selector = '#T' + sanitiseCSSName(tag) + '.show-tag-switch';
        var tag_filter = d3.select(selector);
        if (tag_filter[0][0].checked == false) {
            visible = false;  
        }
    }
    return visible;    
}

// determine the stroke for a node line based upon its visibility
function getNodeLineStroke(node) {
    var node_visible = isNodeVisible(node);
    return (node_visible == true) ? '1 0' : '5 10';
}

// Function to determine if an event should be visible based upon the current filters.
function isEventVisible(ev) {
    // Setup variables to check.
    var ev_tag;
    var ev_node;
    var ev_to;
    var ev_from;
    
    if ('tag' in ev)    ev_tag = ev.tag;
    if ('node' in ev)   ev_node = ev.node;
    if ('to' in ev)     ev_to = ev.to;
    if ('from' in ev)   ev_from = ev.from;
        
    var visible = true;
    
    // Can we exclude due to tag filter?
    visible = visible && isTagVisible(ev_tag);
	if (ev_tag == undefined)
	{
        visible = visible && isTagVisible("Blank");
	}
	
	// Can we exclude due to the node tags?
	visible = visible && isNodeVisible(ev_node);
	visible = visible && isNodeVisible(ev_to);
	visible = visible && isNodeVisible(ev_from);

    return visible;
}
var filtered_events; // A version of data which has been filtered based upon the Node selection criteria
var filtered_msgs;
var filtered_evs;
var filtered_spans;

var tag_list = []; // a list of tags found in the event list.
function isTagInTagList(tagtext) {
    var tag_found = false;
    for (var i=0; i < tag_list.length; i++)
    {
        if (tag_list[i].text == tagtext)
        {
            tag_found = true;
            break;
        }   
    }
    return tag_found;
}

function getTagName(d) {
    return d.name;
}

function getTagText(d) {
    return d.text;
}
function plot_data()
{
    console.log("Metadata: ", metadata);
    console.log("Config: ", config);
    console.log("Events: ", events);
    num_events = events.length;
    console.log("num_events: ", num_events);
    
    num_nodes = config.length;
    console.log("num_nodes: ", num_nodes);
	
	filtered_config = config;
	num_filtered_nodes = num_nodes;
	console.log("filtered_config: ", config);
	console.log("num_filtered_nodes: ", num_filtered_nodes);
	    
    // Calculate num_tags, num_dates;
    num_date = 0;
    num_tag = 0;

    var blank_tag = {};
    blank_tag["name"] = "Blank";
    blank_tag["text"] = "";
    tag_list.push(blank_tag);
    
    for (i = 0; i < num_events; i++)
    {
        if ('date' in events[i])
            num_date++;

        // How many tags do we have
        // also populate the tag list.
        if ('tag' in events[i])
        {
            num_tag++;
            var tag = events[i].tag;
            // is tag value in the tag_list?
            if (! isTagInTagList(tag))
            {
                // No, then push it on.
                var new_tag = {};
                new_tag["name"] = tag;
                new_tag["text"] = tag;
                tag_list.push(new_tag);
            }   
            
            // Is this the longest tag found?
            if (tag.length > longest_tag_length)
                longest_tag_length = tag.length;
        }
    }
    
    console.log("num_date: ", num_date);
    console.log("num_tag: ", num_tag);
    console.log("tag_list: ", tag_list);

    setupVars();

    // Set up the filters options in the Nav Bar
    var filter_node_ul = d3.select("#bs-filter-by-node");
            
    var filter_node_lis = filter_node_ul.selectAll('.list-group-item')
            .data(config)
         .enter()
            .append("li")
                .attr("class", "list-group-item")
                .text(function(d) { return d.name})
            .append("span")
                .attr("class", "switch");
    filter_node_lis
            .append("input")
                .attr("type", "checkbox")
                .attr("class", "show-node-switch pull-right")
                .attr("id", function(d) {return "N" + sanitiseCSSName(d.name);})
                .attr("checked", "true")
                .attr("onClick", "refilterDisplay()");

/*    filter_node_lis.append("div")
                .attr("class", "slider round");
*/           
    // Set up the filters options in the Nav Bar
    var filter_tag_ul = d3.select("#bs-filter-by-tag");
            
    var filter_tag_lis = filter_tag_ul.selectAll('.list-group-item')
            .data(tag_list)
         .enter()
            .append("li")
                .attr("class", "list-group-item")
                .text(function(d) { return getTagName(d);})
            .append("span")
                .attr("class", "switch");
    filter_tag_lis
            .append("input")
                .attr("type", "checkbox")
                .attr("class", "show-tag-switch pull-right")
                .attr("id", function(d) {return "T" + sanitiseCSSName(getTagName(d));})
                .attr("checked", "true")
                .attr("onClick","refilterDisplay()");

    /*filter_tag_lis
            .append("div")
                .attr("class", "slider round");
*/
    drawAllContent();
}

function deleteContent() {
    d3.selectAll("#titlesvg").remove()
    d3.selectAll("#topsvg").remove()
    d3.selectAll("#rowsvg").remove()
    d3.selectAll("#bodysvg").remove()
}

function setAllNodes() {
    var all_checked = true;
	var node_filter = d3.selectAll(".select-all-nodes");
	if (node_filter[0][0].checked == false) {
		all_checked = false;  
	}

	checkboxes = document.getElementsByClassName("show-node-switch");
	for (var i = 0; i < checkboxes.length; i++)
	{
		checkboxes[i].checked = all_checked;
	}

	refilterDisplay();
}

function setAllTags() {
    var all_checked = true;
	var tag_filter = d3.selectAll(".select-all-tags");
	if (tag_filter[0][0].checked == false) {
		all_checked = false;  
	}

	checkboxes = document.getElementsByClassName("show-tag-switch");
	for (var i = 0; i < checkboxes.length; i++)
	{
		checkboxes[i].checked = all_checked;
	}
	
	refilterDisplay();
}

function filterNodes() {
    filtered_config = [];
    
    // now get a filtered view of the data
    for ( i = 0; i < num_nodes; i++ )
    {
        if ( isNodeVisible( config[i].name ) )
        {
            filtered_config.push(config[i]);
        }
        
    }
    
    num_filtered_nodes = filtered_config.length;
    console.log("Filtered Nodes", filtered_config);
}

function filterEvents() {
    filtered_events = [];
    
    // now get a filtered view of the data
    for ( i = 0; i < num_events; i++ )
    {
        if ( isEventVisible( events[i] ) )
        {
            filtered_events.push(events[i]);
        }
        
    }
    
    num_filtered_events = filtered_events.length;
    // now get a filtered view of the messages
    filtered_msgs = [];
    filtered_evs  = [];
    filtered_scs  = [];
    filtered_spans  = [];
    for (i = 0; i < num_filtered_events; i++)
    {
        if ( 'type' in filtered_events[i] )
        {
            if (filtered_events[i].type == 'msg')
            {
                msg = filtered_events[i];
                msg["orig_idx"] = i;
                filtered_msgs.push(msg);
            }
            else if (filtered_events[i].type == 'ev')
            {
                ev = filtered_events[i];
                ev["orig_idx"] = i;
                filtered_evs.push(ev);
            }
            else if (filtered_events[i].type == 'sc')
            {
                sc = filtered_events[i];
                sc["orig_idx"] = i;
                filtered_scs.push(sc);
            }
            else if (filtered_events[i].type == 'span')
            {
                span = filtered_events[i];
                span["orig_idx"] = i;
                filtered_spans.push(span);
            }
            else
            {
                console.log("Unhandled event type: ", filtered_events[i].type);
            }
        }
        else{
            console.log("Event with no type", filtered_events[i]);
        }
    }
    
    console.log("Filtered Events", filtered_events);
    console.log("Filtered Evs", filtered_evs);
    console.log("Filtered msgs", filtered_msgs);
    console.log("Filtered scs", filtered_scs);
}

function drawAllContent() {
    filterEvents();
	filterNodes();
    recalculateColumns();
    LayoutDiv();
    plotCanvases();
    drawTitle();
    drawHdr();
    drawRows();
    drawBody();        
}

function refilterDisplay () {
    console.log("Refiltering display");
    deleteContent();
    drawAllContent();
}

function drawTitle() {
    var title_g = titlesvg.append("g")
      .attr("class", "title_g");
    
    title_g.append("text")
        .attr("class","msghead")
        .attr("x", line_x)
        .attr("y", head_y - 10)
        .text("Line Num")
    
    if (num_date)
    {
        title_g.append("text")
            .attr("class","msghead")
            .attr("x", date_x)
            .attr("y", head_y - 10)
            .text("Time")
    }
    
    if (num_tag)
    {
        title_g.append("text")
            .attr("class","msghead")
            .attr("x", tag_x)
            .attr("y", head_y - 10)
            .text("Tag")        
    }
}

function drawHdr(){    
    var hdr_msc_node_lines = topsvg.append("g")
      .attr("class", "hdr_msc_node_lines");

		var node_line_a = hdr_msc_node_lines.selectAll(".hdr_msc_node_lines")
			.data(filtered_config)
		  .enter()
			.append("a")
				.attr("xlink:href", function( d ) {return ;})

		//Draw Node line
		node_line_a.append("line")
			.attr("class", "nodeline")
			.attr("x1", function(d,i) { return getNodeXFromIdx(i);})
			.attr("x2", function(d,i) { return getNodeXFromIdx(i);})
			.attr("y1", function(d,i) { 
				level= getNodeLevel(d,i);
				return (level+1)*node_box_height+ (level * node_level_gap)+1;})
			.attr("y2", head_y)
			.attr("stroke-dasharray", function(d) { return getNodeLineStroke(getNodeName(d));})
			
	var hdr_msc_nodes = topsvg.append("g")
      .attr("class", "hdr_msc_nodes");

		var node_a = hdr_msc_nodes.selectAll(".hdr_msc_node")
			.data(filtered_config)
		  .enter()
			.append("a")
				.attr("xlink:href", function( d ) {return ;})

				
			
		node_a.append("rect")
				.attr("class", "hdr_msc_node noderect")
				.attr("rx", 10)
				.attr("ry", 10)
				.attr("width", node_box_width)
				.attr("height", node_box_height)
				.attr("x", function( d,i ) { return getNodeXFromIdx(i) - node_box_half_width;})
				.attr("y", function( d, i ) { 
						level = getNodeLevel(d, i);
						return (level * node_box_height) + (level * node_level_gap)+1;
					})
		node_a.append("title")
			.text(function(d){ return getNodeName(d); });
		
		node_a.append("text")
			.attr("text-anchor", "middle")
			.attr("class", function(d) { 
				if (getNodeName(d).length > 8) {
					return "nodetextsmall";
				}
				else if(num_filtered_nodes > 8) {
					return  "nodetextsmall";
				}
				else {
					return "nodetext";
				}
			})
			.attr("x", function(d,i) {return getNodeXFromIdx(i);})
			.attr("y", function(d,i) {
				level = getNodeLevel(d,i);
				return (level+0.5)*node_box_height+3 +(level*node_level_gap+1);
			})
			.text(function(d) {return getNodeName(d);})
}

function drawRows() {
    var row_band_infos_g = rowsvg.append("g")
        .attr("class", "bands")

    band_x1 = 10;
    band_x2 = tag_x+tag_width+5;
    band_width = band_x2-band_x1;
    for (var i = 0; i < num_filtered_events; i+=2)
    {
         row_band_infos_g.append("rect")
            .attr("class","oddrect")
            .attr("rx",1)
            .attr("ry",1)
            .attr("x",band_x1)
            .attr("width", band_width)
            .attr("y",i*event_delta_y + 5)
            .attr("height",event_delta_y)
    }
    
    var row_infos_g = rowsvg.append("g")
        .attr("class", "rows");

    // Draw Rows for Events
    var ev_row_a = row_infos_g.selectAll(".ev_row")
		.data(filtered_evs)
	  .enter()
        .append("g")
            .attr("class","ev_row")
		.append("a")
            .attr("xlink:href", function( d ) {return loghtml+"#L"+getEventLine(d);})
    //            <a target="output"><xsl:attribute name="xlink:href"><xsl:value-of select="../@logname"/>.html#L<xsl:value-of select="@line"/></xsl:attribute>
	
    // line
    ev_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", line_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventLine(d);})
    
    // date
    ev_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", date_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventDate(d);})

    // tag
    ev_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", tag_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventTag(d);})
    
    ev_row_a.append("title")
        .text(function(d) { return getEventTag(d);})
    
    // Draw Rows for Messages
    var msg_row_a = row_infos_g.selectAll(".msg_row")
		.data(filtered_msgs)
	  .enter()
        .append("g")
            .attr("class","msg_row")
		.append("a")
            .attr("xlink:href", function( d ) {return loghtml+"#L"+getEventLine(d);})
	
    // line
    msg_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", line_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventLine(d);})
    
    // date
    msg_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", date_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventDate(d);})

    // tag
    msg_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", tag_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventTag(d);})        

    // Draw Rows for State Changes
    var sc_row_a = row_infos_g.selectAll(".sc_row")
		.data(filtered_scs)
	  .enter()
        .append("g")
            .attr("class","sc_row")
		.append("a")
            .attr("xlink:href", function( d ) {return loghtml+"#L"+getEventLine(d);})
	
    // line
    sc_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", line_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventLine(d);})
    
    // date
    sc_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", date_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventDate(d);})

    // tag
    sc_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", tag_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventTag(d);})          
        
    // Draw Rows for State Changes
    var span_row_a = row_infos_g.selectAll(".span_row")
		.data(filtered_spans)
	  .enter()
        .append("g")
            .attr("class","span_row")
		.append("a")
            .attr("xlink:href", function( d ) {return loghtml+"#L"+getEventLine(d);})
	
    // line
    span_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", line_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventLine(d);})
    
    // date
    span_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", date_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventDate(d);})

    // tag
    span_row_a.append("text")
        .attr("class","msgtext")
        .attr("text-anchor","right")
        .attr("x", tag_x)
        .attr("y", function(d) { return (d.orig_idx * event_delta_y) + 20;})
        .text(function(d) {return getEventTag(d);})         
}

function drawBody() {
    var body_band_infos_g = bodysvg.append("g")
        .attr("class", "bands")

    /* Alternating Dark / Light bands */
    band_x1 = -5;
    band_x2 = nodeMaxX + event_box_half_width;
    band_width = band_x2-band_x1;
    for (var i = 0; i < num_filtered_events; i+=2)
    {
         body_band_infos_g.append("rect")
            .attr("class","oddrect")
            .attr("rx",1)
            .attr("ry",1)
            .attr("x",band_x1)
            .attr("width", band_width)
            .attr("y",i*event_delta_y+5)
            .attr("height",event_delta_y)
    }

    /* Draw the node lines down the page */
    var body_node_lines = bodysvg.append("g")
      .attr("class", "body_node_lines");

    var node_line_a = body_node_lines.selectAll(".body_node_line")
		.data(filtered_config)
	  .enter()
        .append("g")
            .attr("class", "body_node_line")
		.append("a")
            .attr("xlink:href", function( d ) {return ;})

    //Draw Node line
    node_line_a.append("line")
        .attr("class", "nodeline")
        .attr("x1", function(d,i) { return getNodeXFromIdx(i);} )
        .attr("x2", function(d,i) { return getNodeXFromIdx(i);} )
        .attr("y1", 0)
        .attr("y2", max_y + "px")
        .attr("stroke-dasharray", function(d) { return getNodeLineStroke(getNodeName(d));})
    
    // draw events
    var events_g = bodysvg.append("g")
      .attr("class", "events");
    drawBody_event(events_g);

    // draw msgs
    var msgs_g = bodysvg.append("g")
      .attr("class", "msgs");
    drawBody_msgs(msgs_g);

    // draw scs
    var scs_g = bodysvg.append("g")
      .attr("class", "scs");
    drawBody_scs(scs_g);
    
    // draw spans
    var spans_g = bodysvg.append("g")
      .attr("class", "spans");
    drawBody_spans(spans_g);
}

/* Draw an event in the body */
function drawBody_event(g) {
    
    var event_a = g.selectAll(".event")
        .data(filtered_evs)
      .enter()
        .append("g")
            .attr("class","event")
        .append("a")
            .attr("href", function( d ) {return getEventURL(d);})

    event_a.append("title")
        .text(function(d) { return d.data; })
    event_a.append("rect")
            .attr("class","eventrect")
            .attr("fill",function(d) {return getSevColour(d);})
            .attr("rx",1)
            .attr("ry",1)
            .attr("x",function(d) {return getNodeX(d.node) - event_box_half_width;})
            .attr("width", event_box_width)
            .attr("height", event_box_height)
            .attr("y",function(d) { return (getOrigIdx(d) * event_delta_y) + 7;})

    event_a.append("text")
        .attr("class", "eventtext")
        .attr("text-anchor", "middle")
        .attr("x", function(d) { return getNodeX(d.node)})
        .attr("y", function(d) { return (getOrigIdx(d) * event_delta_y)+18;})
        .text(function(d) {return d.event;})
}

function getToX(d)   { return getNodeX(d.to); }
function getFromX(d) { return getNodeX(d.from); }
function getMsg(d)   { return getNodeX(d.msg); }
function getArrowHeadX(d) {
    var to_x = getToX(d);
    var from_x = getFromX(d);
    if (to_x > from_x)
        return to_x - arrow_width;
    else
        return to_x + arrow_width;
}

function getArrowY(d) {
    return d.orig_idx * event_delta_y+20;
}

function getMsgTextX(d) {
    var to_x = getToX(d);
    var from_x = getFromX(d);
    if (to_x > from_x)
        return from_x + 15;
    else
        return to_x + 15;
}


// Draw all Messages
function drawBody_msgs(g) {
    
    var msg_a = g.selectAll(".msg")
        .data(filtered_msgs)
      .enter()
        .append("g")
            .attr("class","msg")
        .append("a")
            .attr("href", function( d ) {return getEventURL(d);})

    msg_a.append("title")
        .text(function(d) { return d.data; })
    
    msg_a.append("text")
        .attr("class", "msgtext")
        .attr("x", function(d) { return getMsgTextX(d) + 15;})
        .attr("y", function(d) { return getArrowY(d)-5;})
        .text(function(d) { return d.msg;})
    
    msg_a.append("line")
        .attr("class", "msgline")
        .attr("x1", function(d) { return getToX(d);})
        .attr("x2", function(d) { return getFromX(d);})
        .attr("y1", function(d) { return getArrowY(d);})
        .attr("y2", function(d) { return getArrowY(d);})
    
    msg_a.append("polygon")
        .attr("class", "msgarrow")
        .attr("points", function(d) {
            to_x = getToX(d);
            arrow_y = getArrowY(d);
            arrow_head_x = getArrowHeadX(d);
            output = "" + to_x + "," + arrow_y + " " 
                    + arrow_head_x + "," + (arrow_y + arrow_height) + " " 
                    + arrow_head_x + "," + (arrow_y - arrow_height);
            return output;
        })
}

// Draw State Changes.
function drawBody_scs(g) {
    var sc_a = g.selectAll(".sc")
        .data(filtered_scs)
      .enter()
        .append("g")
            .attr("class","sc")
        .append("a")
            .attr("href", function( d ) {return getEventURL(d);})

    sc_a.append("title")
        .text(function(d) { return "Trigger: " + d.msg; })
    sc_a.append("rect")
            .attr("class","eventrect")
            .attr("fill",function(d) {return "lightblue";})
            .attr("rx",1)
            .attr("ry",1)
            .attr("x",function(d) {return getNodeX(d.node) - state_box_half_width;})
            .attr("width", state_box_width)
            .attr("height", state_box_height)
            .attr("y",function(d) { return (getOrigIdx(d) * event_delta_y) + 7;})

    sc_a.append("text")
        .attr("class", "statetext")
        .attr("text-anchor", "middle")
        .attr("x", function(d) { return getNodeX(d.node)})
        .attr("y", function(d) { return (getOrigIdx(d) * event_delta_y)+18;})
        .text(function(d) {return d.state;})
}

function getSpanBoxLeftX(d) {
    var x1 = getNodeX(d.from);
    var x2 = getNodeX(d.to);
    if (x1>x2) {return x2; }
    else return x1;
}

function getSpanBoxWidth(d) {
    var x1 = getNodeX(d.from);
    var x2 = getNodeX(d.to);
    if (x1>x2) {return (x1-x2) + event_box_width; }
    else return (x2-x1) + event_box_width;
}

function drawBody_spans(g) {
    var span_a = g.selectAll(".span")
        .data(filtered_spans)
      .enter()
        .append("g")
            .attr("class","span")
        .append("a")
            .attr("href", function( d ) {return getEventURL(d);})

    span_a.append("title")
        .text(function(d) { return d.data; })
    span_a.append("rect")
            .attr("class","spanrect")
            .attr("fill",function(d) {return getSevColour(d);})
            .attr("rx", event_box_half_height)
            .attr("ry", event_box_half_height)
            .attr("x",function(d) {return getSpanBoxLeftX(d) - event_box_half_width;})
            .attr("width", function(d) { return getSpanBoxWidth(d);})
            .attr("height", event_box_height)
            .attr("y",function(d) { return (getOrigIdx(d) * event_delta_y) + 7;})

    span_a.append("text")
        .attr("class", "spantext")
        .attr("text-anchor", "middle")
        .attr("x", function(d) { return (getNodeX(d.to) + getNodeX(d.from)) / 2;})
        .attr("y", function(d) { return (getOrigIdx(d) * event_delta_y) + 18;})
        .text(function(d) {
            return d.event;
           })
}

function getNodeName(d)  { return d.name; }
function getNodeLevel(d,i) { return i % num_node_levels; }

function getEventMsg(d)  { return d.msg; }
function getEventType(d) { return d.type; }
function getEventData(d) { return d.data; }
function getEventLine(d) { return d.line; }
function getEventTag(d)  { return d.tag; }
function getEventTo(d)   { return d.to; }
function getEventFrom(d) { return d.from; }
function getEventURL(d)  
{ 
    if ("url" in d) {
            return d.url; 
    }
    else
        return loghtml+"#L"+getEventLine(d);
}
function getEventDate(d)  { return d.date; }

var topsvg, titlesvg,bodysvg, rowsvg;
function plotCanvases()
{
    titlesvg = d3.select("#titlediv")
          .append("svg")
            .attr("width", tag_x+tag_width+"px")
            .attr("height", head_y+"px")
            .attr("id","titlesvg")
          .append("g")
           
    topsvg = d3.select("#topdiv")
          .append("svg")
            .attr("width",  nodeMaxX + 1.5 * event_box_half_width + "px")
            .attr("height", head_y+"px")
            .attr("id","topsvg")
          .append("g")
            
    rowsvg = d3.select("#rowdiv")
          .append("svg")
            .attr("width", tag_x +  tag_width + "px")
            .attr("height", max_y + 20 +"px")
            .attr("id","rowsvg")
          .append("g")

    bodysvg = d3.select("#bodydiv")
          .append("svg")
            .attr("width", nodeMaxX + 1.5 * event_box_half_width + "px")
            .attr("height", max_y+"px")
            .attr("id","bodysvg")
          .append("g")
}
 