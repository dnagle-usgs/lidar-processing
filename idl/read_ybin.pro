function read_ybin, path, fname_arr=fname_arr, type=type

;this procedure reads an yorick-written ybin file.
;amar nayegandhi 07/11/02
;the following types are supported:
;type='gga'; type='tans'; type='pnav'

if not keyword_set(type) then type='gga'

if not keyword_set(fname_arr) then begin
    ;search in the directory path to find all files with .ybin extension
    spawn, 'find '+path+' -name "*.ybin"', fn_arr
endif else fn_arr = path+fname_arr
bytord = 0L
;type =0L
nwpr = 0L
recs = 0L
nfiles = n_elements(fn_arr)

data_ptr = ptrarr(nfiles, /allocate_heap)

for i = 0, nfiles-1 do begin
  openr, rlun, fn_arr[i], /get_lun
  readu, rlun, recs
  
  ;define the array of data structures using the value of type.  
  data = define_ybin_struc(recs, type)

  ;now read the data
  A = assoc(rlun, data, 4)
  data = A(0)
  *data_ptr[i]=data

  free_lun, rlun
  close, rlun

endfor

return, data_ptr

ptr_free, data_ptr
end

function define_ybin_struc, recs, type
;this procedure defines the ybin data structure using the type keyword
;amar nayegandhi 07/11/02

case type of
     'gga': begin
	  ;this structure consists of float sod; double lat; double lon; float alt
	  data = {SOD:0.0, LAT:0.0, LON:0.0, ALT:0.0}
	  data_arr = replicate(data, recs)
	  end
    'tans': begin
	  ;this structure consists of   float somd; float roll; float pitch; float heading
	  data = {somd:0.0, roll:0.0, pitch:0.0, heading:0.0}
	  data_arr = replicate(data, recs)
	 end
    'pnav': begin
	  ;this structure consists of short sv; short flag; float sod; float pdop; float alt;
  	  ;float xrms; float veast; float vnorth; float vup; double lat; double lon
	  data = {sv:0S, flag:0S, sod:0.0, pdop:0.0, alt:0.0, xrms:0.0, veast:0.0, vnorth:0.0, vup:0.0, lat:0.0D, lon:0.0D}
	  data_arr = replicate(data,recs)
	 end
endcase


return, data_arr
end
