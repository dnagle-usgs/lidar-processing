#!/usr/bin/perl -w

#  unpacks the cam tarfile and puts it into a new directory
#  structure that has images grouped into hhmm.


$SRCDIR  = $ARGV[0];
$SUBDIR  = "/photos";
$TMPDIR  = "/tmp-$$";
$GETTAR  = "find $SRCDIR -name \*-cam1.tar|";


sub basename {
  local($long) = @_;
  return(substr($long, rindex($long, "/")+1));
}

sub dirname {
  local($long) = @_;
  return(substr($long, 0, rindex($long, "/")+0));
}


die("No search path defined, exiting\n") if ( $SRCDIR eq "" );

printf("searching in:\n%s\n", $GETTAR );

open(LIST, $GETTAR) || die("Unable to run $GETTAR\n");

while ( $line = <LIST> ){
  chop $line;

  $tarname = basename($line);
  ( $pdir, $junk) = split("-", $tarname, 2);
  $hhmm = substr($hhmmss, 0, 4);
  printf("->%s\n", $pdir);

  # these directories probably already exist from makecir.pl
  if ( ! -e $pdir ) {
    printf("Creating: %s\n", $pdir);
    mkdir($pdir);
    mkdir($pdir. $SUBDIR);
  }
  
  # Make a temporary directory to untar the file
  $tdir = $pdir . $TMPDIR;
  mkdir($tdir);
  system("tar -C " . $tdir . " -xf " . $line);

  # Now we need to move the files into the cir heirachy

  $GETLIST = "find $tdir -name cam1_CAM1\*.jpg|";

  open(FILES, $GETLIST) || die("Unable to run $GETLIST\n");

  $ohhmm = "9999";
  while ( $file = <FILES> ){
    chop $file;
    $jpgname = basename($file);
    ($j1, $j2, $tdate, $hhmmss, $j3) = split(/[_\.]/, $jpgname);

    $hhmm = substr($hhmmss, 0, 4);

    mkdir($pdir. $SUBDIR);

    if ( $ohhmm ne $hhmm ) {
      $ohhmm = $hhmm;
      printf("hhmmss = %s\n", $hhmm);
      $ndir  = $pdir . $SUBDIR . "/" . $hhmm;

      mkdir ($ndir) if ( ! -e $ndir);
    }

    $nfile = $ndir . "/" . $jpgname;

    rename ( $file, $nfile);

  }
  close (FILES);
  rmdir ($tdir . "/cam1"); # this should be the only intermediate directory
  rmdir ($tdir);

}

close(LIST);

exit(0);
