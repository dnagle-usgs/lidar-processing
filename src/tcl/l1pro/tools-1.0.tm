# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::tools 1.0

namespace eval ::l1pro::tools {
    namespace import ::misc::appendif
}

if {![namespace exists ::l1pro::tools::rcf]} {
    namespace eval ::l1pro::tools::rcf {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .l1wid.rcf
            variable invar ""
            variable outvar ""
            variable w 20
            variable buf 500
            variable n 3
            variable mode {}
        }
    }
}

proc ::l1pro::tools::rcf::gui args {
    set ns [namespace current]
    set w $v::top
    destroy $w
    toplevel $w

    wm resizable $w 1 0
    wm title $w "Random Consensus Filter"

    if {[dict exists $args -var]} {
        set v::invar [dict get $args -var]
    } else {
        set v::invar $::pro_var
    }
    set v::outvar ${v::invar}_grcf
    set v::mode $::plot_settings(display_mode)

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set f $w

    ttk::label $f.lblbuf -text "Horizontal buffer (cm): "
    ttk::label $f.lblw -text "Elevation window (cm): "
    ttk::label $f.lbln -text "Minimum winners: "
    ttk::label $f.lblinput -text "Input variable: "
    ttk::label $f.lbloutput -text "Output variable: "
    ttk::label $f.lblmode -text "Data mode: "

    ::mixin::combobox::mapping $f.mode \
            -state readonly \
            -altvariable ${ns}::v::mode \
            -mapping $::l1pro_data(mode_mapping)

    ::mixin::combobox $f.input \
            -state readonly \
            -listvariable ::varlist \
            -textvariable ${ns}::v::invar

    ttk::spinbox $f.buf -from 1 -to 100000 -increment 1 \
            -format %.0f \
            -textvariable ${ns}::v::buf
    ttk::spinbox $f.w -from 1 -to 100000 -increment 1 \
            -format %.0f \
            -textvariable ${ns}::v::w
    ttk::spinbox $f.n -from 1 -to 100000 -increment 1 \
            -format %.0f \
            -textvariable ${ns}::v::n
    ttk::entry $f.output \
            -textvariable ${ns}::v::outvar

    ttk::frame $f.buttons
    ttk::button $f.filter -text "Filter" \
            -command ::l1pro::tools::rcf::filter
    ttk::button $f.dismiss -text "Dismiss" \
            -command [list destroy [winfo toplevel $f]]

    grid x $f.filter $f.dismiss -padx 2 -in $f.buttons
    grid columnconfigure $f.buttons {0 3} -weight 1

    grid $f.lblinput $f.input -in $w.f -padx 2 -pady 2
    grid $f.lblmode $f.mode -in $w.f -padx 2 -pady 2
    grid $f.lblbuf $f.buf -in $w.f -padx 2 -pady 2
    grid $f.lblw $f.w -in $w.f -padx 2 -pady 2
    grid $f.lbln $f.n -in $w.f -padx 2 -pady 2
    grid $f.lbloutput $f.output -in $w.f -padx 2 -pady 2
    grid $f.buttons - -in $w.f -pady 2

    grid configure $f.lblinput $f.lblmode $f.lblbuf $f.lblw $f.lbln \
            $f.lbloutput -sticky e
    grid configure $f.input $f.mode $f.buf $f.w $f.n $f.output $f.buttons \
            -sticky ew

    grid columnconfigure $w.f 1 -weight 1
}

proc ::l1pro::tools::rcf::filter {} {
    set cmd "$v::outvar = rcf_filter_eaarl($v::invar"
    append cmd ", mode=\"$v::mode\""
    append cmd ", buf=$v::buf"
    append cmd ", w=$v::w"
    append cmd ", n=$v::n"
    append cmd ")"

    exp_send "$cmd\r"

    append_varlist $v::outvar
    destroy $v::top
}


if {![namespace exists ::l1pro::tools::histelev]} {
    namespace eval ::l1pro::tools::histelev {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .l1wid.histelev
            variable cbartop .l1wid.cbartool
            variable auto_binsize 1
            variable binsize 0.30
            variable normalize 1
            variable win 7
            variable dofma 1
            variable dock 1
            variable logy 0

            variable plot_histline_show 1
            variable plot_histline_type solid
            variable plot_histline_color blue
            variable plot_histline_size 2

            variable plot_histbar_show 1
            variable plot_histbar_type dot
            variable plot_histbar_color black
            variable plot_histbar_size 2

            variable plot_tickmarks_show 0
            variable plot_tickmarks_type square
            variable plot_tickmarks_color red
            variable plot_tickmarks_size 0.1

            variable plot_kdeline_show 0
            variable plot_kdeline_type solid
            variable plot_kdeline_color green
            variable plot_kdeline_size 2

            variable kernel gaussian
            variable auto_bandwidth 1
            variable bandwidth 0.15
            variable kdesample 100
        }
        namespace eval c {
            variable colors {black white red green blue cyan magenta yellow}
            variable types {solid dash dot dashdot dashdotdot}
        }
    }
}

proc ::l1pro::tools::histelev {} {
    ::l1pro::tools::histelev::plot
}

