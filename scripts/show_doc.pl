#!/usr/bin/perl -w
# Display the DOCUMENT sectins of .i files
# Usage:  show_doc.pl file1 file2 ...fileN

$width = 80;
$swidth = $width - 9;
$fill = '#' x $width;
printf("%s\n", $fill);

for ( $argc = 0; $argc <= $#ARGV; ++$argc ) {
  open (FILE, $ARGV[$argc]) || die("Unable to open $ARGV[$argc]\n");

  $tag = 0;

  # printf("###  %-51s ###\n", $ARGV[$argc]);
  # printf("############################################################\n");

  while ( $line = <FILE> ) {
    $tag = 1 if ( $line =~ /\/\* *DOCUMENT/ );
    $tag = 3 if ( $line =~ /\*\// && $tag > 0);

    if ( $tag == 1 ) {
      printf("%s\n", $fill);
      printf("###  %-${swidth}s ###\n", $ARGV[$argc]);
      printf("%s\n", $fill);
      ++$tag;
    }
    printf("%s", $line) if ( $tag > 0);
#    printf("############################################################\n")
#      if ( $tag == 3 );
    $tag = 0 if ( $tag == 3 );
  }
  close(FILE);
}
