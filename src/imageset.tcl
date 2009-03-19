# $Id$

package require Itcl
package require vfs::tar

if {[info commands ImageSet] eq ""} {
	itcl::class ImageSet {
		
		constructor {args} {}
		destructor {}
		
		# get number of images
		method size {} {}

		method initial_sod {} {}

		method sod2idx {sod} {}
		method idx2sod {idx} {}
		method sod2hms {sod} {}
		method hms2sod {hms {seconds_offset 0} {frame_off 0}} {}
		method idx2hms {idx} {}
		method hms2idx {hms {seconds_offset 0} {frame_off 0}} {}
		
		# get path of current image.
		# mounts if necessary
		# returns "" when file not found
		# idx defined over [1, size)
		method get_img {idx} {}

		# number of files accessible using data path
		variable nfiles

		variable path ;# path of target dir or file we're getting images from
		variable init_sod ;# sod of first image
		variable sod2idx_map
		variable file_list
		variable mounted
	}
}

itcl::body ImageSet::constructor {args} {
}

itcl::body ImageSet::size {} {
	return $nfiles
}

itcl::body ImageSet::initial_sod {} {
	return $init_sod
}

itcl::body ImageSet::sod2idx {sod} {
	if {[info exists sod2idx_map($sod)]} {
		puts "found $sod at $sod2idx_map($sod)"
		return $sod2idx_map($sod)
	}
	
	set offset 1
	for {set i 0} {$i < 20} {incr i} {
		set key [expr $sod + $offset]
		if {[info exists sod2idx_map($key)]} {
			return $sod2idx_map($key)
		}
		# reverse sign of offset and move away from sod by 1
		set offset [expr ($offset + ($offset / abs ($offset))) * -1]
	}

	return -1
}

itcl::body ImageSet::hms2idx {hms {seconds_offset 0} {frame_off 0}} {
	set sod [hms2sod $hms $seconds_offset $frame_off]
	set idx [sod2idx $sod]
	return $idx
}

itcl::body ImageSet::idx2sod {idx} {return [hms2sod [idx2hms $idx]]}

itcl::body ImageSet::sod2hms { sod } {
	set h [expr {int($sod) / 3600}]
	set m [expr {(int($sod) % 3600) / 60}]
	set s [expr {int($sod) % 60}]
	return [format "%02d%02d%02d" $h $m $s]
}

itcl::body ImageSet::hms2sod {hms {seconds_offset 0} {frame_off 0}} {
	set h 0
	set m 0
	set s 0
	scan $hms "%02d%02d%02d" h m s
	return [expr {$h * 3600 + $m * 60 + $s + $seconds_offset - $frame_off}]
}



#######################################
# RGBDirImageSet
#
# Used to open a sequence of RGB images from a directory of tar files.
# Tar names are formatted as cam147_YYYY-MM-DD_HHMM.tar while the tarred
# JPGs' names are formatted as mnt/ramdisk/2/cam147_YYYY-MM-DD_HHMMSS-II.jpg
# It is uknown to me what the 2-digit II represents.
# 
######################################
if {[info commands ImageSetRGBDir] eq ""} {
	itcl::class ImageSetRGBDir {
		inherit ImageSet

		constructor {target_path args} {}

		method get_img {idx} {}
		
		method img2tarpath {img} {}
		method idx2hms {idx} {}
	}
}

itcl::body ImageSetRGBDir::constructor {target_path args} {
	chain $args

	set path $target_path

	set cam1_flst [lsort [glob $target_path/cam147_*.tar 0]]
	
	
	
	# find the first  hms timestamp in the tar file
	set tf [ lindex $cam1_flst 0]
	
	set mounted [vfs::tar::Mount $tf $this]
	set pat "$this/mnt/ramdisk/2/cam147_*.jpg"
	set fnm [lsort [ glob $pat ] ]
	set fnm1 [lindex $fnm 0 ]
	set hms [ lindex [ split [ file tail $fnm1 ] "_" ] 2 ]
	scan $hms "%02d%02d%02d" h m s
	set start_hms [format "%02d%02d%02d" $h $m $s]
	vfs::tar::Unmount $mounted $this

	set init_sod [hms2sod $start_hms]
	
	set i 1
	foreach tf $cam1_flst {
		set mounted [vfs::tar::Mount $tf $this]
		set pat "$this/mnt/ramdisk/2/cam147_*.jpg"
		set img_list [lsort [glob $pat]]
		foreach img_fl $img_list {
			set hms [ lindex [ split [ file tail $img_fl ] "_" ] 2 ]
			scan $hms "%02d%02d%02d" h m s
			set hms [format "%02d%02d%02d" $h $m $s]
			set sod [hms2sod $hms]
			set sod2idx_map($sod) $i
			set file_list($i) $img_fl
			incr i
		}

		vfs::tar::Unmount $mounted $this
	}

	set nfiles [array size file_list]
	set mounted -1
}

