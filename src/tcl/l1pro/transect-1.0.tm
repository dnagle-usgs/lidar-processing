# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::transect 1.0
package require mixin
package require misc

namespace eval l1pro::transect {
    namespace import ::misc::appendif

    if {![namespace exists v]} {
        namespace eval v {
            variable top .transect
            variable maxrow 0
            variable settings

            variable track
            array set track {
                var     pnav
                skip    5
                color   blue
                win     5
                msize   0.1
                utm     1
            }

            variable marker_mapping {
                Square      1
                Cross       2
                Triangle    3
                Circle      4
                Diamond     5
                Cross2      6
                Triangle2   7
            }

            variable recalls [list 0 -1 -2 -3 1 2 3]
        }
    }

    proc gui {} {
        if {[winfo exists $v::top]} {
            wm deiconify $v::top
            ::misc::raise_win $v::top
            return
        }
        set v::maxrow 0
        toplevel $v::top
        wm title $v::top "Transect Tool"
        wm resizable $v::top 1 0

        array unset v::settings

        set w [ttk::frame $v::top.f]
        pack $w -expand 1 -fill both

        ttk::frame $w.rows
        ttk::frame $w.bottom
        pack $w.rows $w.bottom -side top -expand 1 -fill both

        set f $w.rows

        set p $f.labels_
        ttk::label ${p}data -text "Data"
        ttk::label ${p}recall -text "Recall"
        ttk::label ${p}width -text "Width"
        ttk::label ${p}iwin -text "iWin"
        ttk::label ${p}owin -text "oWin"
        ttk::label ${p}marker -text "Marker"
        ttk::label ${p}options -text "Options"
        ttk::separator ${p}seph -orient horizontal

        grid \
            x x x \
            ${p}data - x \
            ${p}recall - x \
            ${p}width ${p}iwin ${p}owin x \
            ${p}marker - x \
            ${p}options \
            -padx 2 -pady 2
        grid ${p}seph - - - - - - - - - - - - - - - - - - - - - \
                -padx 2 -pady 0 -sticky ew

        gui_add_row

        grid columnconfigure $f 3 -weight 1 -minsize 75

        set var ::l1pro::transect::v::track
        set f $w.bottom
        ttk::separator $f.septop -orient horizontal
        ttk::button $f.show_track -text "Show Track:" -width 0 \
                -command l1pro::transect::do_show_track
        ::mixin::combobox $f.var \
                -width 6 -state readonly \
                -textvariable ${var}(var) \
                -values {pnav gt_fsall gt_fs fs_all}
        ttk::label $f.lblskip -text "Skip:"
        ttk::spinbox $f.skip -width 3 \
                -textvariable ${var}(skip)
        ttk::label $f.lblcolor -text "Color:"
        ::mixin::combobox $f.color \
                -width 7 -state readonly \
                -textvariable ${var}(color) \
                -values {black red blue green yellow magenta cyan}
        ttk::label $f.lblwin -text "Win:"
        ttk::spinbox $f.win -width 2 \
                -textvariable ${var}(win)
        ttk::label $f.lblsize -text "Size:"
        ttk::spinbox $f.size -width 3 \
                -textvariable ${var}(msize)
        ttk::checkbutton $f.utm -text "UTM" \
                -variable ${var}(utm)
        ttk::button $f.history -text "Show History" -width 0
        ttk::button $f.add_row -text "Add Row" -width 0 \
                -command l1pro::transect::gui_add_row

        lower [ttk::frame $f.bottom]
        pack $f.show_track $f.var $f.lblskip $f.skip $f.lblcolor $f.color \
            $f.lblwin $f.win $f.lblsize $f.size $f.utm \
            -in $f.bottom -padx 2 -pady 2 -side left
        pack $f.history $f.add_row \
            -in $f.bottom -padx 2 -pady 2 -side right

        pack $f.septop $f.bottom -in $f -side top -fill both -expand 1
        pack $f.septop -pady 2
    }

