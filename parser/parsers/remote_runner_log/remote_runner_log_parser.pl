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

my $NODE_FRACTAL = "FRACTAL";
my $NODE_FILE    = "CONFIG_FILE";
my $NODE_OPTIMUS = "OPTIMUS";
my $NODE_CT      = "CT";
my $NODE_PT      = "PT";
my $NODE_MGMT      = "MGMT";

print "ARGV\n";
print Dumper @ARGV;
# parser name
parser_set_parser("remote_runner_log");

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

my $pt; # PT IP Address
my $ct; # CT IP Address
my $cmdComplete = 0; # Is cmdComplete enabled?
sub ip_addr_change_check($)
{
	my $msg = shift;
	# Check if Optimus has been instructed to change IP address.
	if ($msg =~ /ip add pt (\d+\.\d+\.\d+\.\d+)/)
	{
		$pt = $1;
	}
	if ($msg =~ /ip add ct (\d+\.\d+\.\d+\.\d+)/)
	{
		$ct = $1;
	}
}

sub further_command_checks($$$$)
{			
	my ($msg, $line_num, $time, $tag) = @_;
	my %tmp_event;
	# Check if Optimus has been instructed to change IP address.
	if ($msg =~ /ip add pt (\d+\.\d+\.\d+\.\d+)/)
	{
		$pt = $1;
		msc_parser_create_event( \%tmp_event,      	# event
			 $line_num + 0.1,         # line number of event
			 $time,   			# time of event
			 $SEV_CLEAR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
			 $tag,    			# call id
			 "Added PT: $pt",	# event title
			 undef,      		# event data
			 $NODE_PT);    # node   
		msc_parser_record_event($line_num + 0.1, \%tmp_event);
	}
	elsif ($msg =~ /ip add ct (\d+\.\d+\.\d+\.\d+)/)
	{
		$ct = $1;
		
		msc_parser_create_event( \%tmp_event,      	# event
			 $line_num + 0.1,         # line number of event
			 $time,   			# time of event
			 $SEV_CLEAR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
			 $tag,    			# call id
			 "Added CT: $ct",	# event title
			 undef,      		# event data
			 $NODE_CT);    # node 
		msc_parser_record_event($line_num + 0.1, \%tmp_event);
	}
	elsif ($msg =~ /ip del pt (\d+\.\d+\.\d+\.\d+)/)
	{
		$pt = undef if $pt =~/$1/;
		msc_parser_create_event( \%tmp_event,      	# event
			 $line_num + 0.1,         # line number of event
			 $time,   			# time of event
			 $SEV_MINOR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
			 $tag,    			# call id
			 "Deleted PT: $pt",	# event title
			 undef,      		# event data
			 $NODE_PT);    # node  				
		msc_parser_record_event($line_num + 0.1, \%tmp_event);
		
	}
	elsif ($msg =~ /ip del ct (\d+\.\d+\.\d+\.\d+)/)
	{
		$ct = undef if $ct =~ /$ct/;
		
		msc_parser_create_event( \%tmp_event,      	# event
			 $line_num + 0.1,         # line number of event
			 $time,   			# time of event
			 $SEV_MINOR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
			 $tag,    			# call id
			 "Deleted CT: $ct",	# event title
			 undef,      		# event data
			 $NODE_CT);    # node 		
		msc_parser_record_event($line_num + 0.1, \%tmp_event);					 
	}			
	elsif ($msg =~ /cmdcomplete on/){$cmdComplete = 1;}
	elsif ($msg =~ /cmdcomplete off/){$cmdComplete = 0;}
}

sub clean_rr_output($)
{
	my $clean_line = shift;
	$clean_line =~ s/.*\[NEW-TIME\]//;
	$clean_line =~ s/.*\[Fractal\]//;
	$clean_line =~ s/^\s*\'//;
	$clean_line =~ s/\'\s*$//;
	return $clean_line;		
}

