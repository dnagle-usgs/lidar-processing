# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::deprecated 1.0

# Global ::data_file_path
namespace eval ::l1pro::deprecated {}

proc ::l1pro::deprecated::read_binary_data_file {} {
    uplevel #0 {
        global cbv cdelta cbvc plot_settings pro_var
        if {$cbv == 1} {
            set cbvc(cmin) $plot_settings(cmin)
            set cbvc(cmax) $plot_settings(cmax)
            set cbvc(msize) $plot_settings(msize)
            set cbvc(mtype) $plot_settings(mtype)
        }

        set _ytk_fn [ tk_getOpenFile -parent .l1wid \
            -filetypes {
            {{Yorick PBD file} {.pbd}  }
            {{IDL Binary file} {.bin}  }
            {{IDL Binary file} {.edf}  }
            {{All Files}       {*}   }
            }]
        if { $_ytk_fn != "" } {
            switch [ file extension $_ytk_fn ] {
                ".pbd" {
                    exp_send "_ytk_pbd_f = openb(\"$_ytk_fn\"); restore, _ytk_pbd_f;\r"
                    exp_send "show, _ytk_pbd_f\r"
                    toplevel .stby
                    exp_send "\r"
                    label .stby.lbl -text "Loading\n$_ytk_fn\nplease wait.."
                    pack .stby.lbl
                    expect ">"
                    update
                    exp_send "set_read_tk \r"
                    expect "Tk updated"
                    expect ">"
                    update
                    set var_type $pro_var
                    update
                    if { $cbv == 0 } {
                        exp_send "set_read_yorick, $var_type \r"
                        expect ">"
                    }
                    destroy .stby
                    if {$cbv == 1} {
                        set plot_settings(cmin) $cbvc(cmin)
                        set cdelta [expr {$cbvc(cmax)-$cbvc(cmin)}]
                        set plot_settings(cmax) $cbvc(cmax)
                        set plot_settings(msize) $cbvc(msize)
                        set plot_settings(mtype) $cbvc(mtype)
                    }
                    update
                }
                ".edf" -
                ".bin" {
                    set ytk_bin_dir [ file dirname $_ytk_fn ]/
                    set ytk_bin_file [ file tail $_ytk_fn ]
                    exp_send "data_ptr = read_yfile(\"$ytk_bin_dir\",\
                    fname_arr=\"$ytk_bin_file\"); \r"
                    expect ">"
                    exp_send "read_pointer_yfile, data_ptr, mode=1; \r"
                    expect ">"
                    set ptype [processing_mode]
                }
            }
        }
    }
}

proc ::l1pro::deprecated::write_binary_data_file {} {
    uplevel #0 {
        global write_some data_file_path pro_var
        if { [info exists data_file_path ] == 0 } {
            set data_file_path "~/"
        }
        destroy .l1write
        toplevel .l1write
        frame .l1write.1
        frame .l1write.2
        frame .l1write.3
        set ftypes {
            {{For pbd}       {.pbd}        }
            {{IDL bin}       {.bin}        }
            {{IDL edf}       {.edf}        }
            {{All Files}            *      }
        }
        set ptype [processing_mode]
        set var_type $pro_var
        LabelEntry .l1write.1.path  -width 30 -relief sunken -bd 3 \
                -label "Output Path:  " \
                -helptext "Enter Output Data Path Here" \
                -textvariable ofname -text $data_file_path
        Button .l1write.1.browse -text "Browse..." -width 10 \
                -command {
                    set ofname [tk_getSaveFile -filetypes $ftypes \
                            -defaultextension ".pbd"]
                    ::l1pro::deprecated::write_binary_file $ofname
                }
        LabelEntry .l1write.2.varname -width 10 -relief sunken -bd 3 \
                -label "Variable Name: " \
                -helptext "Enter Name of Variable to Write to file"  \
                -textvariable var_type -text $var_type
        LabelEntry .l1write.2.plyname -width 10 -relief sunken -bd 3 \
                -label "PLY Name: " \
                -helptext "Enter ply name to Write to file; Leave it empty if\
                        you don't want to write out ply data" \
                -textvariable ply_type -text ""
        LabelEntry .l1write.2.qname -width 10 -relief sunken -bd 3 \
                -label "GGA(q) Name: " \
                -helptext "Enter q name to Write to file; Leave it empty if\
                        you don't want to write out gga data" \
                -textvariable q_type -text ""
        Button .l1write.3.ok -text "Write File" -width 5 \
                -command {
                    global ofname
                    ::l1pro::deprecated::write_binary_file $ofname
                }
        Button .l1write.3.cancel -text "Cancel" -width 5 \
                -command {destroy .l1write}
        pack .l1write.1.path .l1write.1.browse -side left -padx 5
        pack .l1write.2.varname .l1write.2.plyname .l1write.2.qname \
            -side left -padx 5
        pack .l1write.3.ok .l1write.3.cancel -side left -padx 5
        pack .l1write.1 .l1write.2 .l1write.3
    }
}

