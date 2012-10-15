# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission 1.0
package require imglib
package require style
package require fileutil

if {![namespace exists ::mission]} {
    namespace eval ::mission {
        variable plugins {}
        variable path ""
        variable loaded ""
        variable cache_mode ""
        variable conf {}

        variable commands
        array set commands {
            initialize_path_mission {}
            initialize_path_flight {}
            load_data {}
        }
    }

    tky_tie add read ::mission::path \
            from mission.data.path -initialize 1
    tky_tie add read ::mission::loaded \
            from mission.data.loaded -initialize 1
    tky_tie add read ::mission::cache_mode \
            from mission.data.cache_mode -initialize 1
}

proc ::mission::json_import {json} {
    variable conf
    variable plugins
    set data [::json::json2dict $json]
    set conf [dict get $data flights]
    set plugins [dict get $data plugins]
    if {$plugins eq "null"} {
        set plugins ""
    }

    if {[winfo exists $::mission::gui::top]} {
        ::mission::gui::refresh_flights
    }
}

namespace eval ::mission::gui {

    variable top .missconf
    variable view load
    variable flights
    variable details

    variable flight_name ""
    variable detail_type ""
    variable detail_value ""

    variable widget_flight_name
    variable widget_detail_type
    variable widget_detail_value

    proc refresh_vars {} {
        set ::mission::path $::mission::path
        set ::mission::loaded $::mission::loaded
        set ::mission::cache_mode $::mission::cache_mode
    }

    proc launch {} {
        variable top
        toplevel $top
        wm title $top "Mission Configuration"
        gui_empty $top.empty
        gui_edit $top.edit

        bind $top <Enter> ::mission::gui::refresh_vars
        bind $top <Visibility> ::mission::gui::refresh_vars

        refresh_flights
        update_view
    }

    proc change_view {newview} {
        variable top
        variable view
        if {$newview ne $view} {
            wm geometry $top {}
            set view $newview
        }
        update_view
    }

    proc update_view {} {
        variable top
        variable view
        pack forget $top.empty $top.edit
        if {$view eq "load"} {
            set w $top.empty
            wm geometry $top {}
        } else {
            set w $top.edit
        }
        pack $w -fill both -expand 1
    }

    proc gui_empty {w} {
        ttk::frame $w
        set f $w

        ttk::label $f.lblMessage \
                -wraplength 100 \
                -text "No configuration is currently loaded. Load an\
                existing configuration through the File menu or create a\
                new configuration by using \"Switch to Editing Mode\"."

        ttk::button $f.btnSwitch \
                -text "Switch to Editing Mode" \
                -command [list ::mission::gui::change_view edit]

        grid $f.lblMessage - - -sticky news -padx 2 -pady 2
        grid x $f.btnSwitch -pady 2
        grid columnconfigure $f {0 2} -weight 1 -minsize 50

        bind $f.lblMessage <Configure> \
                [list %W configure -wraplength %w]

        return $w
    }

    proc gui_load {w} {
        ttk::frame $w.full
        set f [ttk::frame $w.f]
        pack $w.full -expand both -fill 1
        pack $f -in $w.full -anchor nw

        ttk::frame $f.days
        ttk::frame $f.extra
        ttk::button $f.switch -text "Switch to Editing Mode" \
                -command [list ::mission::gui::change_view edit]
        grid $f.days -sticky ne
        grid $f.extra -sticky ew
        grid $f.button

        return $w
    }

    proc gui_edit {w} {
        variable flights
        variable details
        variable widget_flight_name
        variable widget_detail_type
        variable widget_detail_value

        ttk::frame $w
        set f $w

        ttk::label $f.lblBasepath -text "Mission base path:"
        ttk::entry $f.entBasepath \
                -state readonly \
                -textvariable ::mission::path
        ttk::button $f.btnBasepath -text "Browse..." \
                -command ::mission::gui::browse_basepath

        ttk::label $f.lblPlugins -text "Plugins required:"
        ttk::entry $f.entPlugins -state readonly \
                -textvariable ::mission::plugins
        ttk::menubutton $f.mbnPlugins -text "Modify"
        menu $f.mbnPlugins.mb -postcommand \
                [list ::mission::gui::plugins_menu $f.mbnPlugins.mb]
        $f.mbnPlugins configure -menu $f.mbnPlugins.mb

        ttk::frame $f.fraButtons
        ttk::button $f.btnLoad -text "Load Required Plugins" \
                -command [list exp_send "mission, plugins, load;\r"]
        ttk::button $f.btnInitialize -text "Initialize Mission by Path" \
                -command ::mission::gui::initialize_path_mission
        ::mixin::statevar $f.btnInitialize \
                -statemap {"" disabled} \
                -statedefault {!disabled} \
                -statevariable ::mission::commands(initialize_path_mission)
        grid x $f.btnLoad $f.btnInitialize -in $f.fraButtons
        grid columnconfigure $f.fraButtons {0 3} -weight 1

        ttk::labelframe $f.lfrFlight -text "Mission Flights"

        ttk::frame $f.fraBottom
        ttk::button $f.btnSwitch -text "Switch to Loading Mode" \
                -command [list ::mission::gui::change_view load]
        grid x $f.btnSwitch -in $f.fraBottom
        grid columnconfigure $f.fraBottom {0 2} -weight 1

        grid $f.lblBasepath $f.entBasepath $f.btnBasepath
        grid $f.lblPlugins $f.entPlugins $f.mbnPlugins
        grid $f.fraButtons - -
        grid $f.lfrFlight - -
        grid $f.fraBottom - -
        grid columnconfigure $f 1 -weight 1

        set f $f.lfrFlight

        ttk::frame $f.fraFlights

        ttk::frame $f.fraToolbar
        ttk::button $f.tbnPlus -style Toolbutton \
                -image ::imglib::plus \
                -command [list ::mission::gui::quick_add_flight]
        ttk::button $f.tbnX -style Toolbutton \
                -image ::imglib::x \
                -command [list ::mission::gui::quick_action flights remove]
        ttk::button $f.tbnUp -style Toolbutton \
                -image ::imglib::arrow::up \
                -command [list ::mission::gui::quick_action flights raise]
        ttk::button $f.tbnDown -style Toolbutton \
                -image ::imglib::arrow::down \
                -command [list ::mission::gui::quick_action flights lower]
        grid $f.tbnPlus -in $f.fraToolbar
        grid $f.tbnX -in $f.fraToolbar
        grid $f.tbnUp -in $f.fraToolbar
        grid $f.tbnDown -in $f.fraToolbar

        ttk::treeview $f.tvwFlights \
                -columns name \
                -displaycolumns name \
                -show {} \
                -selectmode browse
        set flights $f.tvwFlights
        ttk::scrollbar $f.vsbFlights -orient vertical

        grid $f.fraToolbar $f.tvwFlights $f.vsbFlights -in $f.fraFlights
        grid columnconfigure $f.fraFlights 1 -weight 1

        ttk::label $f.lblField -text "Flight name:"
        ttk::entry $f.entField
        ::mixin::revertable $f.entField \
                -textvariable ::mission::gui::flight_name \
                -applycommand ::mission::gui::apply_flight_name
        ttk::button $f.btnApply -text "Apply" \
                -command [list $f.entField apply]
        ttk::button $f.btnRevert -text "Revert" \
                -command [list $f.entField revert]
        set widget_flight_name $f.entField

        ttk::frame $f.fraButtons
        ttk::button $f.btnLoad -text "Load Data"
        ::mixin::statevar $f.btnLoad \
                -statemap {"" disabled} \
                -statedefault {!disabled} \
                -statevariable ::mission::commands(load_data)
        ttk::button $f.btnInitialize -text "Initialize Flight by Path" \
                -command ::mission::gui::initialize_path_flight
        ::mixin::statevar $f.btnInitialize \
                -statemap {"" disabled} \
                -statedefault {!disabled} \
                -statevariable ::mission::commands(initialize_path_flight)
        grid x $f.btnLoad $f.btnInitialize -in $f.fraButtons
        grid columnconfigure $f.fraButtons {0 3} -weight 1

        ttk::labelframe $f.lfrDetails -text "Flight Details"

        grid $f.fraFlights - - -
        grid $f.lblField $f.entField $f.btnApply $f.btnRevert
        grid $f.fraButtons - - -
        grid $f.lfrDetails - - -
        grid columnconfigure $f 1 -weight 1

        set f $f.lfrDetails

        ttk::frame $f.fraDetails

        ttk::frame $f.fraToolbar
        ttk::button $f.tbnPlus -style Toolbutton \
                -image ::imglib::plus \
                -command [list ::mission::gui::quick_add_detail]
        ttk::button $f.tbnX -style Toolbutton \
                -image ::imglib::x \
                -command [list ::mission::gui::quick_action details remove]
        ttk::button $f.tbnUp -style Toolbutton \
                -image ::imglib::arrow::up \
                -command [list ::mission::gui::quick_action details raise]
        ttk::button $f.tbnDown -style Toolbutton \
                -image ::imglib::arrow::down \
                -command [list ::mission::gui::quick_action details lower]
        grid $f.tbnPlus -in $f.fraToolbar
        grid $f.tbnX -in $f.fraToolbar
        grid $f.tbnUp -in $f.fraToolbar
        grid $f.tbnDown -in $f.fraToolbar

        ttk::treeview $f.tvwDetails \
                -columns {field value} \
                -displaycolumns {field value} \
                -show headings \
                -selectmode browse
        set details $f.tvwDetails
        $details heading field -text "Field"
        $details column field -width 100 -stretch 0
        $details heading value -text "Value"
        $details column value -width 400 -stretch 1
        ttk::scrollbar $f.vsbDetails -orient vertical

        grid $f.fraToolbar $f.tvwDetails $f.vsbDetails -in $f.fraDetails
        grid columnconfigure $f.fraDetails 1 -weight 1

        ttk::label $f.lblType -text "Field type:"
        mixin::combobox $f.cboType
        ::mixin::revertable $f.cboType \
                -textvariable ::mission::gui::detail_type \
                -applycommand ::mission::gui::apply_detail_type
        ttk::button $f.btnTypeApply -text "Apply" \
                -command [list $f.cboType apply]
        ttk::button $f.btnTypeRevert -text "Revert" \
                -command [list $f.cboType revert]
        set widget_detail_type $f.cboType

        ttk::label $f.lblValue -text "Field value:"
        ttk::entry $f.entValue
        ::mixin::revertable $f.entValue \
                -textvariable ::mission::gui::detail_value \
                -applycommand ::mission::gui::apply_detail_value
        ttk::button $f.btnValueApply -text "Apply" \
                -command [list $f.entValue apply]
        ttk::button $f.btnValueRevert -text "Revert" \
                -command [list $f.entValue revert]
        set widget_detail_value $f.entValue

        ttk::frame $f.fraButtons
        ttk::button $f.btnSelectFile -text "Select File..." \
                -command ::mission::gui::detail_select_file
        ttk::button $f.btnSelectDir -text "Select Directory..." \
                -command ::mission::gui::detail_select_dir
        grid x $f.btnSelectFile $f.btnSelectDir -in $f.fraButtons
        grid columnconfigure $f.fraButtons {0 3} -weight 1

        grid $f.fraDetails - - -
        grid $f.lblType $f.cboType $f.btnTypeApply $f.btnTypeRevert
        grid $f.lblValue $f.entValue $f.btnValueApply $f.btnValueRevert
        grid $f.fraButtons - - -
        grid columnconfigure $f 1 -weight 1

        set padx [list -padx 2]
        set pady [list -pady 2]
        set pad [list {*}$padx {*}$pady]
        foreach child [winfo descendents $w] {
            switch -- [string range [lindex [split $child .] end] 0 2] {
                btn -
                mbn {
                    grid $child -sticky ew {*}$pad
                    $child configure -width 0
                }
                cbo { grid $child -sticky ew {*}$pad }
                ent { grid $child -sticky ew {*}$pad }
                fra { grid $child -sticky news }
                lbl { grid $child -sticky e {*}$pad }
                lfr { grid $child -sticky news {*}$pad }
                tbn { }
                tvw { grid $child -sticky news }
                vsb { grid $child -sticky ns }
            }
        }

        bind $flights <<TreeviewSelect>> ::mission::gui::refresh_details
        bind $details <<TreeviewSelect>> ::mission::gui::refresh_fields

        return $w
    }

