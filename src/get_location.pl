#!/usr/bin/perl

require 'newgetopt.pl' || die "Unable to require newgetopt.pl\n";

undef $opt_help;    # just to quiet the warning message

$Id = '$Id$';
$Source = '$Source$';

sub showusage {
  print <<EOF;

$Id
Extract the antenna location from the -ins.txt files

$0 [-gps] [-kml] File1 File2 FileN

-gps:  process a gps .cfg file, default is to process an -ins.txt file
-kml:  create a basestations.kml file for google earth

EOF
  exit(0);
}


sub get_cli_opts {
  &showusage unless
  &NGetOpt(
  "help",     # help
  "gps",      # use gps.cfg file for input instead of ins.txt
  "kml",      # output a basestations.kml file
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
  <name>BaseStations.kml</name>
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

if ( $opt_kml ) {
  create_head();
  create_tail();
  open( KMZ, ">basestations.kml");
  print KMZ $HEAD;
}

if ( $opt_gps ) {  # create a temporary file to hold the data
  $tmpfile = "/tmp/get_location.$$";
  open( GPS, ">$tmpfile") || die( "Unable to open $tmpfile for writing\n");
}

for ( $argc; $argc <= $#ARGV; ++$argc ) {
  open( TXT, $ARGV[$argc]) || die("Unable to open $ARGV[$argc]\n");

  $done = 0;

  while ( !$done && ($line = <TXT>) ) {
    chop $line;    # dos file, remove \r
    chop $line;    #           remove \n
    # printf("->%s\n", $line);

    if ( ! $opt_gps ) {                                 # process an -ins.txt file
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
        if ( $opt_kml ) {
          create_placemark();
          print KMZ $PLACE;
        }
      }
      $done = 1 if ( $flag =~ "Remote" );
    } else {                                            # process a gps.cfg file
      ($flag, $data) = split(/  = /, $line);
      $name   = $data if ( $flag =~ "MASTER_NAME" );
      $posstr = $data if ( $flag =~ "MASTER_POS"  );
      $antstr = $data if ( $flag =~ "MASTER_ANT"  );

      if ( $flag =~ "MASTER_ANT" ) {                  # the last line to get, process everything
        ($latdeg, $latmin, $latsec,
         $londeg, $lonmin, $lonsec,) = split(/[ ,]+/, $posstr);

         $lat = abs($latdeg) + ($latmin/60.0) + ($latsec/3600.0);
         $lon = abs($londeg) + ($lonmin/60.0) + ($lonsec/3600.0);

         $lat *= -1 if ( $latdeg < 0);
         $lon *= -1 if ( $londeg < 0);  # recover the lost sign bit

        printf GPS ("%s,%f,%f\n", $name, $lat, $lon);
      }
    }

  }

  
  close(TXT);

}

if ( $opt_gps ) {    # close the gps file, filter the data, then output the results
  close(GPS);

  # we'll trust sort and uniq are safe, sort is in /bin for linux and /usr/bin for os x.
  open( GPS, "sort $tmpfile | uniq |") || die ("Unable to open pipen");
  $ehght = 0.0;   # don't have this value
  $cnt = 0;
  while ( $line = <GPS> ) {
    chop $line;    #           remove \n
    ($name, $lat, $lon) = split(/,/, $line);

    $name = "pos$cnt" if ( $name eq "" );
    ++$cnt;

    printf ("%s |  %f |  %f\n", $name, $lat, $lon);
    if ( $opt_kml ) {
      create_placemark();
      print KMZ $PLACE;
    }
  }
  close(GPS);
  unlink($tmpfile);

}

print  KMZ $TAIL      if ( $opt_kml );
close( KMZ )          if ( $opt_kml );
