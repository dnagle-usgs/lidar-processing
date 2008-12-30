#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}
# exec /opt/eaarl/bin/tclsh "$0" ${1+"$@"}
# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

# set host localhost
set host [lindex $argv 0]
set port 9900
set jdir /tmp/batch/jobs
set wdir /tmp/batch/work
set ddir /tmp/batch/done

# global echo

#-----------------------------------------------------


proc Service { sock addr } {
   global jdir echo connections

   puts "Service: $sock $addr"
   if { [eof $sock] || [ catch { gets $sock line } ]} {
      close $sock
      puts "Close $echo(addr,$sock)"
      unset echo(addr,$sock)
   } else {
      puts "Open $echo(addr,$sock)"
      puts "$addr: $line"
      # puts "got $line"
      set lst  [ split $line " " ];
      set cmd  [ lindex $lst 0 ];
      set args [ lrange $lst 1 end ];

      # Process command from client
      switch $cmd {
         list {
            catch { exec ls $jdir } res;
            puts [llength $res];
            set fn [ lindex $res 0 ];
            if { [ llength $res] > 0 } {
               puts $sock "file: $fn";
            } else {
               puts $sock "done:";
            }
         }

         default {
            if { [llength $lst] == 1 } {
               puts "length = 1"
               catch { exec $cmd } res
               puts $cmd->$res ;# local logging
               puts $sock $cmd->$res
            } else {
               puts "length > 1"
               foreach arg $args {
                  catch { exec $cmd $arg } res;
                  puts $cmd->$res ;# local logging
                  puts $sock $cmd->$res
               }
            }
         }
      }
   }
}
#------------------------------------------------------


proc server {sock addr port} {
   global jdir echo connections

   # Record client's information

   puts "Accept connection $sock from $addr on port $port";
   set echo(addr,$sock) [ list $addr $port ]
   # puts "Open $echo(addr, $sock)"

   fconfigure $sock -buffering line

   # set connections($sock) $sock

   # Set up a callback for when client sends data

   fileevent $sock readable [ list Service $sock $addr]
}

proc open_server { port } {
   puts "Server started on port $port...\n"
   set s [ socket -server server $port ]
   vwait forever
}
#-----------------------------------------------------

puts "ARGV:  [lindex $argv 0]"
# invoke as: $0 server

if { $host eq "server"} {
   open_server $port
} else {
   # set sock [socket $host $port]
   set sock [socket $host $port]
   fconfigure $sock -buffering line
   fileevent $sock readable [list client'read $sock]
   fileevent stdin readable [list client'send $sock]
}
#-----------------------------------------------------
proc client'read sock {
   global jdir wdir ddir doall
   if {[eof $sock]} {close $sock; exit}
   gets $sock line
   set lst [ split $line " "];
   set cmd [ lindex $lst 0 ];
   set args [ lrange $lst 1 end ];
   switch $cmd {
      file: {
         puts "line: $line"
         puts "args: $args";
         catch { exec mv $jdir/$args $wdir } res;
         if { $res > "" } {
            puts "res : $res";
         }
         catch { exec /opt/eaarl/lidar-processing/src/cmdline_test $wdir/$args } res
         if { $res > "" } {
            puts "res : $res";
         }
         catch { exec mv $wdir/$args $ddir } res;
         if { $doall > "" } {
            puts $sock $doall
         }
      }
      default {
         set doall "";
         puts "line: $line"
      }
   }
}

proc client'send sock {
   global wdir doall
   gets stdin line

   switch $line {
       exit {
         exit 0;
      }
      work {
         catch { exec ls $wdir } res;
         puts "work: $res";
      }
      run {
         set doall list
         puts "cmd: $doall"
         puts $sock $doall
      }
      default {
         puts $sock $line
      }
   }
}
#------------------------------------------------------

vwait forever

