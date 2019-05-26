# Introduction

Having spent a lot of time trawling through logs, I realised that 
there was a real need for the ability to quickly precis a log file, 
find key events and present them in context of things that may led 
to the error condition.

Considering that Message Sequence Charts are a key part of the design process
it made sense to try to present the production logs in an equivalent format.

Though other message sequence chart tools exist, they all had been 
written with the view of presenting basic sequences. 
However, this does not make them appropriate for summarising the
content of actual log files, where additional behaviours may be required:

* ability to log each event with a timestamp and tag
* ability to configure the order of nodes in the diagram.
* event colour coding to indicate alarm severity and states
* linkage to events in the original log file
* optional linkage to external html references (e.g. Alarm Code reference)
* ability to filter Message Sequence Chart by tag or node.

As a result, I needed to create a tool which was appropriate for this specific 
use case, but which did not particularly care about the original log file format.

## Benefits:

Automating the generation of message sequence charts, will have multiple 
benefits for your software product development:

* tool runs within browser
* faster and more consistent issue investigations
* reduces skill/training required to root cause issues
* provides a visual way to describe the error conditions from your triage team to development
* encourages review and improvement of logging from your applicationconsistent
* consistent logging conventions across your code base

## Known limitations:

* In itself, the tool does not support merging of multiple log files. This 
could be managed up front by a custom pre-processing script.
* no support for processing binary files. However, if you want to do this, 
you may want to consider deserialising the binary data and present it as a 
text file.

 e.g. export a wireshark pcap file to a text file.

* There will be an upper limit on the number of events that can be rendered, 
related to the size of SVG canvas that can be supported. I am not yet clear 
what this limit is in practise.
* Jumping to the appropriate line number of the HTML version of the log file 
can be quite slow due to the time required to load the file. Bear in mind 
that log files could be significantly longer than normal HTML content.

# Creating your own parser

There are a few steps that you need to undertake to create your own parsers that use this viewer:

1. **templates/index.html** - Add an option element listing your parser name
2. **parser/parser_config.xml** - Add an entry for your parser

  <parser name="simple" ext="txt" pl="simple_parser.pl" desc="Create MSCs with a simple mscgen like syntax."/>

3. copy *parser/parsers/template/template_parser.pl* to *parser/parsers/**parser name**/**parser**.pl*
4. update the file accordingly.

# Perl MSC API

## MSC Events

Note: the 'create' APIs below will create an instance of an event. To actually 
register the event in the event list, you need to then call msc_parser_record_event

### Mandatory parameters:
Each event must have the following mandatory parameters defined:

* line_num - the line number in the original log file where the event took place
* title - What text describes this event
* node or from, to - which node is an event or message tied to

### Optional Parameters:
These optional parameters may be passed as 'undef' if they are not appropriate to the log type in question.

* time - timestamp
* severity
* tag - a way to classify events/messages for a particular context, e.g. user ID, call ID
* data - used to specify a tooltip for the message
* trigger - what event triggered a state change.

## Severity

Events are colour coded by severity,

| Level | Enum | Colour | purpose |
| ----- | ---- | ------ | ------- |
| Critical | 0 | Red | Critical alarm raised |
| Major | 1 | Orange | Major alarm raised |
| Minor | 2 | Yellow | Minor alarm raised |
| Intermittent | 3 | salmon | Major alarm raised |
| Info | 4 | White | Major alarm raised |
| Clear| 5 | Green | Alarm condition cleared |

## Events: 

Events are rendered as generic boxes containing a title, and colour coded 
based upon the event severity.
The event is positioned on the node context line.

```perl
   msc_parser_create_event( \%event,        # event
						 $line_num,         # line number of event
						 $time,             # time of event
						 $sev,              # severity
						 $tag,              # call id
						 $title,            # event title
						 $data,             # event data
						 $node);            # node
```

## Spanning Boxes:

A spanning box is a special case of an event, where an event actually 
occurs between two nodes. The two nodes are identifed by the $from & $to 
fields. The order of the two is not important as the javascript code will 
determine their relative positioning.

```perl           
	msc_parser_create_span_box( \%event,        		# event
                                 $line_num,         	# line number of event
                                 $time,   				# time of event
                                 $sev,              	# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    				# call id
                                 $title,				# event title
                                 $data,   				# event data (tooltip)
                                 $from,					# from
                                 $to);            		# to
```

## State Changes:

State changes are a special case of an event where the trigger will be 
used to build the tooltip.
State changes will be coloured blue on the Message Sequence Chart

```perl
	msc_parser_create_state_change( \%event,            # event ref (to be created)
								$line_num,          	# line number of event
								$time,					# timestamp
								$tag,					# call id
								$state,					# state
								$node,              	# node
								$trigger);				# trigger event
```

## Messages:

Messages will be rendered as a horizontal arrow between two nodes (to, from), with 
the message name appearing above the arrow.

```perl
	msc_parser_create_msg( \%event, 
						$line_num, 
						$latest_time, 
						$msg, 
						$call_id, 
						$dest, 
						$src, 
						$data );
```

## Add URL (optional)

The line number of an event on the message sequence chart will always take 
you to the equivalent line in the log file. By default the same behaviour applies
to the event box/arrow. However this can be overridden, to point to an 
alternate URL (e.g. an online alarm code reference)
```perl
    msc_parser_add_url_to_event(\%event,
								$url);
```

## Record events

This API will add the event to the event list which is written to the JSON file.

```perl
msc_parser_record_event($line_num, 
						\%event);
```

## Create JSON file

This api will output the JSON file which will be picked up by the javascript MSC rendering page

```perl
	msc_parser_output_config_json($logfile, 
								  $outpath, 
								  \@nodes);
```