proc ::l1pro::deprecated::write_binary_file {} {
    global ply_type q_type write_some var_type
    if { $ofname != "" }  {
        switch -- [file extension $ofname] {
            ".pbd" {
                if {($ply_type == "") && ($q_type == "")} {
                    exp_send "vname=\"$var_type\";\
                            save, createb(\"$ofname\"), vname, $var_type; \r"
                } elseif {($ply_type == "") && !($q_type == "")} {
                    exp_send "vname=\"$var_type\";\
                            qname=\"$q_type\";\
                            save, createb(\"$ofname\"), vname, $var_type,\
                                    qname, $q_type;\r"
                } elseif {!($ply_type == "") && !($q_type == "")} {
                    exp_send "vname=\"$var_type\";\
                            qname=\"$q_type\";\
                            plyname=\"$ply_type\";\
                            save, createb(\"$ofname\"), vname, $var_type,\
                                    qname, $q_type, plyname, $ply_type;\r"
                } else { ;# !($ply_type == "") && ($q_type == "")
                    exp_send "vname=\"$var_type\";\
                            plyname=\"$ply_type\";\
                            save, createb(\"$ofname\"), vname, $var_type,\
                                    plyname, $ply_type;\r"
                }
                destroy .l1write
            }
            ".bin" -
            ".edf" {
                set opath [file dirname $ofname]/
                set ofname [file tail $ofname]
                if {![string equal "" $ofname]} {
                    if {$ptype == 0} {
                        if {$write_some == 0} {
                            exp_send "write_topo, \"$opath\", \"$ofname\",\
                                    $var_type;\r"
                            expect ">"
                        } else {
                            exp_send "write_topo, \"$opath\", \"$ofname\",\
                                    fs_some;\r"
                            expect ">"
                        }
                    } elseif {$ptype == 1} {
                        if {$write_some == 0} {
                            exp_send "write_bathy, \"$opath\", \"$ofname\",\
                                    $var_type;\r"
                            expect ">"
                        } else {
                            exp_send "write_bathy, \"$opath\", \"$ofname\",\
                                    depth_some;\r"
                            expect ">"
                        }
                    } elseif {$ptype == 2} {
                        if {$write_some == 0} {
                            exp_send "write_veg, \"$opath\", \"$ofname\",\
                                    $var_type;\r"
                            expect ">"
                        } else {
                            exp_send "write_veg, \"$opath\", \"$ofname\",\
                                    veg_some;\r"
                            expect ">"
                        }
                    } elseif {$ptype == 3} {
                        if {$write_some == 0} {
                            exp_send "write_multipeak_veg, $var_type,\
                                    opath=\"$opath\", ofname=\"$ofname\";\r"
                            expect ">"
                        } else {
                            exp_send "write_multipeak_veg, cveg_some,\
                                    opath=\"$opath\", ofname=\"$ofname\";\r"
                            expect ">"
                        }
                    }
                } else {
                    tk_messageBox -icon warning -type ok -message \
                            "You need to specify an output file name"
                }
                set write_some 0
            }
            default {
                tk_messageBox -icon warning -type ok -message \
                        "You need to specify an output file with a valid file\
                        extension (pbd, bin, or edf)" 
            }
        }
    } else {
      tk_messageBox -icon warning -type ok -message \
            "You need to specify an output file name"
    }
}

