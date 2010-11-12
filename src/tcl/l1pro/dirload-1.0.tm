# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::dirload 1.0

# Global ::data_file_path
if {![namespace exists ::l1pro::dirload]} {
    namespace eval ::l1pro::dirload {
        namespace eval v {
            variable top .l1wid.l1dir
            variable searchstr "*.pbd"
            variable vname merged
            variable skip 1
            variable unique 0
            variable zone Auto
            variable zonelist {}
            variable region_data {}
            variable region_desc "All data"
        }
        set v::zonelist [lreplace [::struct::list iota 61] 0 0 Auto]
    }
}

proc ::l1pro::dirload {} {
    if {![winfo exists $dirload::v::top]} {
        ::l1pro::dirload::gui
    }
    wm deiconify $dirload::v::top
    raise $dirload::v::top
}

proc ::l1pro::dirload::gui {} {
    destroy $v::top
    toplevel $v::top
    wm resizable $v::top 1 0
    wm minsize $v::top 440 1
    wm title $v::top "Load ALPS data directory"
    wm protocol $v::top WM_DELETE_WINDOW [list wm withdraw $v::top]

    set ns [namespace current]
    set f $v::top

    # Container for everything that follows; declared first to make sure they
    # stack above it
    ttk::frame $f.f
    pack $f.f -fill both -expand 1

    ttk::label $f.lblPath -text "Data path:"
    ttk::entry $f.entPath -width 40 -textvariable ::data_file_path
    ttk::button $f.btnPath -text "Browse..." -command ${ns}::browse_path

    ttk::label $f.lblSearch -text "Search string:"
    ttk::entry $f.entSearch -width 8 -textvariable ${ns}::v::searchstr

    ttk::label $f.lblVname -text "Output variable:"
    ttk::entry $f.entVname -width 8 -textvariable ${ns}::v::vname

    ttk::frame $f.fraZoneLine

    ttk::label $f.lblUnique -text "Unique:"
    ttk::checkbutton $f.chkUnique -variable ${ns}::v::unique

    ttk::label $f.lblSkip -text "Subsample:"
    ttk::spinbox $f.spnSkip -from 1 -to 10000 -increment 1 -width 5 \
            -textvariable ${ns}::v::skip

    ttk::label $f.lblZone -text "Zone:"
    ::mixin::combobox $f.cboZone -state readonly -width 5 \
            -textvariable ${ns}::v::zone \
            -listvariable ${ns}::v::zonelist

    ttk::label $f.lblRegion -text "Region:"
    ttk::entry $f.entRegion -state readonly \
            -textvariable ${ns}::v::region_desc
    ttk::menubutton $f.mnuRegion -text "Configure..." \
            -menu [set mb $f.mnuRegion.mb]
    menu $mb
    $mb add command -label "Load all data" \
            -command ${ns}::region_all
    $mb add command -label "Load using rubberband box" \
            -command ${ns}::region_bbox
    $mb add command -label "Load using polygon" \
            -command ${ns}::region_poly
    $mb add command -label "Load using current window limits" \
            -command ${ns}::region_lims
    $mb add command -label "Plot current region (if possible)" \
            -command ${ns}::region_plot

    ttk::frame $f.fraButtons
    ttk::button $f.btnLoadCont -text "Load & Continue" \
            -command [list ${ns}::load_data continue]
    ttk::button $f.btnLoadDism -text "Load & Finish" \
            -command [list ${ns}::load_data finish]
    ttk::button $f.btnClose -text "Cancel" -command [list wm withdraw $v::top]

    ::tooltip::tooltip $f.btnLoadCont \
            "Loads the data, then leaves this GUI open. Useful if you're using\
            \nsubsample to preview data before loading it again at a higher\
            \ndensity for a specific subregion, for example."
    ::tooltip::tooltip $f.btnLoadDism \
            "Loads the data, then closes this GUI."

    grid $f.cboZone $f.lblSkip $f.spnSkip $f.lblUnique $f.chkUnique \
            -in $f.fraZoneLine -sticky ew
    grid columnconfigure $f.fraZoneLine {0 2} -weight 1 -uniform 1

    grid $f.lblPath $f.entPath $f.btnPath -in $f.f
    grid $f.lblSearch $f.entSearch x -in $f.f
    grid $f.lblVname $f.entVname x -in $f.f
    grid $f.lblZone $f.fraZoneLine x -in $f.f
    grid $f.lblRegion $f.entRegion $f.mnuRegion -in $f.f
    grid $f.fraButtons - - -in $f.f -pady 2

    grid x $f.btnLoadCont $f.btnLoadDism $f.btnClose x -in $f.fraButtons \
            -sticky e -padx 2
    grid columnconfigure $f.fraButtons {0 4} -weight 1

    grid configure $f.lblPath $f.lblSearch $f.lblVname $f.lblUnique \
            $f.lblSkip $f.lblZone $f.lblRegion -sticky e -padx {2 0}
    grid configure $f.entPath $f.entSearch $f.entVname $f.chkUnique \
            $f.spnSkip $f.cboZone $f.entRegion -sticky ew -padx 2
    grid configure $f.btnPath $f.mnuRegion -sticky news
    grid configure $f.fraZoneLine $f.fraButtons -sticky ew

    grid rowconfigure $f.f {0 1 2 3 4 5} -uniform 1
    grid columnconfigure $f.f 1 -weight 1
}

proc ::l1pro::dirload::browse_path {} {
    set temp_path [tk_chooseDirectory -initialdir $::data_file_path \
            -mustexist 1 -title "Choose data directory"]
    if {$temp_path ne ""} {
        set ::data_file_path $temp_path
    }
}

proc ::l1pro::dirload::region_all {} {
    set v::region_data {}
    set v::region_desc "All data"
}

proc ::l1pro::dirload::region_bbox {} {
    exp_send "dirload_l1pro_selbbox;\r"
}

proc ::l1pro::dirload::region_poly {} {
    exp_send "dirload_l1pro_selpoly;\r"
}

proc ::l1pro::dirload::region_lims {} {
    exp_send "dirload_l1pro_sellims;\r"
}

proc ::l1pro::dirload::region_plot {} {
    exp_send "plotPoly, $v::region_data;\r"
}

proc ::l1pro::dirload::load_data termaction {
    if {![file isdirectory $::data_file_path]} {
        error "Data path is not a directory: $::data_file_path"
    }

    if {$termaction eq "finish"} {
        wm withdraw $v::top
    }

    set filter ""

    # Do we need to filter by region?
    if {[llength $v::region_data]} {
        set filter "dlfilter_poly($v::region_data)"
    }

    # Do we need to force a zone?
    if {$v::zone ne "Auto"} {
        if {$filter ne ""} {
            set filter ", next=$filter"
        }
        set filter "dlfilter_rezone($v::zone$filter)"
    }

    set cmd "$v::vname = dirload(\"$::data_file_path\""
    ::misc::appendif cmd \
        1                   ", searchstr=\"$v::searchstr\"" \
        {$v::skip > 1}      ", skip=$v::skip" \
        {$v::unique}        ", uniq=1" \
        {$filter ne ""}     ", filter=$filter"
        1                   ")"

    append_varlist $v::vname
    set ::pro_var $v::vname
    exp_send "$cmd;\r"
}
