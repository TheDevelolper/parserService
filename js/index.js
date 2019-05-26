// Now start to load the processed data
var input_xml = '/config';
var config;

// Load the xml file using ajax 
$.ajax({
    type: "GET",
    url: input_xml,
    dataType: "xml",
    success: function (xml) {

        // Parse the xml file and get data
        var xmlDoc = $.parseXML(xml),
            $xml = $(xmlDoc);

		
		var $select = $("#parser");
		$select.empty(); // remove old options
		$select.append($("<option></option>")
				.attr("value", '').text('Please Select'));
		$(xml).find('parser_config').each(function(){
			 $(this).find('parser').each(function(){
				  var value = $(this).attr('name');
				  var label = $(this).attr('title');
				  $select.append("<option class='ddindent' value='"+ value +"'>"+label+"</option>");
			 });
		});
		console.log("Update complete")
    }
});