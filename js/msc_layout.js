// Begins
var containerdiv,
    navdiv,
    titlediv,
    topdiv,
    rowdiv,
    bodydiv;
var	IE     = (document.all) ? true : false;
var	last_x = 0;
var	last_y = 0;

function synchronizeScroll() {
    if (undefined != bodydiv )
    {
        topdiv.scrollLeft     = bodydiv.scrollLeft;
        rowdiv.scrollTop      = bodydiv.scrollTop;
    }
} 

function setupVars() {
    containerdiv    = document.getElementById('container');
    headerareadiv    = document.getElementById('headerArea');
    navdiv          = document.getElementById('mySideNav');
    titlediv        = document.getElementById('titlediv');
    topdiv          = document.getElementById('topdiv');
    bodydiv         = document.getElementById('bodydiv');
    rowdiv          = document.getElementById('rowdiv');
}

function LayoutDiv() {

    var 	bodyHeight,
            bodyWidth;
    
	// Does this page have the msc elements on it?
	if (titlediv == undefined)
		return;
	
	
	// position titlediv to be below the container
	titlediv.style.top = headerareadiv.offsetTop + headerareadiv.offsetHeight +"px";
    titlediv.style.left = headerareadiv.offsetLeft +"px";
    titlediv.style.width = tag_x + tag_width + "px";
    titlediv.style.height = head_y + "px";
    
    // Position top div and body div to right of row div 
    topdiv.style.top     = titlediv.offsetTop +"px";
    topdiv.style.left    = titlediv.offsetLeft + titlediv.offsetWidth + "px";
    topdiv.style.height = head_y + "px";
    
    rowdiv.style.left    = titlediv.offsetLeft + "px";
    rowdiv.style.top     = topdiv.offsetTop+topdiv.offsetHeight + "px";
 
    //rowdiv.style.height  = max_y + "px";
    rowdiv.style.width   = tag_x+tag_width+"px";
    
    bodyWidth            = containerdiv.clientWidth -(rowdiv.offsetLeft+rowdiv.offsetWidth+(rowdiv.style.border*4)) - 10;
    if (bodyWidth > 0) 
	{
		bodydiv.style.width  = bodyWidth + "px";
		topdiv.style.width   = bodyWidth -20 + "px";
	}	
    bodydiv.style.left   = rowdiv.offsetLeft + rowdiv.offsetWidth + "px";
    bodydiv.style.top    = rowdiv.offsetTop + "px";
	bodyHeight           = containerdiv.clientHeight - (topdiv.offsetTop + topdiv.offsetHeight) - 80;

    if (bodyHeight > 0) bodydiv.style.height = bodyHeight + "px";
    rowdiv.style.height = bodyHeight + "px";
}