sub parse_log()
{
    my $line_num = 0;
    my $line;
	
	# Persistent information
	my $current_test;
	my $last_ether_to;
	my $config_filename;
	my $loading_config;
	my $mckm_ip;
	my $mckm_name;
	
    msc_parser_open_file($logfile);

    print "...Parsing $logfile\n";
    foreach $line ( @lines )
    {
        $line_num++;
        chomp($line);
        
		$line =~ s/\\r\\n//g;
		$line =~ s/\s+'$/'/g;
		print "Parsing line: $line_num: $line\n" if $debug;
		#die if $line =~ /\\r\\n/;

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
		
		# 09:52:49.917 Started optimus: pid=8532 cmd=['ssh', '-tt', 'fractal@optimus', 'stty -echo; { cd /local_home/fractal/workspaces/fractal/Test/optimus_clone/Optimus/optimus; sudo python optimus.py --config=skd --ignore mckm,mr,ir,icm,mckmccoi,symmkeymgr --import ../../skd; }']
		if ($line =~ /Started optimus: (.*)/)
		{
			$data = $1;
			# Create an event
			$record_msg = 1;
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_MAJOR,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "Starting",	# event title
                                 $data,      		# event data
                                 $NODE_OPTIMUS);    # node   
		}
		# 14:55:14.084 sendTo[OLD-TIME]: suppressed '20-OPTIM: Optimus exiting... Goodbye\r\n'
		elsif ($line =~ /Optimus exiting/)
		{
			$tag = undef; # If shutting down, then there is not currently a valid test.
			$current_test = undef;
			
			# Create an event
			$record_msg = 1;
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CLEAR,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "Gracefully Exiting",	# event title
                                 undef,      		# event data
                                 $NODE_OPTIMUS);    # node   
		}
		# 14:55:14.084 sendTo[OLD-TIME]: suppressed '20-OPTIM: Optimus exiting... Goodbye\r\n'
		elsif ($line =~ / (\'50-.*)/)
		{	
			my $full_error = $1;
			my $error = $full_error;
			$error =~ s/'.*://;
			# Create an event
			$record_msg = 1;
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CRITICAL,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 $error,			# event title
                                 $full_error,      		# event data
                                 $NODE_OPTIMUS);    # node   
		}
		# 14:55:14.084 sendTo[OLD-TIME]: suppressed '40-OPTIM: Optimus exiting... Goodbye\r\n'
		elsif ($line =~ / (\'40-.*)/)
		{	
			my $full_error = $1;
			my $error = $full_error;
			$error =~ s/'.*://;
			# Create an event
			$record_msg = 1;
			    msc_parser_create_event( \%event,      	# event
				                 $line_num,         # line number of event
				                 $time,   			# time of event
				                 $SEV_MAJOR,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
				                 $tag,    			# call id
				                 $error,			# event title
				                 $full_error,      		# event data
				                 $NODE_OPTIMUS);    # node   
		}
		# 14:55:14.084 sendTo[OLD-TIME]: suppressed '30-OPTIM: Optimus exiting... Goodbye\r\n'
		elsif ($line =~ / (\'30-.*)/)
		{	
			my $full_error = $1;
			my $error = $full_error;
			$error =~ s/'.*://;
			# Create an event
			$record_msg = 1;
			    msc_parser_create_event( \%event,      	# event
				                 $line_num,         # line number of event
				                 $time,   			# time of event
				                 $SEV_MINOR,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
				                 $tag,    			# call id
				                 $error,			# event title
				                 $full_error,      		# event data
				                 $NODE_OPTIMUS);    # node   
		}
		# 14:55:14.084 sendTo[OLD-TIME]: Discarding '
		elsif ($line =~ /Discarding HTTP retries due to (\S*):/)
		{	
			# Create an event
			$record_msg = 1;
			msc_parser_create_event( \%event,      	# event
			                 $line_num,         # line number of event
			                 $time,   			# time of event
			                 $SEV_INFO,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
			                 $tag,    			# call id
			                 "Drop HTTP retx\[$1\]",			# event title
			                 undef,
			                 $NODE_OPTIMUS);    # node   
		}
		elsif ($line =~ /PROC_START\[(.*)\]/)
		{			
			my $proc = $1;
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         		# line number of event
                                 $time,   			# time of event
                                 $SEV_INFO,       		# severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 $proc,				# event title
                                 undef,      			# event data
                                 $NODE_OPTIMUS);    		# node   		
			$record_msg = 1;
		}
		elsif ($line =~ /PROC_STATUS\[(.*)\]/)
		{			
			my $proc = $1;
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_INFO,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 $proc,	# event title
                                 undef,      		# event data
                                 $NODE_OPTIMUS);    # node   		
			$record_msg = 1;
			# die;
		}
		elsif ($line =~ /PROC_END\[(.*)\]/)
		{			
			my $proc = $1;
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CLEAR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 $proc,	# event title
                                 undef,      		# event data
                                 $NODE_OPTIMUS);    # node   		
			$record_msg = 1;
			# die;
		}
		# 09:52:45.475 sendTo[NEW-TIME]: dropped '45-OPTIM: Executing config file optimusA\r\n'
		elsif ($line =~ /Executing config file ([a-zA-Z0-9\-_]+)/)
		{
			$config_filename = $1;
			$loading_config = 1;
			
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_MINOR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "Load Config: $config_filename",	# event title
                                 undef,      		# event data
                                 $NODE_FILE);    # node   		
			$record_msg = 1;
		}
		# 09:52:45.478 sendTo[NEW-TIME]: dropped '45-HMI  : >>> keydir ../Keys\r\n'
		elsif (($line =~ /45-HMI  : >>> (.*)/) or ($line =~ /25-HMI  : >>> (.*)/))
		{
			$msg = $1;
			if ($cmdComplete)
			{
				# look over the next few lines and concantenate them into data
				for (my $j = -1; $j <= 15; $j++)
				{
					my $data_line = clean_rr_output($lines[$line_num+$j]);
					$data .= $data_line;
					$data .= "\n";
					last if $data_line =~ /Command complete\:/;
					
				}				
			}
			
			if ($loading_config == 1)
			{
				msc_parser_create_msg(\%event, 
							$line_num, 
							$time, 
							$msg, 
							$tag, 
							$NODE_OPTIMUS, 
							$NODE_FILE, 
							$data);
				$record_msg = 1;
				further_command_checks($msg, $line_num, $time, $tag);
			}
		}		
		# 09:52:45.480 sendTo[NEW-TIME]: dropped '45-OPTIM: Config file optimusA complete!\r\n'
		elsif ($line =~ "Config file (.*) complete")
		{
			$config_filename = $1;
			$loading_config = undef;
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CLEAR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "Config Load Complete",	# event title
                                 undef,      		# event data
                                 $NODE_FILE);    # node   		
			$record_msg = 1;
		}
		# 09:52:51.477 sendTo[NEW-TIME] '45-OPTIM: Optimus ready...\r\n'
		elsif ($line =~ /Optimus ready/)
		{
			$data = $1;
			# Create an event
			$record_msg = 1;
            msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CLEAR,         # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "READY",	# event title
                                 undef,      		# event data
                                 $NODE_OPTIMUS);    # node   
		}
		# 09:52:51.551 RECV[NEW-TIME] 'echo [[[ Starting test cka-inf-crl-ca-restore ]]]'
		elsif ($line =~ "RECV.*Starting test (.*) ")
		{
			$current_test = $1;
			$tag = $current_test;
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_INFO,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "Test: $current_test",	# event title
                                 undef,      		# event data
                                 $NODE_FRACTAL);    # node   		
			$record_msg = 1;
			further_command_checks($msg, $line_num, $time, $tag);

		}
		# 09:52:51.488 RECV[NEW-TIME] 'cmdcomplete on'
		elsif ($line =~ "RECV.*\'(.*)\'")
		{
			$msg = "CLI: $1";
			$record_msg = 1;
			
			if ($cmdComplete)
			{
				# look over the next few lines and concantenate them into data
				for (my $j = -1; $j <= 15; $j++)
				{
					my $data_line = clean_rr_output($lines[$line_num+$j]);
					$data .= $data_line;
					$data .= "\n";
					last if $data_line =~ /Command complete\:/;
					
				}				
			}
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_OPTIMUS, 
						$NODE_FRACTAL, 
						$data);
						
			# Parsing information out of messages
			if ($line =~ /cka mckm add (\S+) (.*)/)
			{
				$mckm_name = $1;
				$mckm_ip = $2;
			}
			elsif ($line =~ /cka mckm del (\S+)/)
			{
				my $tmp_name = $1;
				if ($tmp_name =~ /$mckm_name/)
				{
					$mckm_name = undef;
					$mckm_ip = undef;
				}
			}
			further_command_checks($msg, $line_num, $time, $tag);			
		}
		#  SNMP Table Read Start
		elsif ($line =~ "SNMP Table Read Start")
		{
			$msg = "SNMP Table Read: ";
			$record_msg = 1;
			
			if ($cmdComplete)
			{
				my $num_borders = 0;
				# look over the next few lines and concantenate them into data
				for (my $j = -1; $j <= 15; $j++)
				{
					my $data_line = clean_rr_output($lines[$line_num+$j]);
					$msg = "SNMP Table Read: $1" if $data_line =~ /:(.* Table)\:/;
					$msg = "SNMP Table Read: $1" if $data_line =~ /:(.* Requests)\:/;
					$data .= $data_line;
					$data .= "\n";
					
					$num_borders += 1 if ($data_line =~ /\+\-/); 
					last if $num_borders == 3;
					
				}				
			}
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_MGMT, 
						$NODE_OPTIMUS, 
						$data);
		}
		#  Optimus -> 30.10.1.129: IKE[IKE_SA_INIT request]
		elsif (($line =~ /(\d+\.\d+\.\d+\.\d+) -> Optimus: (.*\])/) or ($line =~ /(\S+T) -> Optimus: (.*\])/))
		{
			my $from = $1;
			my $msg  = $2;

			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_OPTIMUS, 
						$from, 
						undef);
			$record_msg = 1;
		}	
		# Optimus -> 30.10.1.129: IKE[IKE_SA_INIT request]		
		elsif (($line =~ /Optimus -> (\d+\.\d+\.\d+\.\d+): (.*\])/) or ($line =~ /Optimus -> (\S+T): (.*\])/))
		{
			my $to = $1;
			my $msg  = $2;

			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$to, 
						$NODE_OPTIMUS, 
						undef);
			$record_msg = 1 unless $msg =~ /PT FWD/;
		}
		# Optimus -> 30.10.1.129: IKE[IKE_SA_INIT request]		
		elsif ($line =~ /(\d+\.\d+\.\d+\.\d+) -> (\d+\.\d+\.\d+\.\d+): (.*\])/)
		{
			my $from = $1;
			my $to = $1;
			my $msg  = $2;

			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$to, 
						$from, 
						undef);
			$record_msg = 1 unless $msg =~ /PT FWD/;
		}		
		# Sending HTTP POST request for /fullcmc to 128.10.1.6
		elsif ($line =~ /Sending (.*) request for (.*) to (\d+\.\d+\.\d+\.\d+)/)
		{
			$msg = "$1: $2";
			my $to = $3;
			$to =~ s/\'//;
			if (defined $mckm_name and defined $mckm_ip)
			{
				$to = $mckm_name if $to =~ /$mckm_ip/;
			}
			if (defined $pt)
			{
				$to = $NODE_PT if $to =~ /$pt/;
			}
			if (defined $ct)
			{
				$to = $NODE_CT if $to =~ /$ct/;
			}

			$last_ether_to = $to;
			
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$to, 
						$NODE_OPTIMUS, 
						undef);
			$record_msg = 1;
		}
		# 09:39:03.228 sendTo[NEW-TIME] 'Traceback (most recent call last):\r\n'
		elsif ($line =~ /Traceback/)
		{
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CRITICAL,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "CRASH",	# event title
                                 undef,      		# event data
                                 $NODE_OPTIMUS);    # node   		
			$record_msg = 1;
		}
		# 15:54:19.203 sendTo[NEW-TIME] "error: uncaptured python exception, closing channel <skdHttpStack.TcpClient at 0x25f2488> (<class 'socket.error'>:[Errno 9] Bad file descriptor [/usr/lib/python2.7/asyncore.py|read|83] [/usr/lib/python2.7/asyncore.py|handle_read_event|444] [../../skd/modules/skdHttp/skdHttpStack.py|handle_read|1177] [/usr/lib/python2.7/socket.py|meth|224] [/usr/lib/python2.7/socket.py|_dummy|170])\r\n"
		elsif ($line =~ /uncaptured python exception/)
		{
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_CRITICAL,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "CRASH: uncaptured exception", # event title
                                 undef,      		# event data
                                 $NODE_OPTIMUS);    # node   		
			$record_msg = 1;
		}	
		# Sending PROBE ARP message for 30.10.1.2 from 128.10.1.2 due to new CT IP'
		elsif ($line =~ /Sending (.*) from (.*) due/g)
		{
			$msg = $1;
			my $from_addr = $2;
			my $to = $2;

			if (defined $pt)
			{
				$to = $NODE_PT if $from_addr =~ /$pt/;
			}
			elsif (defined $ct)
			{
				$to = $NODE_CT if $from_addr =~ /$ct/;
			}
			else
			{
				# Assume that it is PT.
				$to = $NODE_PT;
			}
			$last_ether_to = $to;
			
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$to, 
						$NODE_OPTIMUS, 
						undef);
			$record_msg = 1;
		}		
		#Sending ARP request for 128.10.1.4 from 128.10.1.2'
		elsif ($line =~ /Sending (.*) from (.*)'/g)
		{
			$msg = $1;
			my $from_addr = $2;
			my $to = $2;
			print "line: $line_num to: $to, last_ether_to1: $last_ether_to, from_addr: $from_addr, pt: $pt, ct: $ct\n";
			$to =~ s/\'$//g;

			if (defined $pt and $from_addr =~ /$pt/)
			{
				$to = $NODE_PT;
			}
			elsif (defined $ct and $from_addr =~ /$ct/)
			{
				$to = $NODE_CT;
			}
			else
			{
				# Assume that it is PT.
				$to = $NODE_PT;
			}
			$last_ether_to = $to;
			
			print "line: $line_num to: $to, last_ether_to1: $last_ether_to, from_addr: $from_addr, pt: $pt, ct: $ct\n";
			#die if $line = 1269;
			
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$to, 
						$NODE_OPTIMUS, 
						undef);
			$record_msg = 1;
		}
		#Received ARP reply for 128.10.1.4
		elsif ($line =~ "20-ETHER: Received (.*)")
		{
			$msg = $1;
			my $to = $2;
			$record_msg = 1;
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_OPTIMUS, 
						$last_ether_to, 
						undef);
		}
		# 14:54:42.966 sendTo[NEW-TIME] '20-SNMP : Handling SNMP SET request for 1 OIDs - regInfIaCertEsn.0'
		elsif ($line =~ "Handling SNMP (.*) request for .* - (.*)\'")
		{
			$msg = "SNMP $1: $2";
			$record_msg = 1;
			msc_parser_create_msg(\%event, 
						$line_num, 
						$time, 
						$msg, 
						$tag, 
						$NODE_OPTIMUS, 
						$NODE_MGMT, 
						undef);
		}		
		# 15:06:49.120 sendTo[Fractal] '20-CKA  : checkTimersFrequent - Retransmitting HTTPRequest(/fullcmc) to 128.10.1.6\r\n'
		elsif ($line =~/Retransmitting (\S*)/)
		{
			# Create an event
			msc_parser_create_event( \%event,      	# event
                                 $line_num,         # line number of event
                                 $time,   			# time of event
                                 $SEV_MINOR,        # severity SEV_CRITICAL, SEV_MAJOR, SEV_MINOR or SEV_INFO
                                 $tag,    			# call id
                                 "Retx: $1", # event title
                                 undef,      		# event data
                                 $NODE_OPTIMUS);    # node   		
			$record_msg = 1;
		}	

        # If a useful message was found then record it.
        if( $record_msg )
        {
            msc_parser_record_event($line_num, \%event);
        }
    }
}


# main program
parse_params();
print "...Parsing log file $logfile\n";
parse_log();

msc_parser_output_config_json($logfile, $outpath, undef);

