# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::file 1.0

# Global ::data_file_path
if {![namespace exists ::l1pro::file]} {
    namespace eval ::l1pro::file {
        namespace eval gui {}
        namespace export prefix
    }
}

proc ::l1pro::file::prefix {} {
    if {[winfo exists .l1wid]} {
        return .l1wid.
    } else {
        return .
    }
}

proc ::l1pro::file::load_pbd {{vname {}}} {
    set fn [tk_getOpenFile -parent .l1wid -filetypes {
        {{Yorick PBD files} {.pbd .pdb}}
        {{IDL binary files} {.bin .edf}}
        {{All files} {*}}
    }]

    if {$fn ne ""} {
        exp_send "restore_alps_data, \"$fn\";\r"
    }
}

proc ::l1pro::file::save_pbd {{outvname {}}} {
    set vname $::pro_var
    if {$outvname eq ""} {
        set outvname $vname
    }
    set outvname [::yorick::sanitize_vname $outvname]
    set fn [tk_getSaveFile -parent .l1wid \
            -title "Select destination to save $vname" \
            -filetypes {
                {"PBD files" {.pbd .pdb}}
                {"IDL binary files" {.bin .edf}}
                {"All files" *}
            }]

    if {$fn ne ""} {
        set ext [file extension $fn]
        set ext [string tolower $ext]

        if {$ext eq ".edf" || $ext eq ".bin"} {
            exp_send "edf_export, \"$fn\", $vname;\r"
        } else {
            exp_send "pbd_save, \"$fn\", \"$outvname\", $vname;\r"
        }
    }
}

proc ::l1pro::file::save_pbd_as {} {
    set vname $::pro_var
    set prompt \
            "You are saving variable $::pro_var. Please specify the\
            \nname you would like $::pro_var saved as in the file."

    lassign [::misc::getstring \
            -default $vname \
            -prompt $prompt \
            -title "Save PBD as..." \
            ] result outvname

    if {$result eq "ok"} {
        save_pbd $outvname
    }
}

proc ::l1pro::file::export_ascii {} {
    gui::export_ascii [prefix]%AUTO%
}

