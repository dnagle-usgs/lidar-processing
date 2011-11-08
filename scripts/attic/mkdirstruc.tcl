# This stand-alone Tcl script was left behind by Jim Lebonitte in his shared
# directory on getafix. It is being archived for historical reference.
# -rwxrwxr-x  1 jlebonit science 1997 Apr 30  2008 mkdirstruc.tcl

# Original by Jim Lebonitte
# This script creates a directory structure for the QQ_Tiles directory, useful if you
# segmented the QQ_Tiles without using the dir_struc=1 keyword.  This main purpose is to 
# create the directory structures for the DVD, and it currently does it based on the .tfw files
# created with the geotiffs, but this can easily be changed in the get_file_list method. 
# Very early version should modify so as not to use a hardcoded directory as well as 
# use a different file to create the directores based on, probably .xyz.

lappend auto_path "[file join [ file dirname [info script]] ../../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ]"

proc get_file_list {} {
        set rv [tk_dialog .y \
                Title "Select the QQ Dir" \
                questhead 0 \
                "Entire directory" \
                "Just a few selected files"
                 ]
        set dir "/"
        if { $rv == 0 } {
              
                set dir [ tk_chooseDirectory -initialdir $dir ]
                set fnlst [lsort -increasing -unique [ glob -directory $dir *.tfw ] ]
        }
        if {$rv == 1} {
        set fnlst [ tk_getOpenFile \
         -filetypes      \
         -multiple 1 \
         -initialdir $dir  ]
        }

        return $fnlst
}


set tdirname "d:/IVAN/be/new_tifs/"
set pfninlist [ get_file_list ]
set count 0

while { $count <= [llength $pfninlist] } {
	set newdirname [string range  [file rootname [file tail [ lindex $pfninlist $count] ]  ] 4 11 ]
	#file mkdir $tdirname$newdirname
	set dfnlist [ glob -directory $tdirname *$newdirname*.tfw* ]
	file rename [lindex $dfnlist 0] $tdirname$newdirname
	
	
	incr count
}

exit 0

