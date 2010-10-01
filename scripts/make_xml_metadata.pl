#!/usr/bin/perl -w

# Original: David Nagle 2008-05-30

use strict;
use warnings;

use XML::LibXML;
use Geo::Coordinates::UTM;
use List::Util qw/min max/;
use List::MoreUtils qw/uniq/;
use File::Spec;
use File::Finder;

my $help = <<END;
Usage: make_xml_metadata.pl ellipsoid template pattern path

This script will generate XML metadata files for data files. The arguments
required are:

   ellipsoid   This should be one of n88, n83, or w84.
   template    This should be the path and filename to the template to be used.
   pattern     This should be a search pattern and MUST be in single quotes,
               for example, '*.tif'. It is also case-sensitive.
   path        This should be the path to the data directory containing the
               files to be processed.

An example invocation:

   make_xml_metadata.pl n88 ~/BE_metadata_temp.xml '*.TIF' /data/0/IVAN_DVD/

The above invocation does the following:

   - Assumes the data is in the NAVD-88 ellipsoid.
   - Reads the template located at ~/BE_metadata_temp.xml.
   - Finds all files matching '*.TIF' underneath /data/0/IVAN_DVD/.
   - Generates XML files for all files found.

The file finding works recursively, so it will look through subdirectories as
well.
END


my $parser = XML::LibXML->new();
my $ellip = undef;

if($#ARGV != 3) {
   print "Requires four args: ellipsoid template pattern path\n\n$help";
   exit 1;
}

# Ellipsoid should be something like n88, n83, navd88, NAD-83, w84, WGS-84

my $ellipsoid = $ARGV[0];
my $template  = $ARGV[1];
my $pattern   = $ARGV[2];
my $path      = $ARGV[3];

if($ellipsoid =~ /^(n(av?d)?-?8[83]|grs-?(19)?80)$/i) {
   $ellip = 'GRS 1980';
} elsif($ellipsoid =~ /^w(gs)?84$/i) {
   $ellip = 'WGS-84';
} else {
   print "Unknown ellipsoid: $ellipsoid\n\n$help";
   exit 1;
}

if(! (-e $template && -f $template) ) {
   print "Template file $template does not exist or is not a regular file.\n\n$help";
   exit 1;
}

if(! (-e $path && -d $path) ) {
   print "Search path does not exist or is not a directory:\n";
   print "  $path\n\n$help";
   exit 1;
}

print "Generating metadata XML files.\n";
print "\n";
print "Parameters:\n";
print "  Ellipsoid:   $ellipsoid ($ellip)\n";
print "  Template:    $template\n";
print "  Search glob: $pattern\n";
print "  Search path: $path\n";
print "\n";

my @files = File::Finder->name($pattern)->in($path);
my $total = scalar @files;

if(!$total) {
   print "Error: No files found. Aborting.\n";
   exit 1;
}

print "Processing $total files:\n";

my $current = 0;
my $status;
foreach my $file (@files) {
   $current++;
   print "$current/$total - " . (File::Spec->splitpath($file))[2] . "\n";
   $status = apply_template($template, $file);
}

print "\n";
print "Processing complete.\n";

my @missing = sort grep { ! $status->{$_} } keys %$status;
my @present = sort grep { $status->{$_} } keys %$status;

if (scalar @present) {
   print "\n";
   print "The nodes with the following paths were found and updated:\n";
   foreach my $node (sort @present) {
      print "  $node\n";
   }
}

if (scalar @missing) {
   print "\n";
   print "The nodes with the following paths were not found in the template:\n";
   foreach my $node (sort @missing) {
      print "  $node\n";
   }
}


##### SUBROUTINES #####

# setnode($node, $status, $tags, $text)
#   $node - a LibXML node, usually the document tree
#   $status - a reference to a hash of tag statuses
#   $tags - either a scalar or array ref of tags to find
#   $text - the replacement text for the final tag in $tags
# This searches through the tree referred to by $node by finding the $tags as
# nodes within it; each successive tag must be a descendent node of the prior.
# The final node's textual content will be replaced by $text.
sub setnode {
   my $node = shift;
   my $status = shift;
   my $tags = shift;
   my $text = shift;
   my @tags;

   eval {
      if(ref($tags) eq "ARRAY") {
         @tags = @$tags;
      } else {
         @tags = ( $tags );
      }

      foreach my $tag (@tags) {
         $node = $node->getElementsByTagName($tag)->[0];
      }
      $node->childNodes->[0]->setData($text);
   };

   if ($@) {
      $status->{join("->", '(doc)', @tags)} = 0;
   } else {
      $status->{join("->", '(doc)', @tags)} = 1;
   }
}

