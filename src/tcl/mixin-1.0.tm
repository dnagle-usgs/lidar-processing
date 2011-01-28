# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin 1.0
package require imglib
package require snit

snit::widgetadaptor ::mixin::statevar {
    constructor args {
        installhull $win
        $self configurelist $args
    }

    destructor {
        catch [list $self configure -statevariable ""]
    }

    delegate method * to hull
    delegate option * to hull

    option {-statevariable stateVariable Variable} -default {} \
            -configuremethod SetStateVar

    option {-statemap stateMap Map} -default {}

    method SetStateVar {option value} {
        if {$options(-statevariable) ne ""} {
            catch [list trace remove variable $options(-statevariable) write \
                    [mymethod TraceStateVar]]
        }
        set options($option) $value
        if {$options(-statevariable) ne ""} {
            trace add variable $options(-statevariable) write \
                    [mymethod TraceStateVar]
            $self TraceStateVar - - -
        }
    }

    method TraceStateVar {name1 name2 op} {
        set state [set $options(-statevariable)]
        if {[dict exists $options(-statemap) $state]} {
            set state [dict get $options(-statemap) $state]
        }
        if {[catch [list $self state $state]]} {
            if {[catch [list $self configure -state $state]]} {
                $self configure -state disabled
            }
        }
    }
}

namespace eval ::mixin::text {}

# readonly <widget> ?<options>?
#     A wrapper around the text widget that makes the widget read-only. This
#     widget works exactly like any other text widget except that all insert
#     and delete actions are no-ops. However, programmatic access to insertion
#     and deletion are provided via the "ins" and "del" methods.
#
#     This can be used to create a new text widget, OR to add a "mixin" to an
#     existing widget.
#
#     Adapted from code at http://wiki.tcl.tk/3963
snit::widgetadaptor ::mixin::text::readonly {
    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using text
        }
        $self configure -insertwidth 0
        $self configurelist $args
    }

    method insert args {}
    method delete args {}

    delegate method ins to hull as insert
    delegate method del to hull as delete

    delegate method * to hull
    delegate option * to hull
}

# autoheight <widget> ?<options>?
#     A wrapper around the text widget that makes the widget automatically
#     update its -height option. This widget works exactly like any other text
#     widget otherwise.
#
#     This can be used to create a new text widget, OR to add a "mixin" to an
#     existing widget.
snit::widgetadaptor ::mixin::text::autoheight {
    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using text
        }
        $self configurelist $args

        bind $win <<Modified>> +[mymethod Modified]
        bind $win <Configure> +[mymethod Configure]
    }

    delegate method * to hull
    delegate option * to hull

    destructor {
        catch {after cancel [mymethod AdjustHeight]}
        catch {after cancel [list after 0 [mymethod AdjustHeight]]}
    }

    method Modified {} {
        if {[$self edit modified]} {
            ::misc::idle [mymethod AdjustHeight]
            $self edit modified 0
        }
    }

    method Configure {} {
        ::misc::idle [mymethod AdjustHeight]
    }

    method AdjustHeight {} {
        after cancel [mymethod AdjustHeight]
        after cancel [list after 0 [mymethod AdjustHeight]]
        set height [::mixin::text::calc_height $win]
        $self configure -height $height
    }
}

proc ::mixin::text::calc_height w {
    set pixelheight [$w count -update -ypixels 1.0 end]
    set font [$w cget -font]
    set top [winfo toplevel $w]
    set fontheight [font metrics $font -displayof $top -linespace]
    set height [expr {int(ceil(double($pixelheight)/$fontheight))}]
    if {$height < 1} {
        set height 1
    }
    return $height
}