proc ::l1pro::deprecated::read_subsampled_data_file {} {
    uplevel #0 {
        global data_file_path
        set ofn [tk_getOpenFile -filetypes {
            {{Yorick PBD file} {.pbd}  }
            {{All Files}       {*}   }
        }]
        destroy .l1ss
        toplevel .l1ss
        wm title .l1ss "Read SubSampled Data File"
        LabelFrame .l1ss.1 -relief groove -borderwidth 3 \
                -text "Points to skip:"
        frame .l1ss.2
        spinbox .l1ss.1.sk \
                -from 1 -to 1000 -increment 1 \
                -textvariable skipl \
                -width 5
        ::tooltip::tooltip .l1ss.1.sk "Enter points to skip (Subsample)"
        LabelEntry .l1ss.1.mvar -label "Variable Name: " -width 10 -bd 3 \
                -helptext "Enter Variable Name of Data array after merging" \
                -textvariable mvar
        Button .l1ss.2.ok -text "OK" -width 5 \
                -command {
                    exp_send "$mvar = subsample_pbd_data(fname=\"$ofn\",\
                            skip=$skipl);\r"
                    destroy .l1ss
                }
        Button .l1ss.2.cancel -text "Cancel" -width 5 -command {destroy .l1ss}
        pack .l1ss.1.sk .l1ss.1.mvar -side left -padx 5
        pack .l1ss.2.ok .l1ss.2.cancel -side left -padx 5
        pack .l1ss.1 .l1ss.2 -pady 5
    }
}

