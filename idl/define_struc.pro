/*
   $Id$
*/
function define_struc, type, nwpr, recs
;this procedure defines the data structure using the value type
;amar nayegandhi 02/23/02

case type of
      1: begin
	  ;this structure consists of raster number(long), easting(long), northing(long), depth(int)
	  data = {dat, RN:0L, NORTH:0L, EAST:0L, DEPTH:0S}
	  data_arr = replicate(data, recs)
	 end
      2: begin
	  ;this structure consists of raster number(long), easting(long), northing(long), elevation(long)
	  data = {dat1, RN:0L, NORTH:0L, EAST:0L, ELV:0L}
	  data_arr = replicate(data, recs)
	 end
      3: begin
	 ;this structure is the similar to structure FS in ytk-EAARL
	  data = {dat2, RN:0L, MNORTH:0L, MEAST:0L, MELEVATION:0L, NORTH:0L, EAST:0L, ELEVATION:0L}
	  data_arr = replicate(data,recs)
	 end
      4: begin
	  ;this structure is what GEO is in ytk-EAARL
	  data = {dat3, RN:0L, NORTH:0L, EAST:0L, SR2:0S, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, BOTTOM_PEAK:0S, FIRST_PEAK:0S, DEPTH:0S}
	  data_arr = replicate(data,recs)
	 end
endcase


return, data_arr
end