proc ::l1pro::tools::histelev::plot {} {
    set plot_defaults {
        histline "solid blue 2"
        histbar "dot black 2"
        tickmarks "hide"
        kdeline "hide"
    }

    if {$v::dock} {
        cbar_tool_docked $v::win
    } else {
        cbar_tool
    }

    set cmd "hist_data_plot, $::pro_var"

    set mode_names [dict merge [lreverse $::l1pro_data(mode_mapping)] \
            [list fs "First surface" be "Bare earth" ba Bathymetry]]
    set title [dict get $mode_names $::plot_settings(display_mode)]
    set title "$title $::pro_var"

    appendif cmd \
            1                   ", mode=\"$::plot_settings(display_mode)\"" \
            1                       ", title=\"$title\"" \
            {! $v::auto_binsize}    ", binsize=$v::binsize" \
            {$v::normalize != 1}    ", normalize=$v::normalize" \
            1                       ", win=$v::win" \
            {! $v::dofma}           ", dofma=0" \
            {$v::logy}              ", logy=1"

    foreach plot [dict keys $plot_defaults] {
        if {[set v::plot_${plot}_show]} {
            set type [set v::plot_${plot}_type]
            set color [set v::plot_${plot}_color]
            set size [format %g [set v::plot_${plot}_size]]
            set val "$type $color $size"
        } else {
            set val hide
        }
        if {$val ne [dict get $plot_defaults $plot]} {
            append cmd ", ${plot}=\"$val\""
        }
    }
    if {$v::plot_kdeline_show} {
        appendif cmd \
                1                          ", kernel=\"$v::kernel\"" \
                {! $v::auto_bandwidth}     ", bandwidth=$v::bandwidth" \
                {$v::kdesample != 100}     ", kdesample=$v::kdesample"
    }
    exp_send "$cmd\r"
}

proc ::l1pro::tools::histelev::krnl_profile {} {
    set cmd "krnl_plot_profile, \"$v::kernel\", win=$v::win"
    exp_send "$cmd\r"
}

proc ::l1pro::tools::histelev::gui {} {
    set w $v::top
    destroy $w
    toplevel $w

    wm resizable $w 1 0
    wm title $w "Histogram Elevations"

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set labels [list]

    gui_general $w.general labels
    gui_line $w.line labels
    gui_box $w.box labels
    gui_ticks $w.ticks labels
    gui_kde $w.kde labels
    gui_buttons $w.buttons

    foreach item {general line box ticks kde buttons} {
        grid $w.$item -in $w.f -sticky news
    }
    grid columnconfigure $w.f 0 -weight 1

    set biggest 0
    foreach label $labels {
        if {$biggest < [winfo reqwidth $label]} {
            set biggest [winfo reqwidth $label]
        }
    }
    foreach label $labels {
        set opts [grid info $label]
        grid columnconfigure [dict get $opts -in] 0 -minsize $biggest
    }
}

proc ::l1pro::tools::histelev::gui_general {f labelsVar} {
    set ns [namespace current]
    upvar $labelsVar labels
    ttk::labelframe $f -text "General settings"
    ttk::label $f.lblnormalize -text "Y axis: "
    ttk::label $f.lblwin -text "Window: "
    ttk::label $f.lbldock -text "Dock buttons to window"
    ttk::label $f.lbldofma -text "Clear before plotting"
    ttk::label $f.lbllogy -text "Use logarithmic y axis"
    ttk::label $f.lblautobin -text "Automatically set bin size"
    ttk::label $f.lblbinsize -text "Bin size: "
    ::mixin::combobox::mapping $f.normalize \
            -state readonly \
            -altvariable ${ns}::v::normalize \
            -mapping {
                "Density"   1
                "Counts"    0
            }
    ttk::spinbox $f.win -from 0 -to 63 -increment 1 \
            -textvariable ${ns}::v::win
    ttk::checkbutton $f.dock \
            -variable ${ns}::v::dock
    ttk::checkbutton $f.dofma \
            -variable ${ns}::v::dofma
    ttk::checkbutton $f.logy \
            -variable ${ns}::v::logy
    ttk::checkbutton $f.autobin \
            -variable ${ns}::v::auto_binsize
    ttk::spinbox $f.binsize -from 0 -to 100 -increment 0.01 \
            -textvariable ${ns}::v::binsize
    grid $f.lblnormalize $f.normalize
    grid $f.lblwin $f.win
    grid $f.dock $f.lbldock
    grid $f.dofma $f.lbldofma
    grid $f.logy $f.lbllogy
    grid $f.autobin $f.lblautobin
    grid $f.lblbinsize $f.binsize
    grid $f.lblnormalize $f.lblwin $f.dock $f.dofma $f.logy $f.autobin \
            $f.lblbinsize -sticky e
    grid $f.normalize $f.win $f.binsize -sticky ew
    grid $f.lbldock $f.lbldofma $f.lbllogy $f.lblautobin -sticky w
    grid columnconfigure $f 1 -weight 1
    lappend labels $f.lblnormalize $f.lblwin $f.lblbinsize

    ::mixin::statevar $f.binsize \
            -statemap {0 normal 1 disabled} \
            -statevariable ${ns}::v::auto_binsize

    ::misc::bind::label_to_checkbutton $f.lbldock $f.dock
    ::misc::bind::label_to_checkbutton $f.lbldofma $f.dofma
    ::misc::bind::label_to_checkbutton $f.lbllogy $f.logy
    ::misc::bind::label_to_checkbutton $f.lblautobin $f.autobin

    foreach widget [list $f.autobin $f.lblautobin] {
        ::tooltip::tooltip $widget \
                "The automatic bin size is determined as thus:\
                \n \u2022 Attempt to use a binsize that gives 50 bins.\
                \n \u2022 If that binsize is < 0.25, then try to increase\
                \n        binsize using 25 bins.\
                \n \u2022 If that binsize is < 0.17, then try to increase\
                \n        binsize using 20 bins.\
                \n \u2022 If that binsize is < 0.10, then set binsize to 0.10."
    }

    return $f
}

proc ::l1pro::tools::histelev::gui_line {w labelsVar} {
    set ns [namespace current]
    upvar $labelsVar labels
    ::mixin::labelframe::collapsible $w \
            -text "Plot histogram line graph" \
            -variable ${ns}::v::plot_histline_show
    set f [$w interior]
    ttk::label $f.lblcolor -text "Line color: "
    ttk::label $f.lblwidth -text "Line width: "
    ttk::label $f.lbltype -text "Line type: "
    ::mixin::combobox $f.color -state readonly \
            -textvariable ${ns}::v::plot_histline_color \
            -values $c::colors
    ttk::spinbox $f.width -from 0 -to 10 -increment 0.1 \
            -textvariable ${ns}::v::plot_histline_size
    ::mixin::combobox $f.type -state readonly \
            -textvariable ${ns}::v::plot_histline_type \
            -values $c::types
    grid $f.lblcolor $f.color
    grid $f.lblwidth $f.width
    grid $f.lbltype $f.type
    grid $f.lblcolor $f.lblwidth $f.lbltype -sticky e
    grid $f.color $f.width $f.type -sticky ew
    grid columnconfigure $f 1 -weight 1
    lappend labels $f.lblcolor $f.lblwidth $f.lbltype
    return $w
}

proc ::l1pro::tools::histelev::gui_box {w labelsVar} {
    set ns [namespace current]
    upvar $labelsVar labels
    ::mixin::labelframe::collapsible $w \
            -text "Plot histogram bar graph" \
            -variable ${ns}::v::plot_histbar_show
    set f [$w interior]
    ttk::label $f.lblcolor -text "Line color: "
    ttk::label $f.lblwidth -text "Line width: "
    ttk::label $f.lbltype -text "Line type: "
    ::mixin::combobox $f.color -state readonly \
            -textvariable ${ns}::v::plot_histbar_color \
            -values $c::colors
    ttk::spinbox $f.width -from 0 -to 10 -increment 0.1 \
            -textvariable ${ns}::v::plot_histbar_size
    ::mixin::combobox $f.type -state readonly \
            -textvariable ${ns}::v::plot_histbar_type \
            -values $c::types
    grid $f.lblcolor $f.color
    grid $f.lblwidth $f.width
    grid $f.lbltype $f.type
    grid $f.lblcolor $f.lblwidth $f.lbltype -sticky e
    grid $f.color $f.width $f.type -sticky ew
    grid columnconfigure $f 1 -weight 1
    lappend labels $f.lblcolor $f.lblwidth $f.lbltype
    return $w
}

proc ::l1pro::tools::histelev::gui_ticks {w labelsVar} {
    set ns [namespace current]
    upvar $labelsVar labels
    ::mixin::labelframe::collapsible $w \
            -text "Plot elevation tickmarks" \
            -variable ${ns}::v::plot_tickmarks_show
    set f [$w interior]
    ttk::label $f.lblcolor -text "Tick color: "
    ttk::label $f.lblsize -text "Tick size: "
    ::mixin::combobox $f.color -state readonly \
            -textvariable ${ns}::v::plot_tickmarks_color \
            -values $c::colors
    ttk::spinbox $f.size -from 0 -to 10 -increment 0.1 \
            -textvariable ${ns}::v::plot_tickmarks_size
    grid $f.lblcolor $f.color
    grid $f.lblsize $f.size
    grid $f.lblcolor $f.lblsize -sticky e
    grid $f.color $f.size -sticky ew
    grid columnconfigure $f 1 -weight 1
    lappend labels $f.lblcolor $f.lblsize
    return $w
}

proc ::l1pro::tools::histelev::gui_kde {w labelsVar} {
    set ns [namespace current]
    upvar $labelsVar labels
    ::mixin::labelframe::collapsible $w \
            -text "Plot kernel density estimate" \
            -variable ${ns}::v::plot_kdeline_show
    set f [$w interior]
    ttk::label $f.lblkernel -text "Kernel: "
    ttk::label $f.lblautoband -text "Match bandwith to bin size"
    ttk::label $f.lblbandwidth -text "Bandwidth: "
    ttk::label $f.lblsample -text "Samples: "
    ttk::label $f.lblcolor -text "Line color: "
    ttk::label $f.lblwidth -text "Line width: "
    ttk::label $f.lbltype -text "Line type: "
    ::mixin::combobox $f.kernel -state readonly -width 12 \
            -textvariable ${ns}::v::kernel \
            -values {uniform triangular epanechnikov quartic triweight \
                    gaussian cosine}
    ttk::button $f.profile -text " Profile " -width 0\
            -command ::l1pro::tools::histelev::krnl_profile
    ttk::checkbutton $f.autoband \
            -variable ${ns}::v::auto_bandwidth
    ttk::spinbox $f.bandwidth -from 0 -to 100 -increment 0.01 \
            -textvariable ${ns}::v::bandwidth
    ttk::spinbox $f.sample -from 1 -to 10000 -increment 1 \
            -textvariable ${ns}::v::kdesample
    ::mixin::combobox $f.color -state readonly \
            -textvariable ${ns}::v::plot_kdeline_color \
            -values $c::colors
    ttk::spinbox $f.width -from 0 -to 10 -increment 0.1 \
            -textvariable ${ns}::v::plot_kdeline_size
    ::mixin::combobox $f.type -state readonly \
            -textvariable ${ns}::v::plot_kdeline_type \
            -values $c::types
    grid $f.lblkernel $f.kernel $f.profile
    grid $f.autoband $f.lblautoband -
    grid $f.lblbandwidth $f.bandwidth -
    grid $f.lblsample $f.sample -
    grid $f.lblcolor $f.color -
    grid $f.lblwidth $f.width -
    grid $f.lbltype $f.type -
    grid $f.lblkernel $f.autoband $f.lblbandwidth $f.lblsample $f.lblcolor \
            $f.lblwidth $f.lbltype -sticky e
    grid $f.kernel $f.profile $f.bandwidth $f.sample $f.color $f.width \
            $f.type -sticky ew
    grid $f.lblautoband -sticky w
    grid columnconfigure $f 1 -weight 1
    ::mixin::statevar $f.bandwidth \
            -statemap {0 normal 1 disabled} \
            -statevariable ${ns}::v::auto_bandwidth

    ::misc::bind::label_to_checkbutton $f.lblautoband $f.autoband

    lappend labels $f.lblkernel $f.lblbandwidth $f.lblsample $f.lblcolor \
            $f.lblwidth $f.lbltype

    foreach widget [list $f.lblautoband $f.autoband] {
        ::tooltip::tooltip $widget \
            "If enabled, then the bandwidth is set to try to give the\
            \nresulting graph a similar scale as the histogram line graph.\
            \nSpecifically:\
            \n \u2022 if kernel is gaussian, bandwith is set to half the\
            \n        binsize;
            \n \u2022 otherwise, bandwidth is set to the binsize."
    }

    return $w
}

proc ::l1pro::tools::histelev::gui_buttons f {
    ttk::frame $f
    ttk::button $f.plot -text "Plot" -command ::l1pro::tools::histelev
    ttk::button $f.dismiss -text "Dismiss" -command [list destroy $v::top]
    grid x $f.plot $f.dismiss -padx 2 -pady 2
    grid columnconfigure $f {0 3} -weight 1
    return $f
}

proc ::l1pro::tools::histelev::cbar_tool {} {
    set ns [namespace current]
    set w $v::cbartop
    if {[winfo exists $w]} {
        return
    }
    toplevel $w
    wm resizable $w 0 0
    wm title $w "Colorbar Tool"

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set f $w

    ttk::frame $f.fwin
    ttk::label $f.lblwin -text "Window: "
    ttk::spinbox $f.win -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::win

    grid $f.lblwin $f.win -in $f.fwin -sticky ew
    grid columnconfigure $f.fwin 1 -weight 1

    set cmd ${ns}::cbar_do
    ttk::button $f.cmax -text "Cmax" -width 0 -command [list $cmd cmax]
    ttk::button $f.cmin -text "Cmin" -width 0 -command [list $cmd cmin]
    ttk::button $f.both -text "Both" -width 0 -command [list $cmd both]
    ttk::button $f.dism -text "Close" -width 0 -command [list $cmd dism]
    ttk::button $f.bdis -text "Both & Close" -width 0 -command [list $cmd bdis]

    grid $f.fwin - - -in $f.f -sticky ew -padx 1 -pady 1
    grid $f.cmax $f.both $f.dism -in $f.f -sticky ew -padx 1 -pady 1
    grid $f.cmin $f.bdis - -in $f.f -sticky ew -padx 1 -pady 1
    grid columnconfigure $f.f {0 1 2} -weight 1 -uniform 1
}

proc ::l1pro::tools::histelev::cbar_tool_docked {win} {
    set ns [namespace current]
    set w [::yorick::window::path $win]
    wm title $w "Window $win - Colorbar Tool"

    set f [$w pane bottom]

    set cmd [list apply [list op "return \"${ns}::cbar_do \$op $win $w\""]]
    ttk::button $f.cmax -text "Cmax" -width 0 -command [{*}$cmd cmax]
    ttk::button $f.cmin -text "Cmin" -width 0 -command [{*}$cmd cmin]
    ttk::button $f.both -text "Both" -width 0 -command [{*}$cmd both]
    ttk::button $f.dism -text "Close" -width 0 -command [{*}$cmd dism]
    ttk::button $f.bdis -text "Both & Close" -width 0 -command [{*}$cmd bdis]

    grid $f.cmax $f.cmin $f.both $f.bdis $f.dism -sticky ew -padx 1 -pady 1
    grid columnconfigure $f {0 1 2 4} -weight 1 -uniform 1
    grid columnconfigure $f 3 -weight 2 -uniform 1
}