# combobox <path> ?options...?
#     A wrapper around the ttk::combobox widget that adds some additional
#     functionality that could be found in other combobox implementations.
#
#     This can be used to create a new combobox widget, OR to add a "mixin" to
#     an existing widget.
#
#     Modifications this provides:
#
#        -listvariable  This option specifies a list variable whose contents
#                       should be used in place of -values.
snit::widgetadaptor ::mixin::combobox {
    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::combobox
        }
        $self configurelist $args
    }

    destructor {
        if {$options(-listvariable) ne ""} {
            $self RemoveTraces $options(-listvariable)
        }
    }

    delegate method * to hull
    delegate option * to hull

    # -listvariable <varname>
    #     This is used to specify a variable whose contents will be used to
    #     populate the combobox's list instead of -values. If set to the empty
    #     string, it is disabled.
    #
    #     When this is used, -values should only be used in a read-only fashion.
    #     Configuring -values directly will not throw an error, but it will
    #     result in inconsistent behavior.
    option {-listvariable listVariable Variable} -default {} \
        -configuremethod SetListVar

    # -modifycmd <script>
    #     Specifies a Tcl command called when the user modifies the value of the
    #     combobox by selecting a value in the dropdown list.
    #
    #     This is implemented using the <<ComboboxSelected>> event. If you want
    #     to add bindings (prepending them with +), that will work. However, if
    #     you replace the bindigns, you'll need to re-configure the -modifycmd
    #     to reapply the behavior. Changing -modifycmd will not alter any
    #     existing bindings that may exist on the combobox.
    #
    #     (From Bwidgets)
    #
    #     This is also equivalent to the iwidgets::combobox -selectioncommand.
    option -modifycmd -default {} -configuremethod SetModifyCmd

    # -text <string>
    #     An alternative mechanism for retrieving/setting the value of the
    #     widget. This is a simple wrapper around the widget's get and set
    #     methods.
    #
    #     (From Bwidgets)
    option -text -default {} -cgetmethod GetText -configuremethod SetText

    # getvalue
    #     Returns the index of the current text of the combobox in the list of
    #     values, or -1 if it doesn't match any value.
    #
    #     (From Bwidgets)
    method getvalue {} {
        return [lsearch -exact [$self cget -values] [$self get]]
    }

    # setvalue <index>
    #     Set the value of the combobox to the value indicated by <index> in the
    #     list of values. <index> may be specified in any of the following
    #     forms:
    #           last
    #              Specifies the last element of the list of values.
    #           first
    #              Specifies the first element of the list of values.
    #           next
    #              Specifies the element following the current (as returned by
    #              getvalue) in the list of values.
    #           previous
    #              Specifies the element preceding the current (as returned by
    #              getvalue) in the list of values.
    #           @<number>
    #              Specifies the integer index in the list of values.
    #
    #     (From Bwidgets)
    method setvalue index {
        set values [$self cget -values]
        # Convert named values to @numbers
        switch -- $index {
            first {
                set index @0
            }
            last {
                set index @[expr {[llength $values]-1}]
            }
            next {
                set index @[expr {[$self getvalue] + 1}]
            }
            previous {
                set index @[expr {[$self getvalue] - 1}]
            }
        }
        set @ [string index $index 0]
        set idx [string range $index 1 end]
        if {${@} eq "@" && [string is integer -strict $idx]} {
            if {0 <= $idx && $idx < [llength $values]} {
                $self set [lindex $values $idx]
                return 1
            } else {
                return 0
            }
        } else {
            error "bad index \"$index\""
        }
    }

    # SetListVar <option> <value>
    #     Used to configure -listvariable
    #
    #     When -listvariable changes, the old variable's traces need to be
    #     removed and the new variable's traces must be added. Or, the empty
    #     string specifies to trace no variable at all.
    method SetListVar {option value} {
        if {![uplevel 1 [list info exists $value]]} {
            uplevel 1 [list set $value [list]]
        }
        set value [uplevel 1 [list namespace which -variable $value]]
        if {$options(-listvariable) ne ""} {
            $self RemoveTraces $options(-listvariable)
        }
        set options(-listvariable) $value
        if {$options(-listvariable) ne ""} {
            $self AddTraces $options(-listvariable)
        }
    }

    # AddTraces <var>
    #     This adds the necessary traces to the specified variable. It also
    #     makes sure that -values gets initialized to the variable's contents.
    method AddTraces var {
        trace add variable $var write [mymethod TraceListVarWrite]
        trace add variable $var unset [mymethod TraceListVarUnset]
        $self configure -values [set $options(-listvariable)]
    }

    # RemoveTraces <var>
    #     Safely removes the traces on the specified variable.
    method RemoveTraces var {
        catch [list trace remove variable $var write [mymethod TraceListVarWrite]]
        catch [list trace remove variable $var unset [mymethod TraceListVarUnset]]
    }

    # TraceListVarWrite <name1> <name2> <op>
    #     Used for 'write' trace on the list variable.
    #
    #     When the list variable is set, the -values get updated to match.
    method TraceListVarWrite {name1 name2 op} {
        $self configure -values [set $options(-listvariable)]
    }

    # TraceListVarUnset <name1> <name2> <op>
    #     Used for 'unset' trace on the list variable.
    #
    #     When the list variable is unset, all traces are normally automatically
    #     removed. This responds by setting the list variable to the empty list
    #     (because the combobox can't display it otherwise), then re-adding the
    #     traces.
    method TraceListVarUnset {name1 name2 op} {
        set $options(-listvariable) [list]
        $self RemoveTraces $options(-listvariable)
        $self AddTraces $options(-listvariable)
    }

    # SetModifyCmd <option> <value>
    #     Used to update the bindings for the -modifycmd.
    method SetModifyCmd {option value} {
        if {$options(-modifycmd) ne ""} {
            set binding [bind $win <<ComboboxSelected>>]
            set binding [string map [list $options(-modifycmd) ""] $binding]
            bind $win <<ComboboxSelected>> $binding
        }
        set options(-modifycmd) $value
        if {$options(-modifycmd) ne ""} {
            bind $win <<ComboboxSelected>> +$options(-modifycmd)
        }
    }

    # SetText <option> <value>
    #     Updates the widget's value.
    method SetText {option value} {
        $self set $value
    }

    # GetText <option>
    #     Returns the widget's value.
    method GetText option {
        return [$self get]
    }
}

