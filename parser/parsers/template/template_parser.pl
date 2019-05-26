use strict;
#use diagnostics;
use lib('parsers/pkgs');
use parser;
use msc_parser;
use File::Copy;
use Getopt::Std;
use Data::Dumper;
# use LWP::Simple;

my $syntax = qq{

Usage: $0 -l <logfile> [-d] [-h]

where:
   -l <logfile> is the logfile to parse
   -d Debug mode
   -h This help screen

};

my $logfile = "";
my $xmlfile = "";
my $debug   = 0;

my $latest_time;

parser_set_parser("template");

sub parse_params()
{
    # Are any command line options specified?
    getopts('dhl:');

    # debug mode
    if( defined $main::opt_d )
    {
        $debug = 1;
        $parser::debug=$debug;
        $main::opt_d = 1;
        print "Debug mode\n" if $debug;
    }

    # Help
    if( defined($main::opt_h) )
    {
        $main::opt_h = 1;
        print $syntax;
        die "\n";
    }

    # Logfile
    if( defined($main::opt_l) )
    {
        $logfile = $main::opt_l;
        print "...Opening $logfile\n" if $debug;
        die "Can't find $logfile because $!" unless -f $logfile;
    }
    else
    {
        print "Logfile required\n";
        exit(1);
    }
}

# parse_line_for_time
# Extracts the time from the line
# @TODO Update for date format used in log file
sub parse_line_for_time($$)
{

    $_ = shift;
    my $latest_time = shift;
    #[15/12/06 09:54:22]
    if( /^\[(\d+)\/(\d+)\/(\d+)\s+(\d+):(\d+):(\d+)\]/ )
    {
        #Output time as YYYY-MM-DD HH:MM:SS mmm
        my $time = parser_format_timestamp($1, $2,$3,$4,$5,$6, "0");
        $latest_time = $time;
        #print "Found time: $latest_time\n";
    }
    return $latest_time;
}


sub parse_log()
{
    my $line_num = 0;
    
    msc_parser_open_file($logfile);

    print "...Parsing $logfile\n";
    foreach( @lines )
    {
        $line_num++;
        chomp;
        my $line = $_;
        my $record_event = 1;
        my $sev = "";
        my %event;
        my $site;

        if( /msg/ )
        {
            # @TODO Parse out appropriate fields

            # Create a msg event
            my $src = $1;
            my $tag = $2;
            my $len = $3;
            my $dest;
            my $data;
            my $msg;

            my $node;
            my $call_id;
            msc_parser_create_msg( \%event, 
                                $line_num, 
                                $latest_time, 
                                $msg, 
                                $call_id, 
                                $dest, 
                                $src, 
                                $data );

        }elsif( /event/ )
        {
           my $data;
           my $node;
           # @TODO Extract from line the various information required below

           # Create an event
           msc_parser_create_event( \%event,            # event
                                 $line_num,         # line number of event
                                 $latest_time,             # time of event
                                 $sev,              # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 undef,             # call id
                                 "Event Title",     # event title
                                 $data,             # event data
                                 $node);            # node
        }elsif (/statechange/)
        {
           my $state;
           my $node;
           my $msg;
           # @TODO Extract from line the various information required below

           # Create a state change event
           msc_parser_create_state_change( \%event,             # event
                                        $line_num,          # line number of event
                                        $latest_time,              # time of event
                                        undef,              # call id
                                        "State Change",     # event title
                                        $state,             # state
                                        $node,              # node
                                        $msg );             # message

        }else {$record_event = 0;}

        # If a useful event was found then record it.
        if( $record_event )
        {
            msc_parser_record_event($line_num, \%event);
        }
    }
}



parse_params();
print "...Parsing log file $logfile\n";
parse_log();
print "...Parsing for Nodes\n";

print "...Writing logfile $logfile to\n   XML file $xmlfile\n";
msc_parser_output_xml_config($logfile);

