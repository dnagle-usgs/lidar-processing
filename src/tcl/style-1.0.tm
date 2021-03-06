# vim: set ts=4 sts=4 sw=4 ai sr et:

# Tcl lib includes a style package, but it's old and does not provide anything
# we want or will ever use. This package therefor obscures that unused package.
# This is not an issue, but is noted here just in case.

package provide style 1.0
package require Tk
package require imglib

# Disable tearoff menus. This feature is obsolete and not common to any modern
# desktop environment.
option add *tearOff 0

namespace eval style {
    # ThemeChanged --
    # Updates various style and option database settings when the theme changes
    # to ensure a consistent experience.
    proc ThemeChanged {} {
        # Toolbar buttons should have text center-justified.
        ttk::style configure TButton -justify center

        # Menus should have colors that match ttk::frame.
        option add *Menu.background [ttk::style lookup TFrame -background]
        option add *Menu.activeBackground [ttk::style lookup TFrame -background]

        # Provide a sash for ttk::panedwindow.
        if {"Sash.xsash" ni [ttk::style element names]} {
            ttk::style element create Sash.xsash image ::imglib::sash \
                    -sticky news
        }
        ttk::style layout TPanedwindow {Sash.xsash}

        ttk::style layout NoLabel.TCheckbutton {
            Checkbutton.padding -sticky nwse
            -children {Checkbutton.indicator -side left -sticky {}}
        }

        foreach class {TCheckbutton TLabel} {
            set font [ttk::style configure $class -font]
            dict set font -size 8
            ttk::style configure Small.$class -font $font
        }

        # Custom styles for buttons that appear on "panels" (as in the main
        # l1pro GUI)
        ttk::style configure Panel.TMenubutton -padding {2 0}
        ttk::style configure Panel.TButton -padding 0

        # Suppresses the tabs on a ttk::notebook
        ttk::style layout NoTabs.TNotebook.Tab null

        # Used by ::mixin::revertable
        foreach type {TEntry TCombobox TSpinbox} {
            ttk::style map Revertable.$type -fieldbackground [list \
                    {alternate readonly} "#FFA500" \
                    {alternate disabled} "#FFA500" \
                    alternate "#FFE5B4" \
                    {*}[ttk::style map $type -fieldbackground]]
        }

    }

    # When the theme changes, update the option database
    bind . <<ThemeChanged>> [namespace current]::ThemeChanged

    # Force ThemeChanged to run up front, so that its changes apply to the
    # current theme as well.
    ThemeChanged

    # FixMenuColors --
    # Update the given menu widget to use the colors appropriate for the
    # current theme, referencing ttk::frame.
    proc FixMenuColors w {
        $w configure \
                -background [ttk::style lookup TFrame -background] \
                -activebackground [ttk::style lookup TFrame -background]
    }

    # When the theme changes, update existing menus
    bind Menu <<ThemeChanged>> [list [namespace current]::FixMenuColors %W]
}
