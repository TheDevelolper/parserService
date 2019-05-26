def gen_tagged_file(infile, outpath)
    print "Opening: $infile\n";
    open( INFILE, $infile ) or die "Could not open $infile for reading: $!\n";
    my @input = <INFILE>;
    close( INFILE );
    
    my $infilename = basename($infile);
    my $outfile = $outpath.$infilename . ".html";
    
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