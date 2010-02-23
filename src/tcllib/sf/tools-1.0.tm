# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide sf::tools 1.0
package require sf::model

namespace eval ::sf::tools {
   namespace eval v {
      variable dump_progress 0
      variable dump_image ""
      variable dump_stop 0
   }
}

proc ::sf::tools::dump_model_images {model dest} {
   set query [$model position 0]

   set w .sfdumper
   toplevel $w
   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w.f

   set v::dump_progress [dict get $query -fraction]
   set v::dump_stop 0

   ttk::progressbar $f.progress \
      -orient horizontal \
      -mode determinate \
      -maximum 1 \
      -variable [namespace which -variable v::dump_progress]

   ttk::label $f.dest -text "Dumping images to $dest"
   ttk::label $f.image -textvariable [namespace which -variable v::dump_image]
   ttk::button $f.abort -text "Abort" \
      -command [list set [namespace which -variable v::dump_stop] 1]

   grid $f.dest
   grid $f.image
   grid $f.progress -sticky ew
   grid $f.abort
   grid columnconfigure $f 0 -weight 1

   dump_model_images_tick $model $dest $query
   vwait [namespace which -variable v::dump_stop]
   destroy $w
   return $v::dump_stop
}

proc ::sf::tools::dump_model_images_tick {model dest query} {
   if {$v::dump_stop} return
   dict with query {
      set v::dump_progress ${-fraction}
      set last ${-soe}
      set fn [$model filename ${-token}]
      set v::dump_image $fn
      set fn [file join $dest $fn]
      file mkdir [file dirname $fn]
      $model export ${-token} $fn
   }
   set query [$model relative [dict get $query -soe] 1]
   if {[dict get $query -soe] == $last} {
      set v::dump_stop 0
   } else {
      ::misc::idle [list ::sf::tools::dump_model_images_tick $model $dest $query]
   }
}

proc ::sf::tools::dump_mission_cir {dest args} {
   if {[dict exists $args -subdir]} {
      set subdir [dict get $args -subdir]
   } else {
      set subdir photos
   }
   foreach day [missionday_list] {
      if {[mission_has "cir dir" $day]} {
         set path [mission_get "cir dir" $day]
         set model [::sf::model::create::cir::tarpath -path $path]
         set dayrel [::fileutil::relative [mission_path] [mission_get data_path $day]]
         set daydest [file join $dest $dayrel $subdir]
         if {[dump_model_images $model $daydest]} {
            return
         }
      }
   }
}