proc ::l1pro::tools::histelev::cbar_do {cmd {win -1} {top null}} {
    set docked 1
    if {$win < 0} {
        set win $v::win
    }
    if {$top eq "null"} {
        set top $v::cbartop
        set docked 0
    }
    switch -- $cmd {
        both  {exp_send "set_cbar, w=$win, \"both\"\r"}
        cmax  {exp_send "set_cbar, w=$win, \"cmax\"\r"}
        cmin  {exp_send "set_cbar, w=$win, \"cmin\"\r"}
        dism  {exp_send "winkill, $win\r"}
        bdis  {
            exp_send "set_cbar, w=$win, \"both\"; winkill, $win\r"
        }
    }
}

if {![namespace exists ::l1pro::tools::elevclip]} {
    namespace eval ::l1pro::tools::histclip {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .l1wid.elevclip
            variable invar {}
            variable minelv 0
            variable maxelv 0
            variable usemin 1
            variable usemax 1
            variable outvar {}
        }
    }
}

proc ::l1pro::tools::histclip::gui {} {
    set ns [namespace current]
    set w $v::top
    destroy $w
    toplevel $w

    wm resizable $w 1 0
    wm title $w "Elevation Clipper"

    set v::invar $::pro_var
    set v::outvar $::pro_var
    set v::minelv $::plot_settings(cmin)
    set v::maxelv $::plot_settings(cmax)
    set v::usemin 1
    set v::usemax 1

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set f $w

    ttk::label $f.lblinput -text "Input variable: "
    ttk::label $f.lblmin -text "Minimum elevation: "
    ttk::label $f.lblmax -text "Maximum elevation: "
    ttk::label $f.lbloutput -text "Output variable: "

    ::mixin::combobox $f.input \
            -state readonly \
            -listvariable ::varlist \
            -textvariable ${ns}::v::invar

    ttk::checkbutton $f.usemin -variable ${ns}::v::usemin
    ttk::checkbutton $f.usemax -variable ${ns}::v::usemax

    ttk::spinbox $f.minelv -from -5000 -to 5000 -increment 0.1 \
            -format %.2f \
            -textvariable ${ns}::v::minelv
    ttk::spinbox $f.maxelv -from -5000 -to 5000 -increment 0.1 \
            -format %.2f \
            -textvariable ${ns}::v::maxelv

    ::mixin::statevar $f.minelv \
            -statemap {1 normal 0 disabled} \
            -statevariable ${ns}::v::usemin

    ::mixin::statevar $f.maxelv \
            -statemap {1 normal 0 disabled} \
            -statevariable ${ns}::v::usemax

    ttk::entry $f.output -textvariable ${ns}::v::outvar

    ttk::frame $f.buttons
    ttk::button $f.clip -text "Clip Data" \
            -command ::l1pro::tools::histclip::clip
    ttk::button $f.dismiss -text "Dismiss" \
            -command [list destroy [winfo toplevel $f]]

    grid x $f.clip $f.dismiss -padx 2 -in $f.buttons
    grid columnconfigure $f.buttons {0 3} -weight 1

    grid x $f.lblinput $f.input -in $w.f -padx 2 -pady 2
    grid $f.usemax $f.lblmax $f.maxelv -in $w.f -padx 2 -pady 2
    grid $f.usemin $f.lblmin $f.minelv -in $w.f -padx 2 -pady 2
    grid x $f.lbloutput $f.output -in $w.f -padx 2 -pady 2
    grid $f.buttons - - -in $w.f -pady 2

    grid configure $f.lblinput $f.lblmin $f.lblmax $f.lbloutput $f.usemin \
            $f.usemax -sticky e
    grid configure $f.input $f.minelv $f.maxelv $f.output $f.buttons -sticky ew

    grid columnconfigure $w.f 2 -weight 1
}

proc ::l1pro::tools::histclip::clip {} {
    set cmd "$v::outvar = filter_bounded_elv($v::invar"

    appendif cmd \
            1           ", mode=\"$::plot_settings(display_mode)\"" \
            $v::usemin  ", lbound=$v::minelv" \
            $v::usemax  ", ubound=$v::maxelv" \
            1           ")"

    exp_send "$cmd\r"

    append_varlist $v::outvar
    destroy $v::top
}

proc ::l1pro::tools::colorbar {} {
    set cmd "window, $::win_no; "
    append cmd "colorbar, $::plot_settings(cmin), $::plot_settings(cmax),\
            drag=1"
    exp_send "$cmd\r"
}

if {![namespace exists ::l1pro::tools::griddata]} {
    namespace eval ::l1pro::tools::griddata {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .l1wid.griddata
            variable invar {}
            variable outvar {}
            variable mode {}
            variable usearea 1
            variable useside 1
            variable usetile 1
            variable maxarea 200
            variable maxside 50
            variable cell 1
            variable tile {}
        }
    }
}

