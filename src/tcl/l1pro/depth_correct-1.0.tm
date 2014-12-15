# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::depth_correct 1.0

if {![namespace exists ::l1pro::depth_correct]} {
    namespace eval ::l1pro::depth_correct::v {
        variable top .l1wid.depthcorrect

        variable invar workdata
        variable outvar workdata
        variable conf {}

        variable custom_outvar 0
    }
}

namespace eval ::l1pro::depth_correct {
    proc gui {} {
        set ns [namespace current]
        set w $v::top
        destroy $w
        toplevel $w

        wm resizable $w 1 0
        wm protocol $w ${ns}::close

        set v::invar $::pro_var

        ttk::frame $w.f
        grid $w.f -sticky news
        grid columnconfigure $w 0 -weight 1
        grid rowconfigure $w 0 -weight 1

        set f $w.f

        ttk::frame $f.f1

        ttk::label $f.lblConf -text "Conf file:"
        ttk::label $f.lblInvar -text "Input variable:"
        ttk::checkbutton $f.chkOutvar -text "Output variable:" \
                -command ${ns}::outvar_refresh \
                -variable ${ns}::v::custom_outvar

        ttk::entry $f.entConf \
                -state readonly \
                -textvariable ${ns}::v::conf
        mixin::combobox $f.cboInvar \
                -state readonly \
                -listvariable ::varlist \
                -textvariable ${ns}::v::invar
        mixin::combobox $f.cboOutvar \
                -listvariable ::varlist \
                -textvariable ${ns}::v::outvar

        ttk::button $f.btnConfBrowse -text "Browse..." \
                -command ${ns}::browse
        ttk::button $f.btnApply -text "Apply" \
                -command ${ns}::apply
        ttk::button $f.btnApplyClose -text "Apply & Close" \
                -command ${ns}::apply_and_close
        ttk::button $f.btnCancel -text "Close" \
                -command ${ns}::close

        ::mixin::statevar $f.cboOutvar \
                -statemap {0 disabled 1 normal} \
                -statevariable ${ns}::v::custom_outvar

        pack $f.btnApply $f.btnApplyClose $f.btnCancel \
                -in $f.f1 -side left -padx 2

        grid $f.lblConf $f.entConf $f.btnConfBrowse -padx 2 -pady 1
        grid $f.lblInvar $f.cboInvar - -padx 2 -pady 1
        grid $f.chkOutvar $f.cboOutvar - -padx 2 -pady 1
        grid $f.f1 - - -pady 1

        grid configure $f.lblConf $f.lblInvar $f.chkOutvar \
                -sticky e
        grid configure $f.entConf $f.cboInvar $f.cboOutvar \
                -sticky ew
        grid rowconfigure $f {0 1 2} -uniform 1 -weight 1
        grid columnconfigure $f 1 -weight 1

        trace add variable ${ns}::v::invar write \
                ${ns}::outvar_refresh
        outvar_refresh
    }

    proc browse {} {
        set opts [list -parent $v::top \
                -title "Select conf file" \
                -filetypes {
                    {{Conf files} {.conf}}
                    {{All files} {*}}
                }]
        if {$v::conf ne ""} {
            dict set opts -initialdir [file dirname $v::conf]
            dict set opts -initialfile $v::conf
        }
        set fn [tk_getOpenFile {*}$opts]

        if {$fn ne ""} {
            set v::conf $fn
        }
    }

    proc apply {} {
        if {![file exists $v::conf]} {
            tk_messageBox \
                    -icon error \
                    -type ok \
                    -message "You must select a valid conf file."
            return 0
        }

        set cmd "$v::outvar = depth_correct($v::invar, conf=\"$v::conf\")"
        exp_send "$cmd;\r"
        append_varlist $v::outvar

        return 1
    }

    proc apply_and_close {} {
        if {[apply]} {
            close
        }
    }

    proc close {} {
        set ns [namespace current]
        trace remove variable ${ns}::v::invar write \
                ${ns}::outvar_refresh
        destroy $v::top
    }

    proc outvar_refresh {args} {
        if {!$v::custom_outvar} {
            set v::outvar ${v::invar}_cal
        }
    }
}
