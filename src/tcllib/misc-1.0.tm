# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide misc 1.0

package require snit

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
      set continue [expr {[llength $parts] > 0}]
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
      catch {after cancel [mymethod AdjustHeight]}
      catch {after cancel [list after 0 [mymethod AdjustHeight]]}
   }

   method Modified {} {
      ::misc::idle [mymethod AdjustHeight]
      $self edit modified 0
   }

   method Configure {} {
      ::misc::idle [mymethod AdjustHeight]
   }

   method AdjustHeight {} {
      after cancel [mymethod AdjustHeight]
      after cancel [list after 0 [mymethod AdjustHeight]]
      set height [::misc::text::calc_height $win]
      $self configure -height $height
   }
}

if {[package vcompare 8.5 [info tclversion]] == 1} {
   # Backwards compatibility for Tcl 8.4, which doesn't have the "text count"
   # method. However, this will only work if the the lines are of uniform
   # height (all have the same font).
   proc ::misc::text::calc_height w {
      set content [$w get 1.0 end]
      # Trim off a single trailing newline, if present
      if {[string index $content end] eq "\n"} {
         set content [string range $content 0 end-1]
      }

      set bw [$w cget -borderwidth]
      set ht [$w cget -highlightthickness]
      set sw [$w cget -selectborderwidth]
      set displaywidth [expr {1.0 * [winfo width $w] - 2 * ($bw + $ht + $sw)}]
      unset bw ht

      set font [$w cget -font]
      set top [winfo toplevel $w]

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

      return $height
   }
} else {
   # Tcl 8.5 drastically simplifies things *and* makes them drastically more
   # accurate by use of "text count".
   proc ::misc::text::calc_height w {
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

namespace eval ::misc::combobox {}

snit::widgetadaptor ::misc::combobox::mapping {
   constructor args {
      if {[winfo exists $win]} {
         installhull $win
      } else {
         installhull using ::misc::combobox
      }
      $self configurelist $args
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
      set value [uplevel 1 [list namespace which -variable $value]]
      if {$options(-altvariable) ne ""} {
         $self RemAltVarTraces $options(-altvariable)
      }
      set options($option) $value
      if {$options(-altvariable) ne ""} {
         $self AddAltVarTraces $options(-altvariable)
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
      if {[$hull cget -textvariable] ne ""} {
         $self RemTextVarTraces [$hull cget -textvariable]
      }
      $hull configure $option $value
      if {[$hull cget -textvariable] ne ""} {
         $self AddTextVarTraces [$hull cget -textvariable]
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

namespace eval ::misc::treeview {}

# treeview::sortable <path> ?options...?
#     A wrapper around the ttk::treeview widget that makes columns sortable.
#
#     This can be used to create a new treeview widget, OR to add a "mixin" to
#     an existing widget.
#
#     Code somewhat adapted from Tcl/Tk demo mclist.tcl
snit::widgetadaptor ::misc::treeview::sortable {
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

namespace eval ::misc::labelframe {}

snit::widgetadaptor ::misc::labelframe::collapsible {
   component toggle
   component interior

   constructor args {
      if {[winfo exists $win]} {
         installhull $win
      } else {
         installhull using ttk::labelframe
      }

      install toggle using ttk::checkbutton $win.toggle
      install interior using ttk::frame $win.interior
      ttk::frame $win.null

      # The null frame is to ensure that the labelframe resizes properly. If
      # all contents are removed, it won't resize otherwise.

      $hull configure -labelwidget $toggle
      grid $interior -in $win -sticky news
      grid $win.null -in $win -sticky news
      grid columnconfigure $win 0 -weight 1
      grid rowconfigure $win 0 -weight 1

      if {[lsearch -exact $args -variable] == -1} {
         set ::$toggle 1
         $self configure -variable ::$toggle
      }
      $self configurelist $args
      $self TraceSetVar - - -
   }

   delegate method * to hull
   delegate option -text to toggle
   delegate option -command to toggle
   delegate option * to hull except -labelwidget

   option {-variable variable Variable} -default {} \
      -configuremethod SetVar -cgetmethod GetVar

   method interior args {
      if {[llength $args] == 0} {
         return $interior
      } else {
         return [eval [list $interior] $args]
      }
   }

   method SetVar {option value} {
      if {$value eq ""} {
         set value ::$toggle
      }
      catch [list trace remove variable [$toggle cget -variable] write \
         [mymethod TraceSetVar]]
      $toggle configure -variable $value
      trace add variable [$toggle cget -variable] write [mymethod TraceSetVar]
   }

   method GetVar option {
      return [$toggle cget -variable]
   }

   method TraceSetVar {name1 name2 op} {
      if {[set [$toggle cget -variable]]} {
         grid $win.interior
      } else {
         grid remove $win.interior
      }
   }
}

# default varName value
#     This is used within a procedure to specify a default value for a
#     parameter. This is useful when the default value is dynamic.
proc default {varName value} {
    upvar $varName var
    set caller [info level -1]
    set caller_args [info args [lindex $caller 0]]
    set arg_index [lsearch -exact $caller_args $varName]
    incr arg_index
    if {$arg_index > 0} {
        if {[llength $caller] <= $arg_index} {
            set var $value
        }
    } else {
        error "Calling function does not have parameter $varName"
    }
}

proc curry {new args} {
# See http://wiki.tcl.tk/_search?S=curry for an explanation of the ideas behind
# currying. Basically, curry makes a shorthand alias for a command.
#
# Suppose we have a function like this:
# proc mult {a b} {expr $a*$b}
#
# Then, this:
#   curry double mult 2
# Lets us call this:
#   double 5
# Which returns 10
#
# double is shorthand for "call mult with its first argument as 2"
#
# This can dramatically shorten code where you have lots of excess repeated
# verbiage, especially if you can condense some key phrases down to something
# like a single punctuation command.
#
# All curried aliases are at the global scope, as they use interp aliases. If a
# curry is intended for short-term use, you can uncurry it using the uncurry
# command. The curry/uncurry commands keep track of what's been curried. If you
# curry something that has already been curried, then the next uncurry command
# will restore the previous curry.
#
# Uncurrying something that's not curried is a no-op. Uncurry won't work with
# any arbitrary interp alias; it will only work with those interp aliases set
# through curry.
    global __curry
    dict lappend __curry $new $args
    eval [list interp alias {} $new {}] $args
}

proc uncurry {name} {
# See curry
    global __curry
    if {[info exists __curry] && [dict exists $__curry $name]} {
        if {[llength [dict get $__curry $name]]} {
            dict set __curry $name [lrange [dict get $__curry $name] 0 end-1]
        }
        if {[llength [dict get $__curry $name]]} {
            eval [list interp alias {} $name {}] [lindex [dict get $__curry $name] end]
        } else {
            interp alias {} $name {}
            dict unset __curry $name
        }
    }
}

##############################################################################

# copied from ADAPT: lib/combinators.tcl

proc S {f g x} {
##
# S -- the S combinator
#
# SYNOPSIS
#   [S <f> <g> <x>]
#
# DESCRIPTION
#   One of the two fundamental functional operators. Sometimes shows up
#   in code from @http://wiki.tcl.tk/(the Tcler's Wiki).
#
#   For information, consult:
#     * @(http://wiki.tcl.tk/1892)
#
#   See also: $K
##
   $f $x [$g $x]
}

proc K {x y} {
##
# K -- the K combinator
#
# SYNOPSIS
#   [K <x> <y>]
#
# DESCRIPTION
#   One of the two fundamental functional operators. Sometimes shows up
#   in code from @http://wiki.tcl.tk/(the Tcler's Wiki).
#
#   For information, consult:
#     * @(http://wiki.tcl.tk/1923)
#
#   See also: $S
##
   set x
}

proc K* {x args} {
##
# K* -- the K combinator
#
# SYNOPSIS
#   [K* <x> ...]
#
# DESCRIPTION
#   One of the two fundamental functional operators. Sometimes shows up
#   in code from @http://wiki.tcl.tk/(the Tcler's Wiki).
#
#   This variant of K can accept any number of arguments beyond the first.
#
#   For information, consult:
#     * @(http://wiki.tcl.tk/1923)
#
#   See also: $S
##
   set x
}

# Helpers so that trace_* works
proc trace_add args {uplevel [list trace add] $args}
proc trace_remove args {uplevel [list trace remove] $args}
proc trace_info args {uplevel [list trace info] $args}

proc trace_append {type name ops prefix} {
##
# trace_append is intended to be equivalent to 'trace add', except that it
# arranges that the new trace will be appended to the list of traces instead of
# prepended. Traces added with 'trace add' are executed in reverse of the
# order they were added; so the last trace added gets executed first. If
# 'trace_append' is used, it puts the give trace to be executed last. Thus a
# series of traces added with 'trace_append' will be executed in the order they
# were added.
##
   # Get a list of the current traces
   set traces [trace info $type $name]

   # Remove all the existing traces
   foreach trace $traces {
      trace remove $type $name [lindex $trace 0] [lindex $trace 1]
   }

   # Add the trace we want to append
   trace add $type $name $ops $prefix

   # Re-add the original traces
   foreach trace [struct::list reverse $traces] {
      trace add $type $name [lindex $trace 0] [lindex $trace 1]
   }
}

namespace eval ::__validation_backups {}

proc validation_trace {cmd varname valcmd args} {
##
# validation_trace add varname valcmd -invalidcmd {}
# validation_trace remove varname valcmd -invalidcmd {}
#
#  Adds (or removes) a validation traces on the specified variable. When a
#  validation fails, the variable remains unchanged.
#
#  Required arguments:
#     cmd: Should be "add" or "remove"
#     varname: The name of a variable. If this is not explicitly scoped, then
#        it will be scoped to the current context.
#     valcmd: The validation command. This will be evaluated at the global
#        scope and will have percent-substitutions applied to it as described
#        further below. This should evaluate to a boolean true or false. True
#        indicates that the value is allowed. False indicates that the value
#        should be rejected.
#
#  Optional arguments:
#     -invalidcmd $cmd: A command to run when an attempt was made to set the
#        variable to a value that resulted in a rejection. This is run at the
#        global scope and also has percent-substitutions applied to it. If this
#        is not provided, then a failure will result in the variable's value
#        not changing. If this is provided, then the calling code must manually
#        fix the variable's value itself.
#
#  Percent substitutions
#     The following percent subtitutions can be included in your commands.
#        %% - Substitutes to %.
#        %B - Substitutes to the previous value for the variable. If the
#             validation fails, this is what the variable will be reassigned
#             to.
#        %v - Substitutes to the name of the variable.
#        %V - Substitutes to the current value for the variable. If the
#             validation succeeds, this is what the variable will remain as.
#
#  Examples:
#     % validation_trace add counter {string is integer {%V}}
#     % set counter 5
#     5
#     % set counter -10
#     -10
#     % set counter "Random string"
#     -10
#
#     % validation_trace add counter {expr {[string is integer {%V}] && {%V} < 20}}
#     % set counter 5
#     5
#     % set counter 15
#     15
#     % set counter 25
#     15
#
#     % validation_trace add counter {string is integer {%V}} \
#        -invalidcmd {puts "You entered a bogus value!!"}
#     % set counter 5
#     5
#     % set counter foo
#     You entered a bogus value!!
#     5
##
   array set opt [list -invalidcmd {}]
   array set opt $args
   switch -- $cmd {
      add - remove - append {}
      default {
         error "Unknown command: $cmd"
      }
   }
   # If the variable doesn't already exist, then setting a trace on it provokes
   # an error. Thus, initialize to a null value if necessary.
   if {![uplevel [list info exists $varname]]} {
      uplevel [list set $varname {}]
   }
   set varname [uplevel [list namespace which -variable $varname]]
   set data [list varname $varname valcmd $valcmd invalidcmd $opt(-invalidcmd)]
   # Create namespace, if necessary
   namespace eval ::__validation_backups[namespace qualifiers $varname] {}
   set ::__validation_backups$varname [set $varname]
   trace_$cmd variable $varname write [list __validate_trace_worker $data]
}

proc __validate_trace_worker {data name1 name2 op} {
   array set _ $data
   set substitutions [list \
      %% % \
      %B [set ::__validation_backups$_(varname)] \
      %v $_(varname) \
      %V [set $_(varname)] ]
   set cmd [::struct::list map $_(valcmd) [list string map $substitutions]]
   set valid [uplevel #0 $cmd]
   if {$valid} {
      set ::__validation_backups$_(varname) [set $_(varname)]
   } else {
      if {[string length $_(invalidcmd)]} {
         set invalidcmd [string map $substitutions $_(invalidcmd)]
         uplevel #0 $invalidcmd
      } else {
         set $_(varname) [set ::__validation_backups$_(varname)]
      }
   }
}

proc constrain {var between min and max} {
# Constrain the given variable's value to the range of min and max. If it is
# outside of that range, it is clipped to either min or max.
   upvar $var v
   if {$v < $min} {
      set v $min
   } elseif {$v > $max} {
      set v $max
   }
   return
}