namespace eval ::mixin::combobox {}

snit::widgetadaptor ::mixin::combobox::mapping {
    variable localalt ""
    variable localval ""

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ::mixin::combobox
        }
        $self configure -altvariable "" -textvariable ""
        $self configurelist $args
    }

    destructor {
        catch [list $self RemTextVarTraces $options(-textvariable)]
        catch [list $self RemAltVarTraces $options(-altvariable)]
    }

    option {-mapping mapping Mapping} -default {} \
        -configuremethod SetMapping -cgetmethod GetMapping

    option {-altvalues altValues Values} -default {}

    option {-altvariable altVariable Variable} -default {} \
        -configuremethod SetAltVar

    option {-textvariable textVariable Variable} -default {} \
        -configuremethod SetTextVar -cgetmethod GetTextVar

    delegate method * to hull
    delegate option * to hull

    method altset value {
        set idx [lsearch -exact [$self cget -altvalues] $value]
        if {$idx > -1 && $idx < [llength [$self cget -values]]} {
            set value [lindex [$self cget -values] $idx]
        }
        $self set $value
    }

    method altget {} {
        set value [$self get]
        set idx [lsearch -exact [$self cget -values] $value]
        if {$idx > -1 && $idx < [llength [$self cget -altvalues]]} {
            set value [lindex [$self cget -altvalues] $idx]
        }
        return $value
    }

    method SetMapping {option value} {
        set vals [list]
        set alts [list]
        foreach {val alt} $value {
            lappend vals $val
            lappend alts $alt
        }
        $self configure -values $vals -altvalues $alts
        if {[$hull cget -textvariable] eq ""} {
            if {[$self cget -altvariable] ne ""} {
                $self TraceSetAltVar - - -
            }
        } else {
            $self TraceSetTextVar - - -
        }
    }

    method GetMapping option {
        set mapping [list]
        foreach val [$self cget -values] alt [$self cget -altvalues] {
            lappend mapping $val $alt
        }
        return $mapping
    }

    method SetAltVar {option value} {
        if {![uplevel 1 [list info exists $value]]} {
            uplevel 1 [list set $value [list]]
        }
        if {$value eq ""} {
            set value [myvar localalt]
        }
        if {$options(-altvariable) ne ""} {
            $self RemAltVarTraces $options(-altvariable)
        }
        set options($option) $value
        if {$options(-altvariable) ne ""} {
            $self AddAltVarTraces $options(-altvariable)
            # Force an update
            $self TraceSetAltVar - - -
        }
    }

    method AddAltVarTraces var {
        trace add variable $var write [mymethod TraceSetAltVar]
    }

    method RemAltVarTraces var {
        catch [list trace remove variable $var write [mymethod TraceSetAltVar]]
    }

    method TraceSetAltVar {name1 name2 op} {
        $self altset [set $options(-altvariable)]
    }

    method SetTextVar {option value} {
        if {![uplevel 1 [list info exists $value]]} {
            uplevel 1 [list set $value [list]]
        }
        set value [uplevel 1 [list namespace which -variable $value]]
        if {$value eq ""} {
            set value [myvar localval]
        }
        if {[$hull cget -textvariable] ne ""} {
            $self RemTextVarTraces [$hull cget -textvariable]
        }
        $hull configure $option $value
        set options($option) $value
        if {[$hull cget -textvariable] ne ""} {
            $self AddTextVarTraces [$hull cget -textvariable]
            # Force an update
            $self TraceSetTextVar - - -
        }
    }

    method GetTextVar option {
        return [$hull cget -textvariable]
    }

    method AddTextVarTraces var {
        trace add variable $var write [mymethod TraceSetTextVar]
    }

    method RemTextVarTraces var {
        catch [list trace remove variable $var write [mymethod TraceSetTextVar]]
    }

    method TraceSetTextVar {name1 name2 op} {
        if {$options(-altvariable) ne ""} {
            $self set [set [$hull cget -textvariable]]
            set $options(-altvariable) [$self altget]
        }
    }
}

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

