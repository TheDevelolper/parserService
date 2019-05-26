#!/usr/bin/perl

# Generic TTY Parser
# Created by Donald Jones
# 13th Oct 2006

=head1 NAME

msc_parser.pm - Parser helper functions

=head1 DESCRIPTION

C<parser> is a Perl module which provides helper functions for automated parsing of debug logs,
and conversion to a standard XML format. This standard XML format can then be output via XSL as
one of many other formats: e.g. HTML tabular format, SVG-based Message Sequence Chart ...

=head1 OVERVIEW

The parser provides an extensible mechanism for generic parser front end to be extended to support different input file formats
and provide either a generic standard XML file, or a custom XML file.

This output can then be passed through one or XSL transforms to provide output in a user friendly format.

=head1 SYNOPSIS

    For application specific parser:
       use parser

       msc_parser_create_event

       msc_parser_create_msg

       msc_parser_create_span_box

       msc_parser_create_state_change

       msc_parser_add_url_to_event

       msc_parser_record_event

       msc_parser_open_file

       msc_parser_output_xml_config

       msc_parser_log_error

       msc_parser_get_num_events

       msc_parser_get_duplicated_links


=cut

package msc_parser;

require Exporter;

@ISA =      qw(Exporter);

@EXPORT =   qw($NUL
               $NUM_EVENTS_PER_IFRAME
               $SEV_CRITICAL
               $SEV_MAJOR
               $SEV_MINOR
               $SEV_INTERMIT
               $SEV_INFO
               $SEV_CLEAR
               $SW_VERSION
               $PARSER
               %PARSER_CONFIG
               $PARSER_XML_CONFIG
               $CONFIG
               %MSC_PARSER_EVENTS
               %MONTHS
               @lines

               msc_parser_add_url_to_event
               msc_parser_build_output
               msc_parser_create_event
               msc_parser_create_msg
               msc_parser_create_span_box
               msc_parser_create_state_change
               msc_parser_get_duplicated_links
               msc_parser_get_num_events
               msc_parser_log_error
               msc_parser_open_file
               msc_parser_output_xml_config
               msc_parser_output_config_json
               msc_parser_record_event

              );

use vars    qw($NUM_EVENTS_PER_IFRAME
               $SEV_CRITICAL
               $SEV_MAJOR
               $SEV_MINOR
               $SEV_INTERMIT
               $SEV_INFO
               $SEV_CLEAR
               $SW_VERSION
               %MSC_PARSER_EVENTS
);


use strict;

#use diagnostics;
use parser;
use Data::Dumper;
use Fcntl qw(:DEFAULT :flock);
use XML::Simple;
use JSON;
use POSIX qw(ceil);
use File::Basename;

=head1 GLOBALS

These are global variables accessible to the test scripts

=cut



=item SEVERITY LEVELS

This list of event categories is used for classifying events/alarms to ensure that important events are brought to the users attention.
In future this can be used for filtering of events.

=over 4

$SEV_CRITICAL
$SEV_MAJOR
$SEV_MINOR
$SEV_INTERMIT
$SEV_CLEAR
$SEV_INFO

=back

=cut

$SEV_CRITICAL = 0;  # red
$SEV_MAJOR    = 1;  # orange
$SEV_MINOR    = 2;  # yellow
$SEV_INTERMIT = 3;  # salmon
$SEV_INFO     = 4;  # INFORMATION
$SEV_CLEAR    = 5;  # CLEARING OF ALARMS

$SW_VERSION   = '1.9.0.0.17';   # default software version

=item $NUM_EVENTS_PER_IFRAME

Internet Explorer cannot handle SVG diagrams that are too large, resulting in an exception or instant closure.
To protect against this, MSCs are limited in size to only contain a fixed number of events.

Note: This value must align with num_events_per_iframe in msc_consts.xsl

Note: The issue with internet Explorer appears to be due to the total size of the resultant MSC and not just the length.
Therefore, a more robust implementation would be to scale this value based upon the number of nodes (and hence the width of the MSC).
This would prevent undue splitting of MSCs into smaller diagrams.

=cut

$NUM_EVENTS_PER_IFRAME = 500;  # This has to tie up with the num_events_per_iframe in msc_consts.xsl

