# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::status 1.0

# Progress in range 0 to 1, for display in GUI
set ::status(progress) 0

# Formatted time remaining, for display in GUI
set ::status(time) ""

# Formatted status message, for display in GUI
set ::status(message) "Ready."

# current is the current progress to the total
# count is the total
# so, progress is always current/count
set ::status(current) 0
set ::status(count) 0

# Template used for constructing message.
# "CURRENT" and "COUNT" will be updated with the current values.
set ::status(template) "Ready."

# Time in milliseconds when process started
set ::status(start) 0

# Time in milliseconds at last update
set ::status(last) 0

# 1 if an on-going process is active and progress should be shown
# 0 if finished and no more progress needed
set ::status(active) 0

namespace eval ::l1pro::status {
    proc start {count msg} {
        set ::status(current) 0
        set ::status(count) [expr {$count}]
        set ::status(template) $msg
        set ::status(start) [clock milliseconds]
        set ::status(last) $::status(start)
        set ::status(active) 1

        after idle ::l1pro::status::update_message
    }

    proc progress {current count} {
        set current [expr {$current}]
        set count [expr {$count}]
        # Only update last if the progress has actually changed
        if {$current != $::status(current) || $count != $::status(count)} {
            set ::status(last) [clock milliseconds]
        }
        set ::status(current) $current
        set ::status(count) $count

        after idle ::l1pro::status::update_message
    }

    proc finished {} {
        after cancel ::l1pro::status::update_message
        after cancel ::l1pro::status::update_time

        set ::status(progress) 0
        set ::status(time) ""
        set ::status(message) "Ready."
        set ::status(active) 0
    }

    proc update_message {} {
        after cancel ::l1pro::status::update_message

        if {$::status(count)} {
            set ::status(progress) [expr \
                    {double($::status(current))/$::status(count)}]
        } else {
            set ::status(progress) 0
        }
        set ::status(message) [string map \
                [list CURRENT $::status(current) COUNT $::status(count)] \
                $::status(template)]

        after 250 ::l1pro::status::update_time
    }

    proc update_time {} {
        after cancel ::l1pro::status::update_time
        if {!$::status(active)} {return}

        after 250 ::l1pro::status::update_time

        if {$::status(progress) <= 0} {
            set ::status(time) "--:--:--"
            return
        }

        set basis [expr {$::status(last) - $::status(start)}]
        if {$basis <= 0} {
            set ::status(time) "--:--:--"
            return
        }

        set now [clock milliseconds]

        set predicted [expr {$basis/$::status(progress) * (1-$::status(progress))}]
        set elapsed [expr {$now - $::status(last)}]

        if {$elapsed > $predicted} {
            set ::status(time) "--:--:--"
            return
        }

        set remaining [expr {($predicted - $elapsed)/1000.}]
        set ::status(time) [format_remaining $remaining]
    }

    proc format_remaining {secs} {
        set secs [expr {int($secs)}]
        set S [expr {int($secs % 60)}]
        set M [expr {int(($secs/60) % 60)}]
        set H [expr {int($secs / 3600)}]
        format "%02d:%02d:%02d" $H $M $S
    }
}