proc ::l1pro::deprecated::ascii_output {} {
    uplevel #0 {
        global opath ofile data_path plot_settings pro_var write_asc_some
        if {[info exists data_path] == 0} {
            set data_path "~/"
        }
        set delimit "space"
        set indx 0
        set intensity 0
        set rnidx 0
        set soeindx 0
        set hline 0
        set split 0
        set zclip 0
        set opath $data_path
        set zmin $plot_settings(cmin)
        set zmax $plot_settings(cmax)
        set ftypes {
            {{For QTViewer}  {.xyz} }
            {{Generic ASCII} {.asc} }
            {{Simple txt}    {.txt} TEXT}
            {{All Files}       *    }
        }

        destroy .l1asc
        toplevel .l1asc
        set w .l1asc
        $w configure -menu $w.mb
        menu $w.mb
        menu $w.mb.file
        $w.mb add cascade -label File -underline 0 -menu $w.mb.file
        $w.mb.file add command -label "File..." \
                -command {
                    set ofname [tk_getSaveFile \
                        -filetypes $ftypes \
                        -initialdir $data_path \
                        -defaultextension .xyz \
                    ]
                    if { $ofname != "" } {
                        set opath "[file dirname $ofname]/"
                        set ofname [file tail $ofname]
                        set data_path $opath

                        set ptype [processing_mode]
                        set dtype [display_type]
                        set var_type $pro_var

                        if {$zclip} {
                            set zclips "\[$zmin, $zmax\]"
                        } else {
                            set zclips "\[\]"
                        }
                        switch -- $utmll {
                            UTM     {set latlon 0}
                            LATLON  {set latlon 1}
                            default {set latlon 0}
                        }
                        switch -- $delimit {
                            space     {set de "\" \""}
                            comma     {set de "\",\""}
                            semicolon {set de "\";\""}
                            default   {set de "\"\""}
                        }
                        switch -- $ptype {
                            0 {
                                set wtype 1
                                set pstruc FS
                            }
                            1 {
                                set wtype [expr {$dtype ? 2 : 1}]
                                set pstruc GEO
                            }
                            2 {
                                set wtype [expr {$dtype ? 3 : 1}]
                                set pstruc VEG__
                            }
                            3 {
                                set wtype 1
                                set pstruc CVEG_ALL
                            }
                            default {
                                set wtype ""
                                set pstruc ""
                            }
                        }
                        if {$wtype ne "" && $pstruc ne ""} {
                            exp_send "write_ascii_xyz, $var_type, \"$opath\",\
                                    \"$ofname\", type=$wtype, indx=$indx,\
                                    split=$split, intensity=$intensity,\
                                    delimit=$de, zclip=$zclips,\
                                    pstruc=$pstruc, rn=$rnidx, soe=$soeindx,\
                                    header=$hline, latlon=$latlon;\r"
                            expect ">"
                        }
                        set write_some 0
                    }
                }

        wm title .l1asc "Write Ascii Data"
        LabelFrame .l1asc.ops -justify center -relief groove -borderwidth 3 \
                -text "Options:"
        set utmll "UTM"
        ::mixin::combobox .l1asc.ops.0 -textvariable utmll -state readonly \
                -values [list UTM LATLON] -width 8
        LabelFrame .l1asc.ops.1 -justify center -relief groove -borderwidth 3 \
                -text "Include:"
        frame .l1asc.ops.2 -relief groove -borderwidth 3
        frame .l1asc.fn -relief groove -borderwidth 3
        frame .l1asc.cmd -relief groove -borderwidth 3
        set ptype [processing_mode]
        set var_type $pro_var

        Separator .l1asc.ops.1.s0 -orient vertical -bg black -relief groove
        Separator .l1asc.ops.1.s1 -orient vertical -bg black -relief groove

        checkbutton .l1asc.ops.1.indx -text "Index Number" -variable indx
        Separator .l1asc.ops.1.s2 -orient vertical -bg black -relief groove

        checkbutton .l1asc.ops.1.rn -text "Raster/Pulse Number" -variable rnidx
        Separator .l1asc.ops.1.s3 -orient vertical -bg black -relief groove

        checkbutton .l1asc.ops.1.int -text "Intensity Data" -variable intensity

        checkbutton .l1asc.ops.1.soe -text "SOE" -variable soeindx
        Separator .l1asc.ops.1.s4 -orient vertical -bg black -relief groove

        checkbutton .l1asc.ops.1.header -text "Header" -variable hline
        Separator .l1asc.ops.1.s5 -orient vertical -bg black -relief groove

        Separator .l1asc.ops.2.s1 -orient vertical -bg black -relief groove

        label .l1asc.ops.2.dl -text "Delimiter: "
        ::mixin::combobox .l1asc.ops.2.d -textvariable delimit \
                -state readonly -values [list comma semicolon space] -width 10

        LabelEntry .l1asc.ops.2.split -width 7 -bd 3 \
                -label "Max number of lines/file" \
                -textvariable split \
                -helptext "Enter maximum number of lines in each file; enter 0\
                        to write all data in 1 file"

        Separator .l1asc.ops.2.s2 -orient vertical -bg black -relief groove
        checkbutton .l1asc.ops.2.zclip -text "Z Clipper:" -variable zclip \
                -command {
                    set state [lindex {disabled normal} $zclip]
                    .l1asc.ops.2.zmin configure -state $state
                    .l1asc.ops.2.zmax configure -state $state
                }
        LabelEntry .l1asc.ops.2.zmin -width 5 -bd 3 -label "Zmin" \
                -textvariable zmin -state disabled
        LabelEntry .l1asc.ops.2.zmax -width 5 -bd 3 -label "Zmax" \
                -textvariable zmax -state disabled

        pack .l1asc.ops.1.s0 .l1asc.ops.1.indx .l1asc.ops.1.s1 \
                .l1asc.ops.1.rn .l1asc.ops.1.s2 .l1asc.ops.1.int \
                .l1asc.ops.1.s3 .l1asc.ops.1.soe .l1asc.ops.1.s4 \
                .l1asc.ops.1.header .l1asc.ops.1.s5 \
                -side left -fill both -padx 3
        pack .l1asc.ops.2.dl .l1asc.ops.2.d .l1asc.ops.2.s1 \
                .l1asc.ops.2.split .l1asc.ops.2.s2 .l1asc.ops.2.zclip \
                .l1asc.ops.2.zmin .l1asc.ops.2.zmax \
                -side left -padx 3 -fill both
        pack .l1asc.ops.0 .l1asc.ops.1 .l1asc.ops.2 -side top

        Button .l1asc.cmd.cancel -text "Cancel" -width 5 -command {
            set write_some 0
            destroy .l1asc
        }
        Button .l1asc.cmd.dismiss -text "Dismiss" -width 5 -command {
            destroy .l1asc
        }
        pack .l1asc.cmd.cancel .l1asc.cmd.dismiss -side left -padx 5
        pack .l1asc.ops .l1asc.fn .l1asc.cmd -side top
    }
}

proc ::l1pro::deprecated::append2tile {} {
    uplevel #0 {
        set selection  [tk_messageBox  -icon question \
                -message "Append \'$pro_var\' array to final data array?" \
                -type yesno -title "Warning"]
        if {$selection == "yes"} {
            exp_send "grow, finaldata, $pro_var;\r"
            expect ">"
        }
    }
}

proc ::l1pro::deprecated::savetile {} {
    uplevel #0 {
        global tilefname initialpath

        if {[info exists initialpath] == 0} {set initialpath "~/"}
        exp_send "if (!curzone) curzone = 17;\
                tilefname = set_tile_filename(win=$win_no);\r"
        expect ">"
        if {[info exists tilefname] == 0} {
            set tilefname ""
        }
        set ofname [tk_getSaveFile -initialdir $initialpath \
                -defaultextension "*.pbd" \
                -initialfile $tilefname]
        if {$ofname != ""} {
            exp_send "$tilename = ifinaldata;\
                    vname=tilename;\
                    save, createb(\"$ofname\"), vname, $tilename;\r"
            expect ">"
        }
    }
}