=head1 FUNCTIONS

=cut

=head2 msc_parser_open_file(FILE)

Opens the original logfile and performs any preprocessing necessary. The resulting file is written into

=item Returns:

Populates @tmp_lines

=cut

sub msc_parser_open_file($)
{
    my $logfile = shift;
    print "...Opening Log File\n";
    open LOGFILE, '<:utf8', "$logfile" or die "Could not open $logfile for reading: $!\n";
    chomp(my @tmp_lines = <LOGFILE>);
    close LOGFILE;

    # Remove non-ascii characters
    if( exists $PARSER_CONFIG{'strip_nonascii'} )
    {
        print "...Cleaning $logfile\n";
        foreach(@tmp_lines)
        {
            s/[\x7F-\xFF]/?/g;
            push(@lines, $_);
        }
    }
    else
    {
        @lines = @tmp_lines;
        @tmp_lines = (); # Clean up the tmp list and save some memory
    }
}

=head2 msc_parser_create_event (EVENT HASH, LINE, DATE, SEV, TAG, TITLE, DATA, NODE)

This creates a hash with the data provided.
B<NOTE:>  Only one entry per line can be created as line is the key.

=item Parameters:

B<EVENT HASH> - hash into which the event will be written.

B<LINE> - Line number for the event.

B<DATE> - timestamp for the event, ideally formatted using parser_format_timestamp.

B<SEV> - severity of the event - This should match one of the severity categories above.

B<TAG> (optional) - freeform identifier used to help classify/filter events:
e.g. call_id, reconfiguration tag

B<TITLE> (optional) - brief title

B<DATA> (optional) Additional data about the event being recorded

B<NODE> (optional) Describes which device/entity the event is occuring to.

=back

=cut
my $MAX_EV_TITLE_LEN = 22;
sub msc_parser_create_event($$$$$$$$)
{
    my ($event, $line_num, $date, $sev, $tag, $ev_title, $data, $node) = @_;
    
    if (! defined $data && length($ev_title) > $MAX_EV_TITLE_LEN)
    {
    	$data = $ev_title;
    	# Truncate ev_title to $MAX_EV_TITLE_LEN
    	$ev_title = substr($ev_title, 0, $MAX_EV_TITLE_LEN);
    	$ev_title .= "...";
    }
    $event->{'line'}    = $line_num;
    $event->{'date'}    = $date if defined $date;
    $event->{'sev'}     = $sev if defined $sev;
    $event->{'event'}   = $ev_title if defined $ev_title;
    $event->{'tag'}     = $tag if defined $tag and length $tag;
    $event->{'data'}    = $data if defined $data and length $data;
    $event->{'node'}    = $node if defined $node;
    $event->{'type'}    = "ev";
    # print Dumper $event if $debug;
}


=head2 msc_parser_create_span_box (EVENT HASH, LINE, DATE, SEV, TAG, TITLE, DATA, FROM, TO)

This creates a hash with the data provided.
B<NOTE:>  Only one entry per line can be created as line is the key.

=item Parameters:

B<EVENT HASH> - hash into which the event will be written.

B<LINE> - Line number for the event.

B<DATE> - timestamp for the event, ideally formatted using parser_format_timestamp.

B<SEV> - severity of the event - This should match one of the severity categories above.

B<TAG> (optional) - freeform identifier used to help classify/filter events:
e.g. call_id, reconfiguration tag

B<TEXT> (optional) - brief title

B<DATA> (optional) Additional data about the event being recorded

B<FROM> Describes node at one extent that the span box extends from.

B<TO> Describes node at other extent that the span box extends to.

=back

=cut
sub msc_parser_create_span_box($$$$$$$$$)
{
    my ($event, $line_num, $date, $sev, $tag, $text, $data, $from, $to) = @_;
    
    $event->{'line'}    = $line_num;
    $event->{'date'}    = $date if defined $date;
    $event->{'sev'}     = $sev if defined $sev;
    $event->{'event'}   = $text if defined $text;
    $event->{'tag'}     = $tag if defined $tag and length $tag;
    $event->{'data'}    = $data if defined $data and length $data;
    $event->{'from'}    = $from if defined $from;
    $event->{'to'}      = $to if defined $to;
    $event->{'type'}    = "span";
        
    # print Dumper $event if $debug;
}




