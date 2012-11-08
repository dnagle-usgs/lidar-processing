#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}
# exec /opt/alps/bin/tclsh "$0" ${1+"$@"}
# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

package require Tclx

# set host localhost
set host [lindex $argv 0]
set port 9900
set pdir /tmp/batch/prep
set jdir /tmp/batch/jobs
set fdir /tmp/batch/farm
set wdir /tmp/batch/work
set ddir /tmp/batch/done
set ldir /tmp/batch/logs

# global echo

#-----------------------------------------------------

proc get_file { sock addr } {
   global jdir fdir status assigned completed delta start log

   catch { exec ls $jdir } res
   # puts [llength $res]
   set fn [ lindex $res 0 ]
   if { [ llength $res] > 0 } {
      set myt [ clock format [clock seconds] -format "%H:%M:%S"]
      catch { exec mv $jdir/$fn $fdir } res
      puts $log "$myt send: $addr $sock ($fdir) $fn"; flush $log;
      puts "send: $addr $sock ($fdir) $fn"
      set status($sock) "Sent: $fn"
      puts $sock "file: $fn"

      # client stats
      set start($sock) [clock seconds]
      incr assigned($sock)

      alarm 3
#   } else {
      # puts "DONE: $addr $sock"
#      puts $sock "done:"
   }
}

proc Service { sock addr } {
   global fdir jdir echo status assigned completed delta start stop updated log
   set myt [ clock format [clock seconds] -format "%H:%M:%S"]

   # puts "Service: $sock $addr"
   if { [eof $sock] || [ catch { gets $sock line } ]} {
      close $sock
      # puts "Close echo($addr,$sock)"
      unset echo($addr,$sock)
   } else {
      # puts "Open echo($addr,$sock)"
      set updated 1
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
            puts $log "$myt Close echo($addr,$sock)"; flush $log;
            puts "Close echo($addr,$sock)"
            unset echo($addr,$sock)
         }

         Status {
            puts "Received status from $addr $sock: $args\n"
            set status($sock) $args
         }

         Skipping {
            # client failed to process 
            set stop($sock) [clock seconds]
            set tdelta [ expr $stop($sock) - $start($sock)]
            incr delta($sock) $tdelta
            puts $log "$myt Received skip on $args from $addr $sock after $tdelta\n"; flush $log;
            puts "Received skip on $args from $addr $sock after $tdelta\n"
         }

         Completed {
            # client stats
            set stop($sock) [clock seconds]
            incr completed($sock)
            set tdelta [ expr $stop($sock) - $start($sock)]
            incr delta($sock) $tdelta
            puts $log "$myt Received completed on $args from $addr $sock after $tdelta\n"; flush $log;
            puts "Received completed on $args from $addr $sock after $tdelta\n"
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
   global echo sock status assigned completed delta start stop updated

   set myt [ clock format [clock seconds] -format "%H:%M:%S"]
   puts -nonewline "$myt: Timer expired: "
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
         if { $updated } {
            if { $status($sock) ne "ready" } {
               puts "ADDR: $addr $sock -> $status($sock)"
            }
            set avg 0
            if { $completed($sock) > 0 } {
               set avg [ expr $delta($sock) / $completed($sock)]
            }
            puts "STAT: $addr $sock -> A:$assigned($sock)  C:$completed($sock)  T:$delta($sock)  a:$avg"
         }
         if { $status($sock) eq "ready" } {
            get_file $sock $addr
         }
      }
   } else {
      puts "We have 0 connections"
   }
   set updated 0
}
#------------------------------------------------------

proc server {sock addr port} {
   global jdir echo completed assigned delta start stop

   # Record client's information

   puts "Accept connection $sock from $addr on port $port"
   set echo($addr,$sock) [ list $addr $port ]
   # puts "Open echo($addr, $sock)"
   puts $sock "Open echo($addr, $sock)"
   set completed($sock) 0
   set assigned($sock)  0
   set delta($sock)     0
   set start($sock)     0
   set stop($sock)      0

   fconfigure $sock -buffering line

   # set connections($sock) sock

   # Set up a callback for when client sends data

   fileevent $sock readable [ list Service $sock $addr]
}

