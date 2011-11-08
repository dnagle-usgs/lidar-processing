# This stand-alone Tcl script was left behind by Jim Lebonitte in his shared
# directory on getafix. It is being archived for historical reference.
# -rwxrwxr-x  1 jlebonit science 12702 Apr 30  2008 qq_tile_maker.tcl

# This script generates Quarter Quad, quick look, html data download pages for each 
# quarter quad tile in a data set.  All you need is your quicklook, JPEG files to be in your
# html/images/jpeg_tiles/ directory and for there to be a bare earth image for every first 
# return image and vice versa.  Just select all of the .JPEG files and the script will
# generate the html pages in the html\Tile_HTMLs folder.  The top-level 
# directories must already be created.  If the format for the coastal product LiDAR DVDs changes
# from the original IVAN DVD then some pathnames may need to be modified.  

lappend auto_path "[file join [ file dirname [info script]] ../../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ]"
package require Img

proc generateHtmlHeader { htmlout } {
	puts $htmlout "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">
<html>
<head>
  <meta http-equiv=\"Content-Type\"
 content=\"text/html; charset=iso-8859-1\">
  <meta name=\"description\"
 content=\"Digital data sets of EAARL coastal topography for the Northern Gulf of Mexico\">
  <meta name=\"Author\" content=\"USGS-John Brock and Laurinda Travers\">
  <meta name=\"keywords\"
 content=\"Lidar,USGS,NASA,EAARL,coastal topography\">
  <meta name=\"publisher\"
 content=\"U.S. Geological Survey, FISC St. Petersburg\">
  <meta name=\"Abstract\"
 content=\"Digital data sets of EAARL coastal topography of the Northern Gulf of Mexico following Hurricane Ivan in September 19, 2004. These remotely-sensed, geographically-referenced elevation measurements of lidar-derived coastal topography were produced as a collaborative effort between the U.S. Geological Survey (USGS), FISC St. Petersburg, Florida and the National Aeronautics and Space Administration (NASA), Wallops Flight Facility, Virginia. One objective of this research is to create techniques to survey areas for the purposes of geomorphic change studies following major storm events. Other applications of high-resolution topography include: habitat mapping, ecological monitoring, change detection, and event assessment.\">
  <meta name=\"created\" content=\"January 15, 2008\">
  <title>EAARL Coastal Topography-Northern Gulf of Mexico Data Sets</title>
  <link href=\"../styles/common.css\" rel=\"stylesheet\" type=\"text/css\">
  <link href=\"../styles/custom.css\" rel=\"stylesheet\" type=\"text/css\">
</head>
<body>
<!-- BEGIN USGS Header Template -->
<div class=\"bannerColorBand\">
<div class=\"banner\">
<div class=\"identifier\"> <a title=\"U.S. Geological Survey Home Page\"
 href=\"http://www.usgs.gov\"><img src=\"../images/header_usgsId_white.jpg\"
 alt=\"U.S. Geological Survey Logo and Link\" border=\"0\" height=\"72\"
 width=\"178\"></a></div>
<img src=\"../images/header_graphic_spacer.gif\" alt=\"\" style=\"float: left;\"
 height=\"72\" width=\"1\">
<div class=\"ccsaBox\"> <img src=\"../images/header_graphic_spacer.gif\" alt=\"\"
 style=\"float: left;\" height=\"72\" width=\"1\">
<div class=\"ccsa\"> <br>
<a title=\"U.S. Geological Survey Home Page\" href=\"http://www.usgs.gov/\"><abbr
 title=\"U.S. Geological Survey\">USGS</abbr> Home</a><br>
<a title=\"Contact USGS\" href=\"http://www.usgs.gov/ask/index.html\">Contact
<abbr title=\"U.S. Geological Survey\">USGS</abbr></a><br>
<a title=\"USGS Search Engine\" href=\"http://www.usgs.gov/search\">Search
<abbr title=\"U.S. Geological Survey\">USGS</abbr></a><br>
</div>
</div>
<img src=\"../images/header_graphic_spacer.gif\" alt=\"\" style=\"float: left;\"
 height=\"72\" width=\"1\"> <a href=\"http://www.nasa.gov/\"><img
 src=\"../images/NASA_ID.gif\" alt=\"NASA Cooperator Logo and Link\"
 style=\"border: medium none ;\" border=\"0\" height=\"70\" width=\"82\"></a></div>
</div>
<div class=\"siteTitle\">
<p id=\"pTitle\"><abbr
 title=\"U.S. Geological Survey-National Aeronautics and Space Administration\">USGS-NASA</abbr>
<abbr title=\"Experimental Advanced Airborne Research Lidar\">EAARL</abbr>
Coastal Topography</p>
</div>
<!-- END USGS Header Template -->
<a href=\"#skipmenu\" title=\"Skip this menu\"></a><!--<div id=\"skipmenu\">
<a href=\"#contents\">Skip Menu</a></div>-->
<!-- BEGIN USGS Left Margin Template --><a name=\"skipmenu\"></a>
<table border=\"0\" cellpadding=\"2\" cellspacing=\"2\" width=\"175\">
  <tbody>
    <tr>
      <td bgcolor=\"#000066\" valign=\"top\" width=\"175\">
      <p style=\"margin-top: 0pt; margin-bottom: 0pt;\" align=\"center\"> <img
 src=\"../images/lidar_plane.gif\" alt=\"LIDAR Illustration\"
 style=\"width: 130px; height: 155px;\"></p>
      <p align=\"center\"><a href=\"../../start.html\"><img 
	  src=\"../images/home.gif\" alt=\"Home\" border=\"0\"
 height=\"24\" width=\"125\"></a></p>
      <p align=\"center\"><a href=\"../purpose_LIDAR.html\"><img
 src=\"../images/purpose.gif\" alt=\"Purpose Link\"
 style=\"border: 0px solid ; width: 125px; height: 24px;\"></a></p>
      <p align=\"center\"><a href=\"../metadata.html\"><img
 src=\"../images/metadata.gif\" alt=\"Metadata Link\" border=\"0\" height=\"24\"
 width=\"125\"></a></p>
      <p align=\"center\"><a href=\"../collaborators.html\"><img
 src=\"../images/collaborators.gif\" alt=\"Collaborators Link\" border=\"0\" height=\"24\"
 width=\"125\"></a></p>
      <p align=\"center\"></p>
      </td>
<!-- END USGS Left Margin Template --> <td valign=\"top\" width=\"750\">
"

}



