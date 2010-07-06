#!/usr/bin/perl -w

# removes the micro seconds from the embedded timestamp in
# the cir .jpg names


$GETFILES = "find . -name \*-\?\?\?-cir.jpg|";

open(FILES, $GETFILES) || die("Unable to run $GETFILES\n");
while ( $line=<FILES> ) {
  chop $line;
  $new = $line;
  $new =~ s/-[0-9][0-9][0-9]-/-/;

  rename($line, $new);
  printf("-> %s   %s\n", $line, $new);
}
