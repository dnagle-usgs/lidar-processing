# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide handler 1.0

# The handlers provided by this package are similar to those provided in Yorick by
# handler.i. However, there are a few notable differences.
#
#   - In Yorick, only a function name could be provided. In Tcl, a command
#     prefix can be provided. This will often be a proc name. However, it could
#     also be something wrapped by "apply" or a command prefix.
#
#   - In Yorick, all handlers received an "ENV" argument. In Tcl, each handler is
#     invoked with a unique call signature and may receive any number of
#     arguments. It thus takes a bit more diligence to make sure that the handler
#     invocations and the handler procs match up. However, unlike in Yorick, Tcl
#     code often relies on variables kept well-organized in namespaces, which
#     reduces the need to pass arguments.

namespace eval ::handler {
    if {![info exists handlers]} {
        variable handlers {}
    }

    proc set {handler_name cmd} {
        variable handlers
        dict set handlers $handler_name $cmd
    }

    proc clear {handler_name} {
        variable handlers
        dict unset handlers $handler_name
    }

    proc get {handler_name} {
        variable handlers
        if {![dict exists $handlers $handler_name]} return {}
        dict get $handlers $handler_name
    }

    proc has {handler_name} {
        variable handlers
        dict exists $handlers $handler_name
    }

    proc invoke {handler_name args} {
        variable handlers
        if {![dict exists $handlers $handler_name]} {
            error "no handler set for $handler_name"
        }
        set cmd [dict get $handlers $handler_name]
        uplevel 1 [list {*}$cmd {*}$args]
    }

}
