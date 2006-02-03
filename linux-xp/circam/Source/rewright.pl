#!/usr/bin/perl -w

# $Id$
# $Source$

require 'newgetopt.pl' || die "Unable to require newgetopt.pl\n";

undef $opt_help;    # just to quiet the warning message

sub showusage {
  print <<EOF;

rewrites all of the files in the specified directory with the specified
extension using an old and new pattern.

$0 -dir=DIR -ext=EXT -old=PAT1 -new=PAT2

  -dir=s    # directory to start search
  -ext=s    # filename extension to search through
  -old=s    # the string to search for
  -new=s    # the new string to replace the old

Example:
  rewright -dir test -ext .kml -old "root://icons" -new "FOO:||BAR"
  rewright -dir test -ext .kml -new "root://icons" -old "FOO:||BAR"

EOF
  exit(0);
}


sub get_cli_opts {
  &showusage unless
  &NGetOpt(
  "help",     # help
  "dir=s",    # directory to start search
  "ext=s",    # filename extension to search through
  "old=s",    # the string to search for
  "new=s",    # the new string to replace the old
  "myint=i",
  "myfloat=f",
  );
  &showusage() if defined($opt_help);
}


############################################################

$opt_dir=".";

&get_cli_opts();

printf("myint   = %d\n", $opt_myint  ) if ( $opt_myint  );
printf("myfloat = %f\n", $opt_myfloat) if ( $opt_myfloat);


&showusage() if ( !$opt_old);


printf("Searching in directory   : %s\n", $opt_dir);
printf("Searching files ending in: %s\n", $opt_ext);
printf("Searching for string     : %s\n", $opt_old);
printf("Replacing with string    : %s\n", $opt_new);

# We need to rewrite $opt_old so that it is shell safe
$opt_oldsrch = $opt_old;
$opt_oldsrch =~ s/\|/\\\\\\|/g;

# $opt_old =~ s/\|/\\\\\|/g;
$opt_old =~ s/\|/\\\|/g;


$srchname = "";
$srchname = "-name \\*" . $opt_ext if ( $opt_ext );

printf("find $opt_dir $srchname | xargs grep -l '$opt_oldsrch'|");
printf("\n");

open(FIND, "find $opt_dir $srchname | xargs grep -l '$opt_oldsrch'|")
  || die("Unable to run find\n");

while ( $file = <FIND> ) {
  chop $file;

  printf("FOUND: %s\n", $file);

  open(FILE, $file) || die("Unable to open $file\n");
  @all = <FILE>;
  close(FILE);

  rename ($file, $file.".bk1");

  for ($i=0; $i<=$#all; ++$i){
    $all[$i] =~ s/$opt_old/$opt_new/g;
  }

  open(FILE, ">$file") || die("Unable\n");
  print FILE @all;
  close(FILE);

}
close(FIND);

