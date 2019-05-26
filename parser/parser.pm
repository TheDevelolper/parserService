#!/usr/bin/perl

# Generic TTY Parser
# Created by Donald Jones
# 13th Oct 2006

=head1 NAME

parser.pm - Parser helper functions

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

       parser_set_parser

       parser_format_timestamp

    for main parser function

       parser_rm_file_ext

       parser_conv_xml_via_xsl

       parser_get_parsers

       parser_gen_tagged_log

=cut

package parser;

require Exporter;

@ISA =      qw(Exporter);

@EXPORT =   qw($NUL
               $PARSER
               %PARSER_CONFIG
               $PARSER_XML_CONFIG
               $PARSER_LOGFILE
               $CONFIG
               %MONTHS
               $debug
               @lines

               parser_build_output_xml
               parser_conv_xml_via_xsl
               parser_format_output_node
               parser_format_timestamp
               parser_gen_tagged_log
               parser_get_parsers
               parser_get_num_splits
               parser_gen_hdr_xml
               parser_gen_hdr_json
               parser_open_file
               parser_parse_params
               parser_process_outputs
               parser_rm_file_ext
               parser_set_parser
              );

use vars    qw($NUL
               $CONFIG
               $SW_VERSION
               $PARSER
               $PARSER_LOGFILE
               %PARSER_CONFIG
               $PARSER_XML_CONFIG
               %MSC_PARSER_EVENTS
               %MONTHS
               @lines
               $debug
              );

use strict;
use lib ('parsers');
use lib ('parsers/lib');
use lib ('common/lib');
#use diagnostics;
use Getopt::Std;
use Data::Dumper;
use Fcntl qw(:DEFAULT :flock);
use XML::Simple;
use File::Basename;
use File::Spec;

$debug    = 0;

=head1 GLOBALS

These are global variables accessible to the test scripts

=cut


%MONTHS   = ( 'Jan'=>1,
              'Feb'=>2,
              'Mar'=>3,
              'Apr'=>4,
              'May'=>5,
              'Jun'=>6,
              'Jul'=>7,
              'Aug'=>8,
              'Sep'=>9,
              'Oct'=>10,
              'Nov'=>11,
              'Dec'=>12 );


=item $PARSER_XML_CONFIG

This hash contains the configuration information read in from parser_config.xml

=cut

=item %PARSER_CONFIG

This hash contains the configuration information read in from parser_config.xml

=cut

BEGIN
{
    my $xmlfile = 'parser_config.xml';    # XML configuration filename

    print "\nStarting parser.pm\n";
    open( XMLFILE, "<$xmlfile" ) or die( "Could not open XML file: $xmlfile : $!\n" );
    print("...Loading XML configuration file $xmlfile ...\n");

    # polite notification of reading xml file
    flock( XMLFILE, LOCK_SH );

    # Load XML config file into global hash
    my $tmp_xml_config = XMLin( $xmlfile,
                                forcearray => [qw(parser output output_type file)] );

    # check XML file in
    $PARSER_XML_CONFIG = eval{$tmp_xml_config};
    if( $@ )
    {
        print( "\n\nError in XML Config File $xmlfile : $@" );
        die;
    }
    else
    {
        print( "\n\nRead in the XML file $xmlfile OK\n" ) if $debug;
    }

    print Dumper($PARSER_XML_CONFIG) if $debug;

    close( XMLFILE );

    return 1;
}

=head1 FUNCTIONS

=cut

=head2 parser_open_file(FILE)

Opens the original logfile and performs any preprocessing necessary. The resulting file is written into

=item Returns:

Populates @tmp_lines

=cut