proc ::l1pro::deprecated::datum_proc {} {
    global varlist datum_var pro_var
    destroy .con
    toplevel .con
    wm title .con "Convert data from w84 to n88..."

    frame .con.05

    Label .con.05.varname -text "Input Variable:"

    ::mixin::combobox .con.05.varlist \
            -textvariable ::datum_var -state readonly \
            -listvariable ::varlist
    set datum_var $pro_var

    Label .con.02 -text \
            "The converted variable is named n88_(currentvariablename)"
    Button .con.1 -width 8 -text "Go" \
            -command {
                set convar "n88_$datum_var"

                exp_send "$convar = datum_convert_data($datum_var);\r"
                expect ">"

                append_varlist $convar
            }

    pack .con.05.varname .con.05.varlist -side left -padx 5
    pack .con.05 .con.02 .con.1  -side top -pady 10
}

proc ::l1pro::deprecated::rbgga_menu {{mode eaarl}} {
    ### DEPRECATED 2009-02-02 ###
    # The rbgga_menu code has been superseded by plot.ytk. It is possible,
    # however, that some of the other code in this file may still be in
    # non-deprecated use.
    global ytk_PLMK_marker data_path _map _ytk utm rbgga_mode rbgga_file_mode
    set gga(null) ""
    set mw .rbgga
    set rbgga_mode $mode
    set rbgga_file_mode "eaarl"
    destroy $mw
    toplevel $mw
    if {[string equal $rbgga_mode "adapt"]} {
        wm title $mw "Vessel Tracks"
    } else {
        wm title $mw "eaarl.rbgga: "
    }
    frame $mw.g1 -relief groove -borderwidth 3
    label $mw.g1.lulb -text "Coordinates:" -anchor e
    tk_optionMenu $mw.g1.lu gga(llu) latlon utm
    grid $mw.g1.lulb $mw.g1.lu -sticky ew

    label $mw.g1.lwlb -text "Line Width:" -anchor e
    tk_optionMenu $mw.g1.lw gga(linewidth) 1 3 5 7 10 12 15 20 25
    grid $mw.g1.lwlb $mw.g1.lw -sticky ew

    label $mw.g1.lclb -text "Line Color:" -anchor e
    tk_optionMenu $mw.g1.lc gga(linecolor) red black blue green cyan magenta \
            yellow white
    grid $mw.g1.lclb $mw.g1.lc -sticky ew

    label $mw.g1.skiplb -text "Points to skip:" -anchor e
    tk_optionMenu $mw.g1.skip gga(skip) 0 1 2 5 10 15 20 25 50 75 100  
    grid $mw.g1.skiplb $mw.g1.skip -sticky ew

    # label $mw.g1.markerslb -text "Use Markers:" -anchor e
    # tk_optionMenu $mw.g1.markers gga(markers) Yes No
    # grid $mw.g1.markerslb $mw.g1.markers -sticky ew

    label $mw.g1.mshapelb -text "Marker shape:" -anchor e
    tk_optionMenu $mw.g1.mshape gga(mshape) None Square Cross \
            Triangle Circle Diamond Cross45 "Inverted-Triangle"
    grid $mw.g1.mshapelb $mw.g1.mshape -sticky ew

    label $mw.g1.msizelb -text "Marker size:" -anchor e
    tk_optionMenu $mw.g1.msize gga(msize) .1 .2 .3 .4 .5 \
        .6 .7 1.0 1.5 2.0 2.5 3.0 5.0 10.0 

    grid $mw.g1.msizelb $mw.g1.msize -sticky ew

    set _map(window) 6
    Label $mw.g1.owinlbl -text "in Win:"
    SpinBox $mw.g1.owin -justify center -range {0 63 1} \
            -width 2 -textvariable _map(window)

    grid $mw.g1.owinlbl $mw.g1.owin -sticky ew

    frame $mw.f1 -relief groove -borderwidth 3
    if {[string equal $rbgga_mode "adapt"]} {
        button $mw.f1.loadadf -text "Load ADF" -command { 
            if {$gga(llu) == "utm"} {
                set utm 1
            } else {
                set utm 0
            }
            exp_send "gga=open_vessel_track()\n"
            set rbgga_file_mode "adapt"
        }
    }
    button $mw.f1.load -text "Load PNAV" -command { 
        if {$gga(llu) == "utm"} {
            set utm 1
        } else {
            set utm 0
        }
        exp_send "pnav=rbpnav();\r" 
        set rbgga_file_mode "eaarl"
    }
    button $mw.f1.plot -text "Plot" -command {
        if { $gga(mshape) == "None" } {
            set marker ",marker=0";
        } else {
            set marker ",marker=$ytk_PLMK_marker($gga(mshape))"
        }
        if {$gga(llu) == "utm"} {
            set utm 1
        } else {
            set utm 0
        }
        if { [string equal $rbgga_file_mode "adapt"] } {
            exp_send "show_vessel_track, color=\"$gga(linecolor)\",\
                    skip=$gga(skip)$marker, msize=$gga(msize), utm=$utm,\
                    win=$_map(window), width=$gga(linewidth);\r" 
        } else {
            exp_send "show_gga_track, color=\"$gga(linecolor)\",\
                    skip=$gga(skip)$marker,msize=$gga(msize), utm=$utm,\
                    win=$_map(window), width=$gga(linewidth);\r" 
        }
        exp_send "utm= $utm;\r"
    }
    button $mw.f1.info -text "Info"
    button $mw.f1.fma -text "Fma" \
            -command {exp_send "window,$_map(window); fma\r"}
    button $mw.f1.jump -text "Jump" -command { 
        exp_send "wsav=current_window();window,$_map(window);\
                gga_click_start_isod()\r" 
        #tk_messageBox  -message "Click using left mouse button over a section
        #of a flightline in Yorick window-6."  -type ok
        expect "region_selected"
        exp_send "window_select,wsav\r"
    }
    button $mw.f1.limits -text "Limits" \
            -command {exp_send "window,$_map(window); limits\r"}
    button $mw.f1.dismiss -text "Dismiss" -command "destroy $mw"
    if {[string equal $rbgga_mode "eaarl"]} {
        pack $mw.f1.load $mw.f1.plot $mw.f1.info $mw.f1.limits \
                $mw.f1.fma $mw.f1.jump -side top -fill x
    } else {
        pack $mw.f1.loadadf $mw.f1.load $mw.f1.plot $mw.f1.limits \
                $mw.f1.fma $mw.f1.jump -side top -fill x
    }
    pack $mw.f1.dismiss -side bottom -anchor s -fill both

    frame $mw.f2 -relief groove -borderwidth 3
    label $mw.f2.title -text "Map controls"
    button $mw.f2.mapredraw  -text "Replot" -command {
        if {$gga(llu) == "utm"} {
            set utm 1
        } else {
            set utm 0
        }
        plot_last_map $utm 
    }
    button $mw.f2.mapload    -text "Load" -command {
        if {$gga(llu) == "utm"} {
            set utm 1
        } else {
            set utm 0
        }
        load_map $utm 
    }

    set w $mw.f2
    Button $w.overlay_grid -text "Overlay\nGrid" -command {
        exp_send "draw_grid, $_map(window)\r"
    }

    Button $w.show_grid -text "Show\nGrid Name" -command {
        exp_send "show_grid_location, $_map(window)\r"
    }

    pack $mw.f2.title -side top
    pack \
            $mw.f2.mapload \
            $mw.f2.mapredraw \
            $w.overlay_grid \
            $w.show_grid \
            -fill both -expand 1 -side left

    frame $mw.f3 -relief groove -borderwidth 3
    button $mw.f3.fpload -text "Load" -command {
        load_fp
    }
    label $mw.f3.title -text "Flight Plans"

    pack $mw.f3.title -side top
    pack $mw.f3.fpload -side left
    ### pack $mw.f3 -side bottom -anchor n -fill both -expand 1

    pack $mw.f3 -side bottom -expand 1 -fill both
    pack $mw.f2 -side bottom -expand 1 -fill both
    pack $mw.f1 $mw.g1 -side left -anchor n -fill both -expand 1

}

