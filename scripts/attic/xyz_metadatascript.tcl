# This stand-alone Tcl script was left behind by Jim Lebonitte in his shared
# directory on getafix. It is being archived for historical reference.
# -rwxrwxr-x  1 jlebonit science 20195 May 22  2008 xyz_metadatascript.tcl

# Metadata Creation Script
# Original by Jim Lebonitte
# This script currently creates metadata for .las and .xyz files.  The XML
# information needs to be modified for each data set, but this was a very early
# version of this script.
# Good add-ons to this would be
# - Allow the changes to the XML be paramters (Basically only park name/keyword
#   locations)
# - Add support for geoTIFFS (Need to add a block to the XML saying the extents
#   of the data which can be obtained by using the geoTIFFS world file)
# - Add a GUI so people who do not know TCL/Programming can use this function
#   easily Cuts down on metadata creation time drastically.

lappend auto_path "[file join [ file dirname [info script]] ../../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ]"


# Recursive glob?
proc glob-r {{dir .} args} {
   set res {}
   foreach i [lsort [glob -nocomplain -dir $dir *]] {
      if {[file isdirectory $i]} {
         eval [list lappend res] [eval [linsert $args 0 glob-r $i]]
      } elseif {[llength $args]} {
         foreach arg $args {
            if {[string match $arg $i]} {
               lappend res $i
               break
            }
         }
      } else {
         lappend res $i
      }
   }
   return $res
} ;# JH

