#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

use File::Finder;
use Cwd;

my $Id     = '&Id&';
my $Source = '&Source&';

# Change the & to $ above for CVS keyword expansion, delete these three lines
$Id     = '$Id$';
$Source = '$Source$';

sub stub_globals ();

my $getopt;       # quiet the warning message
my $options;

my $opts = {
  myint   =>  0,
  myfloat =>  0.0,
  mystr   =>  "",
  help    => -1,
  quiet   =>  0,
  verbose =>  0,
};

sub showusage {
  print <<"EOF";
$Id
$Source

$0 [-[no]help] [-verbose] FILE.mission ... FILEn.mission

Check each mission file to see if newer trajectory files have been installed.

[-verbose]: show Mission filename
[-verbose]: show OLD and NEW trajectory names
[-nohelp]:  better than nothing

EOF

# print out actual GetOptions() used if -nohelp is specified.
printf("\n%s\n", $options) if ( $opts->{help} == 0 );

  exit(0);
}
sub getopt();

############################################################
# defaults are supplied in GetOptions itself
# use: perldoc Getopt::Long           # to get the manpage #


$options = <<"END";
\$getopt = GetOptions (
  'help|h!'    => \\( \$opts->{help}     = -1   ),  # use -nohelp to show this
  'myint=i'    => \\( \$opts->{myint}    = -1   ),  # example optional int
  'myfloat=f'  => \\( \$opts->{myfloat}  = 1.5  ),  # example floaat
  'mystr=s'    => \\( \$opts->{mystr}    = "foo"),  # example string
  'verbose|v+' => \\(  \$opts->{verbose} =  0   ),  # use more -v for more verbose output
);
&showusage() if (\$opts->{help} >= 0);
END

eval $options;
&showusage() if ($getopt == 0); # result is 1 if no errors

sub debug {
  printf("myint    = %d\n", $opts->{myint}  ) if ( $opts->{myint}  );
  printf("myfloat  = %f\n", $opts->{myfloat}) if ( $opts->{myfloat});
  printf("magic    = %f\n", $opts->{magic}  ) if ( $opts->{magic}  );
  printf("mystr    = %s\n", $opts->{mystr}  ) if ( $opts->{mystr}  );
  printf("verbose  = not set\n"     ) if ( $opts->{verbose} == -1 );
  printf("verbose  = %d\n", $opts->{verbose}) if ( $opts->{verbose} >=  0 );
}
# Returns first directory in path
sub basedir {
  my ( $long ) = @_;
  return(substr($long, 0, index($long, "/")+0));
}
# Returns last component in path, filename or last subdir
sub basename {
  my ( $long ) = @_;
  return(substr($long, rindex($long, "/")+1));
}
# Returns the entire path, but the last entry
sub dirname {
  my ( $long ) = @_;
  return(substr($long, 0, rindex($long, "/")+0));
}

sub find_precision {
  my ( $entry, $type ) = @_;
  $entry =~ s/[ \",\\]+//g;   # remove spaces, quotes commas, and backslashes

  my ( $label, $bdir ) = split(/:/, $entry );
  $bdir = basedir( $bdir );

  my $srch_traj = $bdir . "-p-*-" . $type;

  my @traj_files = File::Finder->type('f')->name($srch_traj)->in('..');

  @traj_files = reverse sort @traj_files;   # this puts newest file on top

  return( basename($entry), basename($traj_files[0]) ) if ( scalar @traj_files );
  return("", "");
}

sub main();

# check to see if any filenames were supplied on the cmdline.
# if so, only process those, else check everything
# # this assumes we are in the mission alps subdir

my $LS_CMD;

if ( $#ARGV >= 0 ) {
  my $list="";
  $list .= $_ . " " foreach ( @ARGV );
  $LS_CMD = "ls $list";
}  else {
  $LS_CMD = "ls *.mission*";
}

open my $IN, '-|', $LS_CMD || die("$LS_CMD: $!\n");
my @files = <$IN>;
close($IN);
chomp @files;

foreach my $mission_file ( @files ) {
  printf("Checking %s\n", $mission_file ) if ( $opts->{verbose} );
  open my $IN, '<', $mission_file || die("$mission_file: $!\n");
  my @mission = <$IN>;
  close($IN);

  my $path = cwd();
  chdir dirname($mission_file);

  my @pnav = grep(/pnav file/, @mission);  # extrac pnav and ins entries
  my @ins  = grep( /ins file/, @mission);  # from .mission file
  chomp @pnav;
  chomp @ins ;

  my ( $old, $new );
  foreach my $file ( @pnav ) {             # foreach file, look for a newer version
    ( $old, $new ) = find_precision( $file, "pnav.ybin" );
    printf("%s\n", $new )                       if ( $old ne $new && $opts->{verbose} <= 1);
    printf("OLD: %s\nNew: %s\n\n", $old, $new ) if ( $old ne $new && $opts->{verbose}  > 1);
  }

  foreach my $file ( @ins  ) {
    ( $old, $new ) = find_precision( $file, "ins.pbd"   );
    printf("%s\n", $new )                       if ( $old ne $new && $opts->{verbose} <= 1);
    printf("OLD: %s\nNew: %s\n\n", $old, $new ) if ( $old ne $new && $opts->{verbose}  > 1);
  }

  chdir $path;

}

exit(0)