itcl::body ImageSetRGBDir::get_img {idx} {
	set img_name $file_list($idx)
	set tarname [img2tarpath $img_name]
	if {$mounted != -1} {
		vfs::tar::Unmount $mounted $this
	}
	set mounted [vfs::tar::Mount $tarname $this]
	if {[file exists $img_name]} {
		return $img_name
	}
}

itcl::body ImageSetRGBDir::idx2hms {idx} {
	set img_name $file_list($idx)
	set h 0
	set m 0
	set s 0
	set hms [ lindex [ split [ file tail $img_name ] "_" ] 2 ]
	scan $hms "%02d%02d%02d" h m s
	return [format "%02d%02d%02d" $h $m $s]
}

	

itcl::body ImageSetRGBDir::img2tarpath {img} {
	set h 0
	set m 0
	set s 0
	set hms [ lindex [ split [ file tail $img ] "_" ] 2 ]
	scan $hms "%02d%02d%02d" h m s
	set hm [format "%02d%02d" $h $m]
	set tarname [glob $path/cam147_*$hm.tar 0]
	return $tarname
}


if {[info commands ImageSetRGBTar] eq ""} {
	itcl::class ImageSetRGBTar {
		inherit ImageSet

		constructor {target_path args} {}
		method get_img {idx} {}
		variable mnt_path
	}

}

itcl::body ImageSetRGBTar::constructor {target_path args} {
	chain $args
	
	set path $target_path
	vfs::tar::Mount $path $this
	foreach p {"" cam1 cam2} {
		if {![catch {set file_lst [glob -directory "$this/$p" -tails \
			"*.jpg" ]}]} {
			set file_lst [lsort -increasing $file_lst]
			set i 1
			foreach file $file_lst {
				set file_list($i) $file
				incr i
			}
			if {[string equal p ""] == 0} {
				set mnt_path $this/$p
			} else {
				set mnt_path $this
			}

			break
		}
	}
	set nfiles [array size file_list]
	
	# get initial sod
	set fn $file_list(0)
	set hms [lindex [split $fn "_"] 3]
	set init_sod [hms2sod $hms]
}

itcl::body ImageSetRGBTar::get_img {idx} {
	set fn $mnt_path/$file_list($idx)
	if {[file exists $fn]} {
		return $fn
	}
}

if {[info commands ImageSetCIR] eq ""} {
	itcl::class ImageSetCIR {
		inherit ImageSet

		constructor {target_paths args} {}
		
		method get_img {idx} {}
		method idx2hms {idx} {}
		variable file2tar_map
	}
}

itcl::body ImageSetCIR::constructor {target_path args} {
	chain $args

	set path $target_path

	set flst [lsort [glob $target_path/*.tar 0]]

	# puts flst
	
	# find the first hms timestamp in the tar file
	set tf [ lindex $flst 0]
	puts $tf
	
	set mounted [vfs::tar::Mount $tf $this]
	set pat "$this/*.jpg"
	set fnm [lsort [ glob $pat ] ]
	set fnm1 [lindex $fnm 0 ]
	set hms [ lindex [ split [ file tail $fnm1 ] "-" ] 1 ]
	scan $hms "%02d%02d%02d" h m s
	set start_hms [format "%02d%02d%02d" $h $m $s]
	set init_sod [hms2sod $start_hms]
	vfs::tar::Unmount $mounted $this
	
	set i 1
	set flist {}
	foreach tf $flst {
		set mounted [vfs::tar::Mount $tf $this]
		set img_list [lsort [glob "$this/*.jpg"]]
		set flist [concat $flist $img_list]
		foreach img_fl $img_list {
			set file2tar_map($img_fl) $tf
		}
		vfs::tar::Unmount $mounted $this
	}
	set flist [lsort $flist]
	foreach fl $flist {
		set h 0
		set m 0
		set s 0	
		set hms [ lindex [ split [ file tail $fl ] "-" ] 1 ]
		scan $hms "%02d%02d%02d" h m s
		set hms [format "%02d%02d%02d" $h $m $s]
		set sod [hms2sod $hms]
		set sod2idx_map($sod) $i
		set file_list($i) $fl
		incr i
	}

	set nfiles [array size file_list]
	set mounted -1

}

itcl::body ImageSetCIR::get_img {idx} {
	set fn $file_list($idx)
	set tarname $file2tar_map($fn)
	if {$mounted != -1} {
		vfs::tar::Unmount $mounted $this
	}
	set mounted [vfs::tar::Mount $tarname $this]
	if {[file exists $fn]} {
		return $fn
	}
}

itcl::body ImageSetCIR::idx2hms {idx} {
	set fn $file_list($idx)
	set h 0
	set m 0
	set s 0
	set hms [ lindex [ split [ file tail $fn ] "-" ] 1 ]
	scan $hms "%02d%02d%02d" h m s
	set hms [format "%02d%02d%02d" $h $m $s]
	return $hms
}
	