sub msc_strip_spaces($)
{
	$_ = shift;
	s/^\s+//;
	s/\s*$//;
	return $_;
}

=head2 msc_parser_create_msg (EVENT HASH, LINE, DATE, MSG, TAG, TO, FROM, DATA)

This creates a hash with the data provided.
B<NOTE:>  Only one entry per line can be created as line is the key.

=item Parameters:

B<EVENT HASH> - hash into which the event will be written.

B<LINE> - Line number for the event.

B<DATE> - Timestamp for the event, ideally formatted using parser_format_timestamp.

B<MSG> - Name of the message

B<TAG> (optional) - freeform identifier used to help classify/filter events:
e.g. call_id, reconfiguration tag

B<TO> - Entity which is receiving the message

B<FROM> - Entity which is sending the message

B<DATA> (optional) - Content of the message

=back

=cut

sub msc_parser_create_msg($$$$$$$$)
{
    my ($event, $line_num, $date, $msg, $tag, $to, $from, $data) = @_;
    $event->{'line'}    = $line_num;
    $event->{'date'}    = $date if defined $date;
    $event->{'msg'}     = $msg if defined $msg;
    $event->{'tag'}     = $tag if defined $tag and length $tag;
    $event->{'to'}      = msc_strip_spaces($to) if defined $to;
    $event->{'from'}    = msc_strip_spaces($from) if defined $from;
    $event->{'data'}    = $data if defined $data and length $data;
    $event->{'type'}    = "msg";
    # print Dumper $event if $debug;
}


=head2 msc_parser_create_state_change (EVENT HASH, LINE, DATE, SEV, TAG, TITLE, STATE, NODE, MSG)

This creates a hash with the data provided.
B<NOTE:>  Only one entry per line can be created as line is the key.

=item Parameters:

B<EVENT HASH> - hash into which the event will be written.

B<LINE> - Line number for the event.

B<DATE> - timestamp for the event, ideally formatted using parser_format_timestamp.

B<SEV> - severity of the event - This should match one of the severity categories above.

B<TAG> (optional) - freeform identifier used to help classify/filter events:
e.g. call_id, reconfiguration tag

B<TITLE> (optional) - brief title

B<STATE> (optional) - Additional data about the event being recorded

B<NODE> (optional) - Describes which device/entity the event is occuring to.

B<MSG> (optional) - Trigger for the state change?

=back

=cut
sub msc_parser_create_state_change($$$$$$$)
{
    my ($event, $line_num, $date, $tag, $state, $node, $msg) = @_;
    
    $event->{'date'}    = $date if defined $date;
    $event->{'line'}    = $line_num;
    $event->{'tag'}     = $tag if defined $tag;
    $event->{'state'}   = $state if defined $state;
    $event->{'node'}    = $node if defined $node;
    $event->{'msg'}     = $msg if defined $msg;
    $event->{'type'}    = "sc";
    # print Dumper $event if $debug;
}

=head2 msc_parser_add_url_to_event (EVENT HASH, URL)

This can add a url to an event hash. This allows for context-sensitive hyperlinks to be added to different events:
e.g. link to Alarms description when an alarm is raised/cleared.
Link to source code when an exception occurs.

=item Parameters:

B<EVENT HASH> - hash into which the url will be written.

B<URL> - URL to be added to the event/msg.

=back

=cut

sub msc_parser_add_url_to_event($$)
{
    my $event = shift;
    my $url   = shift;
    $event->{'url'} = $url if( defined($url) );
}

=head2 msc_parser_record_event (INDEX, EVENT HREF)

This logs the event hash provided into the master EVENT HREF,
indexed by the provided INDEX. This should be called once
the event has been fully populated.

=item Parameters:

B<INDEX> - Unique Index value, be it line number, timestamp. This provides the principal means of sorting the data.

B<EVENT HREF> - hash reference for the event which will be added to the Master Event HASH

=back

=cut

