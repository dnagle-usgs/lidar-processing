# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide misc 1.0

# Copied and modified from http://wiki.tcl.tk/28723

# NAME
#   getstring - pops up a window and gets a textual response from the user
# 
# SYNOPSIS
#   getstring ?option value ...?
# 
# DESCRIPTION
#   This procedure creates and displays a modal dialog window with an
#   application-specified prompt message and input-validation and help
#   command hooks. After the window displays, getstring waits for the
#   user to type-in/modify/accept a response and select one of the buttons.
# 
#   The buttons are "Ok", "Cancel", and, if the -helpcommand option is given,
#   "Help". Only the ok and cancel buttons cause the dialog to terminate.
# 
#   The result of the command is a list, where the first element is the button
#   selected to terminate the dialog, and the second element is the input string.
# 
#   The following option-value pairs are supported:
# 
#   -default STRING
#       Gives the default value to return. When the message dialog is first
#       displayed, the entire text will be selected.
# 
#   -fractionx FLOAT
#   -fractiony FLOAT
#       These control how the window is to be centered in its parent. FLOAT is
#       a floating point value in the range 0 to 1, inclusive. 0 represents the
#       top or left edge, and 1 represents the bottom or right. The default is
#       just a little above center.
# 
#   -height INTEGER
#       Specifies the height of the pop-down listbox, in rows. This option is
#       only meaningful if the -values option is used. Defaults to 10. See the
#       ttk::combobox -height option for more information.
# 
#   -helpcommand SCRIPT
#   -helpcmd     SCRIPT
#   -hcmd        SCRIPT
#       The command script to evaluate if the user presses the help button.
#       See ttk::button -command for more information.
# 
#   -invalidcommand SCRIPT
#   -invalidcmd     SCRIPT
#   -icmd           SCRIPT
#       The command script to evaluate whenever the -validatecommand option
#       script returns false (or zero). See ttk::entry validation for more
#       information.
# 
#   -parent WINDOW
#       Makes WINDOW the logical parent of the dialog window. The dialog
#       is displayed on top of the parent window. If no parent window is given,
#       the dialog is centered on the screen.
# 
#   -prompt TEXT
#       The message to display to the user. The message does NOT have word-wrap
#       or any other fancy formatting. You can, however, make multiple lines by
#       embedding newlines in the TEXT.
# 
#   -show TEXT
#       If this option is specified, then the true contents of the entry are not
#       displayed in the dialog window. Instead, each character in the dialog's
#       entry's value will be displayed as the first character in the TEXT, such
#       as "*" or a bullet. This is useful, for example, if the dialog is to be
#       used to enter a password. If characters in the the dialog's entry are
#       selected and copied elsewhere, the information copied will be what is
#       displayed, not the true contents of the entry. See the ttk::entry -show
#       option for more information.
# 
#   -state STATE
#       One of "normal" or "readonly". In the readonly state, the value may not
#       be edited directly, and the user can only select one of the -values from
#       the drop-down listbox. In the normal state, the text field is directly
#       editable. This option is only useful if the -values option is used.
# 
#   -title TEXT
#       The TEXT to give the window manager as the title and iconname for the
#       dialog window.
# 
#   -validatecommand SCRIPT
#   -validatecmd     SCRIPT
#   -vcmd            SCRIPT
#       The command script to evaluate every time an edit is made to the text
#       by the user (but not by changing the -variable programmatically).
#       If set to the empty string (the default), validation is disabled. The
#       script must return a boolean value. See ttk::entry "key" validation for
#       more information.
# 
#   -values LIST
#       If specified, the entry widget is exchanged for a combobox widget,
#       but only if the -show option is not used. Specifies the list of values
#       to display in the drop-down listbox. See ttk::combobox for more
#       information. Also see the -height option.
# 
#   -variable VARNAME
#       Specifies the name of a global variable whose value is linked to the
#       dialog's entry widget's contents. Whenever the variable changes value,
#       the dialog's contents are updated, and vice versa. If the variable did
#       not exist before calling the dialog, it does afterwards.
# 
#   -width INTEGER
#       Specifies an integer value indicating the desired width of the dialog's
#       entry widget, in average-size characters of the widget's font. See the
#       ttk::entry -width option for more information.
# 
# NOTES
#   This dialog uses the ttk::entry widget, which has some differences from the
#   standard Tk entry widget. See ttk::entry "Differences from Tk entry widget
#   validation".
# 
# BINDINGS
#   Besides all the ttk::entry default bindings, the following are also
#   bound to the dialog.
# 
#   * The Return and KP_Enter keys are bound to the ok button.
#   * The Escape key and closing the window are bound to the cancel button.
#   * The F1 and Help keys are bound to the help button (if any).
# 
# BUGS
#   The -height option doesn't seem to be properly handled. (But that is a
#   ttk::combobox issue.)
# 
#   I forgot about the taskbar...
# 
# SEE ALSO
#   ttk::button
#   ttk::combobox
#   ttk::entry
#   ttk::label
#   ...
# 
# TODO
#   Make the prompt take some form of fancy formatting (like HTML or something?) 
# 
# Copyright 2011 Michael Thomas Greer