proc open_server { port } {
   global updated

   puts "Server started on port $port...\n"
   puts "STAT line shows:"
   puts "   A:  number of jobs Assigned"
   puts "   C:  number of jobs Completed"
   puts "   T:  total Time spent processing (in seconds)"
   puts "   a:  Average time spent processing each job\n"

   set s [ socket -server server $port ]
   set updated 1
   vwait forever
}

#-----------------------------------------------------
proc make_dirs {} {
   global jdir fdir wdir ddir ldir;
   catch { exec mkdir -p $pdir }
   catch { exec mkdir -p $jdir }
   catch { exec mkdir -p $fdir }
   catch { exec mkdir -p $wdir }
   catch { exec mkdir -p $ddir }
   catch { exec mkdir -p $ldir }
}

#-----------------------------------------------------

puts "ARGV:  [lindex $argv 0]"
# invoke as: $0 server

if { $host eq "server" } {
   signal trap  [ list ALRM ] check_for_files
   make_dirs
   alarm 5
   set myd [ clock format [clock seconds] -format "%Y-%m-%d_%H:%M:%S"]
   puts $myd
   if { [catch { set log [open "/tmp/batch/logs/$myd.log" w] } ] } {
      puts "Failed to create $myd logfile"
   } else {
      puts $log "Ouptut created"; flush $log
   }
   open_server $port
} else {    # start as client
   system sleep 2 # allow server to start when invoked from .screenrc
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
   puts $sock "Status ready"
   puts "Status Ready:"
   if { $remote == 1 } {
      puts "\nThis will create a copy of the tld files on the server for the"
      puts "necesary tiles using the exact same pathing.  Please verify that"
      puts "the base path is writable on this system."
      puts "\nPlease make sure to create any output directories as specified on"
      puts "the mbatch_process() cmdline.  The pathing must be EXACTLY the same"
      puts "as used on the server."
      puts "\nMost rsync warnings and errors can be ignored."
   }
}

#---------------- CLIENT Code-------------------------

proc client'read sock {
   global jdir wdir fdir ddir doall host remote assigned completed delta
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

         # check status sent
         puts "status $args"
         puts $sock "Status $args"

         set res "";
         if { $remote == 1 } {
            puts "batcher.tcl: rsyncing $host:/$fdir/$args"
            catch { exec rsync -PHaqRk --no-t $host:/$fdir/$args / } res
            if { $res > "" } {      # display errors
               puts "res1: $res"
               # retry once
               system sleep 2
               catch { exec rsync -PHaqRk --no-t $host:/$fdir/$args / } res
            }
         }

         if { $res > "" } {      # give the job back, don't do any processing
                                 # we should only be here if the rsync failed
            puts "RES1: $res"
            puts $sock "mv $fdir/$args $jdir"
            puts $sock "Skipping $args"
            puts $sock "Status ready"
         }  else {               # process the tile

            if { $remote == 1 } {# tell foreman we're working on it.
               puts "batcher.tcl: rsync complete"
               puts $sock "mv $fdir/$args $wdir"
            }

            catch { exec mv $fdir/$args $wdir } res

            if { $res > "" } {
               puts "res2: $res"
            }

            set doall list
            catch { exec /opt/alps/lidar-processing/batcher/cmdline_batch $wdir/$args $host } res
            puts "cmdline_batch: completed"
            if { $res > "" } {
               puts "res3: $res"
            }
            catch { exec mv $wdir/$args $ddir } res
            if { $remote == 1 } {
               puts $sock "mv $wdir/$args $ddir"
               puts "COMPLETED: $ddir/$args, removing"
               catch { exec rm  $ddir/$args } res
               puts         "rm $ddir/$args: $res"
            }
            puts $sock "Completed $args"
            puts $sock "Status ready"
            puts "Completed $args\n"

            if { $doall > "" } {
               puts $sock $doall
            }
         }
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

