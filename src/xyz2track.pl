#!/usr/bin/perl -w

$Id = '$Id$';
$Source = '$Source$';

require 'newgetopt.pl' || die "Unable to require newgetopt.pl\n";

undef $opt_help;    # just to quiet the warning message

sub showusage {
  print <<EOF;

# $Id
# $Source

$0 File1 [File2] [FileN]

 Breaks xyz files into flight segments.

 Reads File and copies the contents to an output file which is
 named after the earliest soe in the file.

 Creates a new output file when there is a gap in the soe
 larger than $gap seconds,

 Properly handles both .xyz and .xyz.gz files.

EOF
  exit(0);
}


sub get_cli_opts {
  &showusage unless
  &NGetOpt(
    "help",     # help
    "myint=i",
    "myfloat=f",
  );
  &showusage() if defined($opt_help);
}

sub basename {
  my ($long ) = @_;
  my $ndx;

  $ndx = rindex($long, ".");
  $ndx = length($long) if ( $ndx < 0 );
  return( substr($long, 0, $ndx ) );
}

sub extension {
  my ($long) = @_;
  my $ndx;

  $ndx = rindex($long, ".");
  $ndx = length($long) if ( $ndx < 0 );
  
  return( substr($long, $ndx ) );
}

############################################################

$gap = 15;

&get_cli_opts();


undef $x;
undef $y;
undef $z;

for ( $arg = 0; $arg <= $#ARGV; ++$arg ) {

  $ifname = $ARGV[$arg];
  $xyz = "";
  $gz  = "";

  $base = $ifname;
  if ( extension( $base ) =~ ".gz" ) {
    $gz = ".gz";
    $base = basename($base);
  }

  if ( extension( $base ) =~ ".xyz" ) {
    $base = basename($base);
    $xyz = ".xyz";
  }

  if ( $gz ne "" ) {
    open(IN, "zcat $ifname |" ) || die("Unable to run zcat $ifname\n");
  } else {
    open(IN, $ifname ) || die("Unable to open $ifname\n");
  }

  $osoe = 0.0;
  while ( $line = <IN> ) {
    chop $line;
    $line =~ s/^ //g;
    ($x, $y, $z, $soe) = split(/\s+/, $line);

    if ( $soe - $osoe > $gap  ) {
      $osoe = $soe;
      $ofname = sprintf("%s-%s%s%s", $base, $soe, $xyz, $gz);

      printf("%s\n", $ofname);

      close( OUT );
      if ( $gz ne "" ) {
        open(OUT, "| gzip >$ofname") || die ("unable to gzip $ofname\n");
      } else {
        open(OUT, "> $ofname") || die ("unable to write to $ofname\n");
      }
    }

    printf OUT ("%s\n", $line );
   
  }

  close( IN  );
  close( OUT );

}