    proc plugins_menu {mb} {
        $mb delete 0 end
        set selected $::mission::plugins
        set available [::plugins::plugins_list]
        foreach plugin $available {
            $mb add checkbutton -label $plugin
            if {$plugin in $selected} {
                $mb invoke end
                $mb entryconfigure end -command [list \
                        ::mission::gui::plugins_menu_command remove $plugin]
            } else {
                $mb entryconfigure end -command [list \
                        ::mission::gui::plugins_menu_command add $plugin]
            }
        }
    }

    proc plugins_menu_command {action plugin} {
        if {$action eq "remove"} {
            set plugins [lsearch -inline -all -not -exact \
                    $::mission::plugins $plugin]
        } else {
            set plugins [lsort [list $plugin {*}$::mission::plugins]]
        }
        #set plugins [join $plugins {", "}]
        if {$plugins eq ""} {
            set plugins "\[\]"
        } else {
            set plugins "\[\"[join $plugins {", "}]\"\]"
        }
        exp_send "mission, data, plugins=$plugins; mission, tksync\r"
    }

    proc browse_basepath {} {
        set original $::mission::path
        set new [tk_chooseDirectory \
                -initialdir $::mission::path \
                -mustexist 1 \
                -title "Choose mission base path"]
        if {$new eq ""} {
            return
        }
        if {![file isdirectory $new]} {
            tk_messageBox \
                    -message "Invalid path selected" \
                    -type ok -icon error
            return
        }
        set new [ystr $new]
        exp_send "mission, data, path=\"$new\";\r"
    }

