#!/usr/bin/perl

$Id    = '$Id$';
$Source = '$Source$';

sub showusage {
  print <<EOF;

# $Id
# $Source
#

$0 : file1.txt [file2.txt filen.txt]

Converts shapefile data into something ALPS will like.

EOF
  exit(0);
}

############################################################

showusage() if ( $#ARGV < 0 );

for ( $i=0; $i <= $#ARGV; ++$i ) {
  $oname = $ARGV[$i];
  $nname = $oname;

  # Create an output name
  $nname =~ s/\.TXT/\.IMAP/ if ( $nname =~ ".TXT" );
  $nname =~ s/\.txt/\.imap/ if ( $nname =~ ".txt" );

  $nname .= ".imap" if ( $nname eq $oname );


  printf("oname: %s\n", $oname);
  printf("nname: %s\n", $nname);


  open (IN,    $oname ) || die ("Unable to open $oname for reading\n");
  open (OUT, ">$nname") || die ("Unable to open $nname for writing\n");

  $tag = 0;
  while ($line = <IN> ) {
    if ( ($line + 0.0) == 0.0 ) {
      if ( $tag == 0 ) {             # only output one # per group
        printf OUT ("#\n");
        $tag = 1;
      }
    } else {
      $tag = 0;
      @ll = split(/,/, $line);
      printf OUT ("%s %s\n", $ll[0], $ll[1]);
    }
  }
}
exit(0);
