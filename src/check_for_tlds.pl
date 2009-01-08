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

Check back again later
[-nohelp]: better than nothing

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
  'myint:i'    => \\( \$myint    = -1   ),  # example optional int
  'myfloat=f'  => \\( \$myfloat  = 1.5  ),  # example floaat
  'mystr=s'    => \\( \$mystr    = "foo"),  # example string
  'verbose!'   => \\( \$verbose  = -1   ),  # example bool with negate option
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
    # printf("NEED: %s\n", $fqn);
    $fqn = $host . ":" . $fqn;     # prepend the hostname
    $list .= $fqn;
    system("rsync -PHaqR $fqn /");
    $list .= " "; 
  } else {
    # printf("have: %s\n", $fqn);
  }
}

if ( 0 && length($list) > 0 ) {
  printf("GET: %s###\n", $list);
  system("echo rsync -PHavR $list /");
  system("rsync -PHaqR $list / >& /dev/null");
}

exit(0);
