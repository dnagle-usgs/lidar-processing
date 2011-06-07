# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::asciixyz 1.0
package require struct::list
package require getstring
package require snit

namespace eval l1pro::asciixyz {
    namespace eval v {
        variable top .l1wid.asciixyz
        variable mappings {
            (ignore)
            east north elevation
            "east (first)" "north (first)" "elevation (first)"
            "east (last)" "north (last)" "elevation (last)"
            "east (mirror)" "north (mirror)" "elevation (mirror)"
            depth
            intensity "intensity (first)" "intensity (last)"
            soe hhmmss hh:mm:ss yyyymmdd yyyy-mm-dd yyyy/mm/dd
            "raster/pulse"
        }
    }
}

proc ::l1pro::asciixyz::launch {} {
    ::l1pro::asciixyz::gui .%AUTO%
}

snit::widget ::l1pro::asciixyz::gui {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    component sample
    component preview

    variable delim " "
    variable delim_custom {}
    variable filename {}
    variable header 0
    variable columns 3
    variable struct VEG__
    variable latlon 0

    variable vname {}
    variable destfn {}
    variable srcdir {}
    variable outdir {}
    variable useoutdir 0
    variable searchstr {}
    variable vprefix {}
    variable vsuffix {}
    variable update 0

    typevariable lastvals {}
    typevariable lastvars {delim delim_custom header columns struct latlon}

    constructor args {
        $self configurelist $args
        wm title $win "ASCII import"
        wm geometry $win 600x600
        wm protocol $win WM_DELETE_WINDOW [mymethod dismiss]

        ttk::frame $win.f
        grid $win.f -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        set w $win.f

        ttk::label $w.srclbl -text "Source:"
        ttk::entry $w.src -width 0 -state readonly \
                -textvariable [myvar filename]
        ttk::button $w.srcbrowse -text "Browse..." \
                -command [mymethod select_file]

        ttk::label $w.structlbl -text "Structure:"
        ::mixin::combobox $w.struct \
                -state readonly \
                -textvariable [myvar struct] \
                -values [list VEG__ FS GEO]

        ttk::label $w.delimlbl -text "Delimiter:"
        ttk::radiobutton $w.delimspace -text "Space" \
                -variable [myvar delim] -value " " \
                -command [mymethod reload_preview_data]
        ttk::radiobutton $w.delimcomma -text ", (comma)" \
                -variable [myvar delim] -value , \
                -command [mymethod reload_preview_data]
        ttk::radiobutton $w.delimtab -text "Tab" \
                -variable [myvar delim] -value "\\t" \
                -command [mymethod reload_preview_data]
        ttk::radiobutton $w.delimother -text "Other:" \
                -variable [myvar delim] -value OTHER \
                -command [mymethod reload_preview_data]
        ttk::entry $w.delimcustom -width 0 \
                -textvariable [myvar delim_custom] \
                -validate focusout \
                -validatecommand [mymethod reload_preview_data]

        ttk::checkbutton $w.latlon -text "Coordinates are lat/lon" \
                -variable [myvar latlon]

        ttk::label $w.headerlbl -text "Header lines:"
        ttk::spinbox $w.header \
                -textvariable [myvar header] \
                -width 4 \
                -from 0 -to 1000 -increment 1 \
                -command [mymethod reload_preview_data]

        ttk::label $w.columnlbl -text "Columns:"
        ttk::spinbox $w.column \
                -width 4 \
                -from 1 -to 1000 -increment 1 -text 3 \
                -textvariable [myvar columns] \
                -command [list $w.preview configure -columncount %s]

        ttk::label $w.previewlbl -text \
                "Preview of import (click on column headings to re-assign):"
        preview $w.preview
        ttk::label $w.samplelbl -text "Sample from file:"
        sample $w.sample

        set nb $w.actions
        ttk::notebook $nb
        $nb add [$self build_pane_import $nb.import] -text "Import"
        $nb add [$self build_pane_convert $nb.convert] -text "Convert"
        $nb add [$self build_pane_batch $nb.batch] -text "Batch Convert"

        lower [ttk::frame $w.f1]
        grid $w.srclbl $w.src $w.srcbrowse -sticky ew -in $w.f1 -padx 2
        grid columnconfigure $w.f1 1 -weight 1

        lower [ttk::frame $w.f2]
        grid $w.delimlbl $w.delimspace x $w.delimcomma x $w.delimtab x \
                $w.delimother $w.delimcustom -sticky ew -in $w.f2 -padx 2
        grid columnconfigure $w.f2 8 -weight 1
        grid columnconfigure $w.f2 {2 4 6} -minsize 3

        lower [ttk::frame $w.f3]
        grid $w.structlbl $w.struct x $w.latlon \
                -in $w.f3 -sticky ew -padx 2
        grid columnconfigure $w.f3 1 -weight 1 -uniform 1
        grid columnconfigure $w.f3 2 -minsize 5

        grid $w.f1 - - - -sticky ew -pady 2
        grid $w.columnlbl $w.column x $w.f2 -sticky ew -pady 2
        grid $w.headerlbl $w.header x $w.f3 -sticky ew -pady 2
        grid $w.previewlbl - - - -sticky w -pady 2 -padx 2
        grid $w.preview - - - -sticky news -pady 2 -padx 2
        grid $w.samplelbl - - - -sticky w -pady 2 -padx 2
        grid $w.sample - - - -sticky news -pady 2 -padx 2
        grid $w.actions - - - -sticky ew -pady 2 -padx 2

        grid $w.columnlbl $w.headerlbl -sticky e -padx 2

        grid columnconfigure $w 3 -weight 1
        grid columnconfigure $w 2 -minsize 5
        grid rowconfigure $w {4 6} -weight 1 -uniform 1

        $w.preview configure -mappings $::l1pro::asciixyz::v::mappings

        $w.preview configure -columncount 3
        $w.column set 3

        set preview $w.preview
        set sample $w.sample

        if {[llength $lastvals]} {
            foreach var $lastvars {
                set $var [dict get $lastvals $var]
            }
            $preview configure \
                    -columnmappings [dict get $lastvals columnmapping]
        }
    }

    method build_pane_import w {
        ttk::frame $w

        ttk::frame $w.f1
        ttk::label $w.vnamelbl -text "Variable name:"
        ttk::entry $w.vname -textvariable [myvar vname]
        grid $w.vnamelbl $w.vname -in $w.f1 -sticky ew -padx 2 -pady 2
        grid columnconfigure $w.f1 1 -weight 1

        ttk::frame $w.f2
        ttk::button $w.load -text "Load" -command [mymethod do_import]
        ttk::button $w.dismiss -text "Dismiss" -command [mymethod dismiss]
        grid x $w.load $w.dismiss x -in $w.f2 -sticky ew -padx 2 -pady 2
        grid columnconfigure $w.f2 {0 3} -weight 1

        grid $w.f1 -sticky ew
        grid $w.f2 -sticky ew
        grid columnconfigure $w 0 -weight 1

        return $w
    }

    method build_pane_convert w {
        ttk::frame $w

        ttk::label $w.vnamelbl -text "Variable name:"
        ttk::entry $w.vname -textvariable [myvar vname]

        ttk::label $w.filelbl -text "Destination:"
        ttk::entry $w.file -state readonly -textvariable [myvar destfn]
        ttk::button $w.filebrowse -text "Browse..." \
                -command [mymethod select_destfn]

        ttk::frame $w.btns
        ttk::button $w.convert -text "Convert" -command [mymethod do_convert]
        ttk::button $w.dismiss -text "Dismiss" -command [mymethod dismiss]
        grid x $w.convert $w.dismiss x -in $w.btns -sticky ew -padx 2
        grid columnconfigure $w.btns {0 3} -weight 1

        grid $w.vnamelbl $w.vname - -sticky ew -padx 2 -pady 2
        grid $w.filelbl $w.file $w.filebrowse -sticky ew -padx 2 -pady 2
        grid $w.btns - - -sticky ew -pady 2
        grid columnconfigure $w 1 -weight 1

        grid configure $w.vnamelbl $w.filelbl -sticky e

        return $w
    }

    method build_pane_batch w {
        ttk::frame $w

        ttk::frame $w.indirf
        ttk::label $w.indirlbl -text "Source directory:"
        ttk::entry $w.indir -state readonly -textvariable [myvar srcdir]
        ttk::button $w.indirbrowse -text "Browse..." \
                -command [mymethod select_dir srcdir]
        grid $w.indir $w.indirbrowse -in $w.indirf -sticky ew -padx 2
        grid columnconfigure $w.indirf 0 -weight 1

        ttk::frame $w.outdirf
        ttk::checkbutton $w.outdirchk -text "Output directory:" \
                -variable [myvar useoutdir]
        ttk::entry $w.outdir -state readonly -textvariable [myvar outdir]
        ttk::button $w.outdirbrowse -text "Browse..." \
                -command [mymethod select_dir outdir]
        grid $w.outdir $w.outdirbrowse -in $w.outdirf -sticky ew -padx 2
        grid columnconfigure $w.outdirf 0 -weight 1

        ::mixin::statevar $w.outdir \
                -statemap {0 disabled 1 readonly} \
                -statevariable [myvar useoutdir]
        ::mixin::statevar $w.outdirbrowse \
                -statemap {0 disabled 1 normal} \
                -statevariable [myvar useoutdir]

        ttk::label $w.sslbl -text "Search string:"
        ttk::entry $w.ss -textvariable [myvar searchstr]

        ttk::checkbutton $w.update -text "Skip existing files" \
                -variable [myvar update]

        ttk::label $w.vlbl -text "Variable names:"
        ttk::entry $w.vprefix -textvariable [myvar vprefix]
        ttk::label $w.vmid -text "(tile/file)"
        ttk::entry $w.vsuffix -textvariable [myvar vsuffix]

        ttk::frame $w.btns
        ttk::button $w.convert -text "Batch convert" \
                -command [mymethod do_batch_convert]
        ttk::button $w.dismiss -text "Dismiss" -command [mymethod dismiss]
        grid x $w.convert $w.dismiss x -in $w.btns -sticky ew -padx 2 -pady 2
        grid columnconfigure $w.btns {0 3} -weight 1

        grid $w.indirlbl  $w.indirf      -           -
        grid $w.outdirchk $w.outdirf     -           -
        grid $w.sslbl     $w.ss          $w.update   -
        grid $w.vlbl      $w.vprefix     $w.vmid     $w.vsuffix
        grid $w.btns      -              -           -

        grid $w.indirlbl $w.outdirchk $w.sslbl $w.vlbl $w.vmid $w.update \
                -sticky e -padx 2 -pady 2
        grid $w.indirf $w.outdirf \
                -sticky ew -pady 2
        grid $w.ss $w.vprefix $w.vsuffix \
                -sticky ew -padx 2 -pady 2
        grid columnconfigure $w {1 3} -weight 1
        grid rowconfigure $w {0 1 2 3} -uniform 1

        ::tooltip::tooltip $w.vprefix \
                "This field provides a prefix that will be prepended to each\
                \nfile's variable name."
        ::tooltip::tooltip $w.vmid \
                "Each file will receive a variable name derived from the\
                \nfile's name. If possible, that name will be a clean form of\
                \nthe tile name encoded in the filename. Otherwise, the\
                \nfilename without its extension is used."
        ::tooltip::tooltip $w.vsuffix \
                "This field provides a suffix that will be appended to each\
                \nfile's variable name."

        return $w
    }

    method select_file {} {
        if {$filename eq ""} {
            set base $::data_file_path
        } else {
            set base [file dirname $filename]
        }

        set temp [tk_getOpenFile -initialdir $base \
                -parent $win -title "Select ASCII file" \
                -filetypes {{"ASCII files" {.txt .asc .xyz}} {"All files" *}}]

        if {$temp ne ""} {
            set filename $temp
            $self load_sample
        }
    }

    method load_sample {} {
        if {
            $filename eq "" || ![file isfile $filename] \
                    || ![file readable $filename]
        } {
            return
        }
        set fh [open $filename]
        set data [read $fh 10000]
        close $fh
        set lines [lrange [split $data \n] 0 end-1]
        $sample configure -text [join $lines \n]
        $self reload_preview_data
    }

    method reload_preview_data {} {
        set delimiter [$self delimiter]
        if {$delimiter eq ""} {
            $preview configure -sample {}
            return 1
        }
        set data [list]
        set lines [lrange [split [$sample cget -text] \n] $header end]
        set maxsize 0
        foreach line $lines {
            set fields [split $line $delimiter]
            lappend data $fields
            if {[llength $fields] > $maxsize} {
                set maxsize [llength $fields]
            }
        }
        $preview configure -sample $data
        if {$maxsize > [$preview cget -columncount]} {
            $preview configure -columncount $maxsize
            set columns $maxsize
        }
        return 1
    }

    method delimiter {} {
        if {$delim eq "OTHER"} {
            return $delim_custom
        } else {
            return $delim
        }
    }

    method build_args {} {
        set cmd ""
        append cmd "delimit=\"[$self delimiter]\""
        append cmd ", header=$header"
        if {$latlon} {
            append cmd ", latlon=1"
        }

        set cols [list]
        foreach col [$preview cget -columnmappings] {
            lappend cols \"$col\"
        }
        append cmd ", columns=\[[join $cols ,]\]"

        return $cmd
    }

    method do_import {} {
        set cmd "$vname = read_ascii_xyz(\"$filename\", $struct"
        append cmd ", [$self build_args])"
        exp_send "$cmd\r"
        append_varlist $vname
        set ::pro_var $vname
        $self dismiss
    }

    method do_convert {} {
        set cmd "pbd_save, \"$destfn\", \"$vname\""
        append cmd ", read_ascii_xyz(\"$filename\", $struct"
        append cmd ", [$self build_args])"
        exp_send "$cmd\r"
        $self dismiss
    }

    method do_batch_convert {} {
        set appendif ::l1pro::tools::appendif
        set cmd "batch_convert_ascii2pbd, \"$srcdir\", $struct"
        $appendif cmd \
            $useoutdir           ", outdir=\"$outdir\"" \
            1                    ", ss=\"$searchstr\"" \
            $update              ", update=1" \
            {$vprefix ne ""}     ", vprefix=\"$vprefix\"" \
            {$vsuffix ne ""}     ", vsuffix=\"$vsuffix\""
        append cmd ", [$self build_args]"
        exp_send "$cmd\r"
        $self dismiss
    }

    method select_destfn {} {
        if {$destfn eq ""} {
            set base [file dirname $filename]
        } else {
            set base [file dirname $destfn]
        }
        set temp [tk_getSaveFile -initialdir $base \
                -parent $win -title "Select destination" \
                -filetypes {{"ALPS PBD files" {.pbd .pdb}} {"All files" *}}]
        if {$temp ne ""} {
            set destfn $temp
        }
    }

    method select_dir which {
        if {$which eq ""} {
            set base [set $which]
        } else {
            set base [file dirname $filename]
        }
        set temp [tk_chooseDirectory -initialdir $base -parent $win]
        if {$temp ne ""} {
            set $which $temp
        }
    }

    method dismiss {} {
        foreach var $lastvars {
            dict set lastvals $var [set $var]
        }
        dict set lastvals columnmapping [$preview cget -columnmappings]
        destroy $win
    }
}

