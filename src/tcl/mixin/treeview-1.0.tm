# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin::treeview 1.0
package require imglib
package require snit

namespace eval ::mixin::treeview {}

# treeview::sortable <path> ?options...?
#     A wrapper around the ttk::treeview widget that makes columns sortable.
#
#     This can be used to create a new treeview widget, OR to add a "mixin" to
#     an existing widget.
#
#     Code somewhat adapted from Tcl/Tk demo mclist.tcl
snit::widgetadaptor ::mixin::treeview::sortable {
    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::treeview
        }
        $self configurelist $args
        # Force the columns to all get configured
        $self SetColumns -columns [$hull cget -columns]
    }

    delegate method * to hull
    delegate option * to hull

    # Override the -columns option so that we can tags columns for sorting
    option {-columns columns Columns} -default {} \
        -configuremethod SetColumns \
        -cgetmethod GetColumns

    # Pass the configuration through and update columns to sort
    method SetColumns {option value} {
        $hull configure $option $value

        foreach col $value {
            $self heading $col -command [mymethod Sortby $col 0]
        }
    }

    # Pass through, retrieve from hull
    method GetColumns option {
        return [$hull cget $option]
    }

    # Core method to enable sorting
    method Sortby {col direction} {
        set data {}
        foreach row [$self children {}] {
            lappend data [list [$self set $row $col] $row]
        }

        set dir [expr {$direction ? "-decreasing" : "-increasing"}]
        set r -1

        # Now resuffle rows into sorted order
        foreach info [lsort -dictionary -index 0 $dir $data] {
            $self move [lindex $info 1] {} [incr r]
        }

        # Put all other headings back to default sort order
        foreach column [$self cget -columns] {
            $self heading $column -command [mymethod Sortby $column 0]
        }

        # Switch the heading so that it sorts in opposite direction next time
        $self heading $col -command [mymethod Sortby $col [expr {!$direction}]]
    }
}

snit::widgetadaptor ::mixin::treeview::notebook {
    delegate method * to hull
    delegate option * to hull

    option {-notebook notebook Notebook} -default {}
    option {-tabid tabid Tabid} -default tabid

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::treeview
            $self configure -selectmode browse -columns {tabid} \
                    -displaycolumns {} -show tree
        }
        $self configure {*}$args

        bind $self <<TreeviewSelect>> [mymethod TreeviewSelect]
    }

    method TreeviewSelect {} {
        set nb [$self cget -notebook]
        if {$nb eq ""} return

        set sel [$self selection]
        if {[llength $sel] != 1} {return}
        set item [lindex $sel 0]

        set cols [$self cget -columns]
        set col [lsearch -exact $cols [$self cget -tabid]]
        if {$col == -1} {return}

        set tabid [lindex [$self item $item -values] $col]
        if {$tabid eq ""} {return}

        $nb select $tabid
    }

}

