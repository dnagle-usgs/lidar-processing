# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide misc::xwd 1.0
package require misc

namespace eval ::misc::xwd {
    variable outdir [file join $::env(HOME) alps-captures]
    variable time 1
    variable raise normal
    variable delay 5
}

proc ::misc::xwd::gui {} {
    if {[winfo exists .xwdall]} {
        ::misc::raise_win .xwdall
        return
    }

    set ns [namespace current]

    toplevel .xwdall
    set f [ttk::frame .xwdall.f]
    pack $f -expand 1 -fill both

    ttk::label $f.lblOut -text "Directory:"
    ttk::entry $f.entOut \
        -textvariable ${ns}::outdir
    ttk::button $f.btnOut \
        -width 0 \
        -text "Browse" \
        -command ${ns}::gui_browse

    ttk::checkbutton $f.chkTime \
        -variable ${ns}::time \
        -text "Create timestamped subdirectories"

    ttk::label $f.lblRaise -text "Raise:"
    ttk::combobox $f.cboRaise \
        -textvariable ${ns}::raise \
        -state readonly \
        -values {none normal force topmost}

    ttk::label $f.lblDelay -text "Delay:"
    ttk::spinbox $f.spnDelay \
        -textvariable ${ns}::delay \
        -from 0 -to 10000 -increment 5

    ttk::button $f.btnCapture \
        -width 0 \
        -text "Capture" \
        -command ${ns}::gui_capture

    grid $f.lblOut $f.entOut $f.btnOut \
        -sticky ew -padx 2 -pady 1
    grid $f.chkTime - - \
        -sticky w -padx 2 -pady 1
    grid $f.lblDelay $f.spnDelay \
        -sticky ew -padx 2 -pady 1
    grid $f.lblRaise $f.cboRaise $f.btnCapture \
        -sticky ew -padx 2 -pady 1

    grid configure $f.lblOut $f.lblDelay $f.lblRaise -sticky e
    grid columnconfigure $f 1 -weight 1
    grid rowconfigure $f 4 -weight 1

    wm resizable .xwdall 1 0
    wm title .xwdall "Capture All"

    ::misc::tooltip $f.lblOut $f.entOut $f.btnOut \
        "Select the output directory where the captures will go."
    ::misc::tooltip $f.chkTime \
        "If enabled, each capture will have a timestamped subdirectory created
        for its images. This prevents the capture from clobbering previous
        captures."
    ::misc::tooltip $f.lblDelay $f.spnDelay \
        "A time in milliseconds to pause between screenshots. This helps give
        the GUIs time to refresh properly if they have been raised."
    ::misc::tooltip $f.lblRaise $f.cboRaise \
        "Advanced setting: this should not normally need to be changed.

        The underlying xwd command will only capture portions of the window
        that are visible. In order to perform a successful capture of all
        windows, this tool will attempt to raise them.

        If you set this setting to \"none\", then no window raising will occur.
        However, portions of windows that are not visible will not capture
        properly.

        If you set this setting to \"normal\", then the built-in raise command
        will be used. This works much of the time, but some window managers
        will ignore it.

        If you set this setting to \"force\", then a more involved technique is
        used to forcibly raise the windows. However, this causes a redraw of
        the windows. That redraw adds a delay which means that the capture may
        happen before the redraw is complete, resulting in an improper capture.

        If you set this setting to \"topmost\", then the window will be hinted
        to be the topmost window. This sometimes works when normal does not."
    ::misc::tooltip $f.btnCapture \
        "Perform the screen captures. (There will be no explicit confirmation
        that the screen captures have occured, though you may notice your
        windows raising.)

        Note: for convenience's sake, this window will be excluded from the
        screen captures."
}

proc ::misc::xwd::gui_browse {} {
    variable outdir

    set tmp [tk_chooseDirectory \
        -initialdir $outdir \
        -mustexist 0 \
        -parent .xwdall]

    if {$tmp ne ""} {
        set outdir $tmp
    }
}

proc ::misc::xwd::gui_capture {} {
    variable outdir
    variable time
    variable delay
    variable raise

    capture_all -outdir $outdir -time $time -delay $delay -raise $raise \
        -exclude .xwdall

    raise .xwdall
}

