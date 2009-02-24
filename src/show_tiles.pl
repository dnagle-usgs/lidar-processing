#!/usr/bin/perl -W
# showdone:

$Id     = '$Id$';
$Source = '$Source$';


use Getopt::Long;

undef $opt_help;     # quiet the warning message
undef $getopt;       # quiet the warning message
undef $j1;
undef $j2;
undef $rm;

sub showusage {
  print <<EOF;
$Id
$Source

$0 [-[no]help]

Used by batch_process.i.
Given the path to the cmd files created by mbatch_process, returns
the tile coordinates.  This is used to color the completed tiles.

[-nohelp]: may show cmdline options that did not get added here.

EOF

# print out actual GetOptions() used if -nohelp is specified.
printf("\n%s\n", $options) if ( $opt_help == 0 );

  exit(0);
}

############################################################
# defaults are supplied in GetOptions itself
# use: perldoc Getopt::Long           # to get the manpage #

$options = <<END;
\$getopt = GetOptions (
  'help!'      => \\( \$opt_help = -1   ),  # use -nohelp to show this
  'rm!'        => \\( \$rm       =  0   ),  # if set, remove files
);
&showusage() if (\$opt_help >= 0);
END

eval $options;
&showusage() if ($getopt == 0); # result is 1 if no errors

############################################################

sub mysplit {
  my ($word) = @_;
  $f1 = substr( $word, 0, 1);
  $f2 = substr( $word, 1);

  return( $f1, $f2);
}

############################################################

if ( $#ARGV == 0 ) {
  $path = $ARGV[0];
} else {
  &showusage();
}

chdir ( $path );
# this foolery avoids getting files that don't belong.  For some
# yet 2b determined reason, yorick sometimes creates a .cmdL file.
open(LS, "echo *.cmd | ") || die("Unable to pipe from echo\n");

while ( $line = <LS> ) {
  @arr = split(/\s+/, $line );
  foreach $line ( @arr ) {
    if ( $line ne "*.cmd" ) {
      ($j1, $min_e, $max_n, $j2) = split("_", $line);
      ($e, $min_e) = mysplit($min_e);
      ($n, $max_n) = mysplit($max_n);
      if ( $e eq 'e' && $n eq 'n' ) {
        printf("%s %s %s %s\n", $min_e, $min_e + 2000, $max_n, $max_n - 2000);
      # this comment will just confuse yorick
      unlink($line)  or die ( "Unable to unklink $line\n") if ( $rm );
      }
    }
  }
}


exit(0);
