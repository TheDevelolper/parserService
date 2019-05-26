#!/usr/bin/perl

use strict;
#use diagnostics;
use lib('parsers/pkgs');
use parser;
use msc_parser;
use Data::Dumper;
use Getopt::Std;

my $syntax = qq{

Usage: $0 -l <logfile> [-d] [-h]

where:
   -l <logfile> is the logfile to parse
   -d Debug mode
   -h This help screen

};

my $logfile;
my $outpath;
my $debug   = 0;

print "ARGV\n";
print Dumper @ARGV;
# parser name
parser_set_parser("sip_msg");

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

    # Logfile
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

%MONTHS=(
	'Jan' => '01',
	'Feb' => '02',
	'Mar' => '03',
	'Apr' => '04',
	'May' => '05',
	'Jun' => '06',
	'Jul' => '07',
	'Aug' => '08',
	'Sep' => '09',
	'Oct' => '10',
	'Nov' => '11',
	'Dec' => '12'
);

sub parse_log()
{
    my $line_num = 0;
    my $line;

    msc_parser_open_file($logfile);

    print "...Parsing $logfile\n";
    foreach $line ( @lines )
    {
        $line_num++;
        chomp($line);
        #print "Parsing line: $line\n";

        my $record_msg = 0;
        my %event;

        my $frame;
        my $time;
        my $msg;
        my $data;
        my $src;
        my $dest;
        my $tag;

        # Frame 1 (571 bytes on wire, 571 bytes captured)
        if( $line =~ /^Frame (\d+) \((\d+) bytes on wire, (\d+) bytes captured\)/ )
        {
            $frame = $1;
            #print "Frame $frame starts at line $line_num\n" if $debug;
            if( $2 != $3 )
            {
                msc_parser_log_error($line_num, "Invalid frame $1 captured", undef);
                next;
            }

            # search within the frame date
            for( my $idx = 0; $idx < 100; $idx++ )
            {
                my $search_line = $lines[$line_num+$idx];
                # blank line
                if( $search_line !~ /./ )
                {
                    #print "Frame $frame ends at line   ".($line_num+$idx+1)."\n" if $debug;
                    last;
                }
                # Arrival Time: Mar 30, 2007 08:27:44.505258000
                elsif( $search_line =~ /Arrival Time: (\w+) (\d+), (\d{4}) (\d{2}):(\d{2}):(\d{2})\.(\d+)/ )
                {
					my $month = $MONTHS{$1};
                    my $msecs = sprintf( "%03d", $7/1000000 );
                    $time = parser_format_timestamp($3,$month,$2,$4,$5,$6,$msecs);
                }
                # Internet Protocol, Src: 172.16.7.16 (172.16.7.16), Dst: 172.16.8.24 (172.16.8.24)
                elsif( $search_line =~ /^Internet Protocol, Src: ([\d\.]+) \([\d\.]+\), Dst: ([\d\.]+) \([\d\.]+\)/ )
                {
                    $src  = $1;
                    $dest = $2;
                    $record_msg = 1;
                }
                elsif( $search_line =~ /^Session Initiation Protocol/ )
                {
                    #print "SIP Info for frame $frame starts at line ".($line_num+$idx+1)."\n" if $debug;
                    # search within the frame date
                    for( my $sipidx = 0; $sipidx < 50; $sipidx++ )
                    {
                        my $sip_line = $lines[$line_num+$idx+$sipidx];

                        if( $sip_line !~ /./ )
                        {
                            #print "SIP Info for frame $frame ends at line   ".($line_num+$idx+$sipidx+1)."\n" if $debug;
                            last;
                        }
                        # Request-Line: REGISTER sip:wateen.net SIP/2.0
                        elsif( $sip_line =~ /^\s+Request-Line: (\S+) \S+ \S+/ )
                        {
                            $msg = "(Frame $frame) SIP Req : $1";
                        }
                        # Status-Line: SIP/2.0 200 OK
                        elsif( $sip_line =~ /^\s+Status-Line: \S+ (\d+) (\S+)/ )
                        {
                            $msg = "(Frame $frame) SIP Stat: $1 $2";
                        }
                        elsif( $sip_line =~ /^\s+(?:f|From): .*?<(\S+)>/ )
                        {
                            $data = $1;
                            print "Data on line ".($line_num+$idx+$sipidx).": $data\n" if $debug;
                        }
                        elsif( $sip_line =~ /^\s+(?:f|From): .*?sip:(\S+?);/ )
                        {
                            $data = "sip:$1;";
                            print "Data on line ".($line_num+$idx+$sipidx).": $data\n" if $debug;
                        }
                        elsif( $sip_line =~ /^\s+P-Charging-Vector: icid-value=\"(\S+)\"/ )
                        {
                            # Strip the info after the @
                            my $tmp_tag = $1;
                            $tmp_tag =~ /(.*)\@/;
                            $tag = $1;
                        }
                        elsif( $sip_line =~ /^\s+Session ID: (\d+)/ )
                        {
                            $msg .= ", SDP Sess ID:$1";
                        }
                    }
                }
            }
        }

        # If a useful message was found then record it.
        if( $record_msg )
        {
            msc_parser_create_msg( \%event,
                                   $line_num,   # line number
                                   $time,       # time
                                   $msg,        # msg - user
                                   $tag,        # tag
                                   $dest,       # to
                                   $src,        # from
                                   $data );     # data

            print Dumper \%event if $debug;
            msc_parser_record_event($line_num, \%event);
        }
    }
}


# main program
parse_params();
print "...Parsing log file $logfile\n";
parse_log();

msc_parser_output_config_json($logfile, $outpath, undef);

