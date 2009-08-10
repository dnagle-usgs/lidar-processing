#!/usr/bin/perl -w
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

################ ############## #####################

sub showusage {
  print <<EOF;
$0 [-skip=N] file1 .... fileN

Reads *-pnav.txt* files and creates .txt files for GlobalMapper.

The input files can be plain text, or compressed using either gzip or bzip2.

The  output file is written into the current directory in the form: YYYYMMDD.txt

  "skip=i",   # skip records to reduce output file size            (default: $opt_skip)

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
  );
  &showusage() if defined($opt_help);
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

$opt_skip =  1;

&get_cli_opts();

for ( $argc=0; $argc<=$#ARGV; ++$argc) {
  $infile = $ARGV[$argc];

  $tname = basename($infile);
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

  printf("%s\t%s\n", $YYYYMMDD, $infile);

  $outfile = $YYYYMMDD . ".txt";

  $stream = $infile;              # assume the file isn't compressed
  $ext = extension( $infile );
  $stream = sprintf("%s %s|", $GZCAT, $infile) if ( $ext =~ ".gz"  );
  $stream = sprintf("%s %s|", $BZCAT, $infile) if ( $ext =~ ".bz2" );
  # printf("Extension: %s\n", extension($infile));
  open(IN,  $stream    ) || die("Unable to read $stream\n");
  open(OUT, ">$outfile") || die("Unable to write $outfile\n");

  $cnt = 0;
  $olat = -999; $olon = -999;
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

      # $lat *= -1 if ( $NS eq 'S');
      # $lon *= -1 if ( $EW eq 'W');

      if ( $olat != int($lat*10e5) && $olon != int($lon*10e5) ) {
        # printf OUT ("%1s%.5f,%1s%.5f\n", $EW, $lon, $NS, $lat)
        printf OUT ("%1s%f, %1s%f\n", $EW, $lon, $NS, $lat)
          if ( $cnt%$opt_skip == 0 );
        $olat = int($lat*10e5);
        $olon = int($lon*10e5);
      }
      ++$cnt;
    }
  }

  close(OUT);
  close(IN);

}
