# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide l1pro::main 1.0

# Implements the main GUI

if {![namespace exists ::l1pro::main]} {
   namespace eval ::l1pro::main {
      namespace eval g {}
   }
}

proc ::l1pro::main::panel_tools w {
   ttk::frame $w
   set f $w

   ttk::button $f.pixelwf -text " Pixel \n Analysis " -width 0 \
      -command {exp_send "pixelwf_enter_interactive\r"}
   ttk::button $f.histelv -text " Histogram \n Elevations " -width 0 \
      -command ::l1pro::tools::histelev
   ttk::button $f.colorbar -text " Color \n Bar " -width 0 \
      -command ::l1pro::tools::colorbar
   ttk::button $f.rcf -text " RCF " -width 0 \
      -command ::l1pro::tools::rcf::gui
   ttk::button $f.datum -text " Datum \n Convert " -width 0 \
      -command ::datum_proc
   ttk::button $f.elvclip -text " Elevation \n Clipper " -width 0 \
      -command ::l1pro::tools::histclip::gui
   misc::combobox::mapping $f.gridtype -width 0 \
      -state readonly \
      -altvariable ::gridtype \
      -mapping {
         "2km Data Tile" grid
         "Quarter Quad" qq_grid
      }
   ttk::button $f.gridplot -text " Plot " -width 0 \
      -command {exp_send "draw_${::gridtype}, $::win_no\r"}
   ttk::button $f.gridname -text " Name " -width 0 \
      -command {exp_send "show_${::gridtype}_location, $::win_no\r"}

   ::tooltip::tooltip $f.gridtype \
      "Select the tiling system to use\ for \"Plot\" and \"Name\" below."
   ::tooltip::tooltip $f.gridplot \
      "Plots a grid showing tile boundaries for the currently selected tiling\
      \nsystem."
   ::tooltip::tooltip $f.gridname \
      "After clicking this button, you will be prompted to click on the\
      \ncurrent plotting window. You will then be told which tile corresponds\
      \nto the location you clicked."

   grid $f.pixelwf $f.histelv $f.colorbar $f.rcf $f.datum $f.elvclip \
      $f.gridtype - -sticky news -padx 1 -pady 1
   grid ^ ^ ^ ^ ^ ^ $f.gridplot $f.gridname -sticky news -padx 1 -pady 1
   grid columnconfigure $f 1000 -weight 1
   grid columnconfigure $f {6 7} -uniform g
}
