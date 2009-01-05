#!/usr/bin/perl -W
# waiter: given a size and path, waits until the path is less than size (in K)
#         before exiting.  Reports current size while waiting.

$Id     = '$Id$';
$Source = '$Source$';

use Getopt::Long;

undef $opt_help;     # quiet the warning message
undef $getopt;       # quiet the warning message
undef $pj;

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
  'noloop!'    => \\( \$noloop   =  0   ),  # don't wait for size before exiting
);
&showusage() if (\$opt_help >= 0);
END

eval $options;
&showusage() if ($getopt == 0); # result is 1 if no errors

if ( $#ARGV == 1 ) {
  $wmrk = $ARGV[0];
  $path = $ARGV[1];
} else {
  &showusage();
}

do {
  open(DU, "du -ks $path |") || die("Unable to create pipe to du\n");
  $line=<DU>;
  close(DU);
  open(LS, "ls $path | wc -l |") || die("Unable to create pipe to ls\n");
  $fc=<LS>;
  close(LS);
  ($space, $pj) = split(/\s+/, $line);
  printf("Waiting for %s to drop below %s\n", $space, $wmrk)
    if ( ! $noloop && $space > $wmrk);
  printf("%d file(s) in queue\n", $fc)
    if ( ! $noloop && $space > $wmrk);
  sleep 10 if ( $space > $wmrk);
}
while ( ! $noloop && $space > $wmrk );

printf("%d %d", $space, $fc ) if ( $noloop );


exit(0);