sub msc_parser_record_event ($$)
{
    my ($index, $eventref) = @_;

    $MSC_PARSER_EVENTS{'event'}->{$index} = $eventref;
}

=head2 msc_parser_log_error (LINE, DESC, TEXT)

This logs an error into the output XML file. Note: Only one error per line can be recorded.

=item Parameters:

B<LINE> - line number of the original log on which the error occurred.

B<DESC> - brief description of the error

B<TEXT> - verbose text describing the problem

=cut

sub msc_parser_log_error($$$)
{
    my ($line, $desc, $text) = @_;
    $MSC_PARSER_EVENTS{'ERROR'}->{$line}->{'desc'} = $desc;
    $MSC_PARSER_EVENTS{'ERROR'}->{$line}->{'text'} = $text if defined $text;
}

=head2 msc_parser_get_num_events (XMLFILE)

This loads the XML file if it has not been done before and determines the number of events in the log.

=item Parameters:

B<XMLFILE> is the standard formatted event XML file.

=item Returns:

Scalar number of events in the log.

=cut

my $xml_hash;
sub msc_parser_get_num_events($)
{
    my $xmlfile = shift;
    # Load XML config file into global hash
    $xml_hash = XMLin( $xmlfile,
                       KeyAttr => 'line',
                       forcearray => [qw(events)] ) unless defined $xml_hash;
    #print Dumper $xml_hash;
    my $num_events = scalar keys %{$xml_hash->{'event'}};

    return $num_events;
}

my %nodes;
sub inc_node_count($)
{
    my $node = shift;
    return if( !defined($node) || length( $node ) == 0 );
    if( exists $nodes{$node} )
    {
        $nodes{$node}->{'node'}++;
    }
    else
    {
        $nodes{$node}->{'node'}++;
    }
    #print "Node: $node\n";
}


# records duplicate links for a bounce count
sub inc_node_link_count($$)
{
    my $node = shift;
    my $from = shift;
    return if( !defined($node) || length( $node ) == 0 );
    if( exists $nodes{$node} )
    {
        $nodes{$node}->{'node'}++;
        #my $i = 0;
        #my $found = 0;
        #foreach( $nodes{$node}->{'link'} )
        #{
        #    if( exists($nodes{$node}->{'link'}[$i]->{'from'}) )
        #    {
        ##        #print "From $from eq $nodes{$node}->{'link'}[$i]->{'from'}\n";
         #       if( $nodes{$node}->{'link'}[$i]->{'from'} eq $from )
         #       {
         #           $nodes{$node}->{'link'}[$i]->{'duplicates'}++;
         #           $found = 1;
         #       }
         #       $i++;
        #    }
        #}
        #if( $found == 0 )
        #{
        #    $nodes{$node}->{'link'}[$i]->{'duplicates'} = 0;
        #    $nodes{$node}->{'link'}[$i]->{'from'} = $from;
        #}
    }
    else
    {
        $nodes{$node}->{'node'}++;
    }
    #print "Node: $node\n";
}


my $master_nodes;
my $parser_config_file;
my $keyAtt = "idx";

sub handle_node_list()
{
    open( CONFFILE, "<$parser_config_file") or die( "Could not open XML file: $parser_config_file : $!\n" );
    # polite notification of reading xml file
    flock( CONFFILE, LOCK_SH );

    # header for XML file
    my $decl = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";

    # check if file exists and is non zero length
    if( -s CONFFILE )
    {
        # read in the database xml file
        my $evalFile = XMLin( $parser_config_file,          # doesn't like using a file handle
                              ForceArray => 0,
                              KeyAttr    => ['value', $keyAtt],
                              NoAttr     => 0   # Do not represent hash key/values as nested elements
                            );

        # check XML file in
        $master_nodes = eval{$evalFile};
        if( $@ )
        {
            die "\n\nError in XML file $parser_config_file : $@\n";
        }
        else
        {
            print "...Read in file $parser_config_file OK\n" if $debug;
        }
        # $keyAtt = undef;
    }

    close( CONFFILE );

    #print "Hash Contents\n" if $debug;
    #print Dumper($master_nodes) if $debug;
}


