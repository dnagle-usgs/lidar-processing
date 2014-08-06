# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::segments 1.0

namespace eval ::l1pro::segments::launcher {}

proc ::l1pro::segments::launcher::launch {} {
    gui .%AUTO%
}

snit::widget ::l1pro::segments::launcher::gui {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    option -vname {}

    variable wanted {}
    variable unwanted {flight ptime line channel digitizer}

    constructor args {
        $self configure {*}$args
        if {$options(-vname) eq ""} {
            set options(-vname) $::pro_var
        }
        wm title $win "Launch Segments"
        $self gui
    }

    method gui {} {
        ttk::frame $win.f
        set f $win.f
        pack $f -fill both -expand 1

        ttk::label $f.lblVar -text "Var:"
        ::mixin::combobox $f.cboVar \
                -textvariable [myvar options](-vname) \
                -state readonly \
                -listvariable ::varlist

        grid $f.lblVar $f.cboVar -sticky ew -padx 2 -pady 2
        grid $f.lblVar -sticky w

        ttk::frame $f.fraSel

        ttk::label $f.lblWanted -text "Split by..."
        ttk::label $f.lblUnwanted -text "Do not split by..."

        listbox $f.lstWanted \
                -width 10 \
                -height 5 \
                -listvariable [myvar wanted] \
                -selectmode browse
        listbox $f.lstUnwanted \
                -width 10 \
                -height 5 \
                -listvariable [myvar unwanted] \
                -selectmode browse
        ttk::button $f.btnAdd \
                -width 0 \
                -text "<--" \
                -state disabled \
                -command [mymethod transfer $f.lstUnwanted unwanted wanted]
        ttk::button $f.btnRem \
                -width 0 \
                -text "-->" \
                -state disabled \
                -command [mymethod transfer $f.lstWanted wanted unwanted]

        bind $f.lstWanted <<ListboxSelect>> \
                [mymethod update_state $f.lstWanted $f.btnRem]
        bind $f.lstWanted <<ListboxSelect>> \
                +[mymethod update_state $f.lstUnwanted $f.btnAdd]
        bind $f.lstUnwanted <<ListboxSelect>> \
                [mymethod update_state $f.lstUnwanted $f.btnAdd]
        bind $f.lstUnwanted <<ListboxSelect>> \
                +[mymethod update_state $f.lstWanted $f.btnRem]

        grid $f.lblWanted x $f.lblUnwanted -in $f.fraSel
        grid $f.lstWanted x $f.lstUnwanted -in $f.fraSel
        grid ^ $f.btnAdd ^ -in $f.fraSel
        grid ^ $f.btnRem ^ -in $f.fraSel
        grid ^ x ^ -in $f.fraSel
        grid configure $f.lblWanted $f.lblUnwanted -padx 2 -pady 2 -sticky w
        grid configure $f.lstWanted $f.lstUnwanted -padx 2 -pady 2 -sticky news
        grid configure $f.btnAdd $f.btnRem -padx 2 -pady 2 -sticky ew
        grid columnconfigure $f.fraSel {0 2} -weight 1 -uniform a
        grid rowconfigure $f.fraSel {1 4} -weight 1 -uniform b

        grid $f.fraSel - -sticky ew -padx 0 -pady 0

        ttk::button $f.btnLaunch -text "Launch Segments" \
                -command [mymethod launch]
        grid $f.btnLaunch - -padx 2 -pady 2

        grid columnconfigure $f 1 -weight 1
        grid rowconfigure $f 1 -weight 1
    }

    # lst - listbox to check
    # btn - button to manage
    method update_state {lst btn} {
        if {[llength [$lst curselection]]} {
            $btn configure -state normal
        } else {
            $btn configure -state disabled
        }
    }

    # lst - the listbox with an active selection to be moved
    # src - the variable name to transfer from
    # dst - the variable name to transfer to
    method transfer {lst src dst} {
        set idx [$lst curselection]
        if {[llength $idx] > 1} {
            error "somehow selected multiple items, this should be impossible"
        }
        if {[llength $idx] == 0} {
            return
        }
        lappend $dst [lindex [set $src] $idx]
        set $src [lreplace [set $src] $idx $idx]

        event generate $lst <<ListboxSelect>>
    }

    method launch {} {
        if {![llength $wanted]} {
            tk_messageBox \
                    -icon warning \
                    -default ok \
                    -type ok \
                    -parent $win \
                    -message "You did not select any methods by which to segment."
            return
        }

        ::l1pro::segments::main::launch $wanted $options(-vname)
        destroy $win
    }
}

