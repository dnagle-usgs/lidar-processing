# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission 1.0
package require imglib
package require style
package require fileutil

if {![namespace exists ::mission]} {
    namespace eval ::mission {
        # List of plugins used by this conf. Updated during "mission, tksync".
        # This is primarily read-only.
        variable plugins {}

        # A dict of dicts containing the current configuration. Updated during
        # "mission, tksync". This is primarily read-only.
        variable conf {}

        # Corresponds to mission.data.path; read-only.
        variable path ""
        tky_tie add read ::mission::path \
                from mission.data.path -initialize 1

        # Corresponds to mission.data.loaded; read-only.
        variable loaded ""
        tky_tie add read ::mission::loaded \
                from mission.data.loaded -initialize 1

        # Corresponds to mission.data.cache_mode; read-only.
        variable cache_mode ""
        tky_tie add read ::mission::cache_mode \
                from mission.data.cache_mode -initialize 1

        variable commands
        array set commands {
            initialize_path_mission {}
            initialize_path_flight {}
            menu_actions {}
            refresh_load {}
        }

        variable detail_types {}

        # GUI specific variables...

        # Toplevel
        variable top .missconf
        # Current view mode
        variable view load
        # Treeview with flight listing
        variable flights
        # Treeview with details listing
        variable details
        # Frame containing flights on load view
        variable load_flights
        # Frame containing extra stuff on load view
        variable load_extra

        # The values for the fields available for editing at the given moment.
        variable flight_name ""
        variable detail_type ""
        variable detail_value ""

        # The paths for the three revertable widgets. These are needed so that
        # the values can be reverted by other code paths and so that the
        # entries can be disabled when they shouldn't be modified (when nothing
        # is selected).
        variable widget_flight_name
        variable widget_detail_type
        variable widget_detail_value

        # Currently loaded file (if opened/saved via the GUI)
        variable currentfile ""
    }
}

namespace eval ::mission {
    namespace import ::yorick::ystr

    # ::mission::has behaves like Yorick mission(has,)
    #   [::mission::has $flight] -> 0|1 is flight present?
    #   [::mission::has $flight $key] -> 0|1 is flight present with key?
    proc has {flight {key {}}} {
        variable conf
        if {![dict exists $conf $flight]} {
            return 0
        }
        if {$key ne "" && ![dict exists $conf $flight $key]} {
            return 0
        }
        return 1
    }

    # ::mission::get behaves like Yorick mission(get,)
    #   [::mission::get] -> flights
    #   [::mission::get $flight] -> keys
    #   [::mission::get $flight $key] -> value
    #   [::mission::get $flight $key -raw 1] -> value without path adjustment
    proc get {{flight {}} {key {}} args} {
        variable conf
        variable path
        set raw 0
        if {[dict exists $args -raw]} {
            set raw [dict get $args -raw]
        }
        if {$flight eq ""} {
            return [dict keys $conf]
        }
        if {![dict exists $conf $flight]} {
            error "invalid flight: $flight"
        }
        set details [dict get $conf $flight]
        if {$key eq ""} {
            return [dict keys $details]
        }
        set val [dict get $details $key]
        if {!$raw && [string length $val] && [lindex $key end] in "file dir"} {
            return [file join $path $val]
        }
        return $key
    }

    # This updates the internal variables used by the mission namespace and
    # should only be called by "mission, tksync".
    proc json_import {json} {
        variable conf
        variable plugins
        set data [::json::json2dict $json]
        set conf [dict get $data flights]
        set plugins [dict get $data plugins]

        # plugins is actually an array. When it's empty, it comes through as
        # "null". When it has values, it'll be a list -- which is a
        # space-separated list of names; that format is fine for display. The
        # "null" token however needs to be converted to the empty string.
        if {$plugins eq "null"} {
            set plugins ""
        }

        # If the GUI exists, it needs to be refreshed whenever the data
        # changes.
        if {[winfo exists $::mission::top]} {
            ::mission::update_view
            ::mission::refresh_flights
        }
    }

