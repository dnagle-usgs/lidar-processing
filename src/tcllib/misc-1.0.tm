# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide misc 1.0

package require snit
package require dict
package require tile

namespace eval ::misc {
   namespace export soe
   namespace export idle
   namespace export safeafter
   namespace export search
}

snit::type ::misc::soe {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   typemethod {from list} {Y {M -} {D -} {h 0} {m 0} {s 0}} {
      if {$M eq "-"} {
         return [eval [$type from list] $Y]
      }
      set fmt "%04d%02d%02d %02d%02d%02d"
      return [clock scan [format $fmt $Y $M $D $h $m $s] -gmt 1]
   }

   typemethod {to list} soe {
      set str [clock format $soe -format "%Y %m %d %H %M %S" -gmt 1]
      set fmt "%04d %02d %02d %02d %02d %02d"
      return [scan $str $fmt]
   }

   typemethod {to sod} soe {
      set day [clock scan [clock format $soe -format "%Y-%m-%d 00:00:00" -gmt 1] -gmt 1]
      return [expr {$soe - $day}]
   }
}

proc ::misc::idle cmd {
   after idle [list after 0 $cmd]
}

proc ::misc::safeafter {var delay cmd} {
   set var [uplevel namespace which -variable $var]
   set $var [after idle [list ::misc::_safeafter $var $delay $cmd]]
}

proc ::misc::_safeafter {var delay cmd} {
   set $var [after $delay $cmd]
}

snit::type ::misc::search {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   # search binary <list> <value> <options>
   #     Searches <list> for <value>. The <list> must already be sorted and
   #     should contain numeric values. Will return the index corresponding to
   #     the position in list whose value is nearest to <value>.
   #
   #     Options may be:
   #        -exact <boolean>  If enabled, will require that the item found
   #              match exactly. If no match is found, returns -1 (or the empty
   #              string if -inline is enabled).
   #        -inline <boolean>  If enabled, returns the matched value rather
   #              than the index.
   typemethod binary {list value args} {
      # Set initial bounds to cover the entire list.
      set b0 0
      set b1 [expr {[llength $list] - 1}]

      # Check to ensure the that search value is in the range covered by list;
      # if not, it's a special case that lets us skip the actual search.
      if {$value <= [lindex $list $b0]} {
         set b1 $b0
      } elseif {[lindex $list $b1] <= $value} {
         set b0 $b1
      }

      # Search until we've narrowed the bounds down to either a single value
      # (an exact match) or a pair of values (no exact match could be found).
      while {[expr {$b1 - $b0}] > 1} {
         set pivot [expr {int(($b0 + $b1) / 2)}]
         set pivotValue [lindex $list $pivot]

         if {$pivotValue == $value} {
            set b0 $pivot
            set b1 $pivot
         } elseif {$pivotValue < $value} {
            set b0 $pivot
         } else {
            set b1 $pivot
         }
      }

      # Select the index for the nearest value
      if {$b0 == $b1} {
         set nearest $b0
      } else {
         # Calculate deltas and return nearest (if there's a tie, the first one
         # wins)
         set db0 [expr {abs($value - [lindex $list $b0])}]
         set db1 [expr {abs($value - [lindex $list $b1])}]
         if {$db0 < $db1} {
            set nearest $b0
         } else {
            set nearest $b1
         }
      }

      # Handle the -exact option
      if {[dict exists $args -exact] && [dict get $args -exact]} {
         if {[lindex $list $nearest] != $value} {
            set nearest -1
         }
      }

      # Handle the -inline option
      if {[dict exists $args -inline] && [dict get $args -inline]} {
         return [lindex $list $nearest]
      } else {
         return $nearest
      }
   }
}

snit::type ::misc::file {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   # file common_base <paths>
   #     Finds the common base path for the given list of <paths>. For example,
   #     a list of {/foo/bar/baz /foo/bar/foo /foo/bar/bar/baz} would return
   #     /foo/bar. Paths will be normalized.
   typemethod common_base paths {
      set parts [list]
      foreach path $paths {
         eval [list dict set parts] [::file split [::file normalize $path]] *
      }
      set common [list /]
      set continue 1
      while {$continue} {
         set continue 0
         set sub [eval [list dict get $parts] $common]
         if {$sub ne "*" && [llength [dict keys $sub]] == 1} {
            lappend common [lindex [dict keys $sub] 0]
            set continue 1
         }
      }
      return [eval [list ::file join] $common]
   }
}

namespace eval ::misc::text {}

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
snit::widgetadaptor ::misc::text::readonly {
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
snit::widgetadaptor ::misc::text::autoheight {
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
      after cancel $cancel
   }

   variable cancel ""

   method Modified {} {
      after cancel $cancel
      set cancel [::misc::idle [mymethod AdjustHeight]]
      $self edit modified 0
   }

   method Configure {} {
      after cancel $cancel
      set cancel [::misc::idle [mymethod AdjustHeight]]
   }

   method AdjustHeight {} {
      after cancel $cancel
      set content [$self get 1.0 end]
      # Trim off a single trailing newline, if present
      if {[string index $content end] eq "\n"} {
         set content [string range $content 0 end-1]
      }

      set bw [$self cget -borderwidth]
      set ht [$self cget -highlightthickness]
      set sw [$self cget -selectborderwidth]
      set displaywidth [expr {1.0 * [winfo width $win] - 2 * ($bw + $ht + $sw)}]
      unset bw ht

      set font [$self cget -font]
      set top [winfo toplevel $win]

      set height 0
      foreach line [split $content \n] {
         set linewidth [font measure $font -displayof $top $line]
         # The displaywidth is cast as a float when it is set above, to avoid
         # integer division here.
         set amt [expr {int(ceil($linewidth / $displaywidth))}]
         if {$amt < 1} {
            set amt 1
         }
         incr height $amt
      }

      if {$height < 1} {
         set height 1
      }

      $self configure -height $height
   }
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
snit::widgetadaptor ::misc::combobox {
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