sub parser_open_file($)
{
    my $logfile = shift;
    print "...Opening Log File\n";
    open LOGFILE, "$logfile" or die "Could not open $logfile for reading: $!\n";
    my @tmp_lines = <LOGFILE>;
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

=head2 parser_format_timestamp(YEAR, MONTH, DAY, HOURS, MINS, SECS,MSECS)

Standard Timestamp formatter.

=item Returns:

Scalar timestamps in ISO format yyyy-mm-dd hh:mm:ss.sss

=cut

sub parser_format_timestamp($$$$$$$)
{
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d.%03d", @_);
}


=head2 parser_set_parser (PARSER)

This configures the global variable PARSER. This allows the common functions to pick up parser-specific functionality e.g. config.xml files,
and select parser specific entries from $PARSER_XML_CONFIG / parser_config.xml.

=item Parameters:

B<PARSER> - name of a standard parser. This must be defined in the parser_config.xml file.

=back

=cut

sub parser_set_parser($)
{
    $PARSER = shift;
    die "Unknown parser: $PARSER" unless exists $PARSER_XML_CONFIG->{'parser'}->{$PARSER};
    %PARSER_CONFIG = %{$PARSER_XML_CONFIG->{'parser'}->{$PARSER}};
    $PARSER_CONFIG{'name'} = $PARSER;

    print Dumper \%PARSER_CONFIG if $debug;
}


=head2 parser_get_parsers ()

Returns a list of parsers from the parser_config.xml file.

=cut

sub parser_get_parsers
{
    my @parsers = @_;

    die "Parser Configuration not loaded" unless defined {$PARSER_XML_CONFIG->{'parser'}};

    @parsers = keys %{$PARSER_XML_CONFIG->{'parser'}};
}



=head2 parser_rm_file_ext (LOGEXT, LOGFILE)

This removes the current extension from the file and returns the truncated result

=item Parameters:

B<LOGEXT> -log extension to be removed.

B<LOGFILE> - file which explains how the XML data can be transformed

=back

=end

=item Returns:

name with the extension stripped off.

=cut

sub parser_rm_file_ext($$)
{
    my $logext = shift;
    my $file   = shift;

    my $noext  = basename($file);
    $noext = $1 if ($noext =~ /^(.+)\.[^\.]*$/);
    $noext = dirname($file)."/$noext\.";
    print "File $file is now        :$noext\n" if $debug;
    return $noext;
}

=head2 parser_gen_tagged_log (INFILE)

This converts the input log file to an html version with anchors on each line.
This allows hyperlinks from external documents to a specific line number in the original log.

The hyperlink will take the form: <file>.html#L<<line#>>

=item Parameters:

B<INFILE> - text file to be converted to html.

=cut

sub parser_gen_tagged_log($$)
{
    my $infile = shift;
    my $outpath = shift;
    print "Opening: $infile\n";
    open( INFILE, $infile ) or die "Could not open $infile for reading: $!\n";
    my @input = <INFILE>;
    close( INFILE );
    
    my $infilename = basename($infile);
    my $outfile = $outpath."/".$infilename .".html";
    
    print "Creating tagged file: $outfile\n";

    open( OUTFILE,">$outfile" ) or die "Could not open $outfile for writing: $!\n";
    print OUTFILE '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">';
    print OUTFILE "\n<HTML><HEAD>\n";
    print OUTFILE '<meta http-equiv="Content-Type" content="text/html; charset=utf-8">';
    print OUTFILE "\n<TITLE>$infile</TITLE>\n";
    print OUTFILE '</HEAD><BODY LINK="FF0000" VLINK="FF0000">';
    print OUTFILE "\n<B><I>$infile</I></B>\n<P><PRE>\n";

    my $line=1;
    my $text;
    foreach $text (@input)
    {
        chomp $text;
        # convert HTML tags so that they can be displayed on a HTML page
        $text =~ s/&/&amp;/g;
        $text =~ s/\</&lt;/g;
        $text =~ s/\>/&gt;/g;
        my $outline = sprintf("<A NAME=\"L%d\"/><FONT COLOR=\"D0D0D0\">%05d:</FONT> %s\n", $line, $line, $text);
        print OUTFILE $outline;
        $line++;
    }

    print OUTFILE "</PRE></BODY></HTML>\n";
    close( OUTFILE );
}


=head2 parser_conv_xml_via_xsl (XMLFILE, XSLFILE, EXT, INDEX, PARAMS)

This takes the provided input XML file, applies the provided XSL file and writes the output to a file with the supplied Extension.

At present there are two implementations supported:

Using msxsl.exe which is slower, but provides debug output. This also allows the use of passing parameters into XSL file.

Using Win32::OLE APIs is quicker as the XML file is only loaded once

The code will chose the appropriate one to make the overall execution time as quick as possible.

=item Parameters:

B<XMLFILE> - XML file containing the data to be translated

B<XSLFILE> - file which explains how the XML data can be transformed

B<EXT> - Extension to be used for the destination file to be used in place of the source files XML extension.

B<INDEX> - Index which is used to set the output file name accordingly, where the same xsl input file is used (e.g. when splitting a log)

B<PARAMS> - Input parameters which need to be passed into the XSL parser.

=back

=cut

my $doc_to_transform;
my $cmdmsxsl = 0;   # 0 is to use OLE approach, 1 is to use command line
sub parser_conv_xml_via_xsl($$$$$)
{
    my ($xmlfilein, $xslfilein, $extin, $index, $params) = @_;
    return unless -f $xmlfilein;
    print "\nXML File : $xmlfilein\nXSL File : $xslfilein\nExtIn    : $extin\n";
    print "Index    : $index\n" if defined $index;
    print "Params   : $params\n" if defined $params;

    my $outfile = parser_rm_file_ext("xml", $xmlfilein).$extin;
    $outfile = parser_rm_file_ext("xml", $xmlfilein).$index."_$extin" if defined $index;
    print "Output   : $outfile\n";


    if( $cmdmsxsl == 0 )
    {
        # @todo temporary workaround
        if( -f 'C:\WINDOWS\system32\msxml6.dll' )
        {
            print "...Using msxml dll version 6.0\n" if $debug;
        }
        else
        {
            $cmdmsxsl = 1;  # we can't use WIN32 OLE revert to cmd line
            print "...Using command line msxsl.exe, please upgrade to msxml 6.0 dll\n" if $debug;
        }
    }

    if( defined $params or $cmdmsxsl )
    {
        #print "...Using msxsl\n";
        my $msxsl = "msxsl.exe";
        my $cmd = "$msxsl \"$xmlfilein\" $xslfilein -o \"$outfile\" $params";
        print "Cmd: $cmd\n" if $debug;
        print qx($cmd);
    }
    else
    {
        #print "...Using Win32::OLE\n";

        my $xmldoctype = 'MSXML2.DOMDocument.6.0';
        my $xsldoctype = 'MSXML2.DOMDocument.6.0';
        my $boolean_Load;

        if( !defined $doc_to_transform )
        {
            # Load the document
            $doc_to_transform = Win32::OLE->new($xmldoctype);
            $doc_to_transform->{async} = "False";
            $doc_to_transform->{validateOnParse} = "True";
            $doc_to_transform->{resolveExternals} = "True";
            $boolean_Load = $doc_to_transform->Load("$xmlfilein");

            if( $doc_to_transform->parseError()->{errorCode} != 0 )
            {
                print("XML Parse Error (not syntactically valid)\n");
                my $error = $doc_to_transform->parseError();
                print("Error ", $error, "\n");
            }

            if( !$boolean_Load )
            {
                # The error message includes file name, line #, position #, and reason.
                print("error at line ".$doc_to_transform->{parseError}->{line}." position ".$doc_to_transform->{parseError}->{linePos}." reason ".$doc_to_transform->{parseError}->{reason});
            }
            die "Failed to load XML File: $xmlfilein\n" unless $boolean_Load;
        }

        # Load the Stylesheet - just like above
        my $style_sheet_doc = Win32::OLE->new($xsldoctype);
        $style_sheet_doc->{async} = "False";
        $style_sheet_doc->{validateOnParse} = "True";
        $style_sheet_doc->{resolveExternals} = "True";
        $boolean_Load = $style_sheet_doc->Load($xslfilein);

        if( $style_sheet_doc->{parseError}->{errorCode} != 0 )
        {
            print("XSL Parse Error : " +  $style_sheet_doc->{parseError}->{errorCode}+ " : " + $style_sheet_doc->{parseError}->{reason} + "\n");
        }
        die "Failed to load XSL File: $xslfilein" unless $boolean_Load;

        # Perform the transformation and save the resulting DOM object
        my $output;
        eval
        {
            $output = $doc_to_transform->transformNode($style_sheet_doc);
        };

        if( $@ )
        {
            print Dumper $@;
            print "Transformation error : " + $@->getErrorMessage() + "\n";
            die;
        }

        $output =~ s/UTF-16/UTF-8/i if $outfile =~ /\.svg/;    # MSXML ignores the Encoding type in the xsl file and hard-codes to UTF-16
                                                               # This breaks the output for the SVG format.
        open( XMLOUT, ">$outfile" ) or die "Could not open $outfile for writing: $!\n";
        print XMLOUT $output;
        close( XMLOUT );
    }
}

=head2 parser_conv_xml_via_xsl_xsltproc (XMLFILE, XSLFILE, EXT, INDEX, PARAMS)

This takes the provided input XML file, applies the provided XSL file and writes the output to a file with the supplied Extension.

At present there are two implementations supported:

Using msxsl.exe which is slower, but provides debug output. This also allows the use of passing parameters into XSL file.

Using Win32::OLE APIs is quicker as the XML file is only loaded once

The code will chose the appropriate one to make the overall execution time as quick as possible.

=item Parameters:

B<XMLFILE> - XML file containing the data to be translated

B<XSLFILE> - file which explains how the XML data can be transformed

B<EXT> - Extension to be used for the destination file to be used in place of the source files XML extension.

B<INDEX> - Index which is used to set the output file name accordingly, where the same xsl input file is used (e.g. when splitting a log)

B<PARAMS> - Input parameters which need to be passed into the XSL parser.

=back

=cut
sub parser_conv_xml_via_xsl_xsltproc($$$$$)
{
    my ($xmlfilein, $xslfilein, $outfile, $index, $params) = @_;
    return unless -f $xmlfilein;
#    print "\nXML File : $xmlfilein\nXSL File : $xslfilein\nOutfile    : $outfile\n";
#    print "Index    : $index\n" if defined $index;
#    print "Params   : $params\n" if defined $params;

    my $xslproc = "xsltproc";
    my $cmd = "$xslproc -o  \"$outfile\"";

    if (defined $index)
    {
        $cmd = "$cmd --param index $index";
    }

    $cmd = "$cmd \"$xslfilein\" \"$xmlfilein\"";

    print "Cmd: $cmd\n" if $debug;
    print qx($cmd);
}


=head2 parser_conv_xml_via_xsl (XMLFILE, XSLFILE, EXT, INDEX, PARAMS)

This takes the provided input XML file, applies the provided XSL file and writes the output to a file with the supplied Extension.

At present there are two implementations supported:

Using msxsl.exe which is slower, but provides debug output. This also allows the use of passing parameters into XSL file.

Using Win32::OLE APIs is quicker as the XML file is only loaded once

The code will chose the appropriate one to make the overall execution time as quick as possible.

=item Parameters:

B<XMLFILE> - XML file containing the data to be translated

B<XSLFILE> - file which explains how the XML data can be transformed

B<EXT> - Extension to be used for the destination file to be used in place of the source files XML extension.

B<INDEX> - Index which is used to set the output file name accordingly, where the same xsl input file is used (e.g. when splitting a log)

B<PARAMS> - Input parameters which need to be passed into the XSL parser.

=back

=cut

sub parser_conv_xml_via_xsl($$$$$)
{
    my ($xmlfilein, $xslfilein, $outfile, $index, $params) = @_;
    return unless -f $xmlfilein;
    print "\nXML File : $xmlfilein\nXSL File : $xslfilein\nOutfile    : $outfile\n";
    print "Index    : $index\n" if defined $index;
    print "Params   : $params\n" if defined $params;

	if ($^O =~ /MSWin32/ )
	{
		parser_conv_xml_via_xsl_msxsl($xmlfilein, $xslfilein, $outfile, $index, $params);
	}
	else
	{
		parser_conv_xml_via_xsl_xsltproc($xmlfilein, $xslfilein, $outfile, $index, $params);
	}
}



=head2 parser_get_num_splits (XMLFILE)

This loads the XML file if it has not been done before and determines the number of splits in the log.

=item Parameters:

B<XMLFILE> is the standard formatted event XML file.

=item Returns:

Scalar number of splits in the log.

=cut

my $xml_hash;
sub parser_get_num_splits($)
{
    my $xmlfile = shift;
    # Load XML config file into global hash
    $xml_hash = XMLin( $xmlfile,
                       KeyAttr => 'line',
                       forcearray => [qw(events)] ) unless defined $xml_hash;
    #print Dumper $xml_hash;
    my $num_splits = 0;
    $num_splits = $xml_hash->{'num_splits'} if exists($xml_hash->{'num_splits'});

    return $num_splits;
}

sub parser_format_output_node($$$)
{
    my ($id, $title, $url) = @_;
    return "<output id=\"$id\" title=\"$title\" url=\"$url\"/>\n";
}

my $id = 0;


sub parser_process_outputs($$@) {
   my ($logfile, $num_splits, @outputs) = @_;
   my $url;
   my $retstr;

   foreach my $output (@outputs)
   {
       # We only mark the output for title entries
       next unless exists $output->{'title'};

       my $ext = $output->{'ext'};
       my $title = $output->{'title'};
       my $url = basename(parser_rm_file_ext(undef, $logfile));
       # Has this output format been split.
       if( exists $output->{'split'} )
       {
           my $loop_idx = 0;#Set up a loop over all the entries.
           while( $loop_idx < $num_splits )
           {
               my $split_url   = $url.$loop_idx."_$ext";
               my $split_title = "$title - page $loop_idx";
               $retstr .= parser_format_output_node($id,$split_title, $split_url);
               $loop_idx++;
               $id++;
           }
       }
       else
       {
           $url .= $ext;
           $retstr .= parser_format_output_node($id,$title, $url);
           $id++;
       }
   }

   return $retstr;
}

sub parser_build_output_xml($)
{
    my $logfile = shift;

    # Build the output data for the output info.
    my $retstr .= "<outputs>\n";
    my $xmlfile = basename(parser_rm_file_ext(undef, $logfile)."xml");

    if( exists $PARSER_CONFIG{'output_type'} )
    {
        my $output_type = $PARSER_CONFIG{'output_type'};

        if (exists $PARSER_XML_CONFIG->{'output_type'}->{$output_type})
        {
            $retstr .= parser_process_outputs($logfile, 0, @{$PARSER_XML_CONFIG->{'output_type'}->{$output_type}->{'output'}});
        }
        else
        {
            print "Could not find output_type: $output_type config\n";
        }
    }
    else
    {
        print "No output_type configured\n" if defined $debug;
    }

    $retstr .= parser_process_outputs($logfile, 0, @{$PARSER_CONFIG{'output'}} ) if exists($PARSER_CONFIG{'output'});

    # Add the Original XML File
    my $url  = $xmlfile;
    $retstr .= parser_format_output_node($id, "XML", $url);
    $id++;

    # Add the Original XML File
    $url     = basename("$logfile.html");
    $retstr .= parser_format_output_node($id, "Log", $url);

    $retstr .= "</outputs>\n";
    # Build data re:

    # print Dumper \%nodes;
    #print $retstr;
    return $retstr
}

# info is an optional parameter
sub parser_gen_hdr_xml($$;$)
{
    my $logfile = shift;
    my $num_splits = shift;
    my $info    = shift;
    my $logname = basename($logfile);
    my $lognamestub = parser_rm_file_ext(undef,$logname);
    my $logdir  = dirname($logfile);
    my $out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    $out .= "<!-- $PARSER Log Parser output -->\n";
    $out .= "<!-- Written by Donald Jones   -->\n";
    my $login = getlogin || getpwuid($<) || "Kilroy";

    $_ = `date /T`;
    print "Date: $_\n";
    chomp;
    $_ =~ s/[^0-9|-]//g;   # Need to remove non-numeric characters to make this work for China.
    my $pc_date = $_;
    print "PC Date: $pc_date\n";

    $_ = `time /T`;
    chomp;
    #$_ =~ s/[^0-9|-]//g;   # Need to remove non-numeric characters to make this work for China.
    my $pc_time = $_;

    $out .= "<eventlist name=\"$logfile\" logname=\"$logname\" lognamestub=\"$lognamestub\" logdir=\"$logdir\" parser=\"$PARSER\" login=\"$login\" num_splits=\"$num_splits\"";
    $out .= " info=\"$info\"" if( defined($info) );
    $out .= " date=\"$pc_date\" time=\"$pc_time\">\n";    # combine date and time
    return $out;
}

# info is an optional parameter
sub parser_gen_hdr_json($$)
{
    my $logfile = shift;
    my $info    = shift;
    my $logname = basename($logfile);
    my $lognamestub = parser_rm_file_ext(undef,$logname);
    my $logdir  = dirname($logfile);
    my $out = "{\n";
    $out .= "  \"_comment\": \"$PARSER Log Parser output. Written by Donald Jones\",\n";
    my $login = getlogin || getpwuid($<) || "Kilroy";

    $_ = `date `;
    print "Date: $_\n";
    chomp;
    my $pc_date = $_;
    print "PC Date: $pc_date\n";

    $out .= "  \"meta_data\": {\n";
    $out .= "    \"logfile\": \"$logfile\",\n";
    $out .= "    \"parser\": \"$PARSER\",\n";
    $out .= "    \"date\": \"$pc_date\"\n";
#     $out .= "    \"time\": \"$pc_time\",\n";
    #$out .= ",\n    \"info\": \"$info\",\n" if (defined($info));
    $out .= "  },\n";
    return $out;
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

For an example of the use of parser see B<parser.pl>

=head1 CREDITS

Donald Jones <donald.starquality@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2006-7 Donald Jones. All rights reserved.

=cut