    proc initialize_path_mission {} {
        if {$::mission::path ne ""} {
            set path $::mission::path
        } else {
            set path [tk_chooseDirectory \
                    -mustexist 1 \
                    -title "Choose mission base path"]
        }
        if {![file isdirectory $path]} {
            tk_messageBox \
                    -message "Invalid path selected" \
                    -type ok -icon error
            return
        }
        {*}$::mission::commands(initialize_path_flight) $path
    }

    proc initialize_path_flight {} {

    }

    proc apply_flight_name {old new} {
        set old [ystr $old]
        set new [ystr $new]
        exp_send "mission, flights, rename, \"$old\", \"$new\";\r"
    }

    proc apply_detail_type {old new} {
        variable flight_name
        set flight [ystr $flight_name]
        set old [ystr $old]
        set new [ystr $new]
        exp_send "mission, details, rename, \"$flight\", \"$old\", \"$new\";\r"
    }

    proc apply_detail_value {old new} {
        variable flight_name
        variable detail_type
        set flight [ystr $flight_name]
        set detail [ystr $detail_type]
        set new [ystr $new]
        exp_send "mission, details, set, \"$flight\", \"$detail\", \"$new\";\r"
    }

    # type must be "flights" or "details"
    # action must be "raise", "lower", or "remove"
    proc quick_action {type action} {
        variable flights
        variable details
        set flight [lindex [$flights selection] 0]
        if {$flight eq ""} {
            return
        }
        if {$type eq "flights"} {
            set flight [ystr $flight]
            exp_send "mission, $type, $action, \"$flight\";\r"
            return
        }
        set detail [lindex [$details selection] 0]
        if {$detail eq ""} {
            return
        }
        set flight [ystr $flight]
        set detail [ystr $detail]
        exp_send "mission, $type, $action, \"$flight\", \"$detail\";\r"
    }

    proc quick_add_flight {} {
        variable ::mission::conf
        variable flights
        variable details
        set base "New Flight"
        set name "$base"
        set counter 1
        while {[dict exists $conf $name]} {
            incr counter
            set name "$base $counter"
        }
        exp_send "mission, flights, add, \"$name\";\r"
    }

    proc quick_add_detail {} {
        variable ::mission::conf
        variable flights
        variable details
        set flight [lindex [$flights selection] 0]
        if {$flight eq ""} {
            return
        }
        set base "New Detail"
        set name "$base"
        set counter 1
        while {[dict exists $conf $flight $name]} {
            incr counter
            set name "$base $counter"
        }

        set flight [ystr $flight]
        exp_send "mission, details, set, \"$flight\", \"$name\", \"\";\r"
    }

    proc detail_select_initialdir {} {
        variable ::mission::conf
        variable flight_name
        variable detail_type
        variable detail_value
        set base $::mission::path
        if {$base eq "" || ![file isdirectory $base]} {
            set base /
        }
        set path $base
        set terminal [list $base . /]
        set candidates [list]
        if {[dict exists $conf $flight_name data_path]} {
            lappend candidates [dict get $conf $flight_name data_path]
        }
        if {[dict exists $conf $flight_name $detail_type]} {
            lappend candidates [dict get $conf $flight_name $detail_type]
        }
        if {$detail_value ne ""} {
            lappend candidates $detail_value
        }
        foreach temp $candidates {
            set temp [file join $base $temp]
            while {$temp ni $terminal && ![file isdirectory $temp]} {
                set temp [file dirname $temp]
            }
            if {$temp ni $terminal && [file isdirectory $temp]} {
                set path $temp
            }
        }
        return $path
    }