namespace eval ::l1pro::deprecated::rbgga {}

proc ::l1pro::deprecated::rbgga::request_heading {psf inhd_count sod} {
    ## this procedure requests heading information for sf_a.tcl
    ## amar nayegandhi
    global sf_pid
    set sf_pid $psf
    exp_send "pkt_sf = prepare_sf_pkt($sod, $psf);\r"
}

proc ::l1pro::deprecated::start_sf {} {
    global cir_id data_path
    exec ../attic/src/2010-07-sf_a.tcl -parent [::comm::comm self] \
            -cir $cir_id -path $data_path &
}

proc ::l1pro::deprecated::start_cir {} {
    global sf_a_id data_path
    exec ../attic/src/2010-07-cir.tcl -parent [::comm::comm self] \
            -sf $sf_a_id -path $data_path &
}

proc ::l1pro::deprecated::limits_tool {} {
    # Added by Jeremy Bracone 4/15/05
    # Opens a limits tool that makes a few functions a little quicker to perform.
    # The main function it provides is to set the limits from one window equal to
    # another.
    destroy .limitstool
    toplevel .limitstool
    wm title .limitstool "Limits Tool"
    frame .limitstool.1 -relief groove -bd 4
    label .limitstool.1.t1 -text "Apply limits from window "
    ::mixin::combobox .limitstool.1.c1 -text 0 -width 3 -state readonly \
            -values [::struct::list iota 64] \
            -takefocus 0
    label .limitstool.1.t2 -text " to window "
    ::mixin::combobox .limitstool.1.c2 -text 0 -width 3 -state readonly \
            -values [::struct::list iota 64] \
            -takefocus 0

    Button .limitstool.1.limits -text "Set Limits" \
            -helptext "Set Limits in window from box 2 equal to limits in\
                    \nwindow from box 1. i.e. Make the second window look like\
                    \nthe first." \
            -command {
                set window1 [.limitstool.1.c1 getvalue]
                set window2 [.limitstool.1.c2 getvalue]
                if {$window1 >= 0 && $window2 >= 0} {
                    #This function provided by l1pro.i
                    exp_send "copy_limits, $window1, $window2;\r"
                }
            }

    frame .limitstool.2
    Button .limitstool.2.l -text "Limits()" \
        -helptext "Set current window limits to view entire plot" \
        -command {
            exp_send "limits\r"
            expect ">"
        }
    Button .limitstool.2.dismiss -text "Dismiss" -command {destroy .limitstool}
    pack .limitstool.1 -side top
    pack .limitstool.1.t1 .limitstool.1.c1 .limitstool.1.t2 .limitstool.1.c2 \
            .limitstool.1.limits -side left
    pack .limitstool.2 -side right
    pack .limitstool.2.dismiss .limitstool.2.l -padx 4 -side right
}