# Convert the nodes hash into a XML format for printing/saving.
sub output_nodes($)
{
    my $output_suffix = shift;
    
    # print "Regenerated output:\n";
    my $retval;
    if( keys %{$master_nodes->{'node'}} )
    {
        if ($output_suffix =~ /xml/)
        {
            $retval = XMLout( \%{$master_nodes},
                           KeyAttr   => [$keyAtt],   # key attibute
                           NoAttr    => 0,           # Represent hash key/values as nested elements
                           RootName  => 'nodelist'); # Root element is user
        }
        elsif ($output_suffix =~ /json/)
        {
            my @master_nodes_arr;
            foreach my $key (sort {$a <=> $b} keys \%{$master_nodes->{'node'}})
            {
                my $node = $master_nodes->{'node'}->{$key};
                push(@master_nodes_arr, $node);
            }
 
            $retval = to_json( \@master_nodes_arr, { pretty => 1, indent=> 1 });
            $retval .= "\n";
        }
        else { die "Unknown output format: $output_suffix"; }
    }
    return $retval;
}

=head2 msc_parser_get_duplicated_links(NAME)

Generates a list of msg paths which are transitioned over more than once.

=item Parameters:

B<XMLFILE> is the standard formatted event XML file.

=item Returns:

A string representing the csv formatted list of msg paths.

=cut

