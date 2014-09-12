# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide misc::fsdialog 1.0

# This package is a wrapper around the fsdialog package found on the tcler's
# wiki at: http://wiki.tcl.tk/15897
#
# It allows for the user to configure whether to use the tk style dialogs or
# the fsdialog style dialogs.

namespace eval misc::fsdialog {
    variable interface
    array set interface {
        file fs
        dir fsfile
    }

    if {[info commands [namespace current]::tk_chooseDirectory] eq ""} {
        rename ::tk_chooseDirectory [namespace current]::tk_chooseDirectory
        rename ::tk_getOpenFile [namespace current]::tk_getOpenFile
        rename ::tk_getSaveFile [namespace current]::tk_getSaveFile
    }
}

proc ::misc::fsdialog::wrapper {cmd drop argList} {
    foreach key $drop {
        dict unset argList $key
    }
    return [{*}$cmd {*}$argList]
}

proc ::misc::getOpenFile {args} {
    if {$fsdialog::interface(file) eq "fs"} {
        set cmd [list ttk::getOpenFile]
        set drop [list -message]
    } else {
        set cmd [list tk_getOpenFile]
        set drop [list -details -foldersfirst -hidden -reverse \
                -sepfolders -sort -choosedir]
    }
    return [fsdialog::wrapper $cmd $drop $args]
}

proc ::misc::getSaveFile {args} {
    if {$fsdialog::interface(file) eq "fs"} {
        set cmd [list ttk::getOpenFile]
        set drop [list -message]
    } else {
        set cmd [list tk_getOpenFile]
        set drop [list -details -foldersfirst -hidden -reverse \
                -sepfolders -sort]
    }
    return [fsdialog::wrapper $cmd $drop $args]
}

proc ::misc::chooseDirectory {args} {
    if {[dict exists $args -choosedir]} {error "invalid option: -choosedir"}
    if {$fsdialog::interface(dir) eq "fsdir"} {
        set cmd [list ttk::chooseDirectory]
        set drop [list -details -foldersfirst -hidden -reverse \
                -sepfolders -sort -multiple]
    } elseif {$fsdialog::interface(dir) eq "fsfile"} {
        set cmd [list ttk::getOpenFile -choosedir 1]
        set drop [list -mustexist]
    } else {
        set cmd [list tk_chooseDirectory]
        set drop [list -details -foldersfirst -hidden -reverse \
                -sepfolders -sort -multiple]
    }
    return [fsdialog::wrapper $cmd $drop $args]
}

interp alias {} tk_getOpenFile {} ::misc::getOpenFile
interp alias {} tk_getSaveFile {} ::misc::getSaveFile
interp alias {} tk_chooseDirectory {} ::misc::chooseDirectory
