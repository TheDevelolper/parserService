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

my $NODE_FRACTAL = "Fractal";
my $NODE_UUT = "UUT";

print "ARGV\n";
print Dumper @ARGV;
# parser name
parser_set_parser("fractal_log");

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
	
	# Persistent information
	my $current_test;
	my $server;
	my $port;
	my $stop_parsing = 0;
	my $server_role;
	my $client_role;
	my $post_msg;
	
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
        my $tag = $current_test;

		#15:44:02.617 INFO    Started on 12/01/2017
		if ($line =~ /(\d+\:\d+:\d+.\d+)/)
		{
			# Extract timestamp
			$time = $1;
		}
		
		#15:44:28.194 INFO    Test:            70  : [icm-request-infca] An ICM will request an
		if ($line =~ /Test\:\s+(\d+)\s+\:\s+\[(.*)\]/)
		{
			my $test_num = $1;
			my $test_name = $2;
			$current_test =  "$test_num:$test_name";
			$tag = $current_test;
			# Create an event
			$record_msg = 1;
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_INFO,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "Test Started",	# event title
                                 undef,      		# event data
                                 $NODE_FRACTAL);    # node    
		}		
		#16:13:39.253 ERROR   Test:                  FAIL
		#16:13:39.261 ERROR                          Test failed
		# 16:13:39.261 ERROR                          Received invalid certificate start time: 12/01/2017 15:12:25.
		elsif ($line =~ /ERROR\s+(.*)/)
		{
			my $error = $1;
			$error = "FAIL" if $error =~ /FAIL/;
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CRITICAL,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# test id
                                 $error,			# event title
                                 undef,      		# event data
                                 $NODE_FRACTAL);    # node

			$record_msg = 1 unless $error =~ /Test failed/;								 
		}
		elsif ($line =~ /INFO\s+Test:\s+PASS/)
		{
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CLEAR,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# test id
                                 "PASS",			# event title
                                 undef,      		# event data
                                 $NODE_FRACTAL);    # node
			$record_msg = 1;
		}
		# 15:45:12.765 INFO                     SKD: MCKM ---> Server POST CMC-request CSR type=Inf-IA
		elsif ($line =~ /SKD\: (\S+)\s+--->\s+Server\s+POST\s+(.*)/)
		{
			$client_role = $1;
			$post_msg = $2;
		}
		elsif ($line =~ /(.*) requesting (.*) from (.*)\./)
		{
			$client_role = $1;
			$post_msg    = $2;
			$server_role = $3;
		}
		# 15:46:32.342 DEBUG                    Generating message signature using cert with serial: 5
		# 15:46:32.360 INFO                     Initiate new connection to ('128.10.1.4', 80):80 in 0.0 second(s)
		# 15:46:32.361 INFO                     SKD: Client ---> Server CMC-request (1340 bytes)
		elsif ($line =~ /(\S+)\: (\S+)\s+--->\s+(\S+)\s+(.*)/)
		{
			my $entity = $1;
			my $from = $2;
			my $to   = $3;
			my $msg  = "$entity:$4";
			
			if($to   =~ /Server/)
			{
				$to   = $server_role;
				$from = $client_role if $from =~ /Client/;
				$msg .= $post_msg;
			}
			if($from =~/Server/)
			{
				$to = $client_role if $to =~ /Client/;
				$from = $server_role;
			}

			if ($line =~ /\?\?\?\?/)
			{
				# Case of stupid Fractal trace where the message name is on the previous line
				my $prev_line = $lines[$line_num-2];
				print "Prev Line\[$line_num-1]: $prev_line\n";
				
				if ($prev_line =~ /ASYNC HTTP (.*)/)
				{
					$msg = "HTTP $1\[$msg\]";
				}
			}

			$from = $NODE_FRACTAL if ($from =~ /None/);
			$to   = $NODE_UUT if ($to =~ /Client/);
			
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$to, 
						$from, 
						undef);
			$record_msg = 1;
			$record_msg = 0 if $msg =~ /CertificateSigningRequest/;
			$post_msg = undef;
		}	
		#2, ('Received poll HTTP request: path=%s', '/status_558322')
		elsif ($line =~ /\d+, \(\'Received (.*)\:.*\', \'(.*)\'/)
		{
			$msg = "$1\[$2\]";

			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_FRACTAL, 
						$NODE_UUT, 
						undef);
			$record_msg = 1;
		}
		# UDP: UUT -X-> Crypto1 INFORMATIONAL-req [msgID=2]
		elsif($line =~ /UUT .*-> (\w+) (.*)/)
		{
			my $to = $1;
			my $msg = $2;
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$to, 
						$NODE_UUT, 
						undef);
			$record_msg = 1;
		}
		#15:44:35.288 DEBUG                          Received SKD message:
		#                                           CertificateSigningRequest:
		elsif ($line =~ /Received SKD message\:/)
		{
			if ($lines[$line_num] =~ /\|\s+(.*)\:/)
			{
				$msg = $1;
				msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_FRACTAL, 
						$NODE_UUT, 
						undef);
				$record_msg = 1;
			}
		}
		#15:44:35.288 DEBUG                          Received SKD message:
		#                                           CertificateSigningRequest:
		elsif ($line =~ /Sending SKD message\:/)
		{
			if ($lines[$line_num] =~ /\|\s+(.*)\:/)
			{
				$msg = $1;
				msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_UUT, 
						$NODE_FRACTAL, 
						undef);
				$record_msg = 1;
			}
		}
		#15:44:35.118 INFO                           #> 2. Expect a Certificate Signing Request.
		elsif ($line =~ /\#> (.*)/)
		{
			my $string = $1;
					 
			msc_parser_create_span_box( \%event,       	# event
                                 $line_num,         	# line number of event
                                 $time,   				# time of event
                                 $SEV_INFO,              	# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    				# test id
                                 $string,				# event title
                                 undef,   				# event data
                                 $NODE_FRACTAL,			# from
                                 $NODE_UUT);            # to
			$record_msg = 1;
		
		}
		#		15:57:42.128 INFO                           Initiate new connection to ('128.10.1.2', 80):80 in 0.0 second(s)
		elsif($line =~ /Initiate new connection to \(\'(.*)\'\, (\d+)\)/)
		{
			$server = $1;
			$port = $1;
		}
		elsif($line =~ /Connect closed for Server/)
		{
			# $server = undef;
			# $port = undef;
		}
		#		15:57:42.179 DEBUG                          Connected to Server
		#		15:57:42.229 DEBUG                          Sending HTTP GET /status_2 message.
		elsif($line =~ /Sending (.*) message\./)
		{
			my $msg = $1;
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_FRACTAL, 
						$server, 
						undef);
			#$record_msg = 1;
		}
		elsif( $line=~ /cmd optimus > (.*)/)
		{
			my $msg ="CLI: $1";
			
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_UUT, 
						$NODE_FRACTAL, 
						undef);
			$record_msg = 1;
		}				
		elsif( $line=~ /(HTTP Status.*)/)
		{
			my $msg =$1;
			
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$server, 
						$NODE_FRACTAL, 
						undef);
			#$record_msg = 1;
		}		
		elsif( $line=~ /Summary of the entire run/)
		{
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CLEAR,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# test id
                                 "TEST SUITE OVER",			# event title
                                 undef,      		# event data
                                 $NODE_FRACTAL);    # node			
			$record_msg = 1;
			$stop_parsing = 1;
		}			
		
        # If a useful message was found then record it.
        if( $record_msg )
        {
            msc_parser_record_event($line_num, \%event);
        }
		
		if( $stop_parsing )
		{
			last;
		}
    }
}


# main program
parse_params();
print "...Parsing log file $logfile\n";
parse_log();

msc_parser_output_config_json($logfile, $outpath, undef);

