#!/usr/bin/perl
#Author: Jeremy Bracone
#Date: 1-03-06
#
#  Completely rewrote script.  Old script can now be invoked calling this
#  script with option "-old"
#	Ex.  type into the prompt "./geotiffer -old"
#
#  New script takes the previously renamed files and converts them back to the
#  data tile format.  The new script reflects the changing of naming protocols
#  and can still convert gridplots in tif format to jpg.  This option is only
#  given if the appropriate file type is specified (will be prompted).
#
#Date: 6-30-05
#  This script batch converts the zbuf plots of geotiffs to jpg and renames
#  them to the correct format.  It also batch renames the geotiff files to the
#  correct finalized naming format.  To use, simply follow the prompts. For
#  zbuf plot conversions to jpg, say 'y' at the corresponding prompts for
#  converting tif to jpg.  Else, script will simply rename files and do no
#  conversion.



if ($#ARGV != -1) {
   if ($ARGV[0]=~m/-/) {
      old_routine() if ($ARGV[0]=~m/old/)
   }
}

print "\nEnter Data Directory (enter nothing for current directory):  ";
chomp($dir=<STDIN>);
print "\nEnter Zone Number: ";
chomp($zone=<STDIN>);
$zone=~s/\s+//; #removie whitespace
$zone =  "_" . $zone if ($zone);
print "\nEnter dataset type (ba=bathy,fs=first_surface,be=bare_earth):  ";
chomp($t=<STDIN>);
$t=~s/\s+//; #remove whitespace
$t = "_" . $t if ($t);
print "\nEnter datum: ";
chomp($datum=<STDIN>);
$datum=~s/\s+//; #remove whitespace
$datum = "_" . $datum if ($datum);
print "\nEnter any additional text to be put into the filename\n      (type exactly as it will be seen):  ";
chomp($info=<STDIN>);
$info=~s/\s+//; #remove whitespace
$info = "_" . $info if ($info);
do {
  print "\nRenaming (1)geotiffs or (2)gridplot_tiffs or (3)gridplot_jpgs:  ";
  chomp($g_z=<STDIN>);
} while ($g_z != 1 && $g_z != 2 && $g_z != 3);
if ($g_z == 1) {
  $type = "_geotiff.tif";
  $search = "*.tif";
} elsif ($g_z == 2) {
  $type = "_zbuf.tif";
  $search = "*.tif";
  do {
    print "\nDo you want to convert these tiff files to jpg (y/n)?";
    chomp($convert=<STDIN>);
  } while ($convert ne 'y' && $convert ne 'Y' && $convert ne 'n' && $convert ne 'N');
} else {
  $type = "_zbuf.jpg";
  $search = "*.jpg";
}
$dir=~s/\w$/\//;
$infile= $dir . "temp.123";
`ls $dir$search > $infile`;
open(IN,"<$infile");
@filenames=<IN>;
close(IN);
`rm $infile`;
foreach $line (@filenames) {
  chomp($line);
  $line=~m/(^\w+_)(e\d\d\d)(n\d\d\d\d)/;
  $v1 = $2 . "000_";
  $v2 = $3 . "0000";
  if ($convert eq 'Y' || $convert eq 'y') {
    $type = "_zbuf.jpg";
    $line2 = "t_$v1$v2$zone$datum$info$t$type";
    `convert $dir$line $dir$line2`;
  } else {
    $line2 = "t_$v1$v2$zone$datum$info$t$type";
    `mv $dir$line $dir$line2`;
  }
  print "$line >>>>> $line2\n";
}

############################
####### OLD ROUTINE ########
############################
sub old_routine {
  print "\nBEGINNING OLD ROUTINE...";
  print "\nEnter Data Directory (enter nothing for current directory):  ";
  chomp($dir=<STDIN>);
  print "\nEnter Dataset Name: ";
  chomp($title=<STDIN>);
  print "\nAre you converting tif to jpg? (y/n):  ";
  chomp($answer=<STDIN>);
  $dir=~s/\w$/\//;
  $infile= $dir . "temp.123";
  `ls $dir > $infile`;
  open(IN,"<$infile");
  @filenames=<IN>;
  close(IN);
  `rm $infile`;
  foreach $line (@filenames) {
    if ($line=~/.tif/) {
      chomp($line);
      $line2 = $line; 
      $line2=~s/t_e/$title/;$line2=~s/000_n/n/;
      if ($answer eq 'y'||$answer eq 'Y') {
         $line2=~s/000_\w+\.tif/.jpg/;
         $title2 = $title . "_e";$line2=~s/$title/$title2/;
         `convert $dir$line $dir$line2`;
      } else {
         $line2=~s/000_\w+//;
         $title2 = $title . "_e";$line2=~s/$title/$title2/;
         `mv $dir$line $dir$line2`;
      }
      print "$line >>>>> $line2\n";
    }
  }
} #end of old_routine

__END__