    proc init_settings {row} {
        variable v::settings

        set settings($row,var) $::pro_var
        set settings($row,userecall) 0
        set settings($row,recall) 0
        set settings($row,width) 3.0
        set settings($row,iwin) 5
        set settings($row,owin) 2
        set settings($row,marker) 1
        set settings($row,msize) 0.1
        set settings($row,connect) 0
        set settings($row,xfma) 1
        set settings($row,showline) 0
        set settings($row,showpts) 0
        set settings($row,flight) 0
        set settings($row,line) 1
        set settings($row,channel) 0
        set settings($row,digitizer) 0

        switch -- $::plot_settings(display_mode) {
            be - ch {
                set settings($row,mode) be
            }
            ba - lint - de {
                set settings($row,mode) ba
            }
            default {
                set settings($row,mode) fs
            }
        }
    }

    proc get_settings {row} {
        set result [list]
        foreach key {
            var userecall recall width iwin owin marker msize connect xfma
            showline showpts flight line channel digitizer mode
        } {
            dict set result $key $v::settings($row,$key)
        }
        return $result
    }

    proc gui_add_row {} {
        set f $v::top.f.rows
        set row [incr v::maxrow]
        set p $f.row${row}_

        init_settings $row

        set var ::l1pro::transect::v::settings

        ttk::button ${p}transect -text "Transect $row:" -width 0 \
                -command [list l1pro::transect::do_transect $row]
        ::mixin::combobox ${p}var -state readonly -width 12 \
                -textvariable ${var}($row,var) \
                -listvariable ::varlist
        ::mixin::combobox ${p}mode -state readonly -width 2 \
                -textvariable ${var}($row,mode) \
                -values {fs be ba}
        ttk::checkbutton ${p}userecall -text "" \
                -variable ${var}($row,userecall) \
                -style NoLabel.TCheckbutton
        ::mixin::combobox ${p}recall -text 0 -width 4 \
                -textvariable ${var}($row,recall) \
                -listvariable ::l1pro::transect::v::recalls
        ttk::spinbox ${p}width -width 4 \
                -textvariable ${var}($row,width)
        ttk::spinbox ${p}iwin -width 2 \
                -textvariable ${var}($row,iwin)
        ttk::spinbox ${p}owin -width 2 \
                -textvariable ${var}($row,owin)
        ::mixin::combobox::mapping ${p}marker \
                -width 7 -state readonly \
                -altvariable ${var}($row,marker) \
                -mapping $v::marker_mapping
        ttk::spinbox ${p}msize -text 1.0 -width 3 \
                -textvariable ${var}($row,msize)
        ttk::checkbutton ${p}connect -text "Connect" \
                -variable ${var}($row,connect) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}fma -text "FMA" \
                -variable ${var}($row,xfma) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}showline -text "Show Line" \
                -variable ${var}($row,showline) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}showpoints -text "Show Points" \
                -variable ${var}($row,showpts) \
                -style Small.TCheckbutton
        ttk::label ${p}segment -text "Segment by:" \
                -style Small.TLabel
        ttk::checkbutton ${p}flight -text "flight" \
                -variable ${var}($row,flight) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}line -text "line" \
                -variable ${var}($row,line) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}channel -text "channel" \
                -variable ${var}($row,channel) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}digitizer -text "digitizer" \
                -variable ${var}($row,digitizer) \
                -style Small.TCheckbutton
        ttk::button ${p}plotline -text "Line" -width 0 \
                -command [list l1pro::transect::do_line $row]
        ttk::button ${p}examine -text "Examine" -width 0 \
                -command [list l1pro::transect::do_examine $row]
        ttk::button ${p}delete -text "X" -width 0 \
                -command [list l1pro::transect::gui_del_row $row]

        ::mixin::statevar ${p}recall \
                -statemap {0 disabled 1 !disabled} \
                -statevariable ${var}($row,userecall)
        ::mixin::statevar ${p}plotline \
                -statemap {0 disabled 1 !disabled} \
                -statevariable ${var}($row,userecall)

        foreach j {0 1 2 3 4 5 6 7} {
            ttk::separator ${p}sep$j -orient vertical
        }
        ttk::separator ${p}seph -orient horizontal

        lower [ttk::frame ${p}optionshi]
        pack ${p}connect ${p}fma ${p}showline ${p}showpoints \
                -in ${p}optionshi -side left -padx 2
        lower [ttk::frame ${p}optionslo]
        pack ${p}segment ${p}flight ${p}line ${p}channel ${p}digitizer \
                -in ${p}optionslo -side left -padx 1
        pack ${p}segment -padx 2
        lower [ttk::frame ${p}options]
        pack ${p}optionshi ${p}optionslo \
                -in ${p}options -side top -anchor w

        grid \
                ${p}sep0 \
                ${p}transect \
                ${p}sep1 \
                ${p}var ${p}mode \
                ${p}sep2 \
                ${p}userecall ${p}recall \
                ${p}sep3 \
                ${p}width ${p}iwin ${p}owin \
                ${p}sep4 \
                ${p}marker ${p}msize \
                ${p}sep5 \
                ${p}options \
                ${p}sep6 \
                ${p}plotline ${p}examine ${p}delete \
                ${p}sep7 \
                -padx 2 -pady 2
        grid ${p}seph - - - - - - - - - - - - - - - - - - - - - \
                -padx 2 -pady 0 -sticky ew

        grid ${p}var -sticky ew

        foreach j {0 1 2 3 4 5 6 7} {
            grid ${p}sep$j -sticky ns -padx 2 -pady 0
        }
    }

    proc gui_del_row {row} {
        set f $v::top.f.rows
        set p $f.row${row}_
        foreach child [winfo children $f] {
            if {[string match ${p}* $child]} {
                destroy $child
            }
        }
    }

    proc add_or_promote_recall {val} {
        set newlist [list $val]
        foreach item $v::recalls {
            if {$item ni $newlist} {
                lappend newlist $item
            }
        }
        set v::recalls [lrange $newlist 0 9]
    }

    # Dummy for debugging for now
    proc do_transect {row} {
        set settings [get_settings $row]
        dict with settings {
            if {$userecall} {
                add_or_promote_recall $recall
            }

            set segment [list]
            foreach type {flight line channel digitizer} {
                if {[set $type]} {
                    lappend segment $type
                }
            }
            if {[llength $segment] > 1} {
                set segment \[\"[join $segment \",\"]\"\]
            } elseif {$segment ne ""} {
                set segment \"$segment\"
            }

            set cmd "tr$row = transect($var, mode=\"$mode\""
            appendif cmd \
                    $userecall          ", recall=$recall" \
                    {$segment ne ""}    ", segment=$segment" \
                    {$width != 3}       ", width=$width" \
                    {$iwin != 5}        ", iwin=$iwin" \
                    {$owin != 2}        ", owin=$owin" \
                    $xfma               ", xfma=1" \
                    {$marker != 1}      ", marker=$marker" \
                    {$msize != 0.1}     ", msize=$msize" \
                    $connect            ", connect=1" \
                    $showline           ", showline=2" \
                    $showpts            ", showpts=1" \
                    1                   ")"
            exp_send "$cmd;\r"

            append_varlist tr$row
        }
    }

    proc do_line {row} {
        set settings [get_settings $row]
        dict with settings {
            exp_send "transect_plot_line, win=$iwin, recall=$recall;\r"
        }
    }

    proc do_examine {row} {
        set settings [get_settings $row]
        dict with settings {
            if {$userecall} {
                set rec $recall
            } else {
                set rec 0
            }
            exp_send "transect_pixelwf_interactive, \"tr$row\", mode=\"$mode\", recall=$rec, win=$owin;\r"
        }
    }

    proc do_show_history {} {
        exp_send "transect_history;\r"
    }

    proc do_show_track {} {
        set settings [array get v::track]
        dict with settings {
            exp_send "show_track, $var, utm=$utm, skip=$skip, color=\"$color\", win=$win, msize=$msize;\r"
        }
    }
}
