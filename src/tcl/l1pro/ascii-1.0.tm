# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::ascii 1.0
package require l1pro::asciixyz
package require struct::list
package require getstring
package require snit
package require huddle
package require struct::matrix
package require json
package require misc

namespace eval l1pro::ascii {
    namespace import ::l1pro::asciixyz::sample
    namespace import ::misc::tooltip
    namespace eval v {
        variable top .l1wid.ascii
    }
}

proc ::l1pro::ascii::launch {} {
    ::l1pro::ascii::gui .%AUTO%
}

snit::widget ::l1pro::ascii::gui {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    component sample -public sample
    component preview -public preview

    option -filename {}
    # width > marker > delim
    # delim marker width
    option -column_detect delim
    option -delim " "
    option -delim_custom {}
    option -type 0
    option -group array
    option -ncols 0
    option -nskip 0
    option -width 0
    option -comment {#}
    option -missing 0.0
    option -select_cols 0
    option -selected_cols {}
    option -vname {}

    option -nlines 0

    typevariable settings_track {
        -column_detect -delim -delim_custom -type -group -ncols -nskip -width
        -comment -missing -select_cols -selected_cols
    }
    typevariable settings_stored {}

    method settings_save {} {
        set settings_stored [list]
        foreach key $settings_track {
            lappend settings_stored $key $options($key)
        }
    }

    method settings_restore {} {
        array set options $settings_stored
    }

    typevariable samplesize 10240

    constructor args {
        $self configurelist $args
        wm title $win "ASCII import"
        wm geometry $win 600x600

        ttk::frame $win.f
        grid $win.f -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        set w $win.f

        ttk::label $w.srclbl -text "Source:"
        ttk::entry $w.srcent -width 0 -state readonly \
                -textvariable [myvar options](-filename)
        ttk::button $w.srcbrowse -text "Browse..." \
                -command [mymethod select_file]

        lower [ttk::frame $w.src]
        grid $w.srclbl $w.srcent $w.srcbrowse \
                -sticky ew -in $w.src -padx 2
        grid columnconfigure $w.src 1 -weight 1

        ttk::label $w.detectlbl -text "Detect columns using:"
        ::mixin::combobox::mapping $w.detectcbo \
                -state readonly \
                -altvariable [myvar options](-column_detect) \
                -mapping {
                    "Delimiter (collapse contiguous)"   delim
                    "Delimiter (split contiguous)"      marker
                    "Fixed width"                       width
                } \
                -modifycmd [mymethod reload_preview_data]

        tooltip $w.detectlbl $w.detectcbo \
                "This setting controls how columns are detected.

                \"Delimiter (collapse contiguous)\": This option expects that
                columns are delimited by a particular character or set of
                characters and that any number of such characters will occur
                between columns. A typical example is a whitespace delimited
                file where columns are lined up using extra spaces.

                \"Delimiter (split contiguous)\": This option also expects that
                columns are delimited by a particular character. However, each
                instance of the character delimits a column. If there are
                several characters in a row, they denote empty columns. A
                typical example is a comma-delimited file.

                \"Fixed width\": This option expects that each column has a
                fixed width. In many cases, you can use the first option to
                handle such data. However, if some of the columns contain the
                character that would be otherwise used for delimiting, you can
                use this option instead."

        lower [ttk::frame $w.detect]
        grid $w.detectlbl $w.detectcbo \
                -sticky ew -in $w.detect -padx 2
        grid columnconfigure $w.detect 1 -weight 1

        ttk::label $w.delimlbl -text "Delimiter:"
        ttk::radiobutton $w.delimspace -text "Space" \
                -variable [myvar options](-delim) -value " " \
                -command [mymethod reload_preview_data]
        ttk::radiobutton $w.delimcomma -text ", (comma)" \
                -variable [myvar options](-delim) -value , \
                -command [mymethod reload_preview_data]
        ttk::radiobutton $w.delimtab -text "Tab" \
                -variable [myvar options](-delim) -value "\\t" \
                -command [mymethod reload_preview_data]
        ttk::radiobutton $w.delimother -text "Other:" \
                -variable [myvar options](-delim) -value OTHER \
                -command [mymethod reload_preview_data]
        ttk::entry $w.delimcustom -width 0 \
                -textvariable [myvar options](-delim_custom) \
                -validate focusout \
                -validatecommand [mymethod reload_preview_data]

        foreach item {lbl space comma tab other custom} {
            ::mixin::statevar $w.delim$item \
                    -statemap {delim normal marker normal width disabled} \
                    -statevariable [myvar options](-column_detect)
            tooltip $w.delim$item \
                    "Specify the delimiter to use. These options are only
                    enabled if \"Detect columns using:\" is set to one of the
                    two \"Delimiter\" options.

                    The first three radio buttons provide commonly-used
                    delimiter values for easy-click use: space, comma, and tab.

                    The final radio button allows you to specify a custom
                    delimiter or delimiters."
        }

        lower [ttk::frame $w.delim]
        grid $w.delimlbl $w.delimspace x $w.delimcomma x $w.delimtab x \
                $w.delimother $w.delimcustom -sticky ew -in $w.delim -padx 2
        grid columnconfigure $w.delim 8 -weight 1
        grid columnconfigure $w.delim {2 4 6} -minsize 3

        ttk::label $w.typelbl -text "Value type:"
        ::mixin::combobox::mapping $w.type \
                -width 0 \
                -state readonly \
                -altvariable [myvar options](-type) \
                -mapping {
                    auto        0
                    string      1
                    integer     2
                    real        3
                    numeric     4
                } \
                -modifycmd [mymethod reload_preview_data]
        tooltip $w.type $w.typelbl \
                "Specify how to interpret column values.

                \"auto\": Automatically determine whether a column contains
                string values, integer values, or real values.  Any presence of
                something non-numerical will result in a string column.  Any
                presence of a floating-point value in a non-string column will
                result in a real column.  Otherwise, it will be an integer
                value. Depending on what you have selected for \"Result:\",
                each column may end up with a different type.

                \"string\", \"integer\", \"real\": Coerces all values to the
                type specified. If a field cannot be coerced, then it is given
                the \"Missing field value:\".

                \"numeric\": Coerces all values into either integers or reals.
                Depending on the \"Result:\" setting, some columns may end up
                with different types."

        ttk::label $w.resultlbl -text "Result:"
        ::mixin::combobox $w.result \
                -width 0 \
                -state readonly \
                -textvariable [myvar options](-group) \
                -values [list array pointers group] \
                -modifycmd [mymethod reload_preview_data]
        tooltip $w.resultlbl $w.result \
                "Specify what kind of result should be yielded.

                \"array\": Yield a two-dimensional array. Since an array can
                only be of a single type, this interacts with the \"Value
                type:\" setting as follows. If any column contains strings,
                then all columns are interepreted as strings; otherwise if any
                column contains reals, then all columns are interpreted as
                reals; otherwise all columns are interpreted as integers.

                \"pointers\": Yield an array of pointers. Each pointer will
                point to an array for a column. Columns may have different
                types.

                \"group\": Yield an oxy group object. Each column will be
                stored anonymously in the group. Columns may have different
                types."

        ttk::label $w.columnlbl -text "Columns:"
        ttk::spinbox $w.column \
                -textvariable [myvar options](-ncols) \
                -width 4 \
                -from 0 -to 1000 -increment 1 \
                -command [mymethod reload_preview_data]
        tooltip $w.columnlbl $w.column \
                "Specify how many columns exist in the file. If you leave this
                set to 0, the column count will be automatically determined."

        ttk::label $w.headerlbl -text "Header lines:"
        ttk::spinbox $w.header \
                -textvariable [myvar options](-nskip) \
                -width 4 \
                -from 0 -to 1000 -increment 1 \
                -command [mymethod reload_preview_data]
        tooltip $w.headerlbl $w.header \
                "Specify how many lines at the top of the file are \"header
                lines\". This many lines will be skipped before starting to
                read column data."

        ttk::label $w.widthlbl -text "Column width(s):"
        ttk::entry $w.width -width 0 \
                -textvariable [myvar options](-width) \
                -validate focusout \
                -validatecommand [mymethod reload_preview_data]
        foreach widget [list $w.widthlbl $w.width] {
            ::mixin::statevar $widget \
                    -statemap {delim disabled marker disabled width normal} \
                    -statevariable [myvar options](-column_detect)
        }
        tooltip $w.widthlbl $w.width \
                "Specify the width or widths of the columns. This option is
                only available when \"Detect columns using:\" is set to \"Fixed
                width\". You may provide a single integer value if all columns
                are of the same width. If columns have different widths, you
                can provide a list of integer values separated by commas."

        ttk::label $w.commentlbl -text "Comment characters:"
        ttk::entry $w.comment -width 0 \
                -textvariable [myvar options](-comment) \
                -validate focusout \
                -validatecommand [mymethod reload_preview_data]
        tooltip $w.commentlbl $w.comment \
                "Specify the comment character. Any line whose first non-blank
                character starts with this will be disregarded as a column.
                (Note that a completely blank line is always disregarded as
                well.)"

        ttk::label $w.missinglbl -text "Missing field value:"
        ttk::entry $w.missing -width 0 \
                -textvariable [myvar options](-missing) \
                -validate focusout \
                -validatecommand [mymethod reload_preview_data]
        tooltip $w.missinglbl $w.missing \
                "Specifies the value to use for fields that are missing a
                value."

        ttk::checkbutton $w.selcol -text "Select columns:" \
                -variable [myvar options](-select_cols) \
                -command [mymethod reload_preview_data]
        ttk::entry $w.selcolval -width 0 \
                -textvariable [myvar options](-selected_cols) \
                -validate focusout \
                -validatecommand [mymethod reload_preview_data]
        tooltip $w.selcol $w.selcolval \
                "If enabled, then only the selected columns of the source data
                will be yielded in the result. This should be provided as a
                list of integer values separated by commas.  1 corresponds to
                the first column, 2 to the second, and so forth."

        ::mixin::statevar $w.selcolval \
                -statemap {0 disabled 1 normal} \
                -statevariable [myvar options](-select_cols)

        ttk::label $w.vnamelbl -text "Variable name:"
        ttk::entry $w.vname -width 0 \
                -textvariable [myvar options](-vname) \
                -validate focusout \
                -validatecommand [mymethod reload_preview_data]
        tooltip $w.vnamelbl $w.vname \
                "Specifies the variable to store the data in once loaded. This
                variable will also be added to the processing gui's variable
                list."

        ttk::button $w.load -text "Load" \
                -command [mymethod load]
        tooltip $w.load \
                "Load the data using the current settings. This GUI will be
                closed afterwards."

        ttk::button $w.dismiss -text "Dismiss" \
                -command [list destroy $win]
        tooltip $w.dismiss \
                "Close the GUI without loading data."

        lower [ttk::frame $w.buttons]
        grid $w.vname x $w.load $w.dismiss \
                -sticky ew -in $w.buttons
        grid configure $w.load -padx 2
        grid columnconfigure $w.buttons 0 -weight 1

        lower [ttk::frame $w.config]
        grid $w.typelbl $w.type $w.widthlbl $w.width \
                -sticky ew -in $w.config -padx 2 -pady 2
        grid $w.resultlbl $w.result $w.commentlbl $w.comment \
                -sticky ew -in $w.config -padx 2 -pady 2
        grid $w.columnlbl $w.column $w.missinglbl $w.missing \
                -sticky ew -in $w.config -padx 2 -pady 2
        grid $w.headerlbl $w.header $w.selcol $w.selcolval \
                -sticky ew -in $w.config -padx 2 -pady 2
        grid $w.vnamelbl $w.buttons - - \
                -sticky ew -in $w.config -padx 2 -pady 2

        foreach lbl {type width result comment column missing header vname} {
            grid $w.${lbl}lbl -sticky e
        }
        grid $w.selcol -sticky e

        grid columnconfigure $w.config {1 3} -weight 1 -uniform a

        ttk::label $w.previewlbl -text "Preview of import:"
        preview $w.preview
        tooltip $w.previewlbl $w.preview \
                "A preview of the data import will be displayed here as
                settings are tuned above. If nothing is shown here, then the
                settings above are incomplete or invalid."

        ttk::label $w.samplelbl -text "Sample from file:"
        sample $w.sample
        tooltip $w.samplelbl $w.sample \
                "A sample of the data from the file, as it appears in the file.
                If this is empty, then there was a problem accessing the file
                you selected (or you haven't selected a file yet)."

        grid $w.src -sticky ew -pady 2
        grid $w.detect -sticky ew -pady 2
        grid $w.delim -sticky ew -pady 2
        grid $w.config -sticky ew
        grid $w.previewlbl -sticky w -padx 2 -pady 2
        grid $w.preview -sticky news -padx 2 -pady 2
        grid $w.samplelbl -sticky w -padx 2 -pady 2
        grid $w.sample -sticky news -padx 2 -pady 2

        grid columnconfigure $w 0 -weight 1
        grid rowconfigure $w {5 7} -weight 1 -uniform 1

        set preview $w.preview
        set sample $w.sample

        $self settings_restore
    }

    destructor {
        $self settings_save
    }

    method select_file {} {
        if {$options(-filename) eq ""} {
            set base $::data_file_path
        } else {
            set base [file dirname $options(-filename)]
        }

        set temp [tk_getOpenFile -initialdir $base \
                -parent $win -title "Select ASCII file" \
                -filetypes {{"ASCII files" {.txt .asc .xyz}} {"All files" *}}]

        if {$temp ne ""} {
            $self configure -filename $temp
            $self load_sample
        }
    }

    method load_sample {} {
        if {
            $options(-filename) eq "" || ![file isfile $options(-filename)] \
                    || ![file readable $options(-filename)]
        } {
            return
        }
        set fh [open $options(-filename)]
        set lines [split [read $fh $samplesize] \n]
        close $fh
        if {[file size $options(-filename)] > $samplesize} {
            set lines [lrange $lines 0 end-1]
        }
        $self configure -nlines [llength $lines]
        $sample configure -text [join $lines \n]
        $self reload_preview_data
    }

    method json_data {short} {
        set items [huddle create \
                fn $options(-filename) \
                nskip $options(-nskip) \
                type $options(-type) \
                comment $options(-comment) \
                missing $options(-missing) \
                group $options(-group)]
        switch -- $options(-column_detect) {
            delim -
            marker {
                huddle set items $options(-column_detect) [$self delimiter]
            }
            width {
                set width [split $options(-width) ,]
                if {[llength $width]} {
                    set width [huddle list {*}$width]
                }
                huddle set items width $width
            }
            default {
                error "Unknown column detection"
            }
        }
        if {$options(-ncols) > 0} {
            huddle set items ncols $options(-ncols)
        }
        if {$options(-select_cols)} {
            set selcols [split $options(-selected_cols) ,]
            huddle set items selcols [huddle list {*}$selcols]
        }

        if {$short} {
            huddle set items nlines [expr {$options(-nlines) - $options(-nskip)}]
        }

        return [huddle jsondump $items "" ""]
    }

    method reload_preview_data {} {
        $preview configure -sample {}
        set json [$self json_data 1]
        set json \"[string map {\" \\\"} $json]\"
        ybkg tky_ascii_rdcols_sample $json \"[mymethod yorick_preview_data]\"
        return 1
    }

    method yorick_preview_data {data} {
        set data [json::json2dict $data]
        set M [struct::matrix]
        $M add rows [llength [lindex $data 0]]
        foreach col $data {
            $M add column $col
        }
        set data [lindex [$M serialize] 2]
        $M destroy
        $preview configure -sample $data
    }

    method load {} {
        set json [$self json_data 0]
        set json \"[string map {\" \\\"} $json]\"
        set cmd "$options(-vname) = ascii_rdcols($json)"
        exp_send "$cmd;\r"
        append_varlist $options(-vname)
        destroy $win
    }

    method delimiter {} {
        if {$options(-delim) eq "OTHER"} {
            return $options(-delim_custom)
        } else {
            return $options(-delim)
        }
    }
}

snit::widgetadaptor ::l1pro::ascii::preview {
    delegate method * to tree
    delegate option * to tree

    component tree
    component vsb
    component hsb

    option -sample -default {} -configuremethod {Update sample}
    option -mappings -default {}

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
    }

    method {Update sample} {option value} {
        set options($option) $value
        foreach child [$self children {}] {
            $self delete $child
        }
        set cols [::struct::list iota [llength [lindex $value 0]]]
        $self configure -columns $cols
        foreach row $value {
            $self insert {} end -values $row
        }
        foreach col $cols {
            $self heading $col -text [expr {$col + 1}]
        }
        $self autosize
    }

    method autosize {} {
        set weights {}
        set sum 0
        set cols [$self cget -columns]
        if {$cols eq ""} {
            return
        }
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
}