#
# Copyright (c) 2011 by Michael Thomas Greer
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

package require Tk 8.5

#-----------------------------------------------------------------------------
namespace eval ::misc::getstring:: {
    proc refocus args {
        # Used to force the modal dialog to have focus after
        # evaluating any of the user command option scripts.
        # (Since the script could do just about anything...)
        focus -force [lindex $args 0]
    }

}

#-----------------------------------------------------------------------------
proc ::misc::getstring args {
    if {[llength $args] % 2} {
        return -code error {wrong # args: must be "getstring ?option value ...?"}
    }

    array set options {
       #-default         {this must not exist unless specified by the user}
        -fractionx       .50
        -fractiony       .425
        -height          10
        -helpcommand     {}
        -invalidcommand  {}
        -parent          {}
        -prompt          {}
        -show            {}
        -state           normal
       #-title           {this must not exist unless specified by the user}
        -validatecommand {}
        -values          {}
        -variable        {}
        -width           0
    }
    array set options $args
        foreach {name abbreviations} {
            -helpcommand     {-hcmd -helpcmd}
            -invalidcommand  {-icmd -invalidcmd}
            -validatecommand {-vcmd -validatecmd}
        } {
            foreach abbreviation $abbreviations {
                if {[info exists options($abbreviation)]} {
                    set options($name) $options($abbreviation)
                }
            }
        }

    # Validate options .........................................................
    if {($options(-parent) ne {}) && ![winfo exists $options(-parent)]} {
        error "bad window path name \"$options(-parent)\""
    }
    foreach opt {fractionx fractiony} {
        set v $options(-$opt)
        if {![string is double -strict $v] || ($v < 0) || ($v > 1)} {
            error "expected floating-point $opt in \[0.0, 1.0\] but got \"$v\""
        }
    }
    foreach opt {height width} {
        if {![string is integer -strict $options(-$opt)]} {
            error "expected integer $opt but got \"$options(-$opt)\""
        }
    }
    if {$options(-state) ni {normal readonly}} {
        error "bad state \"$options(-state)\": must be normal or readonly"
    }

    if {![info exist options(-title)]} {  # we must have a -title
        if {$options(-parent) ne {}} {
            set options(-title) [wm title $options(-parent)]
        } else {
            set options(-title) [wm title .]
        }
    }
    if {$options(-show) ne {}} {          # -show beats -values
        set options(-values) {}
    }

    # Create and populate the dialog window ....................................
    set w [string map {.. .} $options(-parent).[clock microseconds]]

    toplevel $w -relief flat -class TkGetStringDialog
    variable ::tk::$w.buttonpressed
    variable ::tk::$w.refocus {}
    trace add variable ::tk::$w.refocus write \
            [list ::misc::getstring::refocus $w.entry]

    wm title     $w $options(-title)
    wm iconname  $w $options(-title)
    wm protocol  $w WM_DELETE_WINDOW [list set ::tk::$w.buttonpressed cancel]
    wm transient $w [winfo toplevel [winfo parent $w]]

    set prev_focus   [focus -displayof $w]
    set prev_grab    [grab current $w]

    # (The text variable)
    if {$options(-variable) eq {}} {
        set varname ::$w.value; set $varname {}
    } else {
        set varname $options(-variable)
    }
    upvar #0 $varname var
    if {![info exists var]} {
        set var {}
    }
    if {[info exists options(-default)]} {
        set var $options(-default)
    }

    # (The prompt message, if any)
    if {$options(-prompt) ne {}} {
        ttk::label $w.prompt -text $options(-prompt)
        pack $w.prompt -side top -expand yes -fill x
    }

    # (Command options)
    foreach cmd {-helpcommand -invalidcommand -validatecommand} {
        if {[llength $options($cmd)] != 0} {
            set options($cmd) "set ::tk::$w.refocus \[ $options($cmd) \]"
        }
    }

    # (Entry widget)
    if {[llength $options(-values)]} {
        ttk::combobox $w.entry \
                -height          $options(-height) \
                -invalidcommand  $options(-invalidcommand) \
                -state           $options(-state) \
                -textvariable    $varname \
                -validate        [expr {[llength $options(-validatecommand)] \
                        ? {key} : {none}}] \
                -validatecommand $options(-validatecommand) \
                -values          $options(-values) \
                -width           $options(-width)
    } else {
        ttk::entry $w.entry \
                -invalidcommand  $options(-invalidcommand) \
                -show            $options(-show) \
                -textvariable    $varname \
                -validate        [expr {[llength $options(-validatecommand)] \
                        ? {key} : {none}}] \
                -validatecommand $options(-validatecommand) \
                -width           $options(-width)
    }
    if {$var ne {}} { $w.entry selection range 0 end }
    pack $w.entry -side top -padx 10 -pady 5 -expand yes -fill x

    # (Buttons)
    ttk::frame  $w.buttons
    ttk::button $w.buttons.ok     -text Ok \
            -command [list set ::tk::$w.buttonpressed ok]
    ttk::button $w.buttons.cancel -text Cancel \
            -command [list set ::tk::$w.buttonpressed cancel]
    ttk::button $w.buttons.help   -text Help \
            -command $options(-helpcommand)
    pack $w.buttons.ok     -side left -expand yes -fill x
    pack $w.buttons.cancel -side left -expand yes -fill x
    if {[llength $options(-helpcommand)] != 0} {
        pack $w.buttons.help -side left -expand yes -fill x
    }
    pack $w.buttons -expand yes -fill x

    # (Global bindings)
    bind $w <Return>   [list set ::tk::$w.buttonpressed ok]
    bind $w <KP_Enter> [list set ::tk::$w.buttonpressed ok]
    bind $w <Destroy>  [list set ::tk::$w.buttonpressed cancel]
    bind $w <Escape>   [list set ::tk::$w.buttonpressed cancel]
    bind $w <F1>       $options(-helpcommand)
    bind $w <Help>     $options(-helpcommand)

    # Properly position it on the display ......................................
    # See "Total Window Geometry" http://wiki.tcl.tk/11291
    wm withdraw $w
    update idletasks
    focus -force $w.entry
    if {$options(-parent) eq {}} {
        # (Position on the user's screen/vroot)
        lassign [split [winfo geometry $w] +] foo dtop dleft
        set dw [expr {[winfo rootx $w] - $dleft}]
        set dh [expr {[winfo rooty $w] - $dtop }]
        set x [expr {round( \
                ([winfo vrootwidth  $w] - [winfo reqwidth  $w] - $dw) \
                * $options(-fractionx) )}]
        set y [expr {round( \
                ([winfo vrootheight $w] - [winfo reqheight $w] - $dh) \
                * $options(-fractiony) )}]
    } else {
        # (Position on the parent widget)
        set p $options(-parent)
        set x [expr {round( \
                (([winfo width  $p] - [winfo reqwidth  $w]) \
                * $options(-fractionx)) + [winfo x $p] )}]
        set y [expr {round( \
                (([winfo height $p] - [winfo reqheight $w]) \
                * $options(-fractiony)) + [winfo y $p] )}]
    }
    incr x -[winfo vrootx $w]
    incr y -[winfo vrooty $w]
    wm geometry $w +$x+$y
    wm deiconify $w
    wm resizable $w 0 0
    grab $w

    # Run the dialog ...........................................................
    tkwait variable ::tk::$w.buttonpressed

    set result [list [set ::tk::$w.buttonpressed] $var]

    # Clean up .................................................................
    grab release $w
    destroy $w
    focus -force $prev_focus
    if {$prev_grab ne {}} { grab $prev_grab }
    update idletasks

    unset ::tk::$w.refocus
    unset ::tk::$w.buttonpressed
    if {$options(-variable) eq {}} { unset var }

    return $result
}