proc ::l1pro::tools::griddata::gui {} {
    set ns [namespace current]
    set w $v::top
    destroy $w
    toplevel $w

    wm resizable $w 1 0
    wm title $w "Gridding $::pro_var"

    set v::invar $::pro_var
    set v::mode $::plot_settings(display_mode)
    set v::outvar ${::pro_var}_grid
    ::misc::idle [list ybkg tksetfunc \"${ns}::v::tile\" \"guess_tile\" \
            \"$::pro_var\"]

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set f $w

    ttk::label $f.lblmaxside -text "Maximum side: "
    ttk::label $f.lblmaxarea -text "Maximum area: "
    ttk::label $f.lblcell -text "Cell size: "
    ttk::label $f.lbltile -text "Clip to tile: "
    ttk::label $f.lbloutput -text "Output variable: "

    ttk::checkbutton $f.useside -variable ${ns}::v::useside
    ttk::checkbutton $f.usearea -variable ${ns}::v::usearea
    ttk::checkbutton $f.usetile -variable ${ns}::v::usetile

    ttk::spinbox $f.maxside -from 0 -to 5000 -increment 0.1 \
            -format %.2f \
            -textvariable ${ns}::v::maxside
    ttk::spinbox $f.maxarea -from 0 -to 100000 -increment 0.1 \
            -format %.2f \
            -textvariable ${ns}::v::maxarea
    ttk::spinbox $f.cell -from 0 -to 100 -increment 0.1 \
            -format %.2f \
            -textvariable ${ns}::v::cell

    ttk::entry $f.tile -textvariable ${ns}::v::tile
    ttk::entry $f.output -textvariable ${ns}::v::outvar

    ::mixin::statevar $f.maxside \
            -statemap {1 normal 0 disabled} \
            -statevariable ${ns}::v::useside

    ::mixin::statevar $f.maxarea \
            -statemap {1 normal 0 disabled} \
            -statevariable ${ns}::v::usearea

    ::mixin::statevar $f.tile \
            -statemap {1 normal 0 disabled} \
            -statevariable ${ns}::v::usetile

    ttk::frame $f.buttons
    ttk::button $f.grid -text "Grid" \
            -command ::l1pro::tools::griddata::griddata
    ttk::button $f.dismiss -text "Dismiss" \
            -command [list destroy [winfo toplevel $f]]

    grid x $f.grid $f.dismiss -padx 2 -in $f.buttons
    grid columnconfigure $f.buttons {0 3} -weight 1

    grid $f.useside $f.lblmaxside $f.maxside -in $w.f -padx 2 -pady 2
    grid $f.usearea $f.lblmaxarea $f.maxarea -in $w.f -padx 2 -pady 2
    grid $f.usetile $f.lbltile $f.tile -in $w.f -padx 2 -pady 2
    grid x $f.lblcell $f.cell -in $w.f -padx 2 -pady 2
    grid x $f.lbloutput $f.output -in $w.f -padx 2 -pady 2
    grid $f.buttons - - -in $w.f -pady 2

    grid configure $f.lblmaxside $f.lblmaxarea $f.lbltile $f.lblcell \
            $f.lbloutput $f.useside $f.usearea $f.usetile -sticky e
    grid configure $f.maxside $f.maxarea $f.tile $f.cell $f.output -sticky ew

    grid columnconfigure $w.f 2 -weight 1

    ::tooltip::tooltip $f.tile \
            "Enter the name of the tile here, either as a 2k, 10k, or qq tile,\
            \nand the data will be restricted to the tile's boundaries. If you\
            \ndo not known the tile's name, or do not wish to restrict by the\
            \ntile's boundaries, then disable this. If it is not a valid tile\
            \nname, an error will be generated."
}

proc ::l1pro::tools::griddata::griddata {} {
    set cmd "$v::outvar = data_triangle_grid($v::invar"

    appendif cmd \
            1                   ", mode=\"$v::mode\"" \
            $v::usetile         ", tile=\"$v::tile\"" \
            {$v::cell != 1}     ", cell=$v::cell" \
            $v::useside         ", maxside=$v::maxside" \
            {!$v::useside}      ", maxside=0" \
            $v::usearea         ", maxarea=$v::maxarea" \
            {!$v::usearea}      ", maxarea=0" \
            1                   ")"

    exp_send "$cmd\r"

    append_varlist $v::outvar
    destroy $v::top
}

if {![namespace exists ::l1pro::tools::datum]} {
    namespace eval ::l1pro::tools::datum {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .l1wid.datumconvert
            variable invar {}
            variable indatum w84
            variable ingeoid 03
            variable outvar {}
            variable outdatum n88
            variable outgeoid 09
            variable datumlist {w84 n83 n88}
            variable geoidlist {}
        }
        set geoidroot [yget alpsrc.geoid_data_root]
        set geoids [glob -nocomplain -tails -directory $geoidroot -- GEOID*]
        foreach geoid [lsort -dictionary $geoids] {
            lappend v::geoidlist [string range $geoid 5 end]
        }
        unset geoidroot
        unset geoids
        # catch needed in case there were no geoids
        catch {unset geoid}
    }
}

proc ::l1pro::tools::datum::guess_name {vname src dst} {
    if {[regsub -- "_$src\$" $vname "_$dst" vname]} {
        return $vname
    }
    if {[regsub -- "_${src}_" $vname "_${dst}_" vname]} {
        return $vname
    }
    if {[regsub -- "^${src}_" $vname "${dst}_" vname]} {
        return $vname
    }
    return "${dst}_$vname"
}

