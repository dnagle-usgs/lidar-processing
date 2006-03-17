#!/usr/bin/perl

require 'newgetopt.pl' || die "Unable to require newgetopt.pl\n";

undef $opt_help;    # just to quiet the warning message

$Id = '$Id$';
$Source = '$Source$';

sub showusage {
  print <<EOF;

$Id
Extract the antenna location from the -ins.txt files

EOF
  exit(0);
}


sub get_cli_opts {
  &showusage unless
  &NGetOpt(
  "help",     # help
  "kmz",      # output a doc.kml file
  "myint=i",
  "myfloat=f",
  );
  &showusage() if defined($opt_help);
}

############################################################

sub create_head {
  $HEAD = <<HERE_TARGET;
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.0">
<Document>
  <name>BaseStations.kmz</name>
  <Folder>
    <name>BaseStations</name>
    <open>1</open>
HERE_TARGET
}

sub create_placemark {
  $PLACE = <<HERE_TARGET;
    <Placemark>
      <name>$name</name>
      <styleUrl>root://styles#default+icon=0x307</styleUrl>
      <Point>
        <coordinates>$lon,$lat,$ehght</coordinates>
      </Point>
    </Placemark>
HERE_TARGET
}

sub create_tail {
  $TAIL = <<HERE_TARGET;
    </Folder>
  </Document>
</kml>
HERE_TARGET
}
############################################################

&get_cli_opts();

printf("myint   = %d\n", $opt_myint  ) if ( $opt_myint  );
printf("myfloat = %f\n", $opt_myfloat) if ( $opt_myfloat);

if ( $opt_kmz ) {
  create_head();
  create_tail();
  open( KMZ, ">basestations.kml");
  print KMZ $HEAD;
}

for ( $argc; $argc <= $#ARGV; ++$argc ) {
  open(TXT, $ARGV[$argc]) || die("Unable to open $ARGV[$argc]\n");

  $done = 0;

  while ( !$done && ($line = <TXT>) ) {
    chop $line;    # dos file, remove \r
    chop $line;    #           remove \n
    # printf("->%s\n", $line);

    ($flag, $data) = split(/:/, $line);

    if ( $flag =~ "Project" ) {
      $proj = $data;
      $proj =~ s/^ *//;
    }

    if ( $flag =~ "Master" ) {
      $ant1 = $data;
      $ant2 = <TXT>;
      chop $ant2;  # dos file, remove \r
      chop $ant2;  #           remove \n

      $ant1 =~ s/^ *//;
      $ant2 =~ s/^ *//;

      ($namestr, $hghtstr, $status)  = split(",", $ant1);
      ($junk, $name) = split(" ", $namestr);
      ($junk, $hght) = split(" ", $hghtstr);

      ($junk,
       $latdeg, $latmin, $latsec,
       $londeg, $lonmin, $lonsec,
       $ehght,
       $junk2 ) = split(/[ ,]+/, $ant2);

       $lat = abs($latdeg) + ($latmin/60.0) + ($latsec/3600.0);
       $lon = abs($londeg) + ($lonmin/60.0) + ($lonsec/3600.0);

       $lat *= -1 if ( $latdeg < 0);
       $lon *= -1 if ( $londeg < 0);  # recover the lost sign bit

      # printf("%s\n%s\n%s\n", $proj, $ant1, $ant2);
      # printf("<%s>\n", $proj );
      # printf("<%s>\n", $name );
      printf("%s,%s,", $proj, $name);             # do we need ant height?
      printf("%f,%f,%s", $lat, $lon, $ehght);
      # printf("%s %s %s\n", $londeg, $lonmin, $lonsec);
      printf("\n");
      if ( $opt_kmz ) {
        create_placemark();
        print KMZ $PLACE;
      }
    }

    $done = 1 if ( $flag =~ "Remote" );
  }
  close(TXT);

}
print  KMZ $TAIL      if ( $opt_kmz );
close( KMZ )          if ( $opt_kmz );
