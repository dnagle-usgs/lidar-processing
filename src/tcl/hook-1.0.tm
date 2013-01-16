# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide hook 1.0

# The hooks provided by this package are similar to those provided in Yorick by
# hook.i. However, there are a few notable differences.
#
#   - In Yorick, only a function name could be provided. In Tcl, a command
#     prefix can be provided. This will often be a proc name. However, it could
#     also be something wrapped by "apply" or a command prefix.
#
#   - In Yorick, all hooks received an "ENV" argument. In Tcl, each hook is
#     invoked with a unique call signature and may receive any number of
#     arguments. It thus takes a bit more diligence to make sure that the hook
#     invocations and the hook procs match up. However, unlike in Yorick, Tcl
#     code often relies on variables kept well-organized in namespaces, which
#     reduces the need to pass arguments.

namespace eval ::hook {
    if {![info exists hooks]} {
        variable hooks {}
        variable priorities {}
    }

    proc cmp {hook_name a b} {
        variable priorities
        set a1 [dict get $priorities $hook_name $a]
        set b1 [dict get $priorities $hook_name $b]
        expr {$a1 - $b1}
        if {$a1 < $b1} {return -1}
        expr {$a1 > $b1}
    }

    proc prioritize {hook_name} {
        variable hooks
        dict set hooks $hook_name [lsort -real \
                -command [list ::hook::cmp $hook_name] \
                [dict get $hooks $hook_name]]
    }

    proc add {hook_name cmd {priority 0}} {
        variable hooks
        variable priorities
        if {
            ![dict exists $hooks $hook_name] ||
            $cmd ni [dict get $hooks $hook_name]
        } {
            dict lappend hooks $hook_name $cmd
        }
        dict set priorities $hook_name $cmd $priority
        prioritize $hook_name
    }

    proc remove {hook_name cmd} {
        variable hooks
        variable priorities
        dict unset priorities $hook_name $cmd
        if {![dict exists $hooks $hook_name]} return
        set cmds [dict get $hooks $hook_name]
        set idx [lsearch -exact $cmds $cmd]
        if {$idx < 0} return
        if {[llength $cmds] == 1} {
            dict set hooks $hook_name [list]
            return
        }
        dict set hooks $hook_name [lreplace $cmds $idx $idx]
        prioritize $hook_name
    }

    proc query {hook_name} {
        variable hooks
        if {![dict exists $hooks $hook_name]} return {}
        dict get $hooks $hook_name
    }

    proc has {hook_name} {
        expr {[llength [query $hook_name]] > 0}
    }

    proc invoke {hook_name args} {
        variable hooks
        if {![dict exists $hooks $hook_name]} return
        foreach cmd [dict get $hooks $hook_name] {
            uplevel 1 [list {*}$cmd {*}$args]
        }
    }

}
