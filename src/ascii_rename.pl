#!/usr/bin/perl
#Author: Jeremy Bracone
#Date: 6-30-05
#This script batch converts the zbuf plots of geotiffs to jpg and renames
#  them to the correct format.  It also batch renames the geotiff files to
#  the correct finalized naming format.
#  To use, simply follow the prompts. For zbuf plot conversions to jpg, say
#  'y' at the corresponding prompts for converting tif to jpg.  Else, script
#  will simply rename files and do no conversion.

print "\nEnter Data Directory (enter nothing for current directory):  ";
chomp($dir=<STDIN>);
print "\nEnter Dataset Name: ";
chomp($title=<STDIN>);
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
    $line2=~s/000_\w+//;
    $title2 = $title . "_e";$line2=~s/$title/$title2/;
    `mv $dir$line $dir$line2`;
    print "$line >>>>> $line2\n";
  }
  if ($line=~/.txt/) {
    chomp($line);
    $line2 = $line;
    $line2=~s/t_e/$title/;$line2=~s/000_n/n/;
    $line2=~s/000_\w+//;
    $title2 = $title . "_e";$line2=~s/$title/$title2/;
    `mv $dir$line $dir$line2`;
    print "$line >>>>> $line2\n";
  }
}
__END__
