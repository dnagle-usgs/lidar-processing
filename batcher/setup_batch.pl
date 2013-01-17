#!/usr/bin/perl -w

# Prompts for the hostname of the master ALPS server to use and then
# creates the screenrc files to invoke both a master and slave sessions.
# By default the files are stored in /opt/alps/etc and then be rsynced
# to other systems.  The number of slave processes to create is determined
# by checking how many cpus are available.
#
# When invoked with an "initd" arg (from /etc/init.d/batcher), no prompts
# for input are given, but the screenrc files are regenerated with the
# current number of cpus available.  screen is then invoked and put into
# the background
#
# WARNING:  too many simultaneous unauthenticated ssh/rsync connections
# to the foreman may cause refused connections.  This will most likely
# occur when all of the systems are initially trying to get their first
# jobs.  To correct this problem, edit:
#
#   /etc/ssh/sshd_config   (or wherever it lives on your system)
#
# and look for the line:
#   #MaxStartups 10:30:60
# uncomment it and change it something like:
#   MaxStartups 40:30:100
# set the first number to be slightly greater than the number of expected
# workers and the last number a couple times higher.

use Getopt::Long;
use strict;

# Various constants.  You may need to adjust $EAARL if you chose to install
# ALPS in some other place.

my $EAARL         = "/opt/alps";
my $ETC           = "$EAARL/etc";
my $MASTER_file   = "$ETC/ALPS_master";
my $SCREEN_master = "$ETC/.screenrc-batch-master";
my $SCREEN_slave  = "$ETC/.screenrc-batch-slave";
my $NCPU          = `grep -c "^vendor" /proc/cpuinfo`;
my $SCREEN        = "/usr/bin/screen";
my $RUN="";
my $LOG_PATH      = "/tmp/batch/screen";

my $getopt;
my $opt_help;
my $verbose;
my $options;
my $initd;
my $demo;

my $MSTR;
my $TOP;
my $SERVER;
my $SLAVE;
my $BOT;

############################################################

sub showusage {
  print <<eof;
$0 [-[no]help]

creates .screenrc files for both a master and slave alps batch sessions.

[-demo ] : when used with initd, doesn't start screen but shows the command
           that will be used.
[-initd] : invoked from initd, does not prompt the user for the server
           name, but regenerates the files to match the number of processors
           available on this system.  also starts the screen sessions.

[-nohelp]: better than nothing

eof
# print out actual GetOptions() used if -nohelp is specified.
printf("\n%s\n", $options) if ( $opt_help == 0 );

  exit(0);
}

 # defaults are supplied in GetOptions itself
# use: perldoc getopt::long           # to get the manpage #

$options = <<end;
\$getopt = GetOptions (
  'help!'      => \\( \$opt_help = -1   ),  # use -nohelp to show this
  'verbose'    => \\( \$verbose  =  0   ),  #
  'initd'      => \\( \$initd    =  0   ),  # invoked from initd
  'demo'       => \\( \$demo     =  0   ),  # don't start screen, but show cmd
);
&showusage() if (\$opt_help >= 0);
end

eval $options;
&showusage() if ($getopt == 0); # result is 1 if no errors


############################################################
sub prompt {
  local( our $str ) = @_;
  print STDOUT $str;
  local(our $answer) = scalar(<stdin>);
  chop $answer;
  return($answer);
}

sub yorn {
  local( our $str ) = @_;
  print STDOUT $str;
  local( our $answer) = scalar(<stdin>);
  $answer =~ /^y/i;
}

############################################################

$RUN="echo" if ( $demo );

