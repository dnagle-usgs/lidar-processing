# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::transect 1.0

namespace eval l1pro::transect {

    if {![namespace exists v]} {
        namespace eval v {
            variable top .transect
            variable maxrow 0
            variable settings
        }
    }

    proc gui {} {
        destroy $v::top
        set v::maxrow 0
        toplevel $v::top

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

        set f $w.bottom
        ttk::separator $f.septop -orient horizontal
        ttk::button $f.show_track -text "Show Track:" -width 0
        ::mixin::combobox $f.var -text "pnav" -width 8
        ttk::label $f.lblskip -text "Skip:"
        ttk::spinbox $f.skip -width 3
        ttk::label $f.lblcolor -text "Color:"
        ::mixin::combobox $f.color -text "blue" -width 5
        ttk::label $f.lblwin -text "Win:"
        ttk::spinbox $f.win -width 3
        ttk::label $f.lblsize -text "Size:"
        ttk::spinbox $f.size -width 4
        ttk::checkbutton $f.utm -text "UTM"
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

    proc gui_add_row {} {
        set f $v::top.f.rows
        set row [incr v::maxrow]
        set p $f.row${row}_

        init_settings $row

        set var ::l1pro::transect::v::settings

        ttk::button ${p}transect -text "Transect" -width 0 \
                -command [list l1pro::transect::do_transect $row]
        ::mixin::combobox ${p}var -state readonly -width 8 \
                -textvariable ${var}($row,var) \
                -listvariable ::varlist
        ::mixin::combobox ${p}mode -state readonly -width 2 \
                -textvariable ${var}($row,mode) \
                -values {fs be ba}
        ttk::checkbutton ${p}userecall -text "" \
                -variable ${var}($row,userecall) \
                -style NoLabel.TCheckbutton
        ::mixin::combobox ${p}recall -text 0 -width 5 \
                -textvariable ${var}($row,recall)
        ttk::spinbox ${p}width -text 3.00 -width 5 \
                -textvariable ${var}($row,width)
        ttk::spinbox ${p}iwin -text 5 -width 3 \
                -textvariable ${var}($row,iwin)
        ttk::spinbox ${p}owin -text 3 -width 3 \
                -textvariable ${var}($row,owin)
        ::mixin::combobox ${p}marker -text square -width 6 \
                -textvariable ${var}($row,marker)
        ttk::spinbox ${p}msize -text 1.0 -width 4 \
                -textvariable ${var}($row,msize)
        ttk::checkbutton ${p}connect -text "Connect" \
                -variable ${var}($row,connect) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}fma -text "FMA" \
                -variable ${var}($row,xfma) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}showline -text "Line" \
                -variable ${var}($row,showline) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}showpoints -text "Points" \
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
        ttk::button ${p}plotline -text "Line" -width 0
        ttk::button ${p}examine -text "Examine" -width 0
        ttk::button ${p}delete -text "X" -width 0 \
                -command [list l1pro::transect::gui_del_row $row]

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

    # Dummy for debugging for now
    proc do_transect {row} {
        puts "var:\t$v::settings($row,var)"
        puts "mode:\t$v::settings($row,mode)"
    }
}
