#!/usr/bin/perl -W

use Getopt::Long;
use File::Basename;

undef $opt_help;    # just to quiet the warning message
undef $cnull;
undef $cfile;
undef $getopt;

sub showusage {
  print <<EOF;
$0 [-local] [-verbose]

When run from inside a directory maintained wth CVS, displays the
log entries for all files that need to be updated.

-local     : display what has been changed on the local system
-verbose   : display filenames/pathing used

EOF

# print out actual GetOptions() used if -nohelp is specified.
  printf("\n%s\n", $options) if ( $opt_help == 0 );

  exit(0);
}


$options = <<END;
\$getopt = GetOptions (
  'help!'   => \\( \$opt_help   = -1 ),   # help
  'local'   => \\( \$opt_local  =  0 ),   # display what has been changed locally
  'diff'    => \\( \$opt_diff   =  0 ),   # show diffs instead of log
  'verbose' => \\( \$verbose    =  0 ),   # show cvs requests
  );
  &showusage() if ( \$opt_help >= 0 );
END

############################################################
# Break name into components: file, dir, extension
sub parsename {
  my ($name) = @_;
  return fileparse($name, qr{\..*});
}
############################################################

$srch_flag = "U";   # Update

eval $options;
&showusage() if ($getopt == 0); # result is 1 if no errors

$srch_flag = "M" if ( $opt_local );   # Modified locally
$opt_diff = 1    if ( $opt_local );   # force diff output


open(CVS, "cvs -qn update | ") || die("Unable to run: cvs -n update\n");
while ( $line = <CVS> ) {
  chop $line;

  ($flag, $update) = split(/ /, $line);

  if ( $flag eq "U" ) {
    printf("\nUpdate: %s\n", $update);
  }

  if ( $flag eq "M" ) {
    printf("\nModified: %s\n", $update);
  }

  if ( $flag eq $srch_flag ) {
    ($file, $dir, $ext) = parsename($update);
    $entry = sprintf("%sCVS/Entries", $dir);
    $file  .= $ext;
    printf("CVS update : %s\n", $update) if ( $verbose );
    printf("CVS entry  : %s\n", $entry) if ( $verbose );
    printf("CVS file   : %s\n", $file ) if ( $verbose );

    open(ENTRY, $entry) || die("Unable to open $entry\n");
    @entries=<ENTRY>;
    close(ENTRY);
    @list = grep(/\/$file\//, @entries);
    if ( $#list != 0) {
      printf("\nFound %d matches, not processing\n", $#list);
    } else {
      ($cnull, $cfile, $cver, $cdate) = split(/\//, $list[0]);
      printf("current version: %s\t\t%s\n\n", $cver, $cdate);

      if ( ! $opt_diff ) {
        printf("LOG: cvs log -r$cver\:: $update |\n") if ( $verbose );
        open(PIPE, "cvs log -r$cver\:: $update |") || die("Unable to create pipe");
        $start=0;
      } else {
        # first we have to the latest revision number
        printf("DIFFLOG: cvs log -r $cver\:: $update |\n") if ( $verbose );
        open(PIPE, "cvs log -r$cver\:: $update |") || die("Unable to create pipe");
        while ( $junk = <PIPE> ) {
          if ( $junk =~ "head:" ) {
            chop $junk;
            # printf("HEAD: %s\n", $junk);
            @tmp = split(/: /, $junk);
            $cver = $tmp[1];
            # printf("tmp: %s %s\n", $tmp[0], $tmp[1]);
            # printf("cver: %s\n", $cver);
          }
        }
        close(PIPE);

        printf("DIFF: cvs diff -r$cver $update |\n") if ( $verbose );
        open(PIPE, "cvs diff -r$cver $update |") || die("Unable to create pipe");
        $start=1;
      }
      while ( $pipe = <PIPE> ) {
        printf("%s", $pipe) if ( $start );
        $start = 1 if ( $pipe =~ "---------");
      }
    }
  }
}
close(CVS);
