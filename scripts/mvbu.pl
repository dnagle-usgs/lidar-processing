#!/usr/bin/perl

my $Id     = '$Id$';
my $Source = '$Source$';

use strict;
use warnings;
use Getopt::Long;
use POSIX qw/strftime/;
# use Cwd;
# use File::Finder;            # cpan install File::Finder
use File::Copy qw(copy move);
# use Time::Piece;

  my $cpmv = \&move;
     $cpmv = \&copy   if ( $0 =~ "cp" );

# magic to get NAME of function cpmv points
  use B qw(svref_2object);
  my $cv = svref_2object ( $cpmv );
  my $gv = $cv->GV;


sub stub_globals ();

my $getopt;       # quiet the warning message
my $options;

my $opts = {
  help    => -1,
  soe     =>  0,
  ymd     =>  0,
  hms     =>  0,
  osp     => "A",
  nsp     => ".",
  norun   =>  0,
  verbose =>  0,
  force   =>  0,
};

sub showusage {
  my $prog = basename($0);
  my $func = $gv->NAME;
  print <<EOF;

$0
$prog [-soe] [-ymd] [-hms] [-n] [-[no]help] File1 File2 ... FileN

  -soe            # append unix soe as .SOE
  -ymd            # append .YYYYMMDD
  -hms            # append .YYYYMMDD-HHMMSS
  -strip          # remove any time extension
  -help           # this help
  -n              # do not $func files, only show changes
  -nohelp         # code generated help

Append the files creation timestamp to the filename.

$prog: $func file to file.TIME

EOF

# print out actual GetOptions() used if -nohelp is specified.
  printf("\n%s\n", $options) if ( $opts->{help} == 0 );

  exit(0);
}
sub getopt();

############################################################
# defaults are supplied in GetOptions itself
# use: perldoc Getopt::Long           # to get the manpage #

$options = <<END;
\$getopt = GetOptions (
  'help|h!'    => \\( \$opts->{help}     = -1   ),  # use -nohelp to show this
  'soe'        => \\( \$opts->{soe}      =  1   ),  # append unix soe as .SOE
  'ymd'        => \\( \$opts->{ymd}      =  0   ),  # append .YYMMDD
  'hms'        => \\( \$opts->{hms}      =  0   ),  # append .YYMMDD-HHMMSS
  'strip'      => \\( \$opts->{strip}    =  0   ),  # remove any time extension
  'sep=s'      => \\( \$opts->{osp}      = "\."  ),  # old extension seperator
  'nsp=s'      => \\( \$opts->{nsp}      =  ""  ),  # new extension seperator
  'verbose+'   => \\( \$opts->{verbose}  =  0   ),  # display additional info
  'norun|n'    => \\( \$opts->{norun}    =  0   ),  # do not rename files
  'force!'     => \\( \$opts->{force}    =  0   ),  # force overwrite existing files
);
&showusage() if (\$opts->{help} >= 0);
END

eval $options;
&showusage() if ($getopt == 0); # result is 1 if no errors

############################################################

sub noext {
  my ( $long ) = @_;
  if ( $long !~  m/\Q$opts->{osp}\E/i ) {
    return($long);
   } else {
    return(substr($long, 0, rindex( $long, $opts->{osp} )-0));
  }
}

sub ext {
  my ( $long ) = @_;
  if ( $long !~  m/\Q$opts->{osp}\E/i ) {
    return($long);
   } else {
    return(substr($long, rindex($long, $opts->{osp})+1));
  }
}

sub basename {
  my ( $long ) = @_;
  return(substr($long, rindex($long, "/")+1));
}

sub dirname {
  my ( $long ) = @_;
  return(substr($long, 0, rindex($long, "/")+0));
}

sub fstat {
  my ( $fname ) = @_;

  my $self  = {};
  ( $self->{dev},   $self->{ino},   $self->{mode},  $self->{link},
    $self->{uid},   $self->{gid},   $self->{rdev},  $self->{size},
    $self->{atime}, $self->{mtime}, $self->{ctime}, $self->{blksize},
    $self->{blocks}
  ) = stat($fname);

  bless  $self;
  return $self;
}

sub stub_main();

# Validate options

  $opts->{nsp} = $opts->{osp} if ( ! $opts->{nsp} );

  $opts->{soe} = 0 if ( $opts->{strip} + $opts->{ymd} + $opts->{hms} == 1 );
  &showusage() if ( $opts->{strip} + $opts->{soe} + $opts->{ymd} + $opts->{hms} != 1 );

  my $maxlen = 0;
  foreach my $fn ( @ARGV ) {
    my $len = length($fn);
    $maxlen = $len if ( $len > $maxlen );
  }

  foreach my $oldname ( @ARGV ) {
    if ( -e $oldname ) {
      my $fs = fstat( $oldname );

      my $soe = $fs->{mtime};
      my $ymd = strftime("%Y%m%d",        gmtime($soe) );
      my $hms = strftime("%Y%m%d-%H%M%S", gmtime($soe) );

      my $ext = ext( $oldname );
      my $noext   = noext( $oldname );
      my $newname = $oldname;

         $newname = $noext if ( $ext =~ $soe );
         $newname = $noext if ( $ext =~ $ymd );
         $newname = $noext if ( $ext =~ $hms );

      $newname .= $opts->{nsp} if ( ! $opts->{strip} );
      $newname .= $soe if ( $opts->{soe});
      $newname .= $ymd if ( $opts->{ymd});
      $newname .= $hms if ( $opts->{hms});

      my $extlen = length($newname) - length($oldname);

      my $msg = "";
      $msg = "  !Already exists, no changes" if ( -e $newname && ! $opts->{force} );

      printf("%s: %*s -> %*s%s\n", $gv->NAME, $maxlen, $oldname, $maxlen+$extlen, $newname, $msg );

      if ( ! -e $newname || $opts->{force} ) {
        $cpmv->($oldname, $newname) if ( ! $opts->{norun} );
        utime $fs->{atime}, $fs->{mtime}, $newname;
      }
    }
  }

exit(0);

