#!/usr/bin/perl -w

# unpacks the cir tarfile and puts it into a new directory
# structure that has images grouped into hhmm.

# Usage:
# makecir.pl SOURCEDIR
# makecir.pl SOURCEDIR DESTDIR
#
# SOURCEDIR should be the directory containing the tar files.
#
# DESTDIR is the directory in which you want to create the photos/ subdirectory
# that will contain the per-minute directories. If omitted, will default to
# ./YYMMDD. A useful value might be . if you're creating the photos directory
# in the same directory that has the tar files directory.

$CC      = "20";      # Century
$SUBDIR  = "/photos";
$SRCDIR  = $ARGV[0];
$GETLIST = "find $SRCDIR -name \*cir.tar|";
$DESTDIR = $ARGV[1] ? $ARGV[1] : "";

sub basename {
  local($long) = @_;
  return(substr($long, rindex($long, "/")+1));
}

sub dirname {
  local($long) = @_;
  return(substr($long, 0, rindex($long, "/")+0));
}


die("No search path defined, exiting\n") if ( $SRCDIR eq "" );

printf("searching in:\n%s\n", $GETLIST);

open(LIST, $GETLIST) || die("Unable to run $GETLIST\n");

while ( $line = <LIST> ){
  chop $line;

  $tarname = basename($line);
  ( $pdir, $hhmmss, $junk) = split("-", $tarname, 3);
  $hhmm = substr($hhmmss, 0, 4);
  printf("->%s       %s\t", $pdir, $hhmm);

  $YY = substr($pdir, 4, 2);
  $MM = substr($pdir, 0, 2);
  $DD = substr($pdir, 2, 2);

  $ndir = $CC . $YY . $MM . $DD;

  if($DESTDIR ne "") {
    $ndir = $DESTDIR;
  }

  if ( ! -e $ndir ) {
    printf("Creating: %s\n", $ndir);
    mkdir($ndir);
  }
  if ( ! -e $ndir.$SUBDIR ) {
    printf("Creating: %s\n", $ndir.$SUBDIR);
    mkdir($ndir. $SUBDIR);
  }

  $fdir = $ndir . $SUBDIR . "/" . $hhmm;

  if ( -e $fdir ) {
    $str = $fdir . "/*-cir.jpg";
    open(LS, "echo  $str|");
    @foo = <LS>;
    close(LS);
    chop @foo;

    if ( $str ne $foo[0]) {
      printf("FOUND %3d images\t", $#foo+1);
      printf("skipping\n");
    } else {
      printf("creating\n");
      mkdir($fdir);
      system("tar -C " . $fdir . " -xf " . $line);
    }
  } else {
    printf("creating\n");
    mkdir($fdir);
    system("tar -C " . $fdir . " -xf " . $line);
  }
}

close(LIST);
