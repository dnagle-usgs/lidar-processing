# vim: set ts=4 sts=4 sw=4 ai sr et:
package provide yorick 1.0

package require Expect
package require fileutil
package require snit

namespace eval ::yorick {
    namespace export ystr

    proc ystr {str} {
        return [string map {
                \" \\\"
                \\ \\\\
            } $str]
    }

    variable fifo_counter -1
    variable startdate [clock format [clock seconds] -format %y%m%d]
    variable tmpdir [file join [::fileutil::tempdir] ytk]

    exp_exit -onexit ::yorick::destroy_fifos_all
}

proc ::yorick::sanitize_vname var {
    if {[string is digit -strict [string index $var 0]]} {
        set var v$var
    }
    return [regsub -all {[^A-Za-z0-9_]+} $var _]
}

proc ::yorick::create_fifos {} {
    variable fifo_counter
    variable tmpdir
    variable startdate
    set mkfifo [auto_execok mkfifo]
    if {$mkfifo eq ""} {
        error "mkfifo unavailable"
    }

    file mkdir $tmpdir
    set fifo_id $startdate.[pid].[incr fifo_counter]

    set yor_tcl_fn [file join $tmpdir $fifo_id.tcl]
    set tcl_yor_fn [file join $tmpdir $fifo_id.yor]

    if {[file exists $yor_tcl_fn] || [file exists $tcl_yor_fn]} {
        error "named pipe exists prior to creation"
    }

    set result [list]
    foreach fn [list $yor_tcl_fn $tcl_yor_fn] {
        exec {*}$mkfifo -m uog+rw $fn
        set fifo [open $fn "r+"]
        fconfigure $fifo -buffering line -blocking 0
        lappend result $fifo $fn
    }

    return $result
}

proc ::yorick::destroy_fifos_all {} {
    variable fifo_counter
    variable tmpdir
    variable startdate
    while {$fifo_counter >= 0} {
        set fifo_id $startdate.[pid].$fifo_counter
        set fifo_id [pid].$fifo_counter

        set yor_tcl_fn [file join $tmpdir $fifo_id.tcl]
        set tcl_yor_fn [file join $tmpdir $fifo_id.yor]

        catch [list file delete $yor_tcl_fn]
        catch [list file delete $tcl_yor_fn]

        incr fifo_counter -1
    }
    catch [list file delete $tmpdir]
}

proc ::yorick::destroy_fifos {args} {
    variable tmpdir
    if {[llength $args] % 2} {
        error "Must provide fifos as pairs of FIFO FN"
    }
    foreach {fifo fn} $args {
        catch [list close $fifo]
        catch [list file delete $fn]
        catch [list file delete $tmpdir]
    }
}

proc ::yorick::spawn {yor_tcl_fn tcl_yor_fn args} {
    array set opts {-rlterm 0 -rlwrap 0}
    array set opts $args

    set spawner {cmd {
        set cmd [list spawn -noecho {*}$cmd]
        set result [catch $cmd]
        if {!$result} {
            expect "Copyright" {
                return [list $spawn_id [array get spawn_out]]
            }
        }
        return ""
    }}

    set result ""
    set cmd ""

    set yorick [auto_execok yorick]
    set rlterm [auto_execok rlterm]
    set rlwrap [auto_execok rlwrap]

    if {$yorick eq ""} {
        error "Unable to find Yorick"
    }

    lappend yorick -i ytk.i $yor_tcl_fn $tcl_yor_fn

    # Try rlterm first, if enabled
    if {$result eq "" && $opts(-rlterm) && $rlterm ne ""} {
        set result [apply $spawner [concat $rlterm $yorick]]
    }
    # Try rlwrap next, if enabled
    if {$result eq "" && $opts(-rlwrap) && $rlwrap ne ""} {
        set switches [list -c -b "'(){}\[],+=&^%$#@;|\""]
        set dupes [list -D $::_ytk(rlwrap_nodupes)]
        # Try first with -D option, then without (for older rlwraps)
        set result [apply $spawner [concat $rlwrap $switches $dupes $yorick]]
        if {$result eq ""} {
            set result [apply $spawner [concat $rlwrap $switches $yorick]]
        }
    }
    # Try vanilla Yorick last
    if {$result eq ""} {
        set result [apply $spawner $yorick]
    }

    return $result
}

snit::type ::yorick::session {
    variable connected 0
    variable spawn_id ""
    variable spawn_out -array {}
    variable ytk_fifo
    variable ytk_fifo_name
    variable tky_fifo
    variable tky_fifo_name

    constructor args {
        set fifos [::yorick::create_fifos]
        lassign $fifos ytk_fifo ytk_fifo_name tky_fifo tky_fifo_name
        fileevent $ytk_fifo readable [mymethod ytk_fifo_fileevent]
        ::log_user 0
        set result [::yorick::spawn $ytk_fifo_name $tky_fifo_name]
        ::log_user 1
        if {$result ne ""} {
            set spawn_id [lindex $result 0]
            array set spawn_out [lindex $result 1]
            set connected 1
        }
    }

    destructor {
        $self send "\r__quit\r"
        ::yorick::destroy_fifos $ytk_fifo $ytk_fifo_name $tky_fifo $tky_fifo_name
    }

    method send args {
        ::exp_send -i $spawn_id {*}$args
    }

    method expect args {
        ::log_user 0
        ::expect -i $spawn_id {*}$args
        ::log_user 1
    }

    method ytk_fifo_fileevent {} {
        set cmd [gets $ytk_fifo]

        if {$cmd ne ""} {
            if {[catch {uplevel #0 $cmd} errcode]} {
                ::send_user "\r"
                ::send_user "*** Ytk Error in session $spawn_id: $cmd\r"
                ::send_user "*** $errcode\r"
            }
            update idletasks
        }
    }

    method pid {} {
        return [exp_pid -i $spawn_id]
    }
}