snit::widget ::l1pro::file::gui::export_ascii {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    variable vname {}
    variable coordinates UTM
    variable indx 0
    variable rn 0
    variable soe 0
    variable intensity 0
    variable delimiter space
    variable header 0
    variable ESRI 0
    variable limit 0
    variable split 1000000
    variable mode ""

    constructor args {
        set vname $::pro_var
        set mode $::plot_settings(display_mode)

        wm title $win "Export as ASCII..."
        wm resizable $win 1 0

        ttk::frame $win.fraMain
        ttk::labelframe $win.fraSource -text "Data to export"
        ttk::labelframe $win.fraColumns -text "Columns to include"
        ttk::labelframe $win.fraSettings -text "Additional settings"
        ttk::frame $win.f1
        ttk::frame $win.f2
        ttk::frame $win.f3

        ttk::label $win.lblVname -text "Data variable: "
        ::mixin::combobox $win.cboVname \
                -textvariable [myvar vname] \
                -state readonly \
                -listvariable ::varlist

        ttk::label $win.lblType -text "Data mode: "
        ::mixin::combobox::mapping $win.cboType \
                -altvariable [myvar mode] \
                -state readonly \
                -mapping $::l1pro_data(mode_mapping)

        ttk::checkbutton $win.chkIndx -text "Index number" \
                -variable [myvar indx]
        ttk::checkbutton $win.chkRn -text "Record number (raster/pulse)" \
                -variable [myvar rn]
        ttk::checkbutton $win.chkSoe -text "Timestamp (seconds of epoch)" \
                -variable [myvar soe]
        ttk::checkbutton $win.chkIntensity -text "Intensity" \
                -variable [myvar intensity]

        ttk::label $win.lblDelimit -text "Delimiter: "
        ::mixin::combobox $win.cboDelimit \
                -state readonly \
                -textvariable [myvar delimiter] \
                -values {space comma semicolon}

        ttk::label $win.lblCoordinates -text "Coordinates: "
        ::mixin::combobox $win.cboCoordinates \
                -state readonly \
                -textvariable [myvar coordinates] \
                -values {UTM "Geographic (lat/lon)"}

        ttk::checkbutton $win.chkHeader -text "Include header" \
                -variable [myvar header]
        ttk::checkbutton $win.chkESRI -text "ESRI compatibility" \
                -variable [myvar ESRI]

        ttk::checkbutton $win.chkLimit -text "Limit line count to: " \
                -variable [myvar limit]
        ttk::spinbox $win.spnLimit -from 1 -to 1000000000 -increment 1000 \
                -width 10 -textvariable [myvar split]

        ttk::button $win.btnExport -text "Export" -command [mymethod export]
        ttk::button $win.btnCancel -text "Cancel" -command [mymethod cancel]

        grid $win.lblVname $win.cboVname -in $win.fraSource
        grid $win.lblType $win.cboType -in $win.fraSource
        grid columnconfigure $win.fraSource 1 -weight 1
        grid $win.lblVname $win.lblType -sticky e
        grid $win.cboVname $win.cboType -sticky ew

        grid $win.chkIndx -in $win.fraColumns -sticky w
        grid $win.chkRn -in $win.fraColumns -sticky w
        grid $win.chkSoe -in $win.fraColumns -sticky w
        grid $win.chkIntensity -in $win.fraColumns -sticky w
        grid columnconfigure $win.fraColumns 0 -weight 1

        grid x $win.chkLimit $win.spnLimit -in $win.f1
        grid columnconfigure $win.f1 0 -weight 1

        grid $win.lblDelimit $win.cboDelimit -in $win.fraSettings
        grid $win.lblCoordinates $win.cboCoordinates -in $win.fraSettings
        grid $win.chkHeader - -in $win.fraSettings
        grid $win.chkESRI - -in $win.fraSettings
        grid $win.f1 - -in $win.fraSettings
        grid columnconfigure $win.fraSettings 1 -weight 1
        grid $win.lblDelimit $win.lblCoordinates -sticky e
        grid $win.chkHeader $win.chkESRI $win.f1 -sticky w
        grid $win.cboDelimit $win.cboCoordinates -sticky ew

        grid x $win.btnExport $win.btnCancel -in $win.f2 -sticky e \
                -padx 1 -pady 1
        grid columnconfigure $win.f2 {0 3} -weight 1

        grid $win.fraSource -in $win.fraMain -sticky news
        grid $win.fraColumns -in $win.fraMain -sticky news
        grid $win.fraSettings -in $win.fraMain -sticky news
        grid $win.f2 -in $win.fraMain -sticky ew
        grid columnconfigure $win.fraMain 0 -weight 1
        grid rowconfigure $win.fraMain 100 -weight 1

        grid $win.fraMain -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1
    }

    method export {} {
        set filename [tk_getSaveFile -initialdir $::data_file_path \
                -parent $win -title "Select destination" \
                -defaultextension .xyz \
                -filetypes {{"Text files" .txt .xyz} {"All files" *}}]

        if {$filename eq ""} {
            return
        }

        set ::data_path [file dirname $filename]

        set latlon [expr {$coordinates eq "Geographic (lat/lon)"}]
        set delimit [dict get {space " " comma , semicolon ;} $delimiter]

        set cmd "write_ascii_xyz, $vname, \"$filename\""
        append cmd ", delimit=\"$delimit\""

        foreach setting {header indx rn soe intensity ESRI latlon} {
            if {[set $setting]} {
                append cmd ", ${setting}=1"
            }
        }

        if {$limit} {
            append cmd ", split=$split"
        }

        append cmd ", mode=\"$mode\""

        exp_send "$cmd;\r"
        expect "> "

        destroy $self
    }

    method cancel {} {
        destroy $self
    }
}

proc ::l1pro::file::load_las {} {
    if {[winfo exists .l1wid]} {
        set prefix .l1wid.
    } else {
        set prefix .
    }
    ::l1pro::file::gui::load_las ${prefix}%AUTO%
}

