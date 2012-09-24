# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide GUI 1.0
package require Itcl
package require Iwidgets
package require struct::set

namespace eval GUI::utils {}
proc GUI::utils::getfile { args } {
# getfile: pops up one of tk_chooseDirectory, tk_getOpenFile, or tk_getSaveFile
# usage: Much like the above three. Pass the dashed options you want.
# Note that -initialdirvariable can be used so that it updates an external
# variable if the user changes directory
   set defaults [list \
      -variable {} \
      -initialdir {} \
      -initialdirvariable {} \
      -filetypes {
         { {All files} * }
      } \
      -type open]
   set args [dict merge $defaults $args]

   if { [dict get $args -variable] ne "" } {
      upvar [dict get $args -variable] filename
   } else {
      set filename ""
   }

   if { [dict get $args -initialdirvariable] ne "" } {
      upvar [dict get $args -initialdirvariable] initial
   } else {
      set initial [dict get $args -initialdir]
   }
   set initial_bkp $initial

   if { $initial eq "" } {
      set initial $filename
   }
   while { ! [file isdirectory $initial] } {
      set initial [file dirname $initial]
   }

   set mapping {
      dir {cmd tk_chooseDirectory opts {-parent -title}}
      open {cmd tk_getOpenFile opts {-defaultextension -filetypes -parent -title}}
      save {cmd tk_getSaveFile opts {-defaultextension -filetypes -parent -title}}
   }

   set type [string tolower [dict get $args -type]]
   set command [dict get $mapping $type cmd]
   set opts [dict filter $args script {key val} {
      struct::set contains [dict get $mapping $type opts] $key
   }]

   dict set opts -initialdir $initial

   set temp [$command {*}$opts]

   if { $temp ne "" } {
      set filename $temp
      set initial [file dirname $filename]
   } else {
      set initial $initial_bkp
   }
   return $filename
}

if { [info commands GUI::EntryFieldButton] eq "" } {
   itcl::class GUI::EntryFieldButton {
      inherit iwidgets::Entryfield

      constructor {args} {}
   }
}

itcl::body GUI::EntryFieldButton::constructor {args} {
   itk_component add button {
      button $itk_interior.button
   } {
      keep -state
      rename -command -buttoncommand buttonCommand Command
      rename -text -buttontext buttonText Text
      rename -width -buttonwidth buttonWidth Width
      rename -height -buttonheight buttonHeight Height
   }
   pack $itk_component(button)

   itk_initialize {*}$args
}

if { [info commands GUI::FileEntryButton] eq "" } {
   itcl::class GUI::FileEntryButton {
      inherit GUI::EntryFieldButton
      
      constructor {args} {}

      itk_option define -defaultextension defaultextension Extension ""
      itk_option define -filetypes filetypes Filetypes ""
      itk_option define -initialdir initialdir Dir ""
      itk_option define -initialdirvariable initialdirVariable Variable ""
      itk_option define -parent parent Parent ""
      itk_option define -actiontype actiontype ActionType ""
      itk_option define -updatecommand updatecommand Command ""
      
      method file_choose {args} {}
   }
}

itcl::body GUI::FileEntryButton::constructor {args} {
   #itk_option remove GUI::EntryFieldButton::buttoncommand
   itk_initialize {*}$args
   configure \
      -buttoncommand [itcl::code $this file_choose] \
      -buttontext "Choose..."
}

itcl::body GUI::FileEntryButton::file_choose {args} {
   GUI::utils::getfile \
      -defaultextension $itk_option(-defaultextension) \
      -filetypes $itk_option(-filetypes) \
      -initialdir $itk_option(-initialdir) \
      -initialdirvariable $itk_option(-initialdirvariable) \
      -parent $itk_option(-parent) \
      -type $itk_option(-actiontype) \
      -variable $itk_option(-textvariable)
   if {$itk_option(-updatecommand) ne ""} {
      uplevel #0 $itk_option(-updatecommand)
   }
}