    proc detail_select_file {} {
        variable top
        variable flight_name
        variable detail_type
        variable detail_value

        set initialfile ""
        if {$detail_value ne ""} {
            set initialfile [file join $::mission::path $detail_value]
        }
        if {[file isfile $initialfile]} {
            set initialdir [file dirname $initialfile]
            set initialfile [file tail $initialfile]
        } else {
            set initialdir [detail_select_initialdir]
            set initialfile ""
        }

        set chosen [tk_getOpenFile \
                -initialdir $initialdir \
                -initialfile $initialfile \
                -parent $top \
                -title "Select file for \"$detail_type\" for \"$flight_name\""]

        if {$chosen ne "" && [file isfile $chosen]} {
            set path [::fileutil::relative $::mission::path $chosen]
            set flight [ystr $flight_name]
            set detail [ystr $detail_type]
            set path [ystr $path]
            exp_send "mission, details, set, \"$flight\", \"$detail\", \"$path\";\r"
        }
    }

    proc detail_select_dir {} {
        variable top
        variable flight_name
        variable detail_type
        variable detail_value

        set chosen [tk_chooseDirectory \
                -initialdir [detail_select_initialdir] \
                -parent $top \
                -mustexist 1 \
                -title "Select directory for \"$detail_type\" for \"$flight_name\""]

        if {$chosen ne "" && [file isdirectory $chosen]} {
            set path [::fileutil::relative $::mission::path $chosen]
            set flight [ystr $flight_name]
            set detail [ystr $detail_type]
            set path [ystr $path]
            exp_send "mission, details, set, \"$flight\", \"$detail\", \"$path\";\r"
        }
    }

    proc refresh_flights {} {
        variable flights
        variable ::mission::conf
        set selected [lindex [$flights selection] 0]
        set index [lsearch -exact [$flights children {}] $selected]
        $flights delete [$flights children {}]
        dict for {key val} $conf {
            $flights insert {} end \
                -id $key \
                -values [list $key]
        }
        if {$selected ne "" && [$flights exists $selected]} {
            $flights selection set [list $selected]
        } elseif {$index >= 0} {
            set selected [lindex [$flights children {}] $index]
            if {$selected eq ""} {
                set selected [lindex [$flights children {}] end]
            }
            if {$selected ne ""} {
                $flights selection set [list $selected]
            }
        }
        ::misc::idle ::mission::gui::refresh_details
    }

    proc refresh_details {} {
        variable flights
        variable details
        variable ::mission::conf
        set flight [lindex [$flights selection] 0]
        set detail [lindex [$details selection] 0]
        set index [lsearch -exact [$details children {}] $detail]
        $details delete [$details children {}]
        if {$flight eq ""} {
            return
        }
        dict for {key val} [dict get $conf $flight] {
            $details insert {} end \
                -id $key \
                -values [list $key $val]
        }
        if {$detail ne "" && [$details exists $detail]} {
            $details selection set [list $detail]
        } elseif {$index >= 0} {
            set detail [lindex [$details children {}] $index]
            if {$detail eq ""} {
                set detail [lindex [$details children {}] end]
            }
            if {$detail ne ""} {
                $details selection set [list $detail]
            }
        }
        ::misc::idle ::mission::gui::refresh_fields
    }

    proc refresh_fields {} {
        variable ::mission::conf
        variable flights
        variable details
        variable flight_name
        variable detail_type
        variable detail_value
        variable widget_flight_name
        variable widget_detail_type
        variable widget_detail_value
        if {[lindex [$flights selection] 0] ne $flight_name} {
            $widget_flight_name revert
            $widget_detail_type revert
            $widget_detail_value revert
        }
        set flight_name [lindex [$flights selection] 0]
        if {[lindex [$details selection] 0] ne $detail_type} {
            $widget_detail_type revert
            $widget_detail_value revert
        }
        set detail_type [lindex [$details selection] 0]
        if {
            $detail_type ne "" &&
            [dict exists $conf $flight_name $detail_type]
        } {
            set detail_value \
                    [dict get $conf $flight_name $detail_type]
        } else {
            set detail_value ""
        }
    }

    proc ystr {str} {
        return [string map {
                    \" \\\"
                    \\ \\\\
                } $str]
    }
}
