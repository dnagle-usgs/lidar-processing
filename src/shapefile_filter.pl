#!/bin/sh -- # comment mentioning perl to avoid looping
eval 'perl_check="`dirname $0`/`uname -p`/perl"; \
  PATH="`dirname $0`:$PATH"; \
    if [ -x /usr/local/bin/perl ]; then \
      PATH="`dirname $perl_check`:$PATH"; export PATH; \
      exec /usr/local/bin/perl -S $0 ${1+"$@"}; \
    else \
      exec /usr/bin/perl -S $0 ${1+"$@"}; \
    fi'
  if 0;

# Everything above here could be replaced with:
#!/usr/bin/perl -w

sub showusage {
  print <<EOF;

# $Id$
# $Source$
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