namespace eval ::l1pro::deprecated::rollbias {
    namespace eval v {
        variable top .l1wid.rollbias
        variable active 0
        variable var fs_all
        variable winsrc 5
        variable width 5
        variable bias 0
        variable slope 0
        variable windst 0
        variable inout 1
    }

    proc gui {} {
        source [file join $::src_path attic src 2012-03-qaqc_fns.i]
        source [file join $::src_path attic src 2012-03-determine_bias.i]

        set ns [namespace current]
        set v::var $::pro_var
        set v::winsrc $::win_no
        ybkg updatebias

        set w $v::top
        destroy $w
        toplevel $w
        wm title $w "Determine Roll Bias"

        ttk::frame $w.f
        grid $w.f -sticky news
        grid columnconfigure $w 0 -weight 1
        grid rowconfigure $w 0 -weight 1

        foreach x {1 2 3} {
            grid [ttk::frame $w.row$x] -in $w.f -sticky news
        }

        set f $w

        ttk::label $f.lblvar -text "Variable:"
        ttk::entry $f.var -width 5 -textvariable ${ns}::v::var
        ttk::label $f.lblwinsrc -text "in window:"
        ttk::spinbox $f.winsrc -width 2 \
                -from 0 -to 63 -increment 1 \
                -textvariable ${ns}::v::winsrc
        ttk::label $f.lbltrans -text "Then click"
        ttk::button $f.trans -text "Get Transect" -command ${ns}::transect
        ttk::button $f.help -text "Help" -command ${ns}::help

        ::tooltip::tooltip $f.var "EAARL source data"

        grid $f.lblvar $f.var $f.lblwinsrc $f.winsrc $f.lbltrans $f.trans \
                $f.help -in $w.row1 -sticky news -padx 1 -pady 1
        grid columnconfigure $w.row1 1 -weight 1

        ttk::label $f.lblwidth -text "Width:"
        ttk::spinbox $f.width -width 4 \
                -from 0 -to 10000 -increment 1 \
                -textvariable ${ns}::v::width
        ttk::label $f.lblbias -text "Current Roll Bias:"
        ttk::entry $f.bias -width 8 -textvariable ${ns}::v::bias
        ttk::label $f.lblslope -text "Current slope"
        ttk::entry $f.slope -width 8 -textvariable ${ns}::v::slope

        ::tooltip::tooltip $f.width "Transect width"

        $f.bias state readonly
        $f.slope state readonly

        grid $f.lblwidth $f.width $f.lblbias $f.bias $f.lblslope $f.slope \
                -in $w.row2 -sticky news -padx 1 -pady 1
        grid columnconfigure $w.row2 {3 5} -weight 1

        ttk::button $f.plot -text "Plot" -command ${ns}::plot
        ttk::label $f.lblwindst -text "in win:"
        ttk::spinbox $f.windst -width 2 \
                -from 0 -to 63 -increment 1 \
                -textvariable ${ns}::v::windst
        ttk::button $f.selflt -text "Select Flightlines" \
                -command ${ns}::select_flightlines
        ttk::checkbutton $f.inout -text "into screen:" \
                -variable ${ns}::v::inout \
                -onvalue 1 -offvalue -1
        ttk::button $f.determine -text "Determine Bias" \
                -command ${ns}::determine_bias
        grid columnconfigure $w.row3 {0 2} -weight 1
        grid columnconfigure $w.row3 {3 5} -weight 2

        ::tooltip::tooltip $f.plot "Plot flightline transect"

        grid $f.plot $f.lblwindst $f.windst $f.selflt $f.inout $f.determine \
                -in $w.row3 -sticky news -padx 1 -pady 1

        foreach widget [grid slaves $w.row3] {
            if {[winfo class $widget] eq "Spinbox"} {
                set map {0 disabled 1 normal}
            } else {
                set map {0 disabled 1 !disabled}
            }
            ::mixin::statevar $widget \
                    -statemap $map \
                    -statevariable ${ns}::v::active
        }
    }