snit::widgetadaptor ::l1pro::asciixyz::sample {
    delegate method * to text
    delegate option * to text

    option -text -default {} -configuremethod {Update text}

    component text
    component vsb
    component hsb

    constructor args {
        installhull using ttk::frame

        install text using ::mixin::text::readonly $win.text
        install vsb using ttk::scrollbar $win.vsb -orient vertical
        install hsb using ttk::scrollbar $win.hsb -orient horizontal
        grid $text $vsb -sticky news
        grid $hsb x -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        $text configure -height 10 -wrap none \
                -xscrollcommand [list $hsb set] \
                -yscrollcommand [list $vsb set]
        $hsb configure -command [list $text xview]
        $vsb configure -command [list $text yview]

        $self configurelist $args
    }

    method {Update text} {option value} {
        set options($option) $value
        $text del 1.0 end
        $text ins 1.0 $value
    }
}

snit::widgetadaptor ::l1pro::asciixyz::preview {
    delegate method * to tree
    delegate option * to tree

    component tree
    component vsb
    component hsb

    option -sample -default {} -configuremethod {Update sample}
    option -columncount -default 0 -configuremethod {Update columns}
    option -mappings -default {}
    option -columnmappings -default {} \
            -configuremethod {Update mappings} \
            -cgetmethod {Get mappings}

    variable mouse {10 10}

    constructor args {
        installhull using ttk::frame

        install tree using ttk::treeview $win.tree \
                -show headings -selectmode none
        install vsb using ttk::scrollbar $win.vsb -orient vertical
        install hsb using ttk::scrollbar $win.hsb -orient horizontal
        grid $tree $vsb -sticky news
        grid $hsb x -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        $tree configure -height 10 \
                -xscrollcommand [list $hsb set] \
                -yscrollcommand [list $vsb set]
        $hsb configure -command [list $tree xview]
        $vsb configure -command [list $tree yview]

        $self configurelist $args
        bind $tree <Motion> [list set [myvar mouse] [list %X %Y]]
    }

    method {Update sample} {option value} {
        set options($option) $value
        foreach child [$self children {}] {
            $self delete $child
        }
        foreach row $value {
            $self insert {} end -values $row
        }
    }

    method {Update columns} {option value} {
        set options($option) $value
        set fullwidth [winfo width $tree]
        set cols [::struct::list iota $value]
        $self configure -displaycolumns #all
        $self configure -columns $cols
        $self configure -displaycolumns $cols
        set leftover $fullwidth
        foreach col $cols {
            $self heading $col -command [mymethod Popup $col]
            if {[$self heading $col -text] eq ""} {
                $self heading $col -text "(ignore)"
            }
        }
        $self autosize
    }

    method autosize {} {
        set weights {}
        set sum 0
        set cols [::struct::list iota $options(-columncount)]
        foreach row $options(-sample) {
            foreach col $cols {
                dict incr weights $col [string length [lindex $row $col]]
                incr sum [string length [lindex $row $col]]
            }
        }

        if {[llength $weights]} {
            foreach col $cols {
                lappend weighted [list [dict get $weights $col] $col]
            }
        } else {
            foreach col $cols {
                lappend weighted [list 1 $col]
                incr sum 1
            }
        }
        if {$sum < 1} {
            set sum 1
        }
        set weighted [lsort -integer -index 0 $weighted]

        set minwidth 50
        set remaining [winfo width $tree]
        set weightleft $sum
        foreach pair $weighted {
            lassign $pair wt col
            set width [expr {$remaining * $wt / $weightleft}]
            if {$width < $minwidth} {
                set width $minwidth
            }
            $self column $col -width $width -minwidth $minwidth -stretch 1
            incr remaining -$width
            incr weightleft -$wt
        }
    }

    method Popup col {
        variable mouse
        set mb $self.mb
        destroy $mb
        menu $mb
        foreach item [$self cget -mappings] {
            $mb add command -label $item \
                    -command [list $self heading $col -text $item]
        }
        set idx [lsearch [$self cget -mappings] [$self heading $col -text]]
        if {$idx > -1} {
            tk_popup $mb [lindex $mouse 0] [lindex $mouse 1] $idx
        } else {
            tk_popup $mb [lindex $mouse 0] [lindex $mouse 1]
        }
    }

    method {Update mappings} {option value} {
        $self configure -columncount [llength $value]
        foreach col [$self cget -columns] {
            $self heading $col -text [lindex $value $col]
        }
    }

    method {Get mappings} option {
        set result [list]
        foreach col [$self cget -columns] {
            lappend result [$self heading $col -text]
        }
        return $result
    }
}
