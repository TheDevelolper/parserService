#!/usr/bin/perl

use strict;
#use diagnostics;
use lib('parsers/pkgs');
use parser;
use msc_parser;
use Data::Dumper;
use Getopt::Std;

my $syntax = qq{

Usage: $0 -l <logfile> -o <outpath> [-d] [-h]

where:
   -l <logfile> is the logfile to parse
   -o <output path> is the output path where the json file will be written to.
   -d Debug mode
   -h This help screen

};

my $logfile;
my $outpath;
my $debug   = 0;
my @nodes;
my $latest_time;

parser_set_parser("syslog");

sub parse_params()
{
    # Are any command line options specified?
	our ($opt_d, $opt_h, $opt_l, $opt_o);
	getopts('dhl:o:');

    # debug mode
    if( defined $opt_d )
    {
        $debug = 1;
        $parser::debug=$debug;
        $main::opt_d = 1;
        print "Debug mode\n" if $debug;
    }

    # Help
    if( defined($opt_h) )
    {
        $main::opt_h = 1;
        print $syntax;
        die "\n";
    }

    # Logfile
    if( defined($opt_l ))
    {
        $logfile = $opt_l;
        print "...Opening $logfile\n" if $debug;
        die "Can't find $logfile because $!" unless -f $logfile;
    }
    else
    {
        print "Logfile required\n";
        exit(1);
    }
    
    # Output file
    if( defined($opt_o ))
    {
        $outpath = $opt_o;
    }
    else
    {
        print "Outpath required\n";
        exit(1);
    }
}
sub log_simple_msg($$$$$)
{
	my ($ev_hr, $from, $to, $line_num, $param_hr) = @_;
	msc_parser_create_msg($ev_hr, 
						$line_num, 
						$param_hr->{'time'}, 
						$param_hr->{'msg'}, 
						$param_hr->{'tag'}, 
						$to, 
						$from, 
						$param_hr->{'data'} );
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
        my $record_event = 0;
        my $sev;
        my %event;
        my $tag;
        
		# Oct 20 10:41:22 itl8042790S rsyslogd-2039: Could not open output pipe '/dev/xconsole' [try http://www.rsyslog.com/e/2039 ]
		if ($line =~ /(\S+ \d+ \d+\:\d+\:\d+) \S+ (\S+)\[.*\]\: (.*)/)
		{
			my $time = $1;
			my $node = $2;
			my $info = $3;

			if ($info =~ /\<info\> (.*)/ )
			{
			   # Create an event
			   $info = $1;
			   msc_parser_create_event( \%event,        	# event
									 $line_num,         	# line number of event
									 $time,   # time of event
									 $SEV_INFO,              	# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
									 undef,    # call id
									 $info,	# event title
									 $info,   # event data
									 $node);            	# node                                 
				$record_event = 1;
			}
			elsif ($info =~ /\<warn\> (.*)/ )
			{
			   # Create an event
			   $info = $1;
			   msc_parser_create_event( \%event,        	# event
									 $line_num,         	# line number of event
									 $time,   # time of event
									 $SEV_MINOR,              	# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
									 undef,    # call id
									 $info,	# event title
									 $info,   # event data
									 $node);            	# node                                 
				$record_event = 1;
			}
			elsif ($info =~ /error/ )
			{
			   # Create an event
			   msc_parser_create_event( \%event,        	# event
									 $line_num,         	# line number of event
									 $time,   # time of event
									 $SEV_MAJOR,              	# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
									 undef,    # call id
									 $info,	# event title
									 $info,   # event data
									 $node);            	# node                                 
				$record_event = 1;
			}
			else {$record_event = 0;}
											
			# If a useful event was found then record it.
			if( $record_event )
			{
				msc_parser_record_event($line_num, \%event);
			}
		}
        
        #print Dumper \%event;
        # die;
    }
}




# main program
parse_params();
print "...Parsing log file $logfile\n";
parse_log();

print "Input nodes\n";
print Dumper @nodes;

msc_parser_output_config_json($logfile, $outpath, \@nodes);