    proc transect {} {
        exp_send "transdata = get_transect($v::var, win=$v::winsrc, update=1,\
                width=$v::width);\r"
        set v::active 1
    }

    proc help {} {
        set w $v::top.help
        destroy $w
        toplevel $w
        wm title $w "Help: Determine Roll Bias"

        ttk::frame $w.f
        grid $w.f -sticky news
        grid columnconfigure $w 0 -weight 1
        grid rowconfigure $w 0 -weight 1

        ttk::scrollbar $w.sb -command [list $w.doc yview]
        ::mixin::text::readonly $w.doc -height 20 -width 65 \
                -yscrollcommand [list $w.sb set]
        grid $w.doc $w.sb -sticky news -in $w.f
        grid columnconfigure $w.f 0 -weight 1
        grid rowconfigure $w.f 0 -weight 1

        $w.doc ins end \
                "1.\tStart with point data plotted in a window and raw EAARL\
                data loaded. Set the variable and window and click \"Get\
                Transect\".\
                \n2.\tDrag a line perpendicular to the flightlines you wish to\
                examine.  In the window that appears, zoom into the top, type\
                something, and hit enter. Now drag a box over the section of\
                the transect you wish to keep.\
                \n3.\tClick the \"Plot\" button to display the loaded transect.\
                In order to determine the bias automatically all flightlines\
                must be traveling the same direction, so you'll need to remove\
                whichever direction is the minority.\
                \n4.\tClick \"Select Flightlines\" and simply type \"y\" or\
                \"n\" to keep or remove each flightline. Now you have a set of\
                flightlines going the same direction.\
                \n5.\tDetermine whether the flightlines are going into or out\
                of the screen. If they are going INTO the screen, check the\
                \"into screen\" box. If they are going OUT OF the screen,\
                uncheck the \"into screen\" box.\
                \n6.\tClick \"Determine bias\"." \
                formatted

        $w.doc tag configure formatted \
                -lmargin2 20 -spacing3 5 -tabs "20 left" -wrap word
    }

    proc plot {} {
        exp_send "plot_flightline_transect, transdata, $v::windst;\r"
    }

    proc select_flightlines {} {
        exp_send "transdata = selgoodflightlines(transdata, win=$v::windst);\r"
    }

    proc determine_bias {} {
        exp_send "goodroll = find_roll_bias(transdata, 0, $v::inout,\
                update=1);\r"
    }
}