snit::widget ::l1pro::file::gui::load_las {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    variable filename {}
    variable struct LAS_ALPS
    variable vname {}
    variable skip 1
    variable fakemirror 1
    variable rgbrn 1

    constructor args {
        wm title $win "Import LAS data..."
        wm resizable $win 1 0

        ttk::frame $win.f1
        ttk::frame $win.f2

        ttk::label $win.lblFile -text "Source file: "
        ttk::entry $win.entFile -state readonly -width 40 \
                -textvariable [myvar filename]
        ttk::button $win.btnFile -text "Browse..." \
                -command [mymethod select_file]

        ttk::label $win.lblStruct -text "Structure: "
        ::mixin::combobox $win.cboStruct \
                -state readonly \
                -textvariable [myvar struct] \
                -values {LAS_ALPS FS VEG__}

        ttk::label $win.lblVname -text "Variable name: "
        ttk::entry $win.entVname -width 20 \
                -textvariable [myvar vname]

        ttk::label $win.lblSkip -text "Subsample factor: "
        ttk::spinbox $win.spnSkip -from 1 -to 10000 -increment 1 \
                -textvariable [myvar skip]

        ttk::checkbutton $win.chkFakemirror -text "Fake mirror coordinates" \
                -variable [myvar fakemirror]
        ttk::checkbutton $win.chkRgbrn -text "Decode record number from RGB" \
                -variable [myvar rgbrn]

        ::misc::tooltip $win.chkFakemirror \
                "If enabled, mirror coordinates will be faked; coordinates will
                match point coordinates, plus 100m elevation.  Otherwise,
                mirror coordinates are all 0."
        ::misc::tooltip $win.chkRgbrn \
                "If enabled, RGB values will be interpreted as record numbers
                that were exported by ALPS. Otherwise, record number will be
                left as 0. If there are no RGB values, then this setting is
                ignored."

        ttk::button $win.btnLoad -text "Load" -command [mymethod load]
        ttk::button $win.btnCancel -text "Cancel" -command [mymethod cancel]

        grid $win.f1 -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        grid $win.lblFile $win.entFile $win.btnFile -in $win.f1 -padx 1 -pady 1
        grid $win.lblStruct $win.cboStruct -in $win.f1 -padx 1 -pady 1
        grid $win.lblVname $win.entVname -in $win.f1 -padx 1 -pady 1
        grid $win.lblSkip $win.spnSkip -in $win.f1 -padx 1 -pady 1
        grid x $win.chkFakemirror -in $win.f1 -padx 1 -pady 1
        grid x $win.chkRgbrn -in $win.f1 -padx 1 -pady 1
        grid $win.f2 - - -in $win.f1

        grid $win.lblFile $win.lblStruct $win.lblVname $win.lblSkip -sticky e
        grid $win.chkFakemirror $win.chkRgbrn -sticky w
        grid $win.entFile $win.btnFile $win.cboStruct $win.entVname \
                $win.spnSkip $win.f2 -sticky ew

        grid x $win.btnLoad $win.btnCancel -in $win.f2 -sticky e -padx 1 -pady 1

        grid columnconfigure $win.f1 1 -weight 1
        grid columnconfigure $win.f2 {0 3} -weight 1
        grid rowconfigure $win.f1 10 -weight 1

        $self configurelist $args
    }

    method select_file {} {
        if {$filename eq ""} {
            set base $::data_file_path
        } else {
            set base [file dirname $filename]
        }

        set temp [tk_getOpenFile -initialdir $base \
                -parent $win -title "Select source file" \
                -filetypes {{"ASPRS LAS files" .las} {"All files" *}}]

        if {$temp ne ""} {
            set filename $temp
        }
    }

    method load {} {
        if {$vname eq ""} {
            tk_messageBox -icon error -type ok \
                    -message "You must provide a variable name."
            return
        }

        if {$filename eq ""} {
            $self select_file
        }
        if {$filename eq ""} {
            return
        }

        set func [dict get \
                {LAS_ALPS las_to_alps FS las_to_fs VEG__ las_to_veg} $struct]

        set cmd "$vname = ${func}(\"$filename\", fakemirror=$fakemirror,\
                rgbrn=$rgbrn)"
        if {$skip > 1} {
            append cmd "(::$skip)"
        }

        exp_send "$cmd;\r"
        append_varlist $vname
        set ::pro_var $vname
        destroy $self
    }

    method cancel {} {
        destroy $self
    }
}