    # refresh_vars forces the three variables tied to Yorick variables to
    # update. They normally will only update when accessed; this forces a
    # trivial access so that they can be refreshed on mouse-overs and such.
    proc refresh_vars {} {
        set ::mission::path $::mission::path
        set ::mission::loaded $::mission::loaded
        set ::mission::cache_mode $::mission::cache_mode
    }

    # Launch the GUI
    proc launch {} {
        # If the GUI already exists, make sure it's visible and abort
        if {[winfo exists $::mission::top]} {
            wm deiconify $::mission::top
            return
        }

        variable top
        toplevel $top
        wm title $top "Mission Configuration"
        gui_empty $top.empty
        gui_load $top.load
        gui_edit $top.edit

        $top configure -menu [menu::build $top.mb]

        bind $top <Enter> ::mission::refresh_vars
        bind $top <Visibility> ::mission::refresh_vars

        refresh_flights
        update_view
    }

    # change_view sets the current view to $newview and, if the view is
    # actually changing, it will reset the geometry
    proc change_view {newview} {
        variable top
        variable view
        if {$newview ne $view} {
            wm geometry $top {}
            set view $newview
        }
        update_view
    }

    # update_view updates the GUI to display the selected $view
    proc update_view {} {
        variable conf
        variable top
        variable view

        # Determine which frame is needed for the current view
        if {$view eq "load"} {
            if {[llength $conf]} {
                set w $top.load
            } else {
                set w $top.empty
            }
            # Reset geometry for load/empty, since they do not need to be
            # resized.
            wm geometry $top {}
        } else {
            set w $top.edit
        }

        # Check to see if the required view is active and, if not, remove all
        # views and display the required view.
        if {$w ni [pack slaves $top]} {
            pack forget $top.empty $top.edit $top.load
            pack $w -fill both -expand 1
        }
    }

    # Creates the view to display instead of "load" when no data is loaded.
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
                -command [list ::mission::change_view edit]

        grid $f.lblMessage - - -sticky news -padx 2 -pady 2
        grid x $f.btnSwitch -pady 2
        grid columnconfigure $f {0 2} -weight 1 -minsize 50

        bind $f.lblMessage <Configure> \
                [list %W configure -wraplength %w]