proc ::l1pro::tools::datum::gui {} {
    set ns [namespace current]
    set v::invar $::pro_var
    set v::outvar [guess_name $v::invar $v::indatum $v::outdatum]

    set w $v::top
    destroy $w
    toplevel $w
    wm resizable $w 1 0
    wm title $w "Datum Conversion"

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set f $w.f

    ttk::label $f.inlbl -text "Input:"
    ttk::label $f.outlbl -text "Output:"

    ::mixin::combobox $f.invar \
            -state readonly -width [expr {[string length $v::invar]+2}] \
            -textvariable ${ns}::v::invar \
            -listvariable ::varlist

    ttk::entry $f.outvar \
            -width [expr {[string length $v::outvar]+2}] \
            -textvariable ${ns}::v::outvar

    foreach kind {in out} {
        ::mixin::combobox $f.${kind}datum \
                -state readonly -width 4 \
                -textvariable ${ns}::v::${kind}datum \
                -listvariable ${ns}::v::datumlist
        ::mixin::combobox $f.${kind}geoid \
                -state readonly -width 4 \
                -textvariable ${ns}::v::${kind}geoid \
                -listvariable ${ns}::v::geoidlist
        ::mixin::statevar $f.${kind}geoid \
                -statemap {w84 disabled n83 disabled n88 readonly} \
                -statevariable ${ns}::v::${kind}datum
        grid $f.${kind}lbl $f.${kind}var $f.${kind}datum $f.${kind}geoid \
                -sticky ew -padx 2 -pady 2
    }

    ttk::frame $f.btns
    ttk::button $f.convert -text "Convert" -command ${ns}::convert
    ttk::button $f.dismiss -text "Dismiss" -command [list destroy $w]
    grid x $f.convert $f.dismiss x -in $f.btns -sticky ew -padx 2
    grid columnconfigure $f.btns {0 3} -weight 1

    grid $f.btns - - - -sticky ew -pady 2
    grid columnconfigure $f 1 -weight 1
}

proc ::l1pro::tools::datum::convert {} {
    set cmd "$v::outvar = datum_convert_data($v::invar"

    appendif cmd \
            {$v::indatum ne "w84"}  ", src_datum=\"$v::indatum\"" \
            {
                $v::indatum eq "n88" && $v::ingeoid ne "03"
            }                       ", src_geoid=\"$v::ingeoid\"" \
            {$v::outdatum ne "n88"} ", dst_datum=\"$v::outdatum\"" \
            {
                $v::outdatum eq "n88" && $v::outgeoid ne "09"
            }                       ", dst_geoid=\"$v::outgeoid\"" \
            1                       ")"

    exp_send "$cmd\r"

    append_varlist $v::outvar
    destroy $v::top
}

proc ::l1pro::tools::auto_cbar {method {factor {}}} {
    set cmd "auto_cbar, $::pro_var, \"$method\""
    append cmd ", mode=\"$::plot_settings(display_mode)\""
    ::misc::appendif cmd {$factor ne ""} ", factor=$factor"
    exp_send "$cmd;\r"
}

proc ::l1pro::tools::auto_cbar_cdelta {} {
    ::l1pro::tools::auto_cbar rcf $::cdelta
}

proc ::l1pro::tools::sortdata {method desc} {
    set cmd "$::pro_var = sortdata($::pro_var"
    append cmd ", mode=\"$::plot_settings(display_mode)\", method=\"$method\""
    ::misc::appendif cmd $desc ", desc=1"
    append cmd ")"
    exp_send "$cmd;\r"
}

if {![namespace exists ::l1pro::tools::copy_limits]} {
    namespace eval ::l1pro::tools::copy_limits {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .l1wid.copylimits
            variable src 5
            variable dst 6
        }
    }
}

proc ::l1pro::tools::copy_limits::gui {} {
    set ns [namespace current]
    set w $v::top
    destroy $w
    toplevel $w
    wm resizable $w 1 0
    wm title $w "Limits Tool"

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set f $w.f

    ttk::label $f.srclbl -text "Copy from:"
    ttk::button $f.btndst -text "Apply to:" -width 0 -command ${ns}::apply
    ttk::button $f.btnall -text "Apply to all" -width 0 \
            -command ${ns}::apply_all
    ttk::button $f.viz -text "Viz" -width 0 -command ${ns}::viz
    ttk::button $f.swap -text "Swap" -width 0 -command ${ns}::swap
    ttk::spinbox $f.src -justify center -width 2 \
            -textvariable ${ns}::v::src \
            -from 0 -to 63 -increment 1
    ttk::spinbox $f.dst -justify center -width 2 \
            -textvariable ${ns}::v::dst \
            -from 0 -to 63 -increment 1

    grid $f.srclbl $f.src $f.viz -sticky ew -padx 2 -pady 2
    grid $f.btndst $f.dst $f.swap -sticky ew -padx 2 -pady 2
    grid $f.btnall - - -sticky ew -padx 2 -pady 2
    grid columnconfigure $f 1 -weight 1

    grid configure $f.srclbl -sticky e

    ::tooltip::tooltip $f.btndst \
            "Copies the limits from the first window (specified at the right\
            \nof \"Copy from:\") to the second window (specified at the right\
            \nof \"Apply to:\")."
    ::tooltip::tooltip $f.btnall \
            "Copies the limits from the first window (specified at the right\
            \nof \"Copy from:\") to all open windows."
    ::tooltip::tooltip $f.viz \
            "Sets \"Copy from:\" to the current window in the Visualization\
            \nsection of the Process EAARL Data GUI."
    ::tooltip::tooltip $f.swap \
            "Swaps the \"Copy from:\" and \"Apply to:\" window settings."
}