namespace eval ::mixin::labelframe {}

ttk::style configure Collapsible.TCheckbutton -relief flat
ttk::style layout Collapsible.TCheckbutton [ttk::style layout Toolbutton]
ttk::style map Collapsible.TCheckbutton \
        -image [list selected ::imglib::collapsible::collapse \
                !selected ::imglib::collapsible::expand]

snit::widgetadaptor ::mixin::labelframe::collapsible {
    component toggle
    component interior

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::labelframe
        }

        install toggle using ttk::checkbutton $win.toggle \
                -style Collapsible.TCheckbutton -compound left
        install interior using ttk::frame $win.interior
        ttk::frame $win.null

        # The null frame is to ensure that the labelframe resizes properly. If
        # all contents are removed, it won't resize otherwise.

        $hull configure -labelwidget $toggle
        grid $interior -in $win -sticky news
        grid $win.null -in $win -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        ::tooltip::tooltip $toggle \
                "Click to expand or collapse this section."

        if {[lsearch -exact $args -variable] == -1} {
            set ::$toggle 1
            $self configure -variable ""
        }
        $self configurelist $args
        $self TraceSetVar - - -
    }

    destructor {
        catch [list trace remove variable $options(-variable) write \
            [mymethod TraceSetVar]]
    }

    delegate method * to hull
    delegate method invoke to toggle
    delegate option -text to toggle
    delegate option -command to toggle
    delegate option -onvalue to toggle
    delegate option -offvalue to toggle
    delegate option * to hull except -labelwidget

    option {-variable variable Variable} -default {} \
            -configuremethod SetVar -cgetmethod GetVar

    method interior args {
        if {[llength $args] == 0} {
            return $interior
        } else {
            return [$interior {*}$args]
        }
    }

    method SetVar {option value} {
        if {$value eq ""} {
            set value ::$toggle
            $toggle configure -style Collapsible.TCheckbutton -compound left
        } else {
            $toggle configure -style TCheckbutton -compound text
        }
        catch [list trace remove variable [$toggle cget -variable] write \
                [mymethod TraceSetVar]]
        $toggle configure -variable $value
        set options($option) $value
        trace add variable [$toggle cget -variable] write [mymethod TraceSetVar]
    }

    method GetVar option {
        return [$toggle cget -variable]
    }

    method TraceSetVar {name1 name2 op} {
        if {[set [$toggle cget -variable]] == [$toggle cget -onvalue]} {
            grid $win.interior
        } else {
            grid remove $win.interior
        }
    }
}

ttk::style configure Padlock.Toolbutton -relief flat
ttk::style map Padlock.Toolbutton -relief {}

snit::widgetadaptor ::mixin::padlock {
    delegate method * to hull
    delegate option * to hull except -image

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::checkbutton
        }

        $hull configure \
                -compound image \
                -style Padlock.Toolbutton \
                -image [list ::imglib::padlock::open \
                        selected ::imglib::padlock::closed \
                        !selected ::imglib::padlock::open]

        $self configurelist $args
    }
}

namespace eval ::mixin::frame {}