# dropnode($node, $status, $tags)
#   $node - a LibXML node, usually the document tree
#   $status - a reference to a hash of tag statuses
#   $tags - either a scalar or array ref of tags to find
# This searches through the tree referred to by $node by finding the $tags as
# nodes within it; each successive tag must be a descendent node of the prior.
# The final node will be pruned from the tree.
sub dropnode {
   my $node = shift;
   my $status = shift;
   my $tags = shift;
   my @tags;

   eval {
      if(ref($tags) eq "ARRAY") {
         @tags = @$tags;
      } else {
         @tags = ( $tags );
      }

      foreach my $tag (@tags) {
         $node = $node->getElementsByTagName($tag)->[0];
      }
      $node->unbindNode();
   };

   if ($@) {
      $status->{join("->", '(doc)', @tags)} = 0;
   } else {
      $status->{join("->", '(doc)', @tags)} = 1;
   }
}

# ($ll, $utm) = file2coords($file)
#   $file - the filename (without path)
#   $ll   - lat/lon bounding box coords as [$south, $east, $north, $west]
#           will return undef if not parseable
#   $utm  - utm bounding box coords as [$south, $east, $north, $west, $zone]
#           will return undef if not parseable
# This pulls out the lat/lon and utm coords from a file's name.
sub file2coords {
   my $file = shift;
   my $kind = whatkind($file);
   my($ll, $utm);
   if($kind eq 'QQ') {
      $ll = qq2ll($file);
      $utm = ll2utm($ll);
   } elsif($kind eq 'KT') {
      $utm = kt2utm($file);
      $ll = utm2ll($utm);
   } else {
      $ll = $utm = undef;
   }
   return ($ll, $utm);
}

# $kind = whatkind($file)
#   $file - the filename (without path)
#   $kind - 'QQ' for quarter quad, 'KT' for 2-km tile, '' otherwise
# Figures out whether a filename encodes the position in QQ or KT format
sub whatkind {
   my $file = shift;
   my $qq = 1 & $file =~ /\d\d\d\d\d[a-h][1-8][a-d]/;
   my $kts = 1 & $file =~ /_e\d\d\d000_n\d\d\d\d000_\d\d[a-zA-Z]?(\.|_)/;
   my $ktl = 1 & $file =~ /(^|_)e\d\d\d_n\d\d\d\d_z?\d\d[a-zA-Z]?(\.|_)/;
   my $kt = $kts || $ktl;
   if($qq == $kt) {
      print " !! Unable to parse $file to determine QQ versus 2k tile\n";
      print "    Skipping $file\n";
      return '';
   } else {
      return $qq ? 'QQ' : 'KT';
   }
}

# $ll = qq2ll($file)
#    $file - the filename (without path)
#    $ll   - lat/lon bounding box coords as [$south, $east, $north, $west]
# Converts a quarter-quad filename into its bounding coordinates in lat/lon
# Fatal error if the passed filename isn't parseable as QQ
sub qq2ll {
   my $qq = shift;
   die("invalid QQ") unless($qq =~ /(\d\d)(\d\d\d)([a-h])([1-8])([a-d])/);
   my $lat = $1;
   my $lon = $2;
   my $a = $3;
   my $o = $4;
   my $q = $5;

   $lat += index("abcdefgh", $a) * 0.125;
   $lon += ($o - 1) * 0.125;

   $q = index("abcd", $q) + 1;
   $lat += ($q == 2 || $q == 3) * 0.0625;
   $lon += ($q >= 3) * 0.0625;

   return [$lat, $lon * -1, $lat + 0.0625, ($lon + 0.0625) * -1];
}

# $utm = kt2utm($file)
#    $file - the filename (without path)
#    $utm  - utm bounding box coords as [$south, $east, $north, $west, $zone]
# Converts a 2km tile filename into its bounding coordinates in utm
# Fatal error if the passed filename isn't parseable as a 2km tile
sub kt2utm {
   my $kt = shift;
   die("invalid 2km") unless ($kt =~ /(^|_)e(\d\d\d)(000)?_n(\d\d\d\d)(000)?_z?(\d\d)[a-zA-Z]?(\.|_)/);
   my $east = $2 * 1000;
   my $north = $4 * 1000;
   my $zone = $6;
   my $offset = 2000;
   $offset = 10000 if($kt =~ /^i_/);
   return [$north - $offset, $east, $north, $east + $offset, $zone];
}

# $utm = ll2utm($ll)
#    $ll  - lat/lon bounding box coords as [$south, $east, $north, $west]
#    $utm - utm bounding box coords as [$south, $east, $north, $west, $zone]
# Converts a lat/lon bounding box into a utm bounding box
sub ll2utm {
   my $ll = shift;
   my $force = shift;
   my ($south, $east, $north, $west) = @$ll;
   my (@zone, @easting, @northing);
   my ($z, $e, $n);
   foreach my $lat ($north, $south) {
      foreach my $lon ($east, $west) {
         if($force) {
            ($z, $e, $n) = latlon_to_utm_force_zone($ellip, $force, $lat, $lon);
         } else {
            ($z, $e, $n) = latlon_to_utm($ellip, $lat, $lon);
         }
         push @zone, $z;
         push @easting, $e;
         push @northing, $n;
      }
   }
   my $zz = uniq map { s/[A-Za-z]// } @zone;
   if($zz == 1) {
      return [min(@northing), min(@easting), max(@northing), max(@easting), $zone[0]];
   } else {
      my @zz = apply { s/[A-Za-z]// } @zone;
      my @zl = uniq @zz;
      my @zc = apply { my $zll = $_; true { $zll eq $_ } @zz } @zl;
      my $idx = firstidx { max(@zc) == $_ } @zc;
      return ll2utm($ll, $zl[$idx]);
   }
}

# $ll = utm2ll($utm)
#    $utm - utm bounding box coords as [$south, $east, $north, $west, $zone]
#    $ll  - lat/lon bounding box coords as [$south, $east, $north, $west]
# Converts a utm bounding box into a lat/lon bounding box
sub utm2ll {
   my $utm = shift;
   my ($south, $east, $north, $west, $zone) = @$utm;
   my (@lat, @lon);
   my ($la, $lo);
   foreach my $northing ($north, $south) {
      foreach my $easting ($east, $west) {
         ($la, $lo) = utm_to_latlon($ellip, $zone . 'X', $easting, $northing);
         push @lat, $la;
         push @lon, $lo;
      }
   }
   return [min(@lat), min(@lon), max(@lat), max(@lon)];
}

# format_number($number)
#   $number - the number to format properly
# Given a number, this will reformat it to be FGDC and mp complaint.
# For example, this:
#   763374.700047304
# Will become:
#   7.63374700047304 E+5
sub format_number {
   my $number = shift;

   my $length = length($number) - 2;

   $number = sprintf("%.${length}E", $number);
   $number =~ s/E/ E/;
   $number =~ s/\+0/+/;

   return $number;
}

# apply_template($template, $file)
#   $template - full path and file name to an XML template file
#   $file     - full path and file name to a file to create metadata for
# Given the above info, this creates an XML metadata file for a data file. The
# metadata file will be named by appending '.xml' to $file.
# It returns a reference to a hash of tag statuses.
sub apply_template {
   my $template = shift;
   my $file = shift;
   
   my $filename = (File::Spec->splitpath($file))[2];
   my ($ll, $utm) = file2coords($filename);
   return if(!defined($ll));

   my $doc = $parser->parse_file($template);
   my $status = {};

   # Filename
   setnode($doc, $status, [qw/citation ftname/], $filename);
   setnode($doc, $status, [qw/dataIdInfo resTitle/], $filename);

   # UTM
   setnode($doc, $status, [qw/gridsys utm utmzone/], $utm->[4]);
   setnode($doc, $status, [qw/refSysInfo identCode/], 'NAD_1983_UTM_Zone_' . $utm->[4]);

   setnode($doc, $status, [qw/spdom bounding southbc/], format_number($utm->[0]));
   setnode($doc, $status, [qw/spdom bounding westbc/ ], format_number($utm->[1]));
   setnode($doc, $status, [qw/spdom bounding northbc/], format_number($utm->[2]));
   setnode($doc, $status, [qw/spdom bounding eastbc/ ], format_number($utm->[3]));

   # The following are all commented out because they're no longer in use:

   setnode($doc, $status, [qw/spdom lboundng bottombc/], format_number($utm->[0]));
   setnode($doc, $status, [qw/spdom lboundng leftbc/ ], format_number($utm->[1]));
   setnode($doc, $status, [qw/spdom lboundng topbc/   ], format_number($utm->[2]));
   setnode($doc, $status, [qw/spdom lboundng rightbc/  ], format_number($utm->[3]));

   setnode($doc, $status, [qw/dataIdInfo GeoBndBox southBL/], format_number($utm->[0]));
   setnode($doc, $status, [qw/dataIdInfo GeoBndBox westBL/ ], format_number($utm->[1]));
   setnode($doc, $status, [qw/dataIdInfo GeoBndBox northBL/], format_number($utm->[2]));
   setnode($doc, $status, [qw/dataIdInfo GeoBndBox eastBL/ ], format_number($utm->[3]));

   # Lat/lon
   setnode($doc, $status, [qw/dataIdInfo geoBox southBL/], format_number($ll->[0]));
   setnode($doc, $status, [qw/dataIdInfo geoBox westBL/ ], format_number($ll->[1]));
   setnode($doc, $status, [qw/dataIdInfo geoBox northBL/], format_number($ll->[2]));
   setnode($doc, $status, [qw/dataIdInfo geoBox eastBL/ ], format_number($ll->[3]));

   dropnode($doc, $status, [qw/distInfo onLineSrc/]);

   $doc->toFile("$file.xml", 0);

   return $status;
}