proc ::l1pro::tools::copy_limits::apply {} {
    exp_send "copy_limits, $v::src, $v::dst;\r"
}

proc ::l1pro::tools::copy_limits::apply_all {} {
    exp_send "copy_limits, $v::src;\r"
}

proc ::l1pro::tools::copy_limits::viz {} {
    set v::src $::win_no
}

proc ::l1pro::tools::copy_limits::swap {} {
    set tmp $v::src
    set v::src $v::dst
    set v::dst $tmp
}

namespace eval ::l1pro::tools::varmanage {
    namespace eval v {
        variable win .l1wid.varplot
        variable lb ""
        variable var_add ""
        variable fixed_vars [list fs_all depth_all veg_all cveg_all]
    }

    proc gui {} {
        set ns [namespace current]
        set w $v::win
        destroy $w
        toplevel $w
        wm title $w "List"

        set f $w
        set v::lb $f.slbVars
        iwidgets::scrolledlistbox $v::lb \
                -width 12 -listvariable ::varlist \
                -hscrollmode dynamic -vscrollmode dynamic \
                -selectmode extended \
                -scrollmargin 0 -sbwidth 10

        button $f.btnSelect -text "Select" -command ${ns}::cmd_select
        LabelEntry $f.lbeAdd -width 8 -relief sunken -label "Add:" \
                -helptext "Add variable name to list" \
                -textvariable ${ns}::v::var_add
        $f.lbeAdd bind <Return> ${ns}::bind_add_enter
        button $f.btnDelete -text "Delete" -command ${ns}::cmd_delete
        button $f.btnRename -text "Rename" -command ${ns}::cmd_rename
        button $f.btnDismiss -text "Dismiss" -command [list destroy $v::win]

        grid $v::lb -sticky news
        grid $f.btnSelect -sticky news
        grid $f.lbeAdd -sticky news
        grid $f.btnDelete -sticky news
        grid $f.btnRename -sticky news
        grid $f.btnDismiss -sticky news

        grid columnconfigure $f 0 -weight 1 -minsize 110
        grid rowconfigure $f 0 -weight 1 -minsize 200
    }

    proc cmd_select {} {
        set selected [$v::lb getcurselection]
        if {[llength $selected] == 1} {
            set ::pro_var [lindex $selected 0]
        } elseif {[llength $selected] > 1} {
            tk_messageBox -icon warning -type ok -message \
                    "You cannot select multiple variables. Select only one."
        }
    }

    proc bind_add_enter {} {
        append_varlist $v::var_add
        set v::var_add ""
    }

    proc cmd_delete {} {
        set selected [$v::lb getcurselection]

        ::struct::list split $selected \
                [list ::struct::set contains $v::fixed_vars] pass fail

        if {[llength $pass]} {
            set this_variable [this_variable [llength $pass]]
            tk_messageBox -icon warning -type ok -message \
                    "Aborting. You cannot delete ${this_variable}: $pass"
        } else {
            ::struct::list split $::varlist \
                    [list ::struct::set contains $selected] pass fail

            set this_variable [this_variable [llength $pass]]
            set response [tk_messageBox -icon question -type yesno \
                    -title Warning -message "Are you sure you want to delete\
                            ${this_variable}?\n$pass"]

            if {$response eq "yes"} {
                foreach var $pass {
                    exp_send "$var = \[\];\r"
                }
                set ::varlist $fail
            }
        }
    }

    proc cmd_rename {} {
        set selected [$v::lb getcurselection]

        ::struct::list split $selected \
                [list ::struct::set contains $v::fixed_vars] pass fail

        if {[llength $pass]} {
            set this_variable [this_variable [llength $pass]]
            tk_messageBox -icon warning -type ok -message \
                    "Aborting. You cannot delete ${this_variable}: $pass"
        } else {
            ::struct::list split $::varlist \
                    [list ::struct::set contains $selected] pass fail

            if {[llength $pass] == 1} {
                set old [lindex $pass 0]
                set new $old
                set prompt "What would you like to rename '$old' to?"
                if {[::getstring::tk_getString $v::win.gs new $prompt]} {
                    if {$old ne $new} {
                        exp_send "eq_nocopy, $new, $old; $old = \[\];\r"
                        set idx [lsearch -exact $::varlist $old]
                        set ::varlist [lreplace $::varlist $idx $idx $new]
                        if {[info exists ::plot_settings($old)]} {
                            if {![info exists ::plot_settings($new)]} {
                                set ::plot_settings($new) \
                                        $::plot_settings($old)
                            }
                        }
                        if {$::pro_var eq $old} {
                            set ::pro_var $new
                        }
                    }
                }
            } else {
                tk_messageBox -icon warning -type ok -title Warning -message \
                        "You cannot rename multiple variables at once. Select\
                        only one."
            }
        }
    }

    proc this_variable count {
        # Utility function that returns "this variable" or "these variables"
        # depending on the count given.
        return [lindex [list "this variable" "these variables"] \
                [expr {$count > 1}]]
    }
} ;# closes ::l1pro::tools::varmanage

