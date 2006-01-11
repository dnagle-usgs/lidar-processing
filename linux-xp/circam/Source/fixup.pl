#!/bin/sh -- # comment mentioning perl to avoid looping
eval 'perl_check="`dirname $0`/`uname -p`/perl"; \
  PATH="`dirname $0`:$PATH"; \
    if [ -x /usr/local/bin/perl ]; then \
      PATH="`dirname $perl_check`:$PATH"; export PATH; \
      exec /usr/local/bin/perl -S $0 ${1+"$@"}; \
    else \
      exec /usr/bin/perl -S $0 ${1+"$@"}; \
    fi'
  if 0;

# $Id$
# $Source$

$GETFILES = "find . -name \*-\?\?\?-cir.jpg|";

open(FILES, $GETFILES) || die("Unable to run $GETFILES\n");
while ( $line=<FILES> ) {
  chop $line;
	$new = $line;
	$new =~ s/-[0-9][0-9][0-9]-/-/;

	rename($line, $new);
  printf("-> %s   %s\n", $line, $new);
}
