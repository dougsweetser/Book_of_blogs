#!/usr/bin/perl -w
$|++;

#### Name:    lyx_2_blurb.pl
#### License: GPLv3
#### Program Description

my $help_string = <<HELP;
Merges all .lyx files together under this directory
in the order they are found on the file system

PRESUMES: Chapters and Indexes in EVERY file.

Usage: lyx_2_blurb.pl [-out book_of_blogs.lyx]

These 3 are merged:
p1_partname/c1_chater1.lyx
p1_partname/c2_chater2.lyx
p2_nextpart/c1_chapter.lyx

to create book_of_blogs.lyx
HELP

#### Modules

use strict;
use English;
use Getopt::Long;
   $Getopt::Long::autoabbrev = 1;
   $Getopt::Long::ignorecase = 0;

my $out       = "book_of_blogs.lyx";
my $list;
my $help;

# Three kinds of text: header, body, footer, 2 flags.
my $header = '';
my @lines;
my $footer = '';
my $header_flag;
my $footer_flag;
my $do_header_footer = 1;

__get_data();

my ($chapter, @chapters);

# Grab all lyx files below this directory.
@chapters = `find . -depth 2 -name "*.lyx" | grep -v template`;

foreach $chapter (@chapters) {

    # Report which chapter is getting worked on.
    print "$chapter";

    open(CHAPTER, "<$chapter") or die "Unable to open $chapter: $!";

    # Initially in the header, until the footer is found.
    $header_flag = 1;
    $footer_flag = 0;

    # Read in the chapter.
    while (<CHAPTER>) {

        my $line = $_;

        # Set flags.
        $header_flag = 0 if $line =~ /begin_layout Chapter/;

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


### Signals

exit(0);


#### Subroutines

### Get data, assign to variables.
sub __get_data {
    
    my $get = GetOptions(
            "out=s"      => \$out,
            "help!"      => \$help
        );

    die("Check options please.\nProgram exiting.\n") unless $get;
    
    if ($help) {
       print $help_string;
       exit(1);
    }
}