proc write_xml { filename mode  } {

	puts $filename "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
<!DOCTYPE metadata SYSTEM \"http://www.fgdc.gov/metadata/fgdc-std-001-1998.dtd\">
<metadata>
	<idinfo>
		<citation>
			<citeinfo>
				<title>EAARL Coastal Topography-Northern Gulf of Mexico</title>
				<geoform>remote-sensing image</geoform>
				<pubdate>Spring 2008</pubdate><serinfo><sername>Data Series</sername><issue>XXX A</issue></serinfo><pubinfo><pubplace>FISC Saint Petersburg</pubplace><publish>U. S. Geological Survey </publish></pubinfo></citeinfo>
		</citation>
		<descript>
			<abstract>ASCII xyz point cloud data were produced from remotely-sensed, geographically-referenced elevation measurements in cooperation with the U.S. Geological Survey (USGS) and National Air and Space Administration (NASA). Elevation measurements were collected over the area using the NASA Experimental Advanced Airborne Research Lidar (EAARL), a pulsed laser ranging system mounted onboard an aircraft to measure ground elevation, vegetation canopy, and coastal topography. The system uses high-frequency laser beams directed at the earth's surface through an opening in the bottom of the aircraft's fuselage. The laser system records the time difference between emission of the laser beam and the reception of the reflected laser signal in the aircraft. The plane travels over the target area at approximately 50 meters per second at an elevation of approximately 300 meters. The EAARL, developed by NASA at Wallops Flight Facility in Virginia, measures ground elevation with a vertical resolution of 15 centimeters. A sampling rate of 3 kHz or higher results in an extremely dense spatial elevation data set. Over 100 kilometers of coastline can be easily surveyed within a 3 to 4 hour mission time period. When subsequent elevation maps for an area are analyzed, they provide a useful tool to make management decisions regarding land development.</abstract>
			<purpose>The ASCII elevation data can be used to create raster Digital Elevation Models (DEMs). The purpose of this project is to produce highly detailed and accurate bare earth digital elevation map of the post hurricane Ivan data for use as a management tool and to make this map available to natural resource managers and research scientists.</purpose>
			<supplinf>Raw lidar data is not in a format that is generally usable by resource managers and scientists for scientific analysis. Converting dense lidar elevation data into a readily usable format without loss of essential information requires specialized processing. The U. S. Geological Survey has developed custom software to convert raw lidar data into a GIS compatible map product to be provided to GIS specialists, managers, and scientists. The primary tool used in the conversion process is Advanced Lidar Processing System (ALPS), a multi-tiered processing system developed by a USGS/NASA collaborative project. Specialized processing algorithms are used to convert raw waveform lidar data acquired by the EAARL to georeferenced spot (x,y,z) returns for \"first surface\" and \"bare earth\ topography. These data are then converted to the North American Datum of 1983 and the North American Vertical Datum of 1988 (using the Geoid 03 model).  The files are in the Quarter Quad tiling format and the exact tile location is contained in the filename at n88_########_mf_be where ####### is the Quarter Quad tile ID.</supplinf>
		</descript>
		<timeperd>
			<timeinfo>
				<sngdate>
					<caldate>20040919</caldate>
				</sngdate>
			</timeinfo>
			<current>ground condition</current>
		</timeperd>
		<status>
			<progress>Complete</progress>
			<update>None planned</update>
		</status>
		<spdom>
			
			<minalti>0.0</minalti><maxalti>55.5</maxalti><altunits>meters</altunits></spdom>
<keywords>
			<theme>
				<themekey>Lidar</themekey>
				<themekey>Experimental Advanced Airborne Research Lidar</themekey>
				<themekey>EAARL</themekey>
				<themekey>Digital Elevation Model</themekey>
				<themekey>elevation change</themekey>
				<themekey>laser altimetry</themekey>
				<themekey>derived surface</themekey>
				<themekey>resource management</themekey>
				<themekey>ALPS</themekey>
				<themekey>Advanced Lidar Processing System</themekey>
				<themekey>Hurricanes</themekey><themekey>Ivan</themekey></theme>
			<place>
				<placekey>Florida</placekey>
				<placekey>Mississippi</placekey>
				<placekey>Alabama</placekey></place>
			<stratum><stratkey>$mode</stratkey></stratum><temporal><tempkey>2004</tempkey></temporal></keywords>
		<accconst>Any use of these data signifies a user's agreement to comprehension and compliance of the U.S. Geological Survey Standard Disclaimer. Ensure all portions of metadata are read and clearly understood before using these data in order to protect both the user and the U.S. Geological Survey's interests. See section 6.3 Distribution Liability.</accconst>
		<useconst>Although the U.S. Geological Survey is making these data sets available to others who may find the data of value, the U.S. Geological Survey does not warrant, endorse, or recommend the use of this data for any given purpose. The user assumes the entire risk related to the use of these data.</useconst>
		<ptcontac>
			<cntinfo>
				<cntperp>
					<cntper>Dr. John C. Brock</cntper>
					<cntorg>U. S. Geological Survey, FISC St. Peterburg</cntorg>
				</cntperp>
				<cntpos>Research Oceanographer</cntpos>
				<cntaddr>
					<addrtype>mailing and physical address</addrtype>
					<address>600 4th Street South</address>
					<city>Saint Petersburg</city>
					<state>FL</state>
					<postal>33701</postal>
					<country>USA</country>
				</cntaddr>
				<cntvoice>727 803-8747 ext3088</cntvoice>
				<cntfax>727 803-2031</cntfax>
				<cntemail>jbrock@usgs.gov</cntemail>
				<hours>M-F 8:00-5:00 EST</hours>
			</cntinfo>
			<cntinfo>
				<cntperp>
					<cntper>Amar Nayegandhi</cntper>
					<cntorg>Jacobs Technology, Inc., contracted to U. S. Geological Survey, FISC, St. Petersburg</cntorg>
				</cntperp>
				<cntpos>Computer Scientist</cntpos>
				<cntaddr>
					<addrtype>mailing and physical address</addrtype>
					<address>600 4th Street South</address>
					<city>Saint Petersburg</city>
					<state>FL</state>
					<postal>33701</postal>
					<country>USA</country>
				</cntaddr>
				<cntvoice>727 803-8747 ext3026</cntvoice>
				<cntfax>727 803-2031</cntfax>
				<cntemail>anayegandhi@usgs.gov</cntemail>
				<hours>M-F 8:00-5:00 EST</hours>
			</cntinfo>
		</ptcontac>


		<datacred>The U. S. Geological Survey is providing these data \"as is\, and the U. S. Geological Survey disclaims any and all warranties, whether expressed or implied, including (without limitation) any implied warranties of merchantability or fitness for a particular purpose. In no event will the U. S. Geological Survey be liable to you or to any third party for any direct, indirect, incidental, consequential, special, or exemplary damages or lost profits resulting from any use or misuse of these data. Acknowledgement of the U.S. Geological Survey, Florida Integrated Science Center as a data source would be appreciated in products developed from these data, and such acknowledgement as is standad for citation and legal practices for data source is expected by users of this data. Sharing new data layers developed directly from these data would also be appreciated by the U. S. Geological Survey staff. Users should be aware that comparisons with other data sets for the same area from other time periods may be inaccurate due to inconsistencies resulting from changes in photo interpretation, mapping conventions, and digital processes over time. These data are not legal documents and are not to be used as such.</datacred>
		<native>Microsoft Windows XP Version 5.1 (Build 2600) Service Pack 2; ESRI ArcMap 9.2.2.1350</native>
		<crossref><citeinfo><pubdate>To be published </pubdate><title>Small footprint, waveform-resolving Lidar estimation of submerged and subcanopy topography in coastal environments</title><serinfo><sername>International Journal of Remote Sensing</sername></serinfo><origin>Nayegandhi, A., Brock, J.C., Wright, C.W</origin></citeinfo></crossref><crossref><citeinfo><pubdate>2002</pubdate><title>Basis and methods of NASA Airborne Topographic Mapper lidar surveys for coastal studies</title><edition>18(1), pp. 1-13</edition><serinfo><sername>Journal of Coastal Research</sername><issue>18(1), pp. 1-13</issue></serinfo><origin>Brock, J.C., C.W. Wright, A.H. Sallenger, W.B. Krabill, and R.N. Swift</origin></citeinfo></crossref><crossref><citeinfo><origin>Sallenger, A.H., C.W. Wright, and J. Lillycrop</origin><pubdate>2005</pubdate><title>Coastal impacts of the 2004 hurricanes measured with airborne lidar; initial results</title><edition>73(2&amp;3), pp. 10-14</edition><serinfo><sername>Shore and Beach</sername><issue>73(2&amp;3), pp. 10-14</issue></serinfo></citeinfo></crossref></idinfo>
	<dataqual>
		<attracc>
			<attraccr>The expected accuracy of the measured variables are as follows: attitude within 0.07 degree, 3cm nominal laser ranging accuracy, and vertical elevation accuracy of +/-15cm for the topographic surface. Quality checks are built into the data-processing software.</attraccr>
		</attracc>
		<posacc>
			<horizpa>
				<horizpar>Raw elevation measurements have been determined to be within 1 meter horizontal accuracy.</horizpar>
			</horizpa>
			<vertacc>
				<vertaccr>Elevations of the DEM are vertically consistent with the point elevation data, +/-15cm.</vertaccr>
			</vertacc>
		</posacc>
		<lineage>
			<srcinfo>
				<srctime>
					<timeinfo>
						<sngdate>
							<caldate>20040919</caldate>
						</sngdate>
					</timeinfo>
					<srccurr>ground condition</srccurr>
				</srctime>
			</srcinfo>
			<procstep>
				<procdesc>The data are collected using a Cessna 310 aircraft. The NASA Experimental Advanced Airborne Research Lidar (EAARL) laser scanner collects the data using a green (532nm) raster scanning laser, while a digital camera acquires a visual record of the flight. The data are stored on hard drives and archived at the U. S. Geological Survey, FISC St. Petersburg office and the NASA office at Wallops Flight Facility. The navigational data are processed at Wallops Flight Facility. The navigational and raw data are then downloaded into the Advanced Lidar Processing System (ALPS). Data are converted from units of time to x,y,z points for elevation. The derived surface data can then be converted into raster data (geotiffs).</procdesc>
				<procdate>May 2006-December 2007</procdate>
				<proccont><cntinfo><cntaddr><addrtype>mailing and physical address</addrtype><address>600 4th Street South</address><city>Saint Petersburg</city><state>FL</state><postal>33703</postal><country>USA</country></cntaddr><cntvoice>727-803-8747</cntvoice><hours>M-F, 8:00-5:00 EST</hours><cntemail>anayegandhi@usgs.gov</cntemail><cntorgp><cntorg>Jacobs Technology, U. S. Geological Survey, FISC St. Petersburg</cntorg><cntper>Amar Nayegandhi</cntper></cntorgp><cntpos>Computer Scientist</cntpos></cntinfo></proccont></procstep>
			<procstep>
				<procdesc>Metadata imported into ArcCatalog from XML file.</procdesc>
				<proccont><cntinfo><cntaddr><addrtype>mailing and physical address</addrtype><address>600 4th Street South</address><city>Saint Petersburg</city><state>FL</state><postal>33701</postal><country>USA</country></cntaddr><cntvoice>727-803-8747</cntvoice><cntorgp><cntorg>Eckerd College, contracted to U. S. Geological Survey</cntorg><cntper>Laurinda Travers</cntper></cntorgp></cntinfo></proccont><procsv>ESRI ArcCatalog 9.2.2.1350</procsv><procdate>March 2008</procdate></procstep>
		</lineage>
	</dataqual>
	<spdoinfo>
		<direct>Raster</direct>
		<ptvctinf>
			<sdtsterm>
				<sdtstype>Point</sdtstype>
			</sdtsterm>
		</ptvctinf>
	</spdoinfo>
	<spref>
		<horizsys>
			<planar>
				<gridsys>
					<gridsysn>Universal Transverse Mercator</gridsysn>
					<utm>
						<utmzone>16</utmzone>
						<transmer>
							<sfctrmer>0.999600</sfctrmer>
							<longcm>-87.000000</longcm>
							<latprjo>0.000000</latprjo>
							<feast>500000.000000</feast>
							<fnorth>0.000000</fnorth>
						</transmer>
					</utm>
				</gridsys>
				<planci>
					<plance>row and column</plance>
					<coordrep>
						<absres>2.000000</absres>
						<ordres>2.000000</ordres>
					</coordrep>
					<plandu>meters</plandu>
				</planci>
			</planar>
			<geodetic>
				<horizdn>North American Datum of 1983</horizdn>
				<ellips>Geodetic Reference System 80</ellips>
				<semiaxis>6378137.000000</semiaxis>
				<denflat>298.257222</denflat>
			</geodetic>
			<cordsysn><geogcsn>GCS_North_American_1983</geogcsn><projcsn>NAD_1983_UTM_Zone_16N</projcsn></cordsysn></horizsys>
		<vertdef>
			<altsys>
				<altdatum>North American Vertical Datum of 1988</altdatum>
				<altres>0.15m</altres>
				<altunits>meters</altunits>
				<altenc>Explicit elevation coordinate included with horizontal coordinates</altenc>
			</altsys>
		</vertdef>
	</spref>
	<eainfo>
		<overview>
			<eadetcit>The variables measured by EAARL are: distance between aircraft and GPS satellites (m), attitude information (roll, pitch, heading in degrees), scan angle (degrees), second of the epoch (sec), and 1ns time-resolved return intensity waveform (digital counts). Z value is referenced to orthometric elevations derived from National Geodetic Survey Geoid Model, Geoid03.</eadetcit>
		</overview>
	</eainfo>
	<distinfo>
		<distrib>
			<cntinfo>
				<cntpos>Aministrative Assistant</cntpos>
				<cntaddr>
					<addrtype>mailing address</addrtype>
					<address>600 4th Street South</address>
					<city>Saint Petersburg</city>
					<state>FL</state>
					<postal>33701</postal>
					<country>USA</country>
				</cntaddr>
				<cntvoice>727 803-8747</cntvoice>
				<cntemail>eklipp@usgs.gov</cntemail>
				<hours>M-F 8:30-5:00 EST</hours>
				<cntorgp><cntorg>Jacobs Technology contracted to U. S. Geological Survey</cntorg><cntper>Emily Klipp</cntper></cntorgp></cntinfo>
		</distrib>
		<resdesc>Lidar Point Cloud (ascii xyz)</resdesc>
		<distliab>The U. S. Geological Survey shall not be held liable for improper or incorrect use of the data described and/or contained herein. These data and related graphics are not legal documents and are not intended to be used as such. The information contained in these data is dynamic and may change over time. The data are not better than the original sources from which they were derived. It is the responsibility of the data user to use the data appropriately and consistent within the limitations of geospatial data in general and these data in particular. The related graphics are intended to aid the data user in acquiring relevant data; it is not appropriate to use the related graphics as data. The U. S. Geological Survey gives no warranty, expressed or implied, as to the accuracy, reliability, or completeness of these data. It is strongly recommended that these data are directly acquired from a U. S. Geological Survey server and not indirectly through other sources which may have changed the data in some way. Although these data have been processed successfully on a computer system at the U. S. Geological Survey, no warranty expressed or implied is made regarding the utility of the data on another system or for general or scientific purposes, nor shall the act of distribution constitute any such warranty. This disclaimer applies both to individual use of the data and aggregate use with other data.</distliab>
		<stdorder>
			<nondig>Contact USGS for Details</nondig>
		</stdorder>
		<custom>Call USGS for Details</custom>
		<availabl><timeinfo><sngdate><caldate>20040919</caldate></sngdate></timeinfo></availabl></distinfo>
	<metainfo>
		<metd>20080307</metd>
		<metc>
			<cntinfo>
				<cntorgp>
					<cntorg>Eckerd College, contracted to U. S. Geological Survey</cntorg>
					<cntper>Laurinda Travers</cntper>
				</cntorgp>
				<cntaddr>
					<addrtype>mailing address</addrtype>
					<address>600 4th Street South</address>
					<city>Saint Petersburg</city>
					<state>FL</state>
					<postal>33701</postal>
					<country>USA</country>
				</cntaddr>
				<cntvoice>727-803-8747</cntvoice>
				<cntemail>ltravers@usgs.gov</cntemail>
			</cntinfo>
		</metc>
		<metstdn>FGDC Content Standards for Digital Geospatial Metadata</metstdn>
		<metstdv>FGDC-STD-001-1998</metstdv>
		<mettc>local time</mettc>
		<metextns>
			<onlink>http://www.esri.com/metadata/esriprof80.html</onlink>
			<metprof>ESRI Metadata Profile</metprof>
		</metextns>
	</metainfo>
	<Esri><ModDate>20080307</ModDate><ModTime>13395200</ModTime><MetaID>{27BFDCE8-62FE-4BFF-88EC-CB7E1B36EAB5}</MetaID><CreaDate>20080211</CreaDate><CreaTime>13474000</CreaTime><SyncOnce>TRUE</SyncOnce></Esri><mdDateSt Sync=\"TRUE\">20080307</mdDateSt><distInfo><distributor><distorTran><onLineSrc><linkage Sync=\"TRUE\">file://\\IGSAFPESWS126\\D$\\Science_Support_PC\\L_Travers\\A_Nayegandhi\\Ivan_Lidar_data\\GUIS_DS_XXX\\metadata\\meta_temp</linkage><protocol Sync=\"TRUE\">Local Area Network</protocol></onLineSrc></distorTran></distributor></distInfo></metadata>
"

}



proc get_file_list {  } {
        set rv [tk_dialog .y \
                Title "Select the directory of files that metadata needs to be created for" \
                questhead 0 \
                "Entire directory" \
                "Just a few selected files"
                 ]
        set dir "/"
        if { $rv == 0 } {
                set dir [ tk_chooseDirectory -initialdir $dir ]
                set fnlst [ glob-r $dir *.las *.xyz ] 
        }
        if {$rv == 1} {
        set fnlst [ tk_getOpenFile \
         -filetypes  {{ {LAS Files} {*.las} }}   \
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
set count 0
set mode "First Surface"

while { $count < [ llength $flist ]} {
	set xmlfilename [lindex $flist $count].xml
	puts $debug [lindex $flist $count]
	set oxml [open $xmlfilename w]
	write_xml $oxml $mode
	close $oxml
	incr count

}

exit 0
