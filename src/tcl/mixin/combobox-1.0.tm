# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin::combobox 1.0
package require imglib
package require snit

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
    #
    #     Note that array values (such as "foo(a)") must be passed with a fully
    #     qualified paths. Other variables probably should as well, but if they
    #     aren't, an attempt will be made to determine their fully qualified
    #     path. The attempt always fails for array values though.
    method SetListVar {option value} {
        if {![uplevel 1 [list info exists $value]]} {
            uplevel 1 [list set $value [list]]
        }
        if {![string match ::* $value]} {
            set value [uplevel 1 [list namespace which -variable $value]]
        }
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