# ::mixin::treeview::tooltips
#   This package adds tooltip functionality to a ttk::treeview widget. It adds
#   one public subcommand: tooltip. This is a wrapper around ::misc::tooltip
#   that allows you to specify tooltips associated with rows, columns, cells,
#   or tags.
#
#   The tooltip subcommand has three options it knows about: -item, -column,
#   -tag. Other options are passed through as-is to ::misc::tooltip. If you do
#   not use any of the three options, you will set the default tooltip that
#   will be used when there is not a more specific tooltip available. Using
#   -item will associate a tooltip with an item (row), -column with a column,
#   and -tag with a tag. To associate a tooltip with a cell, use both -item and
#   -column together. (It is an error to use -tag with either of -item or
#   -column.)
#
#   When using -column, use #0 for the tree column. For other columns, use the
#   symbolic name.
#
#   When using -item, use {} for the headings. For other items, use the item
#   identifier.
#
#   The package always adds an option, -tippriority. This specifies the
#   priority order to use when trying to locate a tooltip, from low priority to
#   high. The default -tippriority is {column row tag cell}. If you change the
#   -tippriority, you must provide a list with those four values. If you omit
#   any values, they will be placed at lowest priority in an arbitrary order.
#   It is an error to include additional values. Note that the very lowest
#   priority is always the default tooltip (set by not using -item, -column, or
#   -tag).
#
#   When using this mixin, you should not use ::misc::tooltip or
#   ::tooltip::tooltip directly on the treeview as any tooltip that you set
#   will be clobbered.
snit::widgetadaptor ::mixin::treeview::tooltips {
    delegate method * to hull
    delegate option * to hull

    option -tippriority {column row tag cell}

    variable tips {default {""} column {} row {} tag {} cell {}}
    variable last ""

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::treeview
        }
        $self configure {*}$args
        bind $win <Motion> +[mymethod TooltipMotion %x %y]
    }

    method tooltip {args} {
        if {![llength $args]} {
            error "tooltip requires at least one arg: msg"
        }
        set message [lindex $args end]
        set args [lrange $args 0 end-1]

        set has [list apply [list {key} {
            upvar 1 args args
            return [dict exists $args -$key]
        }]]
        set pop [list apply [list {key} {
            upvar 1 args args
            set val [dict get $args -$key]
            dict unset args -$key
            return $val
        }]]
        set update [list apply [list args {
            upvar 1 args opts message msg
            ::misc::tooltip::resolve_message opts msg
            if {$msg eq ""} {
                uplevel 1 [list dict unset tips {*}$args]
            } else {
                uplevel 1 [list dict set tips {*}$args $msg]
            }
        }]]

        if {[{*}$has tag]} {
            if {[{*}$has item] || [{*}$has column]} {
                error "cannot use -item or -column with -tag"
            }
            set tag [{*}$pop tag]
            {*}$update tag $tag
        } elseif {[{*}$has item] && [{*}$has column]} {
            set item [{*}$pop item]
            set column [{*}$pop column]
            {*}$update cell $item $column
        } elseif {[{*}$has item]} {
            set item [{*}$pop item]
            {*}$update row $item
        } elseif {[{*}$has column]} {
            set column [{*}$pop column]
            {*}$update column $column
        } else {
            ::misc::tooltip::resolve_message args message
            dict set tips default $message
        }
        # This makes sure the user doesn't get the tips dict as a return value
        return
    }

    # This is a slightly messy procedure that dips into the private workings of
    # the tooltip library. If the tooltip library ever changes, this may break.
    method TooltipSet {tip} {
        # If the new tooltip matches the previous tooltip, we don't need to do
        # anything. Otherwise, update the tooltip.
        if {$tip eq $last} {return}
        ::tooltip::hide
        ::tooltip::tooltip $win $tip
        set last $tip

        # Borrow the logic from tooltip::menuMotion for how to properly hide
        # any existing tooltip and schedule the new one for visibility.
        variable ::tooltip::G
        if {!$G(enabled)} {return}
        set G(LAST) -1
        after cancel $G(AFTERID)
        catch {wm withdraw $G(TOPLEVEL)}
        if {$tip eq ""} {return}
        set G(AFTERID) [after $G(DELAY) \
                [list ::tooltip::show $win $tip cursor]]
    }

    method TooltipMotion {x y} {
        set region [$self identify region $x $y]
        set row [$self identify item $x $y]
        set col [$self identify column $x $y]

        if {$region eq "nothing"} {
            ::misc::tooltip $win ""
            return
        }

        # Change to use default
        set tip [dict get $tips default]

        if {$region eq "separator"} {
            # just use default
            $self TooltipSet $tip
            return
        }

        if {$col ne "" && $col ne "#0"} {
            set col [$self column $col -id]
        }

        # Simplify the foreach/switch block below by using an anonymous
        # function for the logic shared by each branch. This simply checks if
        # the requested field exists in the tips dict with a non-empty value,
        # and if so updates tip to that value.
        set update [list apply [list args {
            upvar 1 tips tips tip tip
            if {
                [dict exists $tips {*}$args] &&
                [dict get $tips {*}$args] ne ""
            } {
                set tip [dict get $tips {*}$args]
            }
        }]]

        foreach method $options(-tippriority) {
            switch -- $method {
                column {
                    {*}$update column $col
                }
                row {
                    {*}$update row $row
                }
                tag {
                    if {$row ne ""} {
                        foreach tag [$self item $row -tags] {
                            {*}$update tag $tag
                        }
                    }
                }
                cell {
                    {*}$update cell $row $col
                }
                default {
                    error "unknown -tippriority"
                }
            }
        }

        $self TooltipSet $tip
    }
}