        return $w
    }

    # Creates the "load" view. This is a fairly compact view that just lets the
    # user load data.
    proc gui_load {w} {
        variable load_flights
        variable load_extra

        ttk::frame $w
        set f $w

        ttk::frame $f.loaded
        ttk::label $f.lblloaded -text "Loaded flight:"
        ttk::entry $f.entloaded -textvariable ::mission::loaded
        $f.entloaded state readonly
        grid $f.lblloaded $f.entloaded -in $f.loaded -sticky ew -padx 2 -pady 2

        ttk::frame $f.flights
        set load_flights $f.flights

        ttk::separator $f.sep1 -orient horizontal
        ttk::separator $f.sep2 -orient horizontal

        ttk::frame $f.extra
        set load_extra $f.extra

        ttk::button $f.switch -text "Switch to Editing Mode" \
                -command [list ::mission::change_view edit]
        grid $f.loaded -sticky ew -pady 1
        grid $f.sep1 -sticky ew
        grid $f.flights -sticky ne -pady 1
        grid $f.sep2 -sticky ew
        grid $f.extra -sticky ew
        grid $f.switch -padx 2 -pady 2

        return $w
    }

    # Creates the "edit" view. This is an involved view that lets the user set
    # up and change the configuration.
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
                -command ::mission::browse_basepath

        ttk::label $f.lblPlugins -text "Plugins required:"
        ttk::entry $f.entPlugins -state readonly \
                -textvariable ::mission::plugins
        ttk::menubutton $f.mbnPlugins -text "Modify"
        menu $f.mbnPlugins.mb -postcommand \
                [list ::mission::plugins_menu $f.mbnPlugins.mb]
        $f.mbnPlugins configure -menu $f.mbnPlugins.mb

        ttk::frame $f.fraButtons
        ttk::button $f.btnLoad -text "Load Required Plugins" \
                -command [list exp_send "mission, plugins, load;\r"]
        ttk::button $f.btnInitialize -text "Initialize Mission by Path" \
                -command ::mission::initialize_path_mission
        ::mixin::statevar $f.btnInitialize \
                -statemap {"" disabled} \
                -statedefault {!disabled} \
                -statevariable ::mission::commands(initialize_path_mission)
        grid x $f.btnLoad $f.btnInitialize -in $f.fraButtons
        grid columnconfigure $f.fraButtons {0 3} -weight 1

        ttk::labelframe $f.lfrFlight -text "Mission Flights"

        ttk::frame $f.fraBottom
        ttk::button $f.btnSwitch -text "Switch to Loading Mode" \
                -command [list ::mission::change_view load]
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
                -command [list ::mission::quick_add_flight]
        ttk::button $f.tbnX -style Toolbutton \
                -image ::imglib::x \
                -command [list ::mission::quick_action flights remove]
        ttk::button $f.tbnUp -style Toolbutton \
                -image ::imglib::arrow::up \
                -command [list ::mission::quick_action flights raise]
        ttk::button $f.tbnDown -style Toolbutton \
                -image ::imglib::arrow::down \
                -command [list ::mission::quick_action flights lower]
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
                -textvariable ::mission::flight_name \
                -applycommand ::mission::apply_flight_name
        ttk::button $f.btnApply -text "Apply" \
                -command [list $f.entField apply]
        ttk::button $f.btnRevert -text "Revert" \
                -command [list $f.entField revert]
        set widget_flight_name $f.entField

        ttk::frame $f.fraButtons
        ttk::button $f.btnLoad -text "Load Data" \
                -command ::mission::editview_load_data
        ttk::button $f.btnInitialize -text "Initialize Flight by Path" \
                -command ::mission::initialize_path_flight
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
                -command [list ::mission::quick_add_detail]
        ttk::button $f.tbnX -style Toolbutton \
                -image ::imglib::x \
                -command [list ::mission::quick_action details remove]
        ttk::button $f.tbnUp -style Toolbutton \
                -image ::imglib::arrow::up \
                -command [list ::mission::quick_action details raise]
        ttk::button $f.tbnDown -style Toolbutton \
                -image ::imglib::arrow::down \
                -command [list ::mission::quick_action details lower]
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

        ttk::label $f.lblType -text "Detail type:"
        mixin::combobox $f.cboType \
                -postcommand [list ::mission::refresh_detail_types $f.cboType]
        ::mixin::revertable $f.cboType \
                -textvariable ::mission::detail_type \
                -applycommand ::mission::apply_detail_type
        ttk::button $f.btnTypeApply -text "Apply" \
                -command [list $f.cboType apply]
        ttk::button $f.btnTypeRevert -text "Revert" \
                -command [list $f.cboType revert]
        set widget_detail_type $f.cboType

        ttk::label $f.lblValue -text "Detail value:"
        ttk::entry $f.entValue
        ::mixin::revertable $f.entValue \
                -textvariable ::mission::detail_value \
                -applycommand ::mission::apply_detail_value
        ttk::button $f.btnValueApply -text "Apply" \
                -command [list $f.entValue apply]
        ttk::button $f.btnValueRevert -text "Revert" \
                -command [list $f.entValue revert]
        set widget_detail_value $f.entValue

        ttk::frame $f.fraButtons
        ttk::button $f.btnSelectFile -text "Select File..." \
                -command ::mission::detail_select_file
        ttk::button $f.btnSelectDir -text "Select Directory..." \
                -command ::mission::detail_select_dir
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

        bind $flights <<TreeviewSelect>> ::mission::refresh_details
        bind $details <<TreeviewSelect>> ::mission::refresh_fields

        $widget_flight_name state disabled
        $widget_detail_type state disabled
        $widget_detail_value state disabled

        return $w
    }

    # Dynamically (re-)constructs the plugins menu used within the GUI. The
    # menu $mb must already exist.
    proc plugins_menu {mb} {
        $mb delete 0 end
        set selected $::mission::plugins
        set available [::plugins::plugins_list]
        foreach plugin $available {
            $mb add checkbutton -label $plugin
            if {$plugin in $selected} {
                $mb invoke end
                $mb entryconfigure end -command [list \
                        ::mission::plugins_menu_command remove $plugin]
            } else {
                $mb entryconfigure end -command [list \
                        ::mission::plugins_menu_command add $plugin]
            }
        }
    }

    # Utility command used within plugins_menu to select/deselect plugins.
    proc plugins_menu_command {action plugin} {
        if {$action eq "remove"} {
            set plugins [lsearch -inline -all -not -exact \
                    $::mission::plugins $plugin]
        } else {
            set plugins [lsort [list $plugin {*}$::mission::plugins]]
        }
        if {$plugins eq ""} {
            set plugins "\[\]"
        } else {
            set plugins "\[\"[join $plugins {", "}]\"\]"
        }
        exp_send "mission, data, plugins=$plugins; mission, tksync\r"
    }

    # Prompt the user to browse to a path, which is then set for
    # mission.data.path.
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

    # Automatically initializes the dataset using the current mission.data.path
    # (or prompts for one if not defined).
    proc initialize_path_mission {} {
        if {$::mission::commands(initialize_path_mission) eq ""} {
            tk_messageBox -icon error \
                    -parent $::mission::top \
                    -type ok \
                    -title "Plugins not loaded" \
                    -message "You have not loaded any plugins yet. Please\
                        define and load the required plugin(s)."
            return
        }

        set path $::mission::path
        if {$path eq ""} {
            set path [tk_chooseDirectory \
                    -mustexist 1 \
                    -title "Choose mission base path"]
        } elseif {![file isdirectory $path]} {
            tk_messageBox -icon warning \
                    -parent $::mission::top \
                    -type ok \
                    -title "Invalid base path defined" \
                    -message "You must select a valid \"Mission base path\"\
                        before you can initialize the mission by path."
            return
        }

        if {$path eq ""} {
            return
        }

        if {![llength $::mission::conf]} {
            set choice yes
        } else {
            set choice [tk_messageBox -icon question \
                    -parent $::mission::top \
                    -type yesno \
                    -title "Initialize Mission by Path" \
                    -message "Initializing the mission by path will clear the\
                        currently defined configuration and replace it with\
                        automatically determined flights and details. Are you\
                        sure you want to do this?"]
        }

        if {$choice eq "yes"} {
            {*}$::mission::commands(initialize_path_mission) $path
        }
    }

    # Automatically initializes a flight using data_path (or prompts if none
    # present)
    proc initialize_path_flight {} {
        if {$::mission::commands(initialize_path_flight) eq ""} {
            tk_messageBox -icon error \
                    -parent $::mission::top \
                    -type ok \
                    -title "Plugins not loaded" \
                    -message "You have not loaded any plugins yet. Please\
                        define and load the required plugin(s)."
            return
        }

        variable flight_name
        if {$flight_name eq ""} {
            return
        }

        if {[has $flight_name "data_path dir"]} {
            set path [get $flight_name "data_path dir"]

            if {![file isdirectory $path]} {
                tk_messageBox -icon warning \
                        -parent $::mission::top \
                        -type ok \
                        -title "Invalid \"data_path dir\" defined" \
                        -message "You must select a valid \"data_path dir\"\
                            before you can initialize the flight by path."
                return
            }
        } else {
            set path [tk_chooseDirectory \
                    -mustexist 1 \
                    -title "Choose flight path"]

            if {$path eq ""} {
                return
            } elseif {![file isdirectory $path]} {
                tk_messageBox -icon warning \
                        -parent $::mission::top \
                        -type ok \
                        -title "Invalid path" \
                        -message "You must select a valid path in order to\
                                initialize the flight by path."
                return
            }
        }

        if {![llength [get $flight_name]]} {
            set choice yes
        } else {
            set choice [tk_messageBox -icon question \
                    -parent $::mission::top \
                    -type yesno \
                    -title "Initialize Flight by Path" \
                    -message "Initializing the flight by path will clear the\
                        currently defined configuration for this flight and\
                        replace it with automatically determined details. Are\
                        you sure you want to do this?"]
        }

        if {$choice eq "yes"} {
            {*}$::mission::commands(initialize_path_flight) $flight_name $path
        }

    }

    # Updates the values list for the "Detail type:" field. This will display
    # all known detail types that are not already defined for the current
    # flight.
    proc refresh_detail_types {cbo} {
        variable detail_types
        variable detail_type
        variable flight_name
        set values [list]
        if {$detail_type ni $detail_types} {
            lappend values $detail_type
        }
        foreach type $detail_types {
            if {$type eq $detail_type} {
                lappend values $type
            } elseif {![has $flight_name $type]} {
                lappend values $type
            }
        }
        $cbo configure -values $values
    }

    # Used by revertable field "Flight name:" to apply the new value
    proc apply_flight_name {old new} {
        set old [ystr $old]
        set new [ystr $new]
        exp_send "mission, flights, rename, \"$old\", \"$new\";\r"
    }

    # Used by revertable field "Detail type:" to apply the new value
    proc apply_detail_type {old new} {
        variable flight_name
        set flight [ystr $flight_name]
        set old [ystr $old]
        set new [ystr $new]
        exp_send "mission, details, rename, \"$flight\", \"$old\", \"$new\";\r"
    }

    # Used by revertable field "Detail value:" to apply the new value
    proc apply_detail_value {old new} {
        variable flight_name
        variable detail_type
        set flight [ystr $flight_name]
        set detail [ystr $detail_type]
        set new [ystr $new]
        exp_send "mission, details, set, \"$flight\", \"$detail\", \"$new\", raw=1;\r"
    }

    # Implements the raise, lower, and remove quick buttons to the left of the
    # treeviews.
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

    # Implements the add quick button to the left of the flight treeview.
    proc quick_add_flight {} {
        variable conf
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

    # Implements the add quick button to the left of the details treeview.
    proc quick_add_detail {} {
        variable conf
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

    # Utility proc for detail_select_file and detail_select_dir
    # Comes up with an appropriate directory to use for their initialdir
    proc detail_select_initialdir {} {
        variable conf
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

    # Prompts the user to browse to a file to use for the current field
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
            exp_send "mission, details, set, \"$flight\", \"$detail\", \"$path\", raw=1;\r"
        }
    }

    # Prompts the user to browse to a file to use for the current field
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
            exp_send "mission, details, set, \"$flight\", \"$detail\", \"$path\", raw=1;\r"
        }
    }

    # Refreshes the GUI in response to updated flight information.
    proc refresh_flights {} {
        variable flights
        variable conf
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
        ::misc::idle ::mission::refresh_details
    }

    # Refreshes the GUI in response to updated flight information -or- in
    # response to a change in selected flight (in the edit view).
    proc refresh_details {} {
        ::misc::idle ::mission::refresh_load

        variable flights
        variable details
        variable conf
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

        ::misc::idle ::mission::refresh_fields
    }

    # Refreshes the load view GUI.
    proc refresh_load {} {
        variable load_flights
        variable load_extra
        variable commands

        foreach child [winfo children $load_flights] {
            destroy $child
        }
        foreach child [winfo children $load_extra] {
            destroy $child
        }

        if {$commands(refresh_load) ne ""} {
            {*}$commands(refresh_load) $load_flights $load_extra
            return
        }

        set f $load_flights
        set row 0
        foreach flight [get] {
            incr row
            ttk::label $f.lbl$row -text $flight
            ttk::button $f.btn$row -text "Load" -command \
                    [list exp_send "mission, load, \"[ystr $flight]\";\r"]
            grid $f.lbl$row $f.btn$row -padx 2 -pady 2
            grid $f.lbl$row -sticky w
            grid $f.btn$row -sticky ew
        }
    }

    # Refreshes the revertable fields based on current selections in the edit
    # view of the GUI.
    proc refresh_fields {} {
        variable conf
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

        if {[llength [$flights selection]]} {
            $widget_flight_name state !disabled
            if {[llength [$details selection]]} {
                $widget_detail_type state !disabled
                $widget_detail_value state !disabled
            } else {
                $widget_detail_type state disabled
                $widget_detail_value state disabled
            }
        } else {
            $widget_flight_name state disabled
            $widget_detail_type state disabled
            $widget_detail_value state disabled
        }
    }

    # menu command
    # Clears the configuration
    proc new_conf {} {
        variable currentfile
        set currentfile ""
        exp_send "mission, flights, clear;\r"
    }

    # menu command
    # Prompts user to select a configuration, which is then loaded.
    # If a configuration is loaded, returns 1; otherwise, returns 0.
    # If this is called outside of the mission configuration GUI, the calling
    # procedure should provide a -parent option specifying the GUI that should
    # be its parent.
    proc load_conf {args} {
        variable top
        variable currentfile
        set parent $top
        if {[dict exists $args -parent]} {
            set parent [dict get $args -parent]
        }
        set fn [tk_getOpenFile \
                -initialdir $::mission::path \
                -parent $parent \
                -filetypes {{"JSON files" .json} {"All files" *}} \
                -title "Select mission configuration to load"]
        if {$fn ne ""} {
            set currentfile $fn
            set fn [ystr $fn]
            exp_send "mission, read, \"$fn\";\r"
            return 1
        } else {
            return 0
        }
    }

    # menu command
    # Prompts the user for a destination, where the configuration is then saved
    # to.
    proc save_conf {} {
        variable top
        variable currentfile
        set initial ""
        if {$currentfile ne "" && $::mission::path ne ""} {
            set initial [::fileutil::relative $::mission::path $currentfile]
            if {[string index $initial 0] eq "."} {
                set initial ""
                set currentfile ""
            }
        }
        set fn [tk_getSaveFile \
                -initialdir $::mission::path \
                -initialfile $initial \
                -parent $top \
                -title "Select destination for mission configuration"]
        if {$fn ne ""} {
            set currentfile $fn
            set fn [ystr $fn]
            exp_send "mission, save, \"$fn\";\r"
        }
    }

    # Implements the "Load Data" button on the edit view
    proc editview_load_data {} {
        variable flights
        set flight [lindex [$flights selection] 0]
        if {$flight ne ""} {
            exp_send "mission, load, \"[ystr $flight]\";\r"
        }
    }

    namespace eval menu {
        namespace import ::misc::menulabel

        proc postmenu {mb cmd} {
            return [menu $mb -postcommand [list ::mission::menu::$cmd $mb]]
        }

        proc clear {mb} {
            destroy [winfo children $mb]
            $mb delete 0 end
        }

        proc build {mb} {
            menu $mb
            $mb add cascade {*}[menulabel &File] \
                    -menu [postmenu $mb.file menu_file]
            $mb add cascade {*}[menulabel &Actions] \
                    -menu [postmenu $mb.actions menu_actions]
            $mb add cascade {*}[menulabel &Cache] \
                    -menu [postmenu $mb.cache menu_cache]
            return $mb
        }

        proc menu_file {mb} {
            clear $mb
            $mb add command {*}[menulabel "&New configuration"] \
                    -command ::mission::new_conf
            $mb add separator
            $mb add command {*}[menulabel "&Load configuration..."] \
                    -command ::mission::load_conf
            $mb add command {*}[menulabel "&Save configuration..."] \
                    -command ::mission::save_conf
        }

        proc menu_actions {mb} {
            clear $mb
            $mb add command {*}[menulabel "Initialize mission from path"] \
                    -command ::mission::initialize_path_mission

            if {$::mission::commands(menu_actions) ne ""} {
                {*}$::mission::commands(menu_actions) $mb
            }
        }

        proc menu_cache {mb} {
            clear $mb
            $mb add cascade {*}[menulabel "Caching &mode..."] \
                    -menu [postmenu $mb.mode menu_cache_mode]
            $mb add separator
            $mb add command {*}[menulabel "Preload cache"] \
                    -command [list exp_send "mission, cache, preload;\r"]
            $mb add command {*}[menulabel "Clear cache"] \
                    -command [list exp_send "mission, cache, clear;\r"]
        }

        proc menu_cache_mode {mb} {
            clear $mb
            foreach mode {disabled onload onchange} {
                $mb add radiobutton \
                        -label $mode \
                        -variable ::mission::cache_mode \
                        -value $mode \
                        -command [list exp_send \
                                "mission, data, cache_mode=\"$mode\";\r"]
            }
        }
    }
}
