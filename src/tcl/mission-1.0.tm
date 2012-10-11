# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission 1.0
package require imglib

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
    variable flights
    variable details

    variable flight_name ""
    variable detail_type ""
    variable detail_value ""

    proc refresh_vars {} {
        set ::mission::path $::mission::path
        set ::mission::loaded $::mission::loaded
        set ::mission::cache_mode $::mission::cache_mode
    }

    proc launch {} {
        variable top
        toplevel $top
        wm title $top "Mission Configuration"
        gui_edit $top.edit
        pack $top.edit -fill both -expand 1

        bind $top <Enter> ::mission::gui::refresh_vars
        bind $top <Visibility> ::mission::gui::refresh_vars

        refresh_flights
    }

    proc gui_load {w} {
        ttk::frame $w.full
        set f [ttk::frame $w.f]
        pack $w.full -expand both -fill 1
        pack $f -in $w.full -anchor nw

        ttk::frame $f.days
        ttk::frame $f.extra
        ttk::button $f.switch -text "Switch to Editing Mode"
        grid $f.days -sticky ne
        grid $f.extra -sticky ew
        grid $f.button
    }

    proc gui_edit {w} {
        variable flights
        variable details

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
        ttk::button $f.btnLoad -text "Load Required Plugins"
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
        ttk::button $f.btnSwitch -text "Switch to Loading Mode"
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
                -image ::imglib::plus
        ttk::button $f.tbnX -style Toolbutton \
                -image ::imglib::x
        ttk::button $f.tbnUp -style Toolbutton \
                -image ::imglib::arrow::up
        ttk::button $f.tbnDown -style Toolbutton \
                -image ::imglib::arrow::down
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
                -image ::imglib::plus
        ttk::button $f.tbnX -style Toolbutton \
                -image ::imglib::x
        ttk::button $f.tbnUp -style Toolbutton \
                -image ::imglib::arrow::up
        ttk::button $f.tbnDown -style Toolbutton \
                -image ::imglib::arrow::down
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

        ttk::label $f.lblValue -text "Field value:"
        ttk::entry $f.entValue
        ::mixin::revertable $f.entValue \
                -textvariable ::mission::gui::detail_value \
                -applycommand ::mission::gui::apply_detail_value
        ttk::button $f.btnValueApply -text "Apply" \
                -command [list $f.entValue apply]
        ttk::button $f.btnValueRevert -text "Revert" \
                -command [list $f.entValue revert]

        ttk::frame $f.fraButtons
        ttk::button $f.btnSelect -text "Select Path..."
        grid x $f.btnSelect -in $f.fraButtons
        grid columnconfigure $f.fraButtons {0 2} -weight 1

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
        exp_send "mission, flights, rename, \"$old\", \"$new\";\r"
    }

    proc apply_detail_type {old new} {
        variable flight_name
        exp_send "mission, details, rename, \"$flight_name\", \"$old\", \"$new\";\r"
    }

    proc apply_detail_value {old new} {
        variable flight_name
        variable detail_type
        exp_send "mission, details, set, \"$flight_name\", \"$detail_type\", \"$new\";\r"
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
        set flight_name [lindex [$flights selection] 0]
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

}
