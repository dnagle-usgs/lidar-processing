;   $Id$

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
	  data = {dat2, RN:0L, MNORTH:0L, MEAST:0L, MELEVATION:0L, NORTH:0L, EAST:0L, ELEVATION:0L, INTENSITY:0S}
	  data_arr = replicate(data,recs)
	 end
      4: begin
	  ;this structure is what GEO is in ytk-EAARL
	  data = {dat3, RN:0L, NORTH:0L, EAST:0L, SR2:0S, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, BOTTOM_PEAK:0S, FIRST_PEAK:0S, DEPTH:0S}
	  data_arr = replicate(data,recs)
	 end
      5: begin
	  ; this structure is what VEG (old format) is in ytk-EAARL...
	  data = {dat4, RN:0L, NORTH:0L, EAST:0L, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, FELV:0S, FINT:0S, LELV:0S, LINT:0S, NX: 0B}
	  data_arr = replicate(data, recs)
	 end
      6: begin
	  ; this structure is what bare earth VEG_ (new format) is in ytk-EAARL...
	  data = {dat5, RN:0L, NORTH:0L, EAST:0L, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, FELV:0L, FINT:0S, LELV:0L, LINT:0S, NX: 0B}
	  data_arr = replicate(data, recs)
	 end
      7: begin
   	  ;this structure is the same as CVEG_ALL in ytk-EAARL...
	  data = {dat6, RN:0L, NORTH:0L, EAST:0L, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, INTENSITY:0S, NX:0B, SOE:0D}
	  data_arr = replicate(data,recs)
  	 end
      8: begin
	  ;this structure is the same as VEG__ in ytk-EAARL...
	  data = {dat7, RN:0L, NORTH:0L, EAST:0L, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, LNORTH:0L, LEAST:0L, LELV:0L, FINT:0S, LINT:0S, NX: 0B}
	  data_arr = replicate(data,recs)
	 end
     101:begin
	  ;this structure is the new FS with the soe (time of day) added...
	  data = {dat8, RN:0L, MNORTH:0L, MEAST:0L, MELEVATION:0L, NORTH:0L, EAST:0L, $
			ELEVATION:0L, INTENSITY:0S, SOE:0D}
	  data_arr = replicate(data,recs)
	 end
     102:begin
	  ;GEO with SOE
	  data = {dat9, RN:0L, NORTH:0L, EAST:0L, SR2:0S, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, BOTTOM_PEAK:0S, FIRST_PEAK:0S, DEPTH:0S, SOE:0D}
	  data_arr = replicate(data,recs)
	 end
     103:begin
	  ;VEG__ with SOE
	  data = {dat10, RN:0L, NORTH:0L, EAST:0L, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, LNORTH:0L, LEAST:0L, LELV:0L, FINT:0S, LINT:0S, NX: 0B, SOE:0D}
	  data_arr = replicate(data,recs)
	 end
     104:begin
	  ;CVEG_ALL with SOE
	  data = {dat11, RN:0L, NORTH:0L, EAST:0L, ELEVATION:0L, MNORTH:0L, MEAST:0L, $
			MELEVATION:0L, INTENSITY:0S, NX:0B, SOE:0D}
	  data_arr = replicate(data,recs)
  	 end
     1001:begin
	  ;BOTRET for bottom return statistics
	  data = {dat1001, RN:0L, IDX:0S, SIDX:0S, RANGE:0S, AC:0.0, CENT:0.0, $
			CENTIDX:0.0, PEAK:0.0, PEAKIDX:0S, SOE:0.0D}
	  data_arr = replicate(data,recs)
  	 end
endcase


return, data_arr
end
