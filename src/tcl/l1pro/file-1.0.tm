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
        ::mixin::combobox $win.cboType \
                -textvariable [myvar mode] \
                -listvariable ::alps_data_modes
        ::misc::tooltip $win.lblType $win.cboType -wrap single \
                $::alps_data_modes_tooltip

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

proc ::l1pro::file::export_las {} {
    gui::export_las [prefix]%AUTO%
}

snit::widget ::l1pro::file::gui::export_las {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    variable vname {}
    variable mode {}

    # 0 basic
    # 1 gps time
    # 2 rgb
    # 3 gps time + rgb
    variable pdrf 1

    variable src_apply 1
    variable src_datum wgs84
    variable src_proj UTM
    variable src_zone 0

    variable out_reproject 0
    variable out_datum wgs84
    variable out_proj UTM
    variable out_zone 0

    # Range is 0 to 31
    variable class 0
    variable class_custom 0

    variable encode_rn 1
    variable scan_angles 0

    variable enabled -array {
        rn 0 src 0 src_zone 0 out 0 out_zone 0 class_custom 0
    }

    constructor args {
        wm title $win "Export as LAS..."
        wm resizable $win 1 0

        $self InitVars
        $self Gui
        $self UpdateState
        $self InitTraces
    }

    method InitVars {} {
        set vname $::pro_var
        set mode $::plot_settings(display_mode)
        if {[regexp {(^|_)n((ad)?83|(avd)?88)($|_)} $vname]} {
            set src_datum nad83
        }
        set src_zone $::curzone
        set out_datum $src_datum
        set out_zone $src_zone
    }

    method InitTraces {} {
        foreach var {pdrf class src_apply src_proj out_reproject out_proj} {
            trace add variable [myvar $var] write [mymethod UpdateState]
        }
    }

    method UpdateState {args} {
        set enabled(rn) [expr {$pdrf in {2 3}}]
        set enabled(class_custom) [expr {$class == -1}]
        set enabled(src) $src_apply
        set enabled(src_zone) [expr {$enabled(src) && $src_proj eq "UTM"}]
        set enabled(out) [expr {$enabled(src) && $out_reproject}]
        set enabled(out_zone) [expr {$enabled(out) && $out_proj eq "UTM"}]
    }

    method Gui {} {
        ttk::labelframe $win.fraSource -text "Data to export"
        ttk::labelframe $win.fraEncoding -text "Encoding options"
        ttk::labelframe $win.fraCoords -text "Coordinate system options"
        ttk::frame $win.fraButtons

        pack $win.fraSource $win.fraEncoding $win.fraCoords $win.fraButtons \
                -side top -fill x -expand 1 -padx 2 -pady 1

        # "Data to export"
        set f $win.fraSource

        ttk::label $f.lblVname -text "Data variable: "
        ::mixin::combobox $f.cboVname \
                -width 0 \
                -textvariable [myvar vname] \
                -state readonly \
                -listvariable ::varlist

        ttk::label $f.lblMode -text "Data mode: "
        ::mixin::combobox $f.cboMode \
                -width 0 \
                -textvariable [myvar mode] \
                -listvariable ::alps_data_modes
        ::misc::tooltip $f.lblMode $f.cboMode -wrap single \
                $::alps_data_modes_tooltip

        grid $f.lblVname $f.cboVname -sticky ew -padx 1 -pady 1
        grid $f.lblMode $f.cboMode -sticky ew -padx 1 -pady 1
        grid configure $f.lblVname $f.lblMode -sticky w
        grid columnconfigure $f 1 -weight 1

        # "Encoding options"
        set f $win.fraEncoding

        ttk::label $f.lblPdrf -text "Record Format:"
        ::mixin::combobox::mapping $f.cboPdrf \
                -width 0 \
                -altvariable [myvar pdrf] \
                -state readonly \
                -mapping {
                    "0 - Basic"                             0
                    "1 - Include GPS time"                  1
                    "2 - Include RGB channels"              2
                    "3 - Include GPS time + RGB channels"   3
                }

        ttk::checkbutton $f.chkRn -text "Encode RN" \
                -variable [myvar encode_rn]
        ::mixin::statevar $f.chkRn \
                -statevariable [myvar enabled](rn) \
                -statemap {0 disabled 1 normal}
        ttk::checkbutton $f.chkScan -text "Include Scan Angle Rank" \
                -variable [myvar scan_angles]

        ttk::label $f.lblClass -text "Classification:"
        ::mixin::combobox::mapping $f.cboClass \
                -width 40 \
                -altvariable [myvar class] \
                -state readonly \
                -mapping {
                    "0 - ASPRS: Created, never classified"      0
                    "1 - ASPRS: Unclassified"                   1
                    "2 - ASPRS: Ground"                         2
                    "3 - ASPRS: Low Vegetation"                 3
                    "4 - ASPRS: Medium Vegetation"              4
                    "5 - ASPRS: High Vegetation"                5
                    "6 - ASPRS: Building"                       6
                    "7 - ASPRS: Low Point (noise)"              7
                    "8 - ASPRS: Model Key-point (Mass point)"   8
                    "9 - ASPRS: Water"                          9
                    "12 - ASPRS: Overlap Points"                12
                    "Custom"                                    -1
                }

        ttk::label $f.lblCustom -text "Custom Class:"
        ttk::spinbox $f.spnCustom \
                -width 2 \
                -textvariable [myvar class_custom] \
                -from 0 -to 31 -increment 1
        ::mixin::statevar $f.spnCustom \
                -statevariable [myvar enabled](class_custom) \
                -statemap {0 disabled 1 normal}

        grid $f.lblPdrf $f.cboPdrf -sticky ew -padx 1 -pady 1
        grid $f.lblClass $f.cboClass -sticky ew -padx 1 -pady 1
        grid $f.lblCustom $f.spnCustom -sticky ew -padx 1 -pady 1
        grid $f.chkRn - -sticky w -padx 1 -pady 1
        grid $f.chkScan - -sticky w -padx 1 -pady 1
        grid configure $f.lblPdrf $f.lblClass $f.lblCustom -sticky w
        grid columnconfigure $f 1 -weight 1

        # "Coordinate system options"
        set f $win.fraCoords

        ttk::checkbutton $f.chkIncludeCs \
                -text "Include coordinate system info" \
                -variable [myvar src_apply]

        ttk::label $f.lblSrc -text "Data's CS:"
        ::mixin::combobox $f.cboSrcDatum \
                -width 5 \
                -textvariable [myvar src_datum] \
                -values {wgs84 nad83}
        ::mixin::statevar $f.cboSrcDatum \
                -statevariable [myvar enabled](src) \
                -statemap {0 disabled 1 {!disabled readonly}}
        ::mixin::combobox $f.cboSrcProj \
                -width 3 \
                -textvariable [myvar src_proj] \
                -values {UTM Geo}
        ::mixin::statevar $f.cboSrcProj \
                -statevariable [myvar enabled](src) \
                -statemap {0 disabled 1 {!disabled readonly}}
        ttk::spinbox $f.spnSrcZone \
                -width 2 \
                -textvariable [myvar src_zone] \
                -from 1 -to 60 -increment 1
        ::mixin::statevar $f.spnSrcZone \
                -statevariable [myvar enabled](src_zone) \
                -statemap {0 disabled 1 normal}

        ttk::checkbutton $f.chkReproject \
                -text "Reproject to:" \
                -variable [myvar out_reproject]
        ::mixin::combobox $f.cboOutDatum \
                -width 5 \
                -textvariable [myvar out_datum] \
                -values {wgs84 nad83}
        ::mixin::statevar $f.cboOutDatum \
                -statevariable [myvar enabled](out) \
                -statemap {0 disabled 1 {!disabled readonly}}
        ::mixin::combobox $f.cboOutProj \
                -width 3 \
                -textvariable [myvar out_proj] \
                -values {UTM Geo}
        ::mixin::statevar $f.cboOutProj \
                -statevariable [myvar enabled](out) \
                -statemap {0 disabled 1 {!disabled readonly}}
        ttk::spinbox $f.spnOutZone \
                -width 2 \
                -textvariable [myvar out_zone] \
                -from 1 -to 60 -increment 1
        ::mixin::statevar $f.spnOutZone \
                -statevariable [myvar enabled](out_zone) \
                -statemap {0 disabled 1 normal}

        grid $f.chkIncludeCs - - - -sticky w -padx 1 -pady 1
        grid $f.lblSrc $f.cboSrcDatum $f.cboSrcProj $f.spnSrcZone \
                -sticky ew -padx 1 -pady 1
        grid $f.chkReproject $f.cboOutDatum $f.cboOutProj $f.spnOutZone \
                -sticky ew -padx 1 -pady 1
        grid configure $f.lblSrc $f.chkReproject -sticky w
        grid columnconfigure $f {1 2 3} -weight 1

        # buttons
        set f $win.fraButtons

        ttk::button $f.btnExport -text "Export" -command [mymethod export]
        ttk::button $f.btnCancel -text "Cancel" -command [mymethod cancel]

        grid x $f.btnExport $f.btnCancel x -padx 1 -pady 1
        grid columnconfigure $f {0 3} -weight 1 -uniform a
        grid columnconfigure $f {1 2} -uniform b
    }

    method export {} {
        set use_class 0
        if {$class == -1} {
            if {
                ![string is integer -strict $class_custom] ||
                $class_custom < 0 || $class_custom > 31
            } {
                tk_messageBox \
                        -icon error \
                        -parent $win \
                        -type ok \
                        -message "You have an invalid value for Custom Class. The classification must be an integer between 0 and 31, inclusive."
                return
            }
            set use_class $class_custom
        } elseif {$class > 0} {
            set use_class $class
        }

        set cs {}
        if {$src_apply} {
            set cs "cs_${src_datum}("
            if {$src_proj eq "UTM"} {
                append cs "zone=$src_zone"
            }
            append cs ")"
        }
        set cs_out {}
        if {$out_reproject} {
            set cs_out "cs_${out_datum}("
            if {$out_proj eq "UTM"} {
                append cs_out "zone=$out_zone"
            }
            append cs_out ")"
        }

        set filename [tk_getSaveFile -initialdir $::data_file_path \
                -parent $win -title "Select destination" \
                -defaultextension .las \
                -filetypes {{"ASPRS LAS files" .las} {"All files" *}}]

        if {$filename eq ""} {
            return
        }

        set ::data_path [file dirname $filename]

        set cmd "las_export_data, \"$filename\", $vname"
        ::misc::appendif cmd \
                1                   ", mode=\"$mode\"" \
                1                   ", pdrf=$pdrf" \
                {$pdrf in {2 3}}    ", encode_rn=$encode_rn" \
                $scan_angles        ", include_scan_angle_rank=1" \
                $use_class          ", classification=$use_class" \
                $src_apply          ", cs=$cs" \
                $out_reproject      ", cs_out=$cs_out"

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
