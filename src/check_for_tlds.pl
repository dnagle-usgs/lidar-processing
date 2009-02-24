#!/usr/bin/perl -W
# showdone:

$Id     = '$Id$';
$Source = '$Source$';

use Getopt::Long;

undef $opt_help;     # quiet the warning message
undef $getopt;       # quiet the warning message

sub showusage {
  print <<EOF;
$Id
$Source

$0 [-[no]help]

Used by batch_process.i.
unpackage_tile() creates a file with the names of the .tld files
needed for the current tile.  This program then reads that file
to determine which .tld files are still needed from the server.
rsync is then invoked to transfer only those files.

If all the files are already on the client (where this is being run)
then this avoids any calls to rsync to the server.

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

if ( $#ARGV == 1 ) {
  $fn   = $ARGV[0];
  $host = $ARGV[1];
} else {
  printf("argc: %d\n", $#ARGV);
  &showusage();
}

open(IN, $fn) || die("Unable to open $fn\n");

$path = <IN>; chop $path;
$list = "";
while ( $file=<IN> ) {
  chop $file;
  $fqn = $path . "eaarl/" . $file;
  if ( ! -e $fqn ) {
    printf("NEED: %s\n", $fqn);
    $fqn = $host . ":" . $fqn;     # prepend the hostname
    $list .= $fqn;
    system("echo rsync -PHaqR $fqn /");
    system("rsync -PHaqR $fqn /");
    $list .= " ";
  } else {
    # printf("have: %s\n", $fqn);
  }
}

exit(0);
