#!/usr/bin/perl -w
$|++;

#### Name:    lyx_2_blurb.pl
#### License: GPLv3
#### Program Description

my $help_string = <<HELP;
Merges all .lyx files together under this directory
in the order they are found on the file system

PRESUMES: Part/Chapter at start, and Indexes at the end
of EVERY file.

Usage: lyx_2_blurb.pl [-out book_of_blogs.lyx]
                      [-exclude this.lyx] [-ex that.lyx]
                      [-pdf]

These 3 are merged:

p1_partname/c1_chater1.lyx
p1_partname/c2_chater2.lyx
p2_nextpart/c1_chapter.lyx
but not this.lyx or that.lyx

to create book_of_blogs.lyx
The header/fooder of the first lyx file is used.

If -pdf is set, will make an xpdf v1.3 file for blurb.com
HELP

#### Modules

use strict;
use English;
use Getopt::Long;
   $Getopt::Long::autoabbrev = 1;
   $Getopt::Long::ignorecase = 0;
use FindBin qw($Bin);
use Test::More 'no_plan';

my $out;
my $out_default = "book.lyx";
my $out_tex;
my $out_pdf;
my $list;
my $help;
my $pdf;
my $lyx_cmd   = "/Applications/LyX.app/Contents/MacOS/lyx --export xetex";
my $xetex_cmd = qq(xelatex --output-driver="xdvidfmx -q -E -V 3");

# Three kinds of text: header, body, footer, 2 flags.
my $header = '';
my @lines;
my ($exclude, @excludes);
my $footer = '';
my $header_flag;
my $footer_flag;
my $do_header_footer = 1;

__get_data();

my ($chapter, @chapters);

# Grab all lyx files below this directory.
@chapters = `find . -depth 2 -name "*.lyx" | grep -v template`;

foreach $chapter (@chapters) {

    # Determine if chapter is to be skipped.
    foreach $exclude (@excludes) {
        if ($chapter =~ /$exclude/) {
            print STDERR "Excluding: $chapter\n";
            next();
        }
    }

    # Report which chapter is getting worked on.
    print STDOUT "Including: $chapter";

    open(CHAPTER, "<$chapter") or die "Unable to open $chapter: $!";

    # Initially in the header, until the footer is found.
    $header_flag = 1;
    $footer_flag = 0;

    # Read in the chapter.
    while (<CHAPTER>) {

        my $line = $_;

        # Set flags.
        $header_flag = 0 if $line =~ /begin_layout (Part|Chapter)/;

        if ($line =~ /index_print/) {
            $footer_flag = 1;

            # Remove the line before.
            pop @lines; 
        }

        # Act on the three sections of lyx text.
        if ($header_flag) {
            $header .= $line if $do_header_footer;
            next();
        }
        elsif ($footer_flag) {
            $footer .= $line if $do_header_footer;
            next();
        }
        else {
            push @lines, $line;
        }
    }

    # Only grab the header once.
    $do_header_footer = 0 if $header;

    close CHAPTER;
}

# Print the header, lines and footer.
open BOOK, ">$out" or die "Unable to open file $out: $!";

print BOOK $header;

foreach my $line (@lines) {
    print BOOK "$line";    
}

# Add back the line on the footer.
print BOOK '\begin_layout Standard' . "\n";
print BOOK $footer;

close BOOK;

if ($pdf) {
    my $command = qq($lyx_cmd $out);
    print STDOUT qq(running $command\n);
    system $command;

    $command = qq($xetex_cmd $out_tex);
    print STDOUT qq(running $command\n);
    system $command;

    system "open $out_pdf";
}

### Tests
ok (-s $out, "Checking $out has non zero size.");
#done_testing();

### Signals

exit(0);


#### Subroutines

### Get data, assign to variables.
sub __get_data {
    
    my $get = GetOptions(
            "exclude=s@" => \@excludes,
            "out=s"      => \$out,
            "pdf!"       => \$pdf,
            "help!"      => \$help
        );

    die("Check options please.\nProgram exiting.\n") unless $get;
    
    if ($help) {
       print $help_string;
       exit(1);
    }

    # Optional config files.
    my $excludes_option = 1 if @excludes;
    my $config_file;
    if (-e "$Bin/.merge_lyx_files") {
        $config_file = "$Bin/.merge_lyx_files";
    }
    elsif (-e "$ENV{HOME}/.merge_lyx_files") {
        $config_file = "$ENV{HOME}/.merge_lyx_files";
    }
    elsif (-e "/etc/merge_lyx_files") {
        $config_file = "/etc/merge_lyx_files";
    }
    if ($config_file) {

        open CONFIG, "<$config_file" 
            or die "Unable to open config file $config_file: $!";

        while (<CONFIG>) { 
            chomp;  # no newline 
            s/#.*//; # no comments 
            s/^\s+//; # no leading white 
            s/\s+$//; # no trailing white 
            next unless length; # anything left? 
            
            my ($var, $value) = split(/\s*=\s*/, $_, 2); 
            
            # Let the option trump config, if it exists.
            if ($var =~ /out/i) {
                $out = $value unless $out;
            }

            if (!$excludes_option and $var =~ /exc/i) {
                push @excludes, $value;
            }
        }
    }

    # Check the out file name for .lyx.
    die "The out file must end in .lyx.\nProgram exiting.\n"
        unless $out =~ /lyx$/;

    $out_tex = $out;
    $out_tex =~ s/lyx$/tex/;

    $out_pdf = $out;
    $out_pdf =~ s/lyx$/pdf/;

    print "out: $out\nexcludes: @excludes\n";
}
