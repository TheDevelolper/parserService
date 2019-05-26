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

parser_set_parser("simple");

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

sub extract_params($$)
{
	my $hash_ref= shift;
	$_ = shift;
#	print "Extract_params: $_\n";
	while (s/(.*?)=\"(.*?)\"\s*//)
	{
		$hash_ref->{$1} = $2;
	}
}

sub simple_map_sev_text($) {
    my $sev_s = shift;
    my $sev = 0;
    $sev = $SEV_CRITICAL if $sev_s =~ /critical/i;
    $sev = $SEV_MAJOR if $sev_s =~ /major/i;
    $sev = $SEV_MINOR if $sev_s =~ /minor/i;
    $sev = $SEV_INTERMIT if $sev_s =~ /intermit/i;
    $sev = $SEV_INFO if $sev_s =~ /info/i;
    $sev = $SEV_CLEAR if $sev_s =~ /clear/i;
    return $sev;
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
        my $record_event = 1;
        my $sev;
        my %event;
        my $tag;
        my $cmd;
        my $param_txt;
        my %param_hash;

		print "Line: $line\n";
        # split line into command and params
        if (/^(.*?)\s+\[(.*?)\];\s*$/)
        {
        	$cmd = $1;
        	$param_txt = $2;
        	extract_params(\%param_hash, $param_txt);
        }
        else
        {
        	next;
        }
        # print "Have a valid string\n";
        #print Dumper \%param_hash;
        
        if ($cmd =~ /\^/)
		{
			print "Have Node $param_hash{'name'}\n" if $debug;
			push (@nodes, $param_hash{'name'});
			$record_event = 0;
		}
		#S-FAP_RRC -> S-FAP_MMGMM [msg="RELOCATION REQUIRED [CS]"]
        elsif ($cmd =~ /(.*)\s*\-\>\s*(.*)/)
        {
        	print "have msg\n" if $debug;
			log_simple_msg(\%event, $1, $2, $line_num, \%param_hash);
        } 
        elsif ($cmd =~ /(\S*)\s*<-\s*(\S*)/)
        {
        	print "have msg\n" if $debug;
			log_simple_msg(\%event, $2, $1, $line_num, \%param_hash);
        }         
        elsif($cmd =~ /^<(\S*?)>/ )
        {
			print "have event\n" if $debug;
           my $node = $1;
           
           $sev = simple_map_sev_text($param_hash{'sev'}) if exists $param_hash{'sev'};
           
           # @TODO Extract from line the various information required below

           # Create an event
           msc_parser_create_event( \%event,        	# event
                                 $line_num,         	# line number of event
                                 $param_hash{'time'},   # time of event
                                 $sev,              	# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $param_hash{'tag'},    # call id
                                 $param_hash{'title'},	# event title
                                 $param_hash{'data'},   # event data
                                 $node);            	# node                                 
        }
        elsif($cmd =~ /^<(\S*)\s+(\S*)>/ )
        {
           my $from = $1;
           my $to = $2;
           print "have event\n" if $debug;
           $sev = simple_map_sev_text($param_hash{'sev'}) if exists $param_hash{'sev'};

           # Create an event
           msc_parser_create_span_box( \%event,        	# event
                                 $line_num,         	# line number of event
                                 $param_hash{'time'},   # time of event
                                 $sev,              	# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $param_hash{'tag'},    # call id
                                 $param_hash{'title'},	# event title
                                 $param_hash{'data'},   # event data
                                 $from,					# from
                                 $to);            		# to
        }
        elsif ($cmd =~ /^{(.*?)}/)
        {
           my $node = $1;
           # Create a state change event
           msc_parser_create_state_change( \%event,             # event
                                        $line_num,          	# line number of event
                                        $param_hash{'time'},	# time of event
                                        $param_hash{'tag'},		# call id
                                        $param_hash{'state'},	# state
                                        $node,              	# node
                                        $param_hash{'msg'});	# message
        }
        else {$record_event = 0;}
                                        
        msc_parser_add_url_to_event(\%event, $param_hash{'url'}) if exists $param_hash{'url'};
        
        # If a useful event was found then record it.
        if( $record_event )
        {
            msc_parser_record_event($line_num, \%event);
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