namespace eval ::l1pro::segments::select {}

# Replaces select_data_segments
proc ::l1pro::segments::select::data_segments {{selected {}}} {
   global varlist

   set d [iwidgets::dialog .#auto -title "Select variables" \
      -master .l1wid \
      -modality application]
   $d hide Apply
   $d hide Help

   set w [$d childsite]

   iwidgets::disjointlistbox $w.djlVariables \
      -lhslabeltext "Available variables" \
      -rhslabeltext "Selected variables" \
      -lhsbuttonlabel "Add >>" \
      -rhsbuttonlabel "<< Remove"

   pack $w.djlVariables -fill both -expand true
   $w.djlVariables setlhs $varlist

   if {[llength $selected]} {
      $w.djlVariables setrhs $selected
   }

   if {[$d activate]} {
      set selected [$w.djlVariables getrhs]
      if {[llength $selected]} {
         ::l1pro::segments::main::launch_segs $selected
      }
   }

   destroy $d
}

namespace eval ::l1pro::segments::main {}

# Replaces segment_data_launcher
proc ::l1pro::segments::main::launch_split {how {yvar -}} {
    if {$yvar eq "-"} {
        set yvar $::pro_var
    }
    set how \[\"[join $how \",\"]\"\]
    exp_send "tk_sdw_launch_split, \"$yvar\", $how;\r"
    expect "> "
}

# Replaces launch_segmenteddatawindow
proc ::l1pro::segments::main::launch_segs {segments args} {
    gui .%AUTO% \
        -varlistvariable ::varlist \
        -maxwin 64 \
        -segmentvariables $segments \
        -windowvariable ::win_no \
        -fmavariable ::l1pro_fma \
        {*}$args
}

snit::widget ::l1pro::segments::main::gui {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    # All options should be treated as read-only after creation
    # Variable containing the list of variables
    option -varlistvariable ""
    # Variable containing list of valid windows
    option -maxwin 64
    # Variable containing list of variables to populate interface with
    option -segmentvariables ""
    option -windowvariable ""
    option -fmavariable ""

    option -title -default "Segments" -configuremethod SetTitle

    # Holds per-segment data
    variable _segment
    # The window to plot selected items in jointly
    variable _ywindow 0
    # The variable to merge data into
    variable _merge_var merged_segments
    # How many items does the interface hold?
    variable _count
    # Do we frame advance prior to plots?
    variable _fma
    # Do we plot titles?
    variable _pltitle 0
    # For holding private GUI variables (array)
    variable _private -array {}
    # The format to use for time
    variable _dateformat "%Y-%m-%d"
    variable _timeformat "%H:%M:%S"
    variable _rangeformat "START - END"

    constructor {args} {
        $self configure {*}$args

        wm resizable $win 1 1
        wm minsize $win 460 100
        wm title $win $options(-title)

        $self init_opt_var -varlistvariable \
            [list fs_all depth_all veg_all cveg_all workdata]
        $self init_opt_var -windowvariable 0
        $self init_opt_var -fmavariable 0

        set f1 $win.fraVariables
        iwidgets::scrolledframe $f1 \
            -vscrollmode dynamic \
            -hscrollmode dynamic \
            -relief groove

        set f [$f1 childsite]
        $f configure -padx 4

        set mb $f.btnHeadingSelect.mb
        # \u2713 is Unicode for a checkmark
        # \u2714 is a heavier version
        menubutton $f.btnHeadingSelect -menu $mb -text \u2713 -relief raised
        menu $mb
        $mb add command -label "Select all" \
            -command [mymethod selected all]
        $mb add command -label "Select none" \
            -command [mymethod selected none]
        $mb add command -label "Toggle selection" \
            -command [mymethod selected toggle]
        label $f.lblHeadingVariables -text "Variable"
        set mb $f.btnHeadingTime.mb
        menubutton $f.btnHeadingTime -text "Time Format/Refresh" -menu $mb \
            -relief raised
        menu $mb
        menu $mb.date
        menu $mb.time
        menu $mb.range
        $mb add cascade -label "Date format" -menu $mb.date
        $mb.date add radiobutton -label "YYYY-MM-DD" \
            -command [mymethod refresh_times] \
            -variable [myvar _dateformat] -value "%Y-%m-%d"
        $mb.date add radiobutton -label "MM-DD" \
            -command [mymethod refresh_times] \
            -variable [myvar _dateformat] -value "%m-%d"
        $mb.date add radiobutton -label "YYYY-DOY" \
            -command [mymethod refresh_times] \
            -variable [myvar _dateformat] -value "%Y-%j"
        $mb.date add radiobutton -label "DOY" \
            -command [mymethod refresh_times] \
            -variable [myvar _dateformat] -value "%j"
        $mb.date add radiobutton -label "(omit)" \
            -command [mymethod refresh_times] \
            -variable [myvar _dateformat] -value " "
        $mb add cascade -label "Time format" -menu $mb.time
        $mb.time add radiobutton -label "HH:MM:SS" \
            -command [mymethod refresh_times] \
            -variable [myvar _timeformat] -value "%H:%M:%S"
        $mb.time add radiobutton -label "HH:MM" \
            -command [mymethod refresh_times] \
            -variable [myvar _timeformat] -value "%H:%M"
        $mb.time add radiobutton -label "SOE" \
            -command [mymethod refresh_times] \
            -variable [myvar _timeformat] -value "SOE"
        $mb.time add radiobutton -label "SOD" \
            -command [mymethod refresh_times] \
            -variable [myvar _timeformat] -value "SOD"
        $mb.time add radiobutton -label "(omit)" \
            -command [mymethod refresh_times] \
            -variable [myvar _timeformat] -value " "
        $mb add cascade -label "Range format" -menu $mb.range
        $mb.range add radiobutton -label "START - END" \
            -command [mymethod refresh_times] \
            -variable [myvar _rangeformat] -value "START - END"
        $mb.range add radiobutton -label "START" \
            -command [mymethod refresh_times] \
            -variable [myvar _rangeformat] -value "START"
        $mb.range add radiobutton -label "START (DURATION)" \
            -command [mymethod refresh_times] \
            -variable [myvar _rangeformat] -value "START (DURATION)"
        $mb add command -label "Refresh" \
            -command [mymethod refresh_times]
        label $f.lblHeadingPlot -text "Plot Segment"

        grid configure $f.btnHeadingSelect $f.lblHeadingVariables \
            $f.lblHeadingPlot - $f.btnHeadingTime

        set _count [llength $options(-segmentvariables)]
        set idx 0
        foreach segment $options(-segmentvariables) {
            incr idx

            if {[lsearch [set $options(-varlistvariable)] $segment] < 0} {
                lappend $options(-varlistvariable) $segment
            }
            set _segment($idx,var) $segment
            set _segment($idx,use) 1
            set _segment($idx,time) "..."
            set _segment($idx,win) 5

            checkbutton $f.chk$idx \
                -variable [myvar _segment($idx,use)]

            ::mixin::combobox $f.cbo$idx \
                -textvariable [myvar _segment($idx,var)] \
                -state readonly \
                -modifycmd [mymethod clear_time $idx] \
                -listvariable $options(-varlistvariable)

            button $f.btnPlot$idx -text "Plot in:" \
                -command [mymethod plot_segment $idx]

            ttk::spinbox $f.spnWin$idx \
                -textvariable [myvar _segment($idx,win)] \
                -from 0 -to $options(-maxwin) -width 2

            label $f.lbl$idx \
                -textvariable [myvar _segment($idx,time)]

            grid $f.chk$idx $f.cbo$idx \
                $f.btnPlot$idx $f.spnWin$idx $f.lbl$idx \
                -sticky ew
        }
        unset idx
        grid columnconfigure $f 1 -weight 1 -minsize 80

        labelframe $win.fraWithSelected -text "With selected variables..."

        set f $win.fraWithSelected.fraBottom1
        frame $f
        button $f.btnMerge -text "Merge to:" \
            -command [mymethod merge_selected]
        entry $f.entMergeVar \
            -textvariable [myvar _merge_var]

        button $f.btnPlot -text "Plot in:" \
            -command [mymethod plot_selected]

        ttk::spinbox $f.spnWin \
            -textvariable $options(-windowvariable) \
            -from 0 -to $options(-maxwin) -width 2

        grid $f.btnPlot $f.spnWin x $f.btnMerge $f.entMergeVar \
            -sticky we
        grid columnconfigure $f 4 -weight 2 -minsize 80
        grid columnconfigure $f 2 -weight 1

        set f $win.fraWithSelected.fraBottom2
        frame $f
        button $f.btnDefine -text "Define Region to Process" \
            -command [mymethod define_region]
        button $f.btnStats -text "Statistics" \
            -command [mymethod launch_stats]
        button $f.btnNew -text "New Segment Window" \
            -command [mymethod new_segment_window]

        grid $f.btnDefine x $f.btnStats x $f.btnNew -sticky we
        grid columnconfigure $f {1 3} -weight 1

        grid $win.fraWithSelected.fraBottom1 -sticky we
        grid $win.fraWithSelected.fraBottom2 -sticky we
        grid columnconfigure $win.fraWithSelected 0 -weight 1

        set f $win.fraOptions
        labelframe $f -text "Options"

        checkbutton $f.chkFma \
            -text "Auto Fma" \
            -variable $options(-fmavariable)

        checkbutton $f.chkTitle \
            -text "Var Title" \
            -variable [myvar _pltitle]
        ::misc::tooltip $f.chkTitle \
            "If enabled, the per-variable Plot commands will add the variable's title
            to the plot. This is only suitable if each variable will be plotted in
            separate windows."

        button $win.btnCloseClear -text "Close & Clear" \
            -command [mymethod close_clear]

        grid $f.chkTitle $f.chkFma -sticky w
        grid columnconfigure $f 2 -weight 1

        grid $win.fraVariables - -sticky wens
        grid $win.fraWithSelected $win.fraOptions -sticky wens
        grid ^ $win.btnCloseClear -sticky se
        grid columnconfigure $win 0 -weight 1

        grid rowconfigure $win 0 -weight 1

        after idle [list after 0 [mymethod refresh_times]]
        after idle [list after 0 [mymethod size_optimally]]
        after idle [list after 250 [mymethod size_optimally]]
        after idle [list after 1000 [mymethod size_optimally]]
    }

    method SetTitle {option value} {
        set options($option) $value
        wm title $win $value
    }

    method init_opt_var {opt default} {
        if {![string length $options($opt)]} {
            set options($opt) [myvar _private]($opt)
            set $options($opt) $default
        }
    }

    method size_optimally {} {
        set f $win.fraVariables

        $f configure \
            -vscrollmode none \
            -hscrollmode none

        wm geometry $win ""

        set hw [winfo width $win]
        set fsw [winfo width $f]
        set frw [winfo reqwidth [$f childsite]]
        set padw [expr {[[$f childsite] cget -padx] * 2}]
        set nw [expr {$hw + ($frw - $fsw) + $padw + 4}]

        set hh [winfo height $win]
        set fsh [winfo height $f]
        set frh [winfo reqheight [$f childsite]]
        set padh [expr {[[$f childsite] cget -pady] * 2}]
        set nh [expr {$hh + ($frh - $fsh) + $padh + 4}]

        set sw [winfo screenwidth $win]
        set sh [winfo screenheight $win]

        set too_w 0
        if {$nw > $sw - 100} {
            set nw [expr {$sw - 100}]
            set too_w 1
        }

        set too_h 0
        if {$nh > $sh - 100} {
            set nh [expr {$sh - 100}]
            set too_h 1
        }

        if {$too_w && ! $too_h} {
            incr nh [expr {8 + [$f cget -sbwidth]}]
        }

        if {$too_h && ! $too_w} {
            incr nw [expr {8 + [$f cget -sbwidth]}]
        }

        $f configure \
            -vscrollmode dynamic \
            -hscrollmode dynamic

        set ow [expr {($sw - $nw)/2}]
        set oh [expr {($sh - $nh)/2}]

        wm geometry $win "${nw}x${nh}+$ow+$oh"

        $f configure \
            -vscrollmode none \
            -hscrollmode none
        update idletasks
        set xv [$f xview]
        set yv [$f yview]
        $f configure \
            -vscrollmode dynamic \
            -hscrollmode dynamic
        update idletasks
        {*}[[$f component canvas] cget -xscrollcommand] {*}$xv
        {*}[[$f component canvas] cget -yscrollcommand] {*}$yv
        {*}[[$f component canvas] cget -xscrollcommand] {*}[$f xview]
        {*}[[$f component canvas] cget -yscrollcommand] {*}[$f yview]
    }

    method refresh_times {} {
        for {set i 1} {$i <= $_count} {incr i} {
            after [expr {$i * 20}] [list \
                ybkg tk_sdw_send_times \"[mymethod set_time]\" $i $_segment($i,var)]
        }
    }

    method set_time {idx time_start time_end} {
        set start [clock scan $time_start -gmt 1]
        set end [clock scan $time_end -gmt 1]
        set diff [expr {$end - $start}]

        set date0 [clock format $start -format $_dateformat -gmt 1]
        set date1 [clock format $end -format $_dateformat -gmt 1]

        switch -- $_timeformat {
            SOE {
                set time0 $start
                set time1 $end
            }
            SOD {
                set time0 [expr {$start % 86400}]
                set time1 [expr {$end % 86400}]
            }
            default {
                set time0 [clock format $start -format $_timeformat -gmt 1]
                set time1 [clock format $end -format $_timeformat -gmt 1]
            }
        }

        set datetime0 [string trim "$date0 $time0"]
        set datetime1 [string trim "$date1 $time1"]

        switch -- $_rangeformat {
            "START - END" {
                set _segment($idx,time) "$datetime0 - $datetime1"
            }
            "START" {
                set _segment($idx,time) "$datetime0"
            }
            "START (DURATION)" {
                set d [clock format $diff -format "(%M min %S sec)" -gmt 1]
                set _segment($idx,time) "$datetime0 $d"
            }
        }
    }

    method clear_time {idx} {
        set _segment($idx,time) "..."
    }

    method plot_segment {idx} {
        set args [list -var $_segment($idx,var) -win $_segment($idx,win) \
            -fma [set $options(-fmavariable)]]
        if {$_pltitle} {
            lappend args -title $_segment($idx,var)
        }
        ::display_data {*}$args
    }

    method plot_selected {} {
        set fma [set $options(-fmavariable)]
        for {set idx 1} {$idx <= $_count} {incr idx} {
            if {$_segment($idx,use)} {
                ::display_data -var $_segment($idx,var) \
                    -win [set $options(-windowvariable)] \
                    -fma $fma
                set fma 0
            }
        }
    }

    method merge_selected {} {
        global pro_var

        exp_send "$_merge_var = \[\];\r"
        expect ">"

        for {set idx 1} {$idx <= $_count} {incr idx} {
            if {$_segment($idx,use)} {
                exp_send "grow, $_merge_var, $_segment($idx,var) ;\r"
                expect ">"
            }
        }

        append_varlist $_merge_var
        tk_messageBox -icon info -type ok -parent $win \
            -message "The selected variables have been merged to $_merge_var."
    }

    method launch_stats {args} {
        set seg_vars [list]
        for {set idx 1} {$idx <= $_count} {incr idx} {
            if {$_segment($idx,use)} {
                lappend seg_vars $_segment($idx,var)
            }
        }

        if {[llength $seg_vars]} {
            launch_datastatswindow $seg_vars
        } else {
            tk_messageBox -icon warning \
                -message "No variables were selected." \
                -type ok
        }
    }

    method define_region {} {
        ybkg tk_swd_define_region_possible \"$self\"
    }

    method define_region_not_possible {} {
        tk_messageBox -icon error -type ok -parent .l1wid \
            -message "It is not possible to define a region. You must ensure\
                that you have loaded pnav and edb data first."
    }

    method define_region_is_possible {} {
        set region_list [list]
        for {set idx 1} {$idx <= $_count} {incr idx} {
            if {$_segment($idx,use)} {
                lappend region_list $_segment($idx,var)
            }
        }
        if {[llength $region_list]} {
            set region_list [join $region_list ", "]
            exp_send "tk_sdw_define_region_variables,\
                \"$self\", $region_list;\r"
        } else {
            tk_messageBox -icon error -type ok -parent .l1wid \
                -message "You must select at least one variable in order to define\
                    a region."
        }
    }

    method define_region_successful {} {
        tk_messageBox -icon info -type ok -parent .l1wid \
            -message "The region has been defined."
    }

    method define_region_mismatch {} {
        tk_messageBox -icon error -type ok -parent .l1wid \
            -message "One or more of the selected data variables do not match the\
                loaded data. Please only select data variables whose time frame falls\
                within the loaded edb and pnav data."
    }

    method define_region_multilines {} {
        # Prompt for action
        set response [tk_messageBox -icon question -type yesno -parent .l1wid \
            -message "One or more of the selected data variables appears to contain\
                merged data from multiple flightlines. Do you still want to define\
                the region?"]
        if {$response eq "yes"} {
            ybkg funcset q _tk_swd_region
            tk_messageBox -icon info -type ok -parent .l1wid \
                -message "The region has been defined."
        }
    }

    method new_segment_window {} {
        set seg_vars [list]
        for {set idx 1} {$idx <= $_count} {incr idx} {
            if {$_segment($idx,use)} {
                lappend seg_vars $_segment($idx,var)
            }
        }

        if {[llength $seg_vars]} {
            ::l1pro::segments::select::data_segments $seg_vars
        } else {
            tk_messageBox -icon warning \
                -message "No variables were selected." \
                -type ok
        }
    }

    method close_clear {} {
        set vars $options(-segmentvariables)
        if {[llength $vars] > 1} {
            set this_var "these variables"
        } else {
            set this_var "this variable"
        }

        set response [tk_messageBox -icon question -type yesno \
                -title Warning -message "Do you want to delete ${this_var}?\n$vars"]
        if {$response eq "yes"} {
            set cmd ""
            foreach var $vars {
                append cmd "$var = "
                delete_varlist $var
            }
            append cmd "\[\];"
            exp_send "$cmd\r"
            destroy $self
        }
    }

    method selected {cmd} {
        for {set idx 1} {$idx <= $_count} {incr idx} {
            switch -- $cmd {
                all {
                    set _segment($idx,use) 1
                }
                none {
                    set _segment($idx,use) 0
                }
                toggle {
                    set _segment($idx,use) [expr {1 - $_segment($idx,use)}]
                }
            }
        }
    }
}
