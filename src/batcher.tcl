#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}
# exec /opt/eaarl/bin/tclsh "$0" ${1+"$@"}
# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

package require Tclx

# set host localhost
set host [lindex $argv 0]
set port 9900
set jdir /tmp/batch/jobs
set fdir /tmp/batch/farm
set wdir /tmp/batch/work
set ddir /tmp/batch/done

# global echo

#-----------------------------------------------------

proc get_file { sock addr } {
   global jdir fdir 

   catch { exec ls $jdir } res
   # puts [llength $res]
   set fn [ lindex $res 0 ]
   if { [ llength $res] > 0 } {
      catch { exec mv $jdir/$fn $fdir } res
      puts "sending file: ($fdir) $fn"
      puts $sock "file: $fn"
      alarm 3
   } else {
      puts "DONE: $addr $sock"
      puts $sock "done:"
   }
}

proc Service { sock addr } {
   global fdir jdir echo status

   # puts "Service: $sock $addr"
   if { [eof $sock] || [ catch { gets $sock line } ]} {
      close $sock
      puts "Close echo($addr,$sock)"
      unset echo($addr,$sock)
   } else {
      # puts "Open echo($addr,$sock)"
      puts "RCVD: $addr $sock: $line"
      # puts "got $line"
      set lst  [ split $line " " ]
      set cmd  [ lindex $lst 0 ]
      set args [ lrange $lst 1 end ]

      # Process command from client
      switch $cmd {
         list {
            get_file $sock $addr
         }

         quit {
            puts "got close request on $sock"
            close $sock
            puts "Close echo($addr,$sock)"
            unset echo($addr,$sock)
         }

         status {
            puts "Received status from $addr $sock: $args\n"
            set status($sock) $args
         }

         default {
            if { [llength $lst] == 1 } {
               puts "length = 1"
               catch { exec $cmd } res
               puts $cmd->$res         # local logging
               puts $sock $cmd->$res
            } else {
               puts "length > 1"
               foreach arg $args {
                  catch { exec $cmd $arg } res
                  puts $cmd->$res      # local logging
                  puts $sock $cmd->$res
               }
            }
         }
      }
   }
}

#------------------------------------------------------
proc check_for_files { } {
   global echo sock status

   set myt [ clock format [clock seconds] -format "%H:%M:%S"]
   puts -nonewline "\n$myt: Timer expired: "
   alarm 10 ; # reset the clock

   # puts "echo :  [lindex $echo 0]"
   if  { [array exists echo] } {
      set sz [array size echo ];
      puts "We have $sz connections!"
      set elem [ array startsearch echo ]
      for { set i 1 } { $i <= $sz } { incr i } {
         # puts "Search : $elem"
         set child [ array nextelement echo $elem ]
         # puts "child :  $child"
         set lst [ split $child ","]
         set addr [ lindex $lst 0 ]
         set sock [ lindex $lst 1 ]
         puts "ADDR: $addr $sock -> $status($sock)"
         if { $status($sock) eq "ready" } {
            get_file $sock $addr
         }
      }
   }

}
#------------------------------------------------------

proc server {sock addr port} {
   global jdir echo 

   # Record client's information

   puts "Accept connection $sock from $addr on port $port"
   set echo($addr,$sock) [ list $addr $port ]
   puts "Open echo($addr, $sock)"
   puts $sock "Open echo($addr, $sock)"

   fconfigure $sock -buffering line

   # set connections($sock) sock

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
   catch { exec mkdir -p $jdir }
   catch { exec mkdir -p $fdir }
   catch { exec mkdir -p $wdir }
   catch { exec mkdir -p $ddir }
   signal trap  [ list ALRM ] check_for_files
   alarm 5
   open_server $port
} else {    # start as client
   # set sock [socket $host $port]
   set sock [socket $host $port]
   fconfigure $sock -buffering line
   fileevent $sock readable [list client'read $sock]
   fileevent stdin readable [list client'send $sock]
   puts $sock "status ready"
}

#---------------- CLIENT Code-------------------------

proc client'read sock {
   global jdir wdir fdir ddir doall
   if {[eof $sock]} {close $sock; exit}
   gets $sock line
   set lst [ split $line " "]
   set cmd [ lindex $lst 0 ]
   set args [ lrange $lst 1 end ]
   switch $cmd {
      file: {
         puts "line(file): $line"
         puts "args: $args"
         catch { exec mv $fdir/$args $wdir } res
         if { $res > "" } {
            puts "res : $res"
         }
         set doall list
         puts $sock "status $args"
         catch { exec /opt/eaarl/lidar-processing/src/cmdline_batch $wdir/$args } res
         if { $res > "" } {
            puts "res : $res"
         }
         catch { exec mv $wdir/$args $ddir } res
         if { $doall > "" } {
            puts $sock $doall
         }
         puts $sock "status ready"
         puts "Completed $args\n"
      }

      done: {
         set doall ""
         puts "line(done): $line"
      }
      default {
         puts "line(default): $line."
      }
   }
}

proc client'send sock {
   global wdir doall
   gets stdin line

   switch $line {
       exit {
         exit 0
      }
      work {
         catch { exec ls $wdir } res
         puts "work: $res"
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

