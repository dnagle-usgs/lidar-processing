#!/usr/bin/perl -w

# $Id$
# Original: David Nagle 2008-07-17

use strict;
use warnings;

use File::Finder;
use File::Spec;
use File::Util;
use List::MoreUtils qw/uniq/;

my $help = <<END;
Usage: make_html_tiles.pl template token source destination

This script will generate HTML files for overview image files. The arguments
required are:

   template       The full path and file name for the html template to use.
   token          The name of the tile used in the template file.
   source         The directory containing the images that need to have html
                  files made.
   destination    The destination directory for the html files.

An example invocation:

   make_html_tiles.pl /data/dvd/html/template_29084e8b.html 29084e8b \\
      /data/dvd/html/images/jpeg_tiles/ /data/dvd/html/tile_htmls/

The above invocation does the following:

   - Reads the template file template_29084e8b.html into memory.
   - Analyses the token 29084e8b and determines that it's a quarter quad token.
   - Scans /data/dvd/html/images/jpeg_tiles/ and generates a list of all
     quarter quad tokens found in the file names.
   - Generates html files in /data/dvd/html/tile_htmls/ for each quad found;
     the contents will be the same as the template file, but the token will be
     replaced by that quad's name.

This should work with the following three naming schemes:

   - Quarted quads such as 29084e8b
   - Long 2k tile names such as t_e366000_n420000_18
   - Short 2k tile names such as e366_n4120_18 or e366_n4120_z18
END

if($#ARGV != 3) {
   print "Requires 4 arguments: template token source destination\n\n$help";
   exit 1;
}

my $template   = $ARGV[0];
my $token      = $ARGV[1];
my $src_dir    = $ARGV[2];
my $dest_dir   = $ARGV[3];

if(! (-e $template && -f $template)) {
   print "Template file $template does not exist or is not a regular file.\n\n$help";
   exit 1;
}

if(! (-e $src_dir && -d $src_dir)) {
   print "Source directory $src_dir does not exist or is not a directory.\n\n$help";
   exit 1;
}

if(! (-e $dest_dir && -d $dest_dir)) {
   print "Destination directory $dest_dir does not exist or is not a directory. Please create it before running this script.\n\n$help";
   exit 1;
}

my @patterns = grep { $token =~ /$_/ } map { qr/$_/ } (
   '(^|_)(\d\d\d\d\d[a-h][1-8][a-d])(\.|_|$)',
   '(^|_)(e\d\d\d_n\d\d\d\d_z?\d\d)(\.|_|$)',
   '(^|_)(e\d\d\d000_n\d\d\d\d000_\d\d)(\.|_|$)',
);
if($#patterns > 0) {
   print "Token parses to match more than one type\n\n$help";
   exit 1;
} elsif($#patterns != 0) {
   print "Unable to parse token to determine type\n\n$help";
   exit 1;
}
my $pattern = $patterns[0];

print "Generating HTML files.\n";
print "\n";
print "Parameters:\n";
print "  Template:               $template\n";
print "  Token:                  $token\n";
print "  Source directory:       $src_dir\n";
print "  Destination directory:  $dest_dir\n";
print "\n";
print "Token's pattern: $pattern\n";
print "\n";

my @files = File::Finder->type('f')->in($src_dir);

if(! scalar @files) {
   print "Error: No files found in source directory. Aborting.\n";
   exit 1;
}

my @tiles = uniq sort map { /$pattern/; $2 } grep { /$pattern/ } @files;

my $total = scalar @tiles;
if(! scalar @tiles) {
   print "Error: No files matched the same pattern as the given token. Aborting.\n";
   exit 1;
}

my $f = File::Util->new();
my $template_content = $f->load_file($template);
my $current = 0;
print "Processing tokens found.\n";
foreach my $tile (@tiles) {
   $current++;
   print "$current/$total - $tile\n";
   my $dest = File::Spec->catfile($dest_dir, "$tile.html");
   my $content = $template_content;
   $content =~ s/$pattern/$1$tile$3/g;
   $f->write_file(
      file => File::Spec->catfile($dest_dir, "$tile.html"),
      content => $content,
   );
}

print "\n";
print "Processing complete.\n";

