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
#   } else {
      # puts "DONE: $addr $sock"
#      puts $sock "done:"
   }
}

proc Service { sock addr } {
   global fdir jdir echo status

   # puts "Service: $sock $addr"
   if { [eof $sock] || [ catch { gets $sock line } ]} {
      close $sock
      # puts "Close echo($addr,$sock)"
      unset echo($addr,$sock)
   } else {
      # puts "Open echo($addr,$sock)"
      puts "RCVD: $addr $sock: $line"
      # puts "got $line"
      set lst  [ split $line " " ]
      set cmd  [ lindex $lst 0 ]
      set args [ lrange $lst 1 end ]

      # SERVER: Process command from client
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

         mv {
            set src [lindex $lst 1 ]
            set dst [lindex $lst 2 ]
            catch { exec $cmd $src $dst} res
            puts "Result: $cmd $src $dst->$res";      # local logging
            puts $sock "Result: $cmd $src $dst->$res"
         }

         default {
            if { [llength $lst] == 1 } {
               puts "length = 1"
               catch { exec $cmd } res
               puts "$cmd->$res";         # Local logging
               puts $sock "$cmd->$res"
            } else {
               puts "length > 1"
               set all []
               foreach arg $args {
                  set all [concat $all $arg]
               }
               puts "cmd: $cmd"
               puts "all: $all"
               # we don't really need to run anything received, except when testing
               # catch { exec $cmd $all } res
               # puts "$cmd->$res";      # local logging
               # puts $sock "$cmd->$res"


               # foreach arg $args {
               #    catch { exec $cmd $arg } res
               #    puts "$cmd->$res";      # local logging
               #    puts $sock "$cmd->$res"
               # }
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
      set sz [array size echo ]
      puts "We have $sz connection(s)!"

      # 120.0 addresses should sort before 192.168 addresses,
      # thus giving preference to localhost.  If you are on
      # a different network, your mileage may vary.
      set byaddr [ lsort [array names echo ]]

      foreach entry  $byaddr {
         # puts "Search : $entry"
         set lst [ split $entry ","]
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
   # puts "Open echo($addr, $sock)"
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
proc make_dirs {} {
   global jdir fdir wdir ddir;
   catch { exec mkdir -p $jdir }
   catch { exec mkdir -p $fdir }
   catch { exec mkdir -p $wdir }
   catch { exec mkdir -p $ddir }
}

#-----------------------------------------------------

puts "ARGV:  [lindex $argv 0]"
# invoke as: $0 server

if { $host eq "server" } {
   signal trap  [ list ALRM ] check_for_files
   make_dirs
   alarm 5
   open_server $port
} else {    # start as client
   # set sock [socket $host $port]
   set remote 0
   if { $host ne "localhost" } {
      set remote 1
      make_dirs
   }
   set sock [socket $host $port]
   fconfigure $sock -buffering line
   fileevent $sock readable [list client'read $sock]
   fileevent stdin readable [list client'send $sock]
   puts $sock "status ready"
}

#---------------- CLIENT Code-------------------------

proc client'read sock {
   global jdir wdir fdir ddir doall host remote
   if {[eof $sock]} {close $sock; exit}
   gets $sock line
   set lst [ split $line " "]
   set cmd [ lindex $lst 0 ]
   set args [ lrange $lst 1 end ]
   set myt [ clock format [clock seconds] -format "%H:%M:%S"]
   puts "$myt CMD: $cmd: $args"
   switch $cmd {
      file: {
         puts "line(file): $line"
         puts "args: $args"
         if { $remote == 1 } {
            puts "batcher.tcl: rsyncing $host:/$fdir/$args"
            catch { exec rsync -PHaqR $host:/$fdir/$args / } res
            puts "batcher.tcl: rsync complete"
         }
         if { $remote == 1 } {
            puts $sock "mv $fdir/$args $wdir"
         }
         catch { exec mv $fdir/$args $wdir } res
         if { $res > "" } {
            puts "res : $res"
         }
         set doall list
         puts $sock "status $args"
         catch { exec /opt/eaarl/lidar-processing/src/cmdline_batch $wdir/$args $host } res
         puts "cmdline_batch: completed"
         if { $res > "" } {
            puts "res : $res"
         }
         catch { exec mv $wdir/$args $ddir } res
         if { $remote == 1 } {
            puts $sock "mv $wdir/$args $ddir"
            puts "COMPLETED: $ddir/$args, removing"
            catch { exec rm  $ddir/$args } res
            puts         "rm $ddir/$args: $res"
         }
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
      Result: {
         # we don't need to do anything.
      }
      default {
         puts "line(default): $line"
      }
   }
}

proc client'send sock {
   global wdir doall remote host
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
      remote {
         puts "Remote: $remote: $host"
      }
      default {
         puts $sock $line
      }
   }
}
#------------------------------------------------------

vwait forever

