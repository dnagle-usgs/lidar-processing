#!/usr/bin/perl -w
$Id = '$Id$';
$Source = '$Source$';

require 'newgetopt.pl' || die "Unable to require newgetopt.pl\n";

undef $opt_help;    # just to quiet the warning message

################ System defines #####################
$OS = $ENV{"OSTYPE"};

# printf("OS: %s\n", $OS);

$ZIP   = "/usr/bin/zip";

if ( $OS eq "darwin" ) {      # looks like OS X
  $GZCAT = "/usr/bin/gzcat";
  $BZCAT = "/usr/bin/bzcat";
} else {                      # must be linux
  $GZCAT = "/bin/zcat";
  $BZCAT = "/usr/bin/bzcat";
}

# cycle through N colors
@colors = (
  "800080ff",
  "ff0000ff",
  "ff00ff00",
  "ff00ffff",
  "ffff0000",
  "ffff00ff",
  "ffffff00",
  "ffffffff",
);

################ ############## #####################

sub showusage {
  print <<EOF;
# $Id
# $Source

$0 [-skip=N] [-elev=N] [-poles=N] file1 .... fileN

Reads *-pnav.txt* files and creates .kml files to show the flightline.

The input files can be plain text, or compressed using either gzip or bzip2.

The  output file is written into the current directory in the form: YYYYMMDD.kml

  "skip=i",   # skip records to reduce output file size            (default: $opt_skip)
  "elev=i",   # multiplier for elevation to make it more dramatic. (default: $opt_elev)
  "poles=i",  # [0|1] turn on drawing a line to the ground         (default: $opt_poles)
  "width=i",  # set line width                                     (default: $opt_width)
  "colndx=x", # set starting index into color table                (default: $opt_colndx)
  "kml",      # create kml files instead of kmz
  "keepname"  # use the source file name instead of autonaming

EOF

  exit(0);
}


sub get_cli_opts {
  &showusage unless
  &NGetOpt(
  "help",     # help
  "myint=i",
  "myfloat=f",
  "skip=i",   # skip records to make the output file smaller
  "elev=i",   # set a multiplier for the elevation to make it more dramatic.
  "poles=i",  # turn on drawing a line to the ground
  "width=i",  # set line width
  "colndx=i", # set starting index into color table
  "kml",      # create kml files instead of kmz
  "keepname", # use the source file instead of autonaming
  );
  &showusage() if defined($opt_help);
}

sub write_header {
  local($tfil, $oname) = @_;

  $opt_colndx = 0 if ( $opt_colndx > $#colors);
  $color = $colors[$opt_colndx++];

  printf OUT ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  printf OUT ("<kml xmlns=\"http://earth.google.com/kml/2.0\">\n");
  printf OUT ("<Placemark>\n");
  printf OUT ("  <description>%s</description>\n", $tfil );
  printf OUT ("  <name>%s</name>\n", $oname);
  printf OUT ("  <visibility>1</visibility>\n");
  printf OUT ("  <open>0</open>\n");
  printf OUT ("  <Style>\n");
  printf OUT ("    <LineStyle>\n");
  printf OUT ("      <color>%s</color>\n", $color);
  printf OUT ("      <width>%s</width>\n", $opt_width);
  printf OUT ("    </LineStyle>\n");
  printf OUT ("    <PolyStyle>\n");
  printf OUT ("      <color>ff00ff00</color>\n");
  printf OUT ("    </PolyStyle>\n");
  printf OUT ("  </Style>\n");
  printf OUT ("  <LineString>\n");
  printf OUT ("    <extrude>%d</extrude>\n", $opt_poles);
  printf OUT ("    <tessellate>1</tessellate>\n");
  printf OUT ("    <altitudeMode>absolute</altitudeMode>\n");
  printf OUT ("    <coordinates>\n");

  return(0);
}

sub write_footer() {
  printf OUT ("    </coordinates>\n");
  printf OUT ("  </LineString>\n");
  printf OUT ("</Placemark>\n");
  printf OUT ("</kml>\n");

  return(0);
}

# strip off any directory pathing from the filename
sub basename {
  local($long) = @_;
  return(substr($long, rindex($long, "/")+1));
}

# get the extension
sub extension {
  my ($long) = @_;
  return(substr($long, rindex($long, ".")));
}


############################################################

$opt_poles=  0;   # don't display poles to the ground
$opt_skip =  4;
$opt_elev =  1;   # set a default value
$opt_width=  1;
$opt_colndx = 0;  # set the starting index value into the color array
$opt_kml  =  0;
$opt_keepname = 0;

&get_cli_opts();

printf("myint   = %d\n", $opt_myint  ) if ( $opt_myint  );
printf("myfloat = %f\n", $opt_myfloat) if ( $opt_myfloat);


for ( $argc=0; $argc<=$#ARGV; ++$argc) {
  $infile = $ARGV[$argc];

  $tname = basename($infile);
  if($opt_keepname) {
    $YYYYMMDD = (split(/\./,(reverse split(/\//, $infile))[0]))[0];
  } else {
  undef $junk;
  ($a, $b, $c, $junk) = split(/-/, $tname, 4);
  if ( $a < 1990 ) {
    $m = $a;
    $d = $b;
    $y = $c;

    $y =~ s/[a-zA-Z]//g;   # force it into being a numeric when VR misses a "-"
    $y += 2000 if ( $y < 20 );
    $y += 1900 if ( $y < 100);
  } else {
    $y = $a;
    $m = $b;
    $d = $c;
  }

  $YYYYMMDD = sprintf("%04d%02d%02d", $y, $m, $d);
  }

  printf("%s\t%s\n", $YYYYMMDD, $infile);

  $outfile = $YYYYMMDD . ".kml";

  $stream = $infile;              # assume the file isn't compressed
  $ext = extension( $infile );
  $stream = sprintf("%s %s|", $GZCAT, $infile) if ( $ext =~ ".gz"  );
  $stream = sprintf("%s %s|", $BZCAT, $infile) if ( $ext =~ ".bz2" );
  # printf("Extension: %s\n", extension($infile));
  open(IN,  $stream    ) || die("Unable to read $stream\n");
  open(OUT, ">$outfile") || die("Unable to write $outfile\n");

  # write_header($outfile, $outfile, 38.3, -75.5  );
  write_header($tname, $outfile);

  $cnt = 0;
  while ( $line = <IN> ) {
    chop $line;
    @arr = split(/\s+/, $line);

    # XYZZY - 14 seems to be the # of fields in the lat/long line
    if ( $#arr == 14 ) {
      $NS   = $arr[5];
      $lat  = $arr[6];
      $EW   = $arr[7];
      $lon  = $arr[8];
      $elev = $arr[9];

      $lat *= -1 if ( $NS eq 'S');
      $lon *= -1 if ( $EW eq 'W');

      printf OUT ("%.5f,%.5f,%.2f\n", $lon, $lat, $elev*$opt_elev)
        if ( $cnt%$opt_skip == 0 );
      ++$cnt;
    }
  }

  write_footer();

  close(OUT);
  close(IN);

  # Convert the file to a .kmz if reqested
  if ( ! $opt_kml ) {
    $koutfile = $outfile;
    $koutfile =~ s/kml/kmz/;
    system("$ZIP -m $koutfile $outfile");
  }
}
