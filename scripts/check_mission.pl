#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

use File::Finder;
use Cwd;
use JSON::PP;
use POSIX qw/strftime/;

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
  update  =>  0,
};

my $OLSYMB = '{';      # object left symbol
my $ORSYMB = '}';
my $ALSYMB = '\[';      # array  left symbol
my $ARSYMB = '\]';

sub showusage {
  print <<"EOF";
$Id
$Source

$0 [-[no]help] [-verbose] FILE.mission ... FILEn.mission

Check each mission file to see if newer trajectory files have been installed.

[-verbose]: show Mission filename
[-verbose]: show OLD and NEW trajectory names
[-update] : Create a new MISSION-update file with the new trajectories
[-nohelp] : better than nothing

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
  'verbose|v+' => \\( \$opts->{verbose}  =  0   ),  # use more -v for more verbose output
  'update'     => \\( \$opts->{update}   =  0   ),  # update mission file
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

sub create_change_header {
  my $hdr;

  my $user = $ENV{USER};
  my $hms = strftime("%Y%m%d-%H%M%S", gmtime( time() ) );

  $hdr->{time} = $hms;
  $hdr->{user} = $user;

  bless $hdr;
}

sub find_precision {
  my ( $entry, $type ) = @_;
  $entry =~ s/[ \",\\]+//g;   # remove spaces, quotes commas, and backslashes

  my ( $label, $bdir ) = split(/:/, $entry );
  my $tdir = $bdir;
  $bdir = basedir( $bdir );

  my $srch_traj = $bdir . "-p-*-" . $type;

  my @traj_files = File::Finder->type('f')->name($srch_traj)->in('..');

  @traj_files = reverse sort @traj_files;   # this puts newest file on top

  if ( scalar @traj_files && $opts->{update} ) {
    if ( basename($entry) ne basename($traj_files[0] ) ) {
      $traj_files[0] =~ s|../||;

#     printf("< %s\n", $tdir );
#     printf("> %s\n", $traj_files[0] );
      return( $bdir, $tdir, $traj_files[0] );
    }
  }

  return( $bdir, basename($entry),  basename($traj_files[0]) ) if ( scalar @traj_files );
  return("", "", "");
}

sub update_trajectories {
  my ( @mission ) = @_;
  my $changes;

  my @pnav = grep(/pnav file/, @mission);  # extrac pnav and ins entries
  my @ins  = grep( /ins file/, @mission);  # from .mission file
  chomp @pnav;
  chomp @ins ;

  my ( $date, $old, $new );
  foreach my $file ( @pnav ) {             # foreach file, look for a newer version
    ( $date, $old, $new ) = find_precision( $file, "pnav.ybin" );
    if ( $old ne $new ) {

      $changes->{$date}->{pnav}->{old} = $old;
      $changes->{$date}->{pnav}->{new} = $new;

      printf("%s\n", $new )                       if ( $opts->{verbose} <= 1);
      printf("OLD: %s\nNew: %s\n\n", $old, $new ) if ( $opts->{verbose}  > 1);
      if ( $opts->{update} ) {
        $old =~ s|/|\\\\/|g;   # looks wrong,
        $new =~ s|/|\\/|g;     # but it works
#       printf("#%s#\n#%s#", $old, $new);
        $_ =~ s/$old/$new/ foreach ( @mission );
      }
    }

  }

  foreach my $file ( @ins  ) {
    ( $date, $old, $new ) = find_precision( $file, "ins.pbd"   );
    if ( $old ne $new ) {

      $changes->{$date}->{ins}->{old} = $old;
      $changes->{$date}->{ins}->{new} = $new;

      printf("%s\n", $new )                       if ( $opts->{verbose} <= 1);
      printf("OLD: %s\nNew: %s\n\n", $old, $new ) if ( $opts->{verbose}  > 1);
      if ( $opts->{update} ) {
        $old =~ s|/|\\\\/|g;   # looks wrong,
        $new =~ s|/|\\/|g;     # but it works
        $_ =~ s/$old/$new/ foreach ( @mission );
      }
    }
  }

  return( $changes, @mission );
}

sub get_notes {
  my ( $key, @mission ) = @_;

  my $json_str = join('', @mission );       # turn array into a single string
  my $perl_obj = decode_json( $json_str );  # load string into perl objects

  return ( $perl_obj->{$key} );
}

sub obj2str {
  my ( $key, $obj ) = @_;

  my $json   = JSON::PP->new->pretty;         # create json parser
  my $pretty = $json->encode( $obj );         # get obj as a json string

  $pretty = "\"$key\": " . $pretty;
  printf("%s\n", $pretty ) if ( $opts->{verbose} > 2 );

  return( $pretty );
}

sub add_change_notes {
  my ( $lvl, $swap_key, $swap_str, @arr ) = @_;

  my $lvl_cnt = 0;

  my $lcnt_obj = 0;
  my $lcnt_arr = 0;
  my $rcnt_obj = 0;
  my $rcnt_arr = 0;

  my $outline  = "";
  my $lvl_key  = "";

  my $d_obj;
  my $d_arr;

  my $entry_updated = 0;
  my @new_mission;

  foreach my $line ( @arr ) {
    chomp $line;

    $lcnt_obj += $line =~ /$OLSYMB/g;   # these will be right/closing symbols
    $rcnt_obj += $line =~ /$ORSYMB/g;   # or array elements

    $lcnt_arr += $line =~ /$ALSYMB/g;
    $rcnt_arr += $line =~ /$ARSYMB/g;

    $d_obj = $lcnt_obj - $rcnt_obj;
    $d_arr = $lcnt_arr - $rcnt_arr;

    $lvl_cnt = $d_obj + $d_arr;

    my ( $key, $value ) = split /\s*:\s*/, $line;
      $key   =~ s/[ ]+//;

    $outline .= $line . '#';

    if ( ! $value ) {
      if ( $key !~ /[$OLSYMB|$ORSYMB|$ALSYMB|$ARSYMB]/ ) {    # we have a array value
      } else {
        if ( $lvl == $lvl_cnt ) {

          if ( $lvl_key eq "\"$swap_key\"" ) {
#           printf("Inseting new key: %s\n", $lvl_key );
            $outline = $swap_str;
            $entry_updated = 1;
          }

          $outline =~ s/#/\n/g;
          push @new_mission, "$outline" if ( $outline gt "" );
          $outline = "";
          $lvl_key = "";
        }
        if ( $lvl > $lvl_cnt ) {       # last line
          if ( ! $entry_updated && $lvl_cnt == 0 ) {
#           printf("%d : %d - Appending new key: %s\n", $lvl, $lvl_cnt, $swap_key );
            $outline = $swap_str;
            $outline =~ s/#/\n/g;
            chomp $outline;

            if ( $outline gt "" ) {
              chomp $new_mission[-1];
              push @new_mission, ",\n";
              push @new_mission, "$outline\n";
            }
          }
          push @new_mission, "$line\n";
        }
      }
    } else {
      if ( $lvl == $lvl_cnt
        || $lvl+1 == $lvl_cnt ) {
        $lvl_key = $key if ( ! $lvl_key );
      }

        if ( $lvl == $lvl_cnt ) {
          $outline =~ s/#/\n/g;
          push @new_mission, $outline if ( $outline gt "" );
          $outline = "";
        }
    }
  }
  return( @new_mission );
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

my $lvl = 1;
my $notes_key = "check_mission";
my $notes_obj;

my $header = create_change_header();

foreach my $mission_file ( @files ) {
  printf("Checking %s\n", $mission_file ) if ( $opts->{verbose} );
  open my $IN, '<', $mission_file || die("$mission_file: $!\n");
  my @mission = <$IN>;
  close($IN);

  my $path = cwd();
  chdir dirname($mission_file);

  my $hits = grep( /$notes_key/, @mission );

  $notes_obj = get_notes( $notes_key, @mission ) if ( $hits );

  my ( $changes, @new_mission ) = update_trajectories( @mission );

  if ( $changes ) {
    @{$changes}{keys %$header} = values %$header;       # merge header with changes

    $notes_obj->{updates} = [] if ( !$notes_obj->{updates} ); # create updates array

    push $notes_obj->{updates}, $changes;               # push changes onto updates

    my $notes_str = obj2str( $notes_key, $notes_obj );

    printf("%s\n", $notes_str ) if ( $opts->{verbose} );
    @new_mission = add_change_notes( $lvl, $notes_key, $notes_str, @new_mission );

    if ( $opts->{update} ) {
      my $new = $mission_file."-update";
      printf("Updating %s\n", $new);
      open my $OUT, '>', $new || die("creating $new $!\n");
      print $OUT @new_mission;
      close ($OUT);
    }
  }

  chdir $path;

}

exit(0)