printf("ARGC: %d\n", $#ARGV ) if ( $verbose );

# using options causes problems from the actual initd script.
$initd = 1 if ( $#ARGV >= 0 && $ARGV[0] =~ "initd" );

my $update = 1;

printf("NCPU = %d\n", $NCPU ) if ( $verbose );

system("mkdir -p $LOG_PATH");

system("mkdir -p $ETC") if ( ! -e $ETC );
if ( -e $MASTER_file ) {
  $MSTR = `cat $MASTER_file`;
  if ( ! $initd ) {
    printf("\nCurrent Master ALPS Server: %s\n", $MSTR);
    $update = 0
      if ( ! &yorn("Do you want to change (y/n)? ") );
  } else {
    $update = 0;
  }
} else {
  exit(-1) if ( $initd );  # no master, stop now
}

if ( $update ) {
  $MSTR = prompt("Master ALPS Server: ");
  printf("Master: %s\n", $MSTR);
  open (OUT, ">$MASTER_file") || die("unable to open $MASTER_file\n");
  print OUT $MSTR;
  close(OUT);
}

############################################################

$TOP = <<HERE_TARGET;
# gnu screen configuration file
#
shell tcsh

autodetach            on              # default: on
crlf                  off             # default: off
deflogin              off             # default: on
hardcopy_append       on              # default: off
startup_message       off             # default: on
vbell                 off             # default: ???

# ===============================================================
# variables - number values
# ===============================================================
  defscrollback         1000            # default: 100
  silencewait           15              # default: 30

hardstatus alwayslastline "%-Lw%{= BW}%50>%f* %t%{-}%+Lw%< %=[%c %D, %d/%m/%y]"

# yellow on blue
sorendition 02 34 

# sorendition 10 99 # default!
# sorendition 02 40 # green  on black
# sorendition 02 34 # yellow on blue
# sorendition    rw # red    on white
# sorendition    kg # black  on bold green

activity              "activity in %n (%t) [%w:%s]~"
# bell:         this message *includes* a "beep" with '~'.
bell                  "bell     in %n (%t) [%w:%s]~"

chdir /opt/alps/lidar-processing
HERE_TARGET

$SERVER = <<HERE_TARGET;
setenv SERVER localhost
screen -t SERVER  ./batcher/batcher.tcl server
logfile $LOG_PATH/foreman.log
log on
HERE_TARGET

$SLAVE = <<HERE_TARGET;
setenv SERVER $MSTR
HERE_TARGET

$BOT = <<HERE_TARGET;
# screen -t client1 ./batcher/batcher.tcl \$SERVER
screen -t tcsh
next
multiuser on
acladd wright
acladd mitchell
acladd rmitchel
acladd rtroche
acladd dnagle
acladd ckranenburg
acladd afredericks
acladd mpal

# detach
# invoke as : screen -d -m -c ~/.screenrc_batch_master
HERE_TARGET

############################################################

my $i;

$update = 1;
if ( ! $initd && -e $SCREEN_master ) {
  $update = 0
    if ( ! &yorn("do you want to update\n\t$SCREEN_master (y/n)? ") );
}

if ( $update ) {
  open (OUT, ">$SCREEN_master") || die("Unable to open $SCREEN_master\n");
  print OUT $TOP;
  print OUT $SERVER;
  for ( $i=1; $i <= $NCPU; ++$i ) {
    printf OUT ("screen -t sub%d ./batcher/batcher.tcl \$SERVER\n", $i);
    printf OUT ("logfile $LOG_PATH/worker-%d.log\n", $i);
    printf OUT ("log on\n");
  }
  print OUT $BOT;
  close(OUT)
}


$update = 1;
if ( ! $initd && -e $SCREEN_slave ) {
  $update = 0
    if ( ! &yorn("Do you want to update\n\t$SCREEN_slave (y/n)? ") );
}

if ( $update ) {
  open (OUT, ">$SCREEN_slave") || die("Unable to open $SCREEN_slave\n");
  print OUT $TOP;
  print OUT $SLAVE;
  for ( $i=1; $i <= $NCPU; ++$i ) {
    printf OUT ("screen -t sub%d ./batcher/batcher.tcl \$SERVER\n", $i);
    printf OUT ("logfile $LOG_PATH/worker-%d.log\n", $i);
    printf OUT ("log on\n");
  }
  print OUT $BOT;
  close(OUT)
}

if ( $initd ) {

  my $hostname = `hostname -s`;
  my $rc;
  chop $hostname;
  
  print `/bin/echo grep $hostname $ETC/ALPS_master` if ( $verbose );

  $rc = system("grep $hostname $ETC/ALPS_master > /dev/null");

  if ( ! $rc ) { # rc is 0 on success
    printf("Starting master\n") if ( $verbose );
    print `$RUN $SCREEN -d -m -c $ETC/.screenrc-batch-master`;
  } else {
    # !!!!!!! Check and wait for SERVER to become available
    # #####################################################
    # XYZZY
    # #####################################################
    printf("Starting slave\n")  if ( $verbose );
    print `$RUN $SCREEN -d -m -c $ETC/.screenrc-batch-slave`;
  }
  system("(echo -n screen -x amps/; screen -ls | grep Multi | cut --fields=2) > $EAARL/screen.sh");
  printf("exiting\n") if ( $verbose );
}