sub msc_parser_get_duplicated_links($)
{
    my $name   = shift;
    my $found  = 0;
    my $output = "File,Duplicates,From,To\n";

    # print Dumper %{$master_nodes->{'node'}};
    foreach my $val( sort keys %{$master_nodes->{'node'}} )
    {
        if( exists( $master_nodes->{'node'}->{$val}->{'link'} ) )
        {
            my $from;
            my $to;
            my $dup;
            for( my $i = 0; $i <= $#{@{$master_nodes->{'node'}->{$val}->{'link'}}}; $i++ )
            {
                if( exists($master_nodes->{'node'}->{$val}->{'link'}[$i]->{'duplicates'}) )
                {
                    $from = $master_nodes->{'node'}->{$val}->{'link'}[$i]->{'from'};
                    $to   = $master_nodes->{'node'}->{$val}->{'name'};
                    $dup  = $master_nodes->{'node'}->{$val}->{'link'}[$i]->{'duplicates'};
                    $output .= "$name,$dup,$from,$to\n";
                    $found = 1;
                }
            }
        }
    }
    $output = undef if( $found == 0 );
    return( $output );
}

=head2 msc_parser_build_config(NAME, OUTPUTTYPE)

Updates the $CONFIG global variable to provide an XML description of the node list and the appropriate ordering of the nodes within that node list.

=item Parameters:

B<XMLFILE> is the standard formatted event XML file.

=end

=back

The function does quite a lot of processing to achieve this:

=over 4

Loads the config.xml appropriate to the current PARSER (if it exists) to seed a master node list
Builds a list of the unique node/from/to entries found in %MSC_PARSER_EVENTS
Remove nodes from the master node list which do not appear in %MSC_PARSER_EVENTS.
Renumber the remaining nodes in the master node list to remove any gaps.
Append any nodes found in %MSC_PARSER_EVENTS which are not already in the master node list.
Convert the master node list to an XML fragment.
Add the possible titled output files to the XML fragment.

=back


=cut


sub msc_parser_build_config($$$)
{
    $parser_config_file = "parsers/$PARSER/config.xml";   # Parser specific config file
    print "Using conf File: $parser_config_file\n";

    my $logfile = shift;
	my $nodes = shift;
    my $output_type = shift;
    $CONFIG = "<config>\n" if $output_type =~ /xml/;
    $CONFIG = "\"config\":\n" if $output_type =~ /json/;
    

    if (defined $nodes)
	{
		print Dumper $nodes if $debug;
		my $idx = 0;
		foreach my $node (@$nodes)
		{
			$master_nodes->{'node'}->{$idx}->{'name'}=$node;
			$idx++;
		}
	}
	elsif( -e $parser_config_file )    # check file exists
    {
        open( PARSER_CONFIG, $parser_config_file ) or die "Could not open $parser_config_file for reading\n";
        my @parser_config = <PARSER_CONFIG>;
        close( PARSER_CONFIG );
        print Dumper @parser_config if $debug;

        #print "Calling handle_node_list\n";
        handle_node_list();
    }
	print Dumper $master_nodes;
	print "...Parsing for Nodes\n";

    # Parse hash for list of nodes that occur in the log
    foreach my $key ( keys %{$MSC_PARSER_EVENTS{'event'}} )
    {
        #print "Key  : $key\n";
        my $to = $MSC_PARSER_EVENTS{'event'}->{$key}->{'to'};
        #print "To   : $to\n";
        my $from = $MSC_PARSER_EVENTS{'event'}->{$key}->{'from'};
        #print "From : $from\n";
        #print "Node : $MSC_PARSER_EVENTS{'event'}->{$key}->{'node'}\n";

        inc_node_link_count($to,$from);
        inc_node_count($from);
        inc_node_count($MSC_PARSER_EVENTS{'event'}->{$key}->{'node'});
    }

    print Dumper \%nodes if $debug;

	print "Master Nodes\n" if $debug;
	print Dumper $master_nodes if $debug;
	
    # Check for master nodes which do not feature in the node list
    print "Checking for master nodes to delete\n" if $debug;
    my $last_free_idx = 0;
    foreach my $master_node_val( sort keys %{$master_nodes->{'node'}} )
    {
        my $found_match = 0;
        my $value = $master_nodes->{'node'}->{$master_node_val}->{'name'};
        #print "Testing for $master_node_val:\"$value\" in nodes\n";
        if( exists($nodes{$value}) )
        {
            if( exists( $nodes{$value}->{'link'} ) )
            {
                $master_nodes->{'node'}->{$master_node_val}->{'link'} = $nodes{$value}->{'link'};
            }
            next;
        }

        # Check the alternate names;
        my $altnames = $master_nodes->{'node'}->{$master_node_val}->{'altname'};
        if( defined $altnames )
        {
            #print "- Testing Alternates\n";
            foreach my $alt_value ( keys %{$altnames} )
            {
                if( exists $nodes{$alt_value} )
                {
                    if( exists( $nodes{$alt_value}->{'link'} ) )
                    {
                        $master_nodes->{'node'}->{$master_node_val}->{'link'} = $nodes{$alt_value}->{'link'};
                    }
                    $found_match = 1;
                    last;
                }
            }
            next if $found_match;
        }
        print "Could not find match for $value\n" if $debug;
        delete $master_nodes->{'node'}->{$master_node_val};
    }

    print output_nodes($output_type) if $debug;

    # Remove any spaces introduced into the master list.
	print "Remove any spaces in master list\n" if $debug;
    my $gap_found = 0;

    unless( $gap_found )
    {
        my $last_free_idx = 0;
        my $num_master_keys = scalar keys %{$master_nodes->{'node'}};
        foreach my $master_node_val ( sort{ $a <=> $b } keys %{$master_nodes->{'node'}} )
        {
           print "Testing Node: $master_node_val/$num_master_keys\n" if $debug;
           print "Last_Free: $last_free_idx\n" if $debug;
            if( $master_node_val !~ /^$last_free_idx$/ )
            {
                # Copying from $master_node_val to $last_free_idx
                print "Copying from $master_node_val to $last_free_idx\n" if $debug;
                # Need to do a deep copy;
                $master_nodes->{'node'}->{$last_free_idx} = $master_nodes->{'node'}->{$master_node_val};
                delete $master_nodes->{'node'}->{$master_node_val};
                $gap_found = 1;
            }
            $last_free_idx++;     # Increment the next gap pointer\n;
        }
    }

	print "Master Nodes\n" if $debug;
	print Dumper $master_nodes if $debug;
	
    # Look for nodes found which may not be in the initial master list
    print "Checking for nodes to add\n" if $debug;
    foreach my $nodekey ( sort keys %nodes )
    {
        my $node_in_master = 0;
        print "Testing for $nodekey in master_nodes\n" if $debug;
        foreach my $master_node_val ( sort keys %{$master_nodes->{'node'}} )
        {
            my $value = $master_nodes->{'node'}->{$master_node_val}->{'name'};
            print "- Testing $master_node_val: $value\n" if $debug;
            if( $value =~ /^$nodekey$/ )
            {
                $node_in_master = 1;
                print "Found $nodekey in Master List at pos: $master_node_val\n" if $debug;
                last;
            }

            # Need to test for possible alternate names
            my $altnames = $master_nodes->{'node'}->{$master_node_val}->{'altname'};
            next unless defined $altnames;
            print "- Testing Alternates\n" if $debug;
            foreach my $alt_value ( keys %{$altnames} )
            {
                #print "- - Testing $master_node_val Altname: $alt_value\n";
                if( $alt_value =~ /^$nodekey$/ )
                {
                    $node_in_master = 1;
                    print "Found $nodekey in Master List at $value pos: $master_node_val: $alt_value\n" if $debug;
                    last;
                }
            }
        }
        next if $node_in_master;

        # We did not find the node in the master list, so add it.
        my $current_num_master_nodes = scalar keys %{$master_nodes->{'node'}};
        print "Adding $nodekey to master list at position $current_num_master_nodes\n" if $debug;
        $master_nodes->{'node'}->{$current_num_master_nodes}->{'name'} = $nodekey;

        if( exists( $nodes{$nodekey}->{'link'} ) )
        {
            $master_nodes->{'node'}->{$current_num_master_nodes}->{'link'} = $nodes{$nodekey}->{'link'};
        }
    }

    $CONFIG .= output_nodes($output_type);
    $CONFIG .= msc_parser_build_output($logfile, $output_type);
    
    $CONFIG .= "</config>\n" if $output_type =~ /xml/;
    $CONFIG .= "\n" if $output_type =~ /json/;
}

sub msc_parser_gen_ftr($)
{
    my $output_format = shift;
	my $out;
    my $evs;
    
    # Only output events if there are any
	$evs = scalar keys %{$MSC_PARSER_EVENTS{'event'}};
	my $errors = 0;
	print "#evs: $evs #errors: $errors\n";
    if ( $evs or $errors)
    {
        if ($output_format =~ /xml/)
		{
			$out = XMLout( \%MSC_PARSER_EVENTS,
	                       NoAttr     => 0,          # Do not represent hash key/values as nested elements
	                       AttrIndent => 1,          # Attributes printed one-per-line with sensible indentation
	                       RootName   => "",         # Root element will be name
	                       KeyAttr    => ['line'] ); # key attribute in info_id is called "line"
		}
		elsif ($output_format =~ /json/)
		{            
            my @SIMPLER_PARSER_EVENTS;
            foreach my $key (sort {$a <=> $b} keys $MSC_PARSER_EVENTS{'event'})
            {
                push(@SIMPLER_PARSER_EVENTS, $MSC_PARSER_EVENTS{'event'}->{$key});
            }
            
            $out = "\t,\"events\":\n";
            $out .= to_json( \@SIMPLER_PARSER_EVENTS, , { pretty => 1, indent=> 2 });
            $out .= "}";
		}
    }
    
    $out .="</eventlist>" if ($output_format =~ /xml/);
    return $out;
}



=head2 msc_parser_output_xml_config (LOGFILE, INFO)

This outputs the Config and Event hash tables into a single XML Log file.

=item Parameters:

B<LOGFILE> - input file to derive the XML filename from

B<INFO> (optional) - Information field which may be added to the XML header.

=back

=item Returns:

$xmlfile - the output XML file name.

=cut

sub _msc_parser_output_xml_config($$$)
{
    my $logfile = shift;
    my $info    = shift;
	my $nodes   = shift;
    print "In msc_parser_output_xml_config()" if $debug;
    # Generate Config data
    msc_parser_build_config($logfile, $nodes, "xml");
    print "config:\n$CONFIG\nlogfile:\n$logfile\n" if $debug;

    my $xmlfile = parser_rm_file_ext($PARSER_CONFIG{'ext'}, $logfile).'xml';
    my $out;

    my $num_events = scalar keys %{$MSC_PARSER_EVENTS{'event'}};
    my $num_splits = ceil($num_events / $NUM_EVENTS_PER_IFRAME);
    # Build the XML header
    if( defined($info) )
    {
        $out = parser_gen_xml_hdr($logfile, $num_splits, $info);
    }
    else
    {
        $out = parser_gen_xml_hdr($logfile, $num_splits);
    }
    # print Dumper \%MSC_PARSER_EVENTS;
    # Add the CONFIG fragment
    $out .= $CONFIG;
    # add the event/error list and close the XML fragment.
    $out .= msc_parser_gen_ftr("xml");

    # Write out the XML file
    open( OUTFILE, ">$xmlfile" ) or die "Could not open $xmlfile for writing: $!\n";
    print OUTFILE $out;
    close( OUTFILE );
    return( $xmlfile );
}


sub msc_parser_output_config_json($$$;$)
{
    my $logfile = shift;
    my $outpath = shift;
    my $nodes   = shift;
    my $info    = shift;
	

    print "In msc_parser_output_json_config()\n" if $debug;
    # Generate Config data
    msc_parser_build_config($logfile, $nodes, "json");
    print "config:\n$CONFIG\nlogfile:\n$logfile\n" if $debug;
    print Dumper \%PARSER_CONFIG;

    my $out;

    # Build the header
    if( defined($info) )
    {
        $out = parser_gen_hdr_json($logfile,$info);
    }
    else
    {
        $out = parser_gen_hdr_json($logfile, undef);
    }
    $out .= $CONFIG;
    $out .= msc_parser_gen_ftr("json");

    # Write out the file
    $logfile = basename($logfile);
    my $json_conffile = $outpath .'/'.parser_rm_file_ext($PARSER_CONFIG{'ext'}, $logfile).'json';
    open( OUTFILE, ">$json_conffile" ) or die "Could not open $json_conffile for writing: $!\n";
    print OUTFILE $out;
    close( OUTFILE );
}

my $id = 0;
sub msc_parser_process_outputs($$@)
{
    my ($output_format, $logfile, @outputs) = @_;
    my $num_events = scalar keys(%{$MSC_PARSER_EVENTS{'event'}});
    my $num_splits = ceil($num_events / $NUM_EVENTS_PER_IFRAME);

	print "#events: $num_events num/frame: $NUM_EVENTS_PER_IFRAME #splits: $num_splits\n" if $debug;
    my $retstr = parser_process_outputs($logfile, $num_splits, @outputs);
    $id++ while $retstr =~ /\<output/g;
    return $retstr
}

sub msc_parser_build_output($$)
{
    my $logfile = shift;
    my $output_format = shift;

    # Build the output data for the output info.
    my $retstr;
    $retstr    .= "<outputs>\n" if $output_format =~ /xml/;
    my $outfile;
    $outfile = basename(parser_rm_file_ext(undef, $logfile)."xml") if $output_format =~ /xml/;
    $outfile = basename(parser_rm_file_ext(undef, $logfile)."json") if $output_format =~ /json/;

    if( exists $PARSER_CONFIG{'output_type'} )
    {
        my $output_type = $PARSER_CONFIG{'output_type'};
        if (exists $PARSER_XML_CONFIG->{'output_type'}->{$output_type})
        {
            $retstr .= msc_parser_process_outputs($logfile, @{$PARSER_XML_CONFIG->{'output_type'}->{$output_type}->{'output'}});
        }
        else
        {
            print "Could not find output_type: $output_type config\n";
        }
    }

    $retstr .= msc_parser_process_outputs($logfile, @{$PARSER_CONFIG{'output'}} ) if exists($PARSER_CONFIG{'output'});


    $retstr .= "</outputs>\n" if $output_format =~ /xml/;

    return $retstr
}


1;

__END__
=head1 REPORTING BUGS

When reporting bugs/problems please include as much information as possible.
It may be difficult for me to reproduce the problem as almost every setup
is different.

A small logfile which yields the problem will probably be of help,
together with the execution output.

Please send the bug/problem report to the author.

=head1 AUTHOR

Donald Jones <donald.starquality@gmail.com>

=head1 USE EXAMPLES

For an example of the use of msc_parser see B<sip_msg_parser.pl>

=head1 CREDITS

Donald Jones <donald.starquality@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2006-7 Donald Jones. All rights reserved.

=cut