# ::mixin::frame::scrollable is based on the code found at
# http://wiki.tcl.tk/9223 in the section "The KJN optimized & enhanced
# version". It has been modified to use Snit as well as to use Themed Tk.
snit::widgetadaptor ::mixin::frame::scrollable {
    component interior

    delegate method * to hull
    delegate option * to hull

    option {-xfill xFill Fill} -default 0 -type snit::boolean \
            -configuremethod SetFill
    option {-yfill yFill Fill} -default 0 -type snit::boolean \
            -configuremethod SetFill
    option {-xscrollcommand xScrollCommand ScrollCommand} -default ""
    option {-yscrollcommand yScrollCommand ScrollCommand} -default ""

    variable vheight 0
    variable vwidth 0
    variable vtop 0
    variable vleft 0
    variable width 0
    variable height 0

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::frame
        }

        install interior using ttk::frame $win.interior

        place $win.interior -in $win -x 0 -y 0
        $self configurelist $args

        bind $win <Configure> [mymethod Resize]
        bind $win.interior <Configure> [mymethod Resize]
    }

    method interior args {
        if {[llength $args] == 0} {
            return $interior
        } else {
            return [$interior {*}$args]
        }
    }

    method xview {{cmd ""} args} {
        $self View xview $cmd {*}$args
    }

    method yview {{cmd ""} args} {
        $self View yview $cmd {*}$args
    }

    method View {view cmd args} {
        set len [llength $args]
        switch -glob -- $cmd {
            ""  {
                set args {}
            }
            mov* {
                if {$len != 1} {
                    error "wrong # args: should be \"$win $view moveto\
                            fraction\""
                }
            }
            scr* {
                if {$len != 2} {
                    error "wrong # args: should be \"$win $view scroll count\
                            unit\""
                }
            }
            default {
                error "unknown operation \"$cmd\": should be empty, moveto, or\
                    scroll"
            }
        }

        if {$view eq "xview"} {
            set xy x
            set wh width
            set fill $options(-xfill)
            set scrollcmd $options(-xscrollcommand)
            upvar 0 vleft vside
            upvar 0 width size
            upvar 0 vwidth vsize
        } else {
            set xy y
            set wh height
            set fill $options(-yfill)
            set scrollcmd $options(-yscrollcommand)
            upvar 0 vtop vside
            upvar 0 height size
            upvar 0 vheight vsize
        }

        # save old value
        set _vside $vside

        # compute new value for $vside
        set count ""
        switch $len {
            0 { # return fractions
                if {$vsize == 0} {return {0 1}}
                set first [expr {double($_vside) / $vsize}]
                set last [expr {double($_vside + $size) / $vsize}]
                if {$last > 1.0} {return {0 1}}
                return [list [format %g $first] [format %g $last]]
            }
            1 { # absolute movement
                set vside [expr {int(double($args) * $vsize)}]
            }
            2 { # relative movement
                lassign $args count unit
                if {[string match p* $unit]} {
                    set count [expr {$count * 9}]
                }
                set vside [expr {$_vside + $count * 0.1 * $size}]
            }
        }
        if {$vside + $size > $vsize} {
            set vside [expr {$vsize - $size}]
        }
        if {$vside < 0} {
            set vside 0
        }
        if {$vside != $_vside || $count == 0} {
            if {$scrollcmd ne ""} {
                {*}$scrollcmd {*}[$self ${xy}view]
            }
            if {$fill && ($vsize < $size || $scrollcmd eq "")} {
                # "scrolled object" is not scrolled, because it is too small or
                # because no scrollbar was requested. fill means that, in these
                # cases, we must tell the object what its size should be.
                place $win.interior -in $win -$xy [expr {-$vside}] -$wh $size
                # If there's no scrollcommand, we also need to propagate the width
                # to the parent window.
                if {$scrollcmd eq ""} {
                    $win configure -$wh $vsize
                }
            } else {
                place $win.interior -in $win -$xy [expr {-$vside}] -$wh {}
            }
        }
    }

    method SetFill {option value} {
        set options($option) $value
        $self Resize -force
    }

    method Resize {{force {}}} {
        if {$force ne "" && $force ne "-force"} {
            error "invalid call to Resize, must be \"Resize\" or \"Resize\
                    -force\""
        }
        set force [expr {$force eq "-force"}]

        # Old values
        set _vheight $vheight
        set _vwidth $vwidth
        set _height $height
        set _width $width

        # New values
        set vheight [winfo reqheight $win.interior]
        set vwidth [winfo reqwidth $win.interior]
        set height [winfo height $win]
        set width [winfo width $win]

        if {$force || $vheight != $_vheight || $height != $_height} {
            $self yview scroll 0 unit
        }

        if {$force || $vwidth != $_vwidth || $width != $_width} {
            $self xview scroll 0 unit
        }
    }
}
