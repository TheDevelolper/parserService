#!/usr/bin/perl

# Log Parser
# Created by Donald Jones
# 13th Oct 2006

use strict;
use warnings;
#use diagnostics;
use lib ('parsers/pkgs');
use Data::Dumper;
use File::Copy;
use File::Basename;
use Getopt::Std;
use parser;
use msc_parser;
use vars qw( $opt_d $opt_h $opt_l $opt_o $opt_p);

my $syntax = qq{

Usage: $0 -p <parser> -l <logfile> -o outfile [-d] [-h]

where:
\t-p <parser> parser to be use
\t-l <logfile> is the logfile to parse
\t-o <outfile> is the output file
\t-d Debug mode
\t-h This help screen

};

my $logfile;
my $outfolder;
my $logfiledir;
my $debug = 0;

$PARSER="";

sub parse_params
{
    # Are any command line options specified?
    getopts('dhl:o:p:');

    # debug mode
    if( defined($opt_d) )
    {
        $debug = 1;
        $parser::debug=$debug;
        $opt_d = 1;
        print "Debug mode\n" if $debug;
    }

    # Help
    if( defined($opt_h) )
    {
        $opt_h = 1;
        print $syntax;
        my @parsers = sort(parser_get_parsers());
        my $pars = join( "\n\t", @parsers );
        print "The parsers available are:\n\n\t$pars\n";
        die "\n";
    }

    # Parser
    if( defined($opt_p) )
    {
        parser_set_parser($opt_p);
    }
    else
    {
        print $syntax;
        die "Parser required\n";
    }
    # Need to ensure that either an XML or Log file is provided.
    if( !defined $opt_l)
    {
        print $syntax;
        die "Please specify an input file\n";
    }

    # Logfile
    if( defined($opt_l) )
    {
        $logfile = $opt_l;
        print "Opening Logfile: $logfile\n" if $debug;
        # check logfile exists
        die "Can't find $logfile because $!" unless -f $logfile;
    }

    # Output File
    if( !defined($opt_o) )
    {
        print $syntax;
        die "Please specify an output folder\n";
    }
    else
    {
        $outfolder = $opt_o;
        print "output folder: $outfolder\n" if $debug;
    }
}

# main program
parse_params();

my $parser_cmd = "perl parsers/$PARSER";
print "$PARSER:\n   $PARSER_CONFIG{'desc'}\n";
$parser_cmd .= "/".$PARSER_CONFIG{'pl'};
$parser_cmd .= " -l \"$logfile\"" if( defined($logfile) );
$parser_cmd .= " -o \"$outfolder\"" if( defined($outfolder) );
$parser_cmd .= " -d " if $debug;
print "cmd: $parser_cmd";
system($parser_cmd);

print Dumper $PARSER_CONFIG{'output'} if $debug;

print "...Generating tagged version of log file\n";
parser_gen_tagged_log($logfile, $outfolder) if( defined($logfile) ); # Do not create this if we were are processing XML files

# Populate the logfiledir;
$logfile =~ /([\S\s]+)\\/ if( defined($logfile) );
$logfiledir = $1;
print "Logfile: $logfile\n" if $debug;

#process any specific output formats
parser_create_output(@{$PARSER_CONFIG{'output'}}) if exists $PARSER_CONFIG{'output'};