proc generateHtmlFooter { htmlout tilename } {
	puts $htmlout "</td>
    </tr>
  </tbody>
</table>
<hr align=\"left\" width=\"100%\">
<p><!-- BEGIN USGS Footer Template --> </p>
<p style=\"margin-top: 0pt; margin-bottom: 0pt;\" class=\"footerBar\"> <a
 href=\"http://www.usgs.gov/accessibility.html\"
 title=\"Accessibility Policy (Section 508)\">Accessibility</a> <a
 href=\"http://www.usgs.gov/foia/\" title=\"Freedom of Information Act\">FOIA</a>
<a href=\"http://www.usgs.gov/privacy.html\"
 title=\"Privacy policies of the U.S. Geological Survey\">Privacy</a> <a
 href=\"http://www.usgs.gov/policies_notices.html\"
 title=\"Policies and notices that govern information posted on 
USGS Web sites.\">Policies
and Notices</a>
</p>
<p class=\"footerText\"><a href=\"http://www.takepride.gov/\"><img
 src=\"../images/footer_graphic_takePride.jpg\"
 alt=\"Take Pride in America home page\"
 style=\"border: medium none ; float: right;\"
 title=\"Take Pride in America home page\" height=\"58\" width=\"60\"></a> <a
 href=\"http://www.usa.gov/\"><img src=\"../images/footer_graphic_firstGov.gif\"
 alt=\"USA Gov Link\"
 style=\"border: medium none ; float: right; margin-right: 10px;\"
 title=\"USA Gov: The U.S. Government's Official Web Portal\" height=\"26\"
 width=\"90\"></a> <a href=\"http://www.doi.gov/\">U.S. Department of the
Interior</a> | <a href=\"http://www.usgs.gov/\">U.S. Geological Survey</a>
<br>
URL: \[<abbr title=\"Digital Versital Disc\">DVD</abbr> Drive\]:\\html\\Tile_HTMLs\\$tilename.html<br>
Page Contact Information: <a
 href=\"http://coastal.er.usgs.gov/webmail.html\">Feedback</a><br>
Page Last Modified: January 15, 2008 (LJT)</p>
<hr>
<!-- END USGS Footer Template -->
</body>
</html>
"

}

proc generateHtmlBody { htmlout beimgname fsimgname tilename beheight bewidth } {
	# Scaling Image Size
	
	if { $bewidth < 600 } {
		set htmlimageheight $beheight
		set htmlimagewidth  $bewidth
	} elseif { $bewidth > 600 && $bewidth < 1200} {
		set htmlimageheight [ expr $beheight / 2 ]
		set htmlimagewidth [ expr $bewidth / 2 ]
	} elseif { $bewidth > 1200 && $bewidth < 1800 } {
		set htmlimageheight [ expr $beheight / 3 ]
		set htmlimagewidth [ expr $bewidth / 3 ]
	}  elseif { $bewidth > 1800 && $bewidth < 2400 } {
		set htmlimageheight [ expr $beheight / 4 ]
		set htmlimagewidth [ expr $bewidth / 4 ]
	} else {
		set htmlimageheight [ expr $beheight / 5 ]
		set htmlimagewidth [ expr $bewidth / 5 ]
	}
	
	
	if {$beheight > 800 } {
		if {$beheight > 800 && $beheight < 1200 } {
			set htmlimageheight [ expr $beheight / 2 ]
			set htmlimagewidth [ expr $bewidth / 2 ]
		} elseif { $beheight > 1200 && $beheight < 1800 } {
			set htmlimageheight [ expr $beheight / 3 ]
			set htmlimagewidth [ expr $bewidth / 3 ]
		} elseif { $beheight > 1800 && $beheight< 2400 } {
			set htmlimageheight [ expr $beheight / 4 ]
			set htmlimagewidth [ expr $bewidth / 4 ]
		} elseif {$beheight > 2400 } {
			set htmlimageheight [ expr $beheight / 5 ]
			set htmlimagewidth [ expr $bewidth / 5 ]
		}
	}
	
	puts $htmlout "		<h2 align \"left\">Quarter Quad Tile $tilename</h2>
										
							<h3>First Surface</h3>
							<p><img border=3 src=\"../images/jpeg_tiles/$fsimgname\" alt=\"First Surface\" height=\"$htmlimageheight\" width=\"$htmlimagewidth\"></p> 
								<ul type=\"disc\">
									<li><a href=\"../../Data_files/fs/$tilename/\">Link To Tile Directory</a></li><br>
									<li><a href=\"../../Data_files/fs/$tilename/n88_$tilename\_mf.las\">ASPRS LAS format .las file</a></li><br>
									<li><a href=\"../../Data_files/fs/$tilename/n88_$tilename\_mf_fs.xyz\">ASCII .xyz file</a></li><br>
									<li><a href=\"../../Data_files/fs/$tilename/n88_$tilename\_mf_fs_grd.TIF\"> GeoTIFF DEM (TIF)</a></li><br>
								</ul><br><br>
						
							<h3>Bare Earth</h3>
							<p><img border=3 src=\"../images/jpeg_tiles/$beimgname\" alt=\"Bare Earth\" height=\"$htmlimageheight\" width=\"$htmlimagewidth\"></p>
								<ul type=\"disc\">
									<li><a href=\"../../Data_files/be/$tilename/\">Link To Tile Directory</a></li><br>
									<li><a href=\"../../Data_files/be/$tilename/n88_$tilename\_mf.las\">ASPRS LAS format .las file</a></li><br>
									<li><a href=\"../../Data_files/be/$tilename/n88_$tilename\_mf_be.xyz\">ASCII .xyz file</a></li><br>
									<li><a href=\"../../Data_files/be/$tilename/n88_$tilename\_mf_be_grd.TIF\"> GeoTIFF DEM (TIF)</a></li><br>
								</ul><br><br>  
								"
					
}

proc get_file_list {  } {
        set rv [tk_dialog .y \
                Title "Select the jpeg files that you would like to put on the webpages" \
                questhead 0 \
                "Entire directory" \
                "Just a few selected files"
                 ]
        set dir "/"
        if { $rv == 0 } {
                set dir [ tk_chooseDirectory -initialdir $dir ]
                set fnlst [ glob -directory $dir *.jpg ] 
        }
        if {$rv == 1} {
        set fnlst [ tk_getOpenFile \
         -filetypes  {{ {jpg files} {*.jpg *.JPG } }}   \
         -multiple 1 \
         -initialdir $dir  ]
        }
		
		set fnlst [lsort -increasing -unique $fnlst]
        
		return $fnlst
}
################################# Main #######################################


 
#Selecting files
set debug [ open "debug.txt" w ]
puts $debug "start of debug"
set flist [ get_file_list ]
if { $flist == "" } {
         exit 0
}

#Variable declarations
set count 1


#Getting base html path
set splitfname [ file split [ lindex $flist 1] ]
puts $debug $splitfname
set basehtmlpname [ lindex $splitfname 0 ]


while { $count < [ expr [llength $splitfname] - 3 ]} {
	set temp [ lindex $splitfname $count ]
	puts $debug "$count [ expr [llength $splitfname] - 2 ] $basehtmlpname $temp"
	set basehtmlpname [file join $basehtmlpname $temp]
	incr count
}

file join $basehtmlpname html/
puts $debug $basehtmlpname

set count 0

#Start of while loop
while { $count < [ llength $flist ]  } {
	set img [image create photo]
	if { [ catch { $img read [ lindex $flist $count ] -shrink } ] } {
        puts "Cannot read image: [ lindex $flist $count ]";
    }
	set beheight [ image height $img ]
	set bewidth  [ image width $img ]
	
	puts $debug "$beheight $bewidth "
	
	puts $debug "[ lindex $flist $count ] [lindex $flist [ expr $count + 1]]"
	set nhtmlfname "[ string range [file rootname [ file tail [ lindex $flist $count ] ] ] 4 11 ].html"
	puts $debug $nhtmlfname
	set ohtmlname [ open "$basehtmlpname/Tile_HTMLs/$nhtmlfname" w ]
	generateHtmlHeader $ohtmlname
	generateHtmlBody $ohtmlname [ file tail [ lindex $flist $count ] ] [file tail [ lindex $flist [expr $count + 1] ] ] [ file rootname $nhtmlfname ] $beheight $bewidth
	generateHtmlFooter $ohtmlname [ file rootname $nhtmlfname ]
	incr count 2
}





exit 0




				