proc ::misc::xwd::capture {args} {
# ::misc::xwd::capture ?options...?
# Uses xwd to take a screenshot of a window.
#
# Options:
#   -win <path>
#       Window to capture. If omitted, the user will be prompted to click to
#       select the window.
#   -outdir <path>
#       Place to store image captured. If omitted, defaults to current
#       directory. If -outfile is specified, -outdir is ignored.
#   -outfile <path>
#       Output file to use for image captures. If omitted, the user will be
#       prompted.
#   -delay <int>
#    default: 5
#       A time delay before taking the screenshot, to give time for GUIs to
#       refresh.
#   -raise <none|normal|force>
#    default: normal
#       Specifies how the window should be raised. fFr "none", the window is
#       not raised; if the window is obscured, that section of the window will
#       not capture properly. For "normal", the built-in "raise" command will
#       be used; however, this may not be honored properly by all window
#       managers. For "force", the window will be minimized and then restored
#       which forces it to the top; however, this will cause a redraw on Yorick
#       windows which will cause improper captures on slow-redrawing complex
#       plots.
#   -token <string>
#    default: "ALPS - CAPTURE THIS"
#       An arbitrary but unique string that is used to temporarily denote which
#       window to capture. This should not need to be changed.
#   -tmp <path>
#    default: /tmp/junk.xwd
#       A temporary file to use as a destination of the xwd command. This
#       should not need to be changed.
    array set opts {
        -win {}
        -outdir {}
        -outfile {}
        -delay 5
        -raise normal
        -token "ALPS - CAPTURE THIS"
    }
    set opts(-tmp) [file join $::alpsrc(temp_dir) junk.xwd]
    array set opts $args

    set dir $opts(-outdir)

    set lower {{w} {}}
    switch -- $opts(-raise) {
        none {
            set raise {{w} {}}
        }
        normal {
            set raise {{w} {raise $w}}
        }
        force {
            set raise {{w} {::misc::raise_win $w}}
        }
        topmost {
            set raise {{w} {wm attributes $w -topmost 1}}
            set lower {{w} {wm attributes $w -topmost 0}}
        }
        default {
            error "Unknown setting for -raise: $opts(-raise)"
        }
    }

    file mkdir [file dirname $opts(-tmp)]

    set cmd [list xwd -out $opts(-tmp)]

    if {$opts(-win) eq {}} {
        tk_messageBox -type ok -message \
            "After clicking OK, click on the window to capture"
    } else {
        lappend cmd -name $opts(-token)
        set title [wm title $opts(-win)]
        wm title $opts(-win) $opts(-token)
    }

    update
    after $opts(-delay)

    if {$opts(-win) ne ""} {
        apply $raise $opts(-win)
    }

    exec {*}$cmd

    if {$opts(-win) ne ""} {
        wm title $opts(-win) $title
        apply $lower $opts(-win)
    }

    set fn $opts(-outfile)
    if {$fn eq ""} {
        set fn [tk_getSaveFile \
            -initialdir $opts(-outdir) \
            -defaultextension .png]
    }

    if {$fn ne ""} {
        exec convert $opts(-tmp) $fn
    }

    file delete -force $opts(-tmp)
}

proc ::misc::xwd::capture_all {args} {
# ::misc::xwd::capture ?options...?
# Uses xwd via capture to take a screenshot of all visible windows. (Excludes
# the console.)
# Options passed through to capture:
#   -delay
#   -raise
#   -token
#   -tmp
# Options for capture_all:
#   -outdir <path>
#       Place to store images captured. If omitted, defaults to current
#       directory.
#   -time <0|1>
#    default: 1
#       If set to 1, then a timestamp subdirectory will be created for the
#       captures. This is enabled by default so that subsequent captures will
#       not clobber previous ones.
#   -exclude <list>
#    default: {}
#       A list of paths to skip. This paths will not have screenshots made.
#   -root <string>
#    default: "ROOT"
#       Output image names are based on the Tk window paths, minus their
#       leading period. The root window is just a period, which would make its
#       name just ".png". This option specifies what name to give the root
#       window, if it's one of the windows being captured. The default results
#       in "ROOT.png".
    array set opts {
        -outdir {}
        -time 1
        -exclude {}
        -root ROOT
    }
    array set opts $args

    set dir $opts(-outdir)
    if {$dir eq ""} {
        set dir [file join [pwd] captures]
    }
    if {$opts(-time)} {
        set time [clock format [clock seconds] -format %Y%m%d_%H%M%S]
        set dir [file join $dir $time]
    }

    file mkdir $dir
    foreach w [wm stackorder .] {
        if {$w in $opts(-exclude)} {continue}

        set fn [string range $w 1 end]
        if {$fn eq ""} {set fn $opts(-root)}
        set fn [file join $dir ${fn}.png]

        capture {*}[array get opts] -win $w -outfile $fn
    }
}

