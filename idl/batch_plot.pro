pro batch_plot, path, filename=filename, only_rcf=only_rcf, min_z_limit=min_z_limit, max_z_limit=max_z_limit, $
		print_all_to = print_all_to, only_no_rcf = only_no_rcf, rcf_meta= rcf_meta

; this procedure batch plots all xyz data points and saves them as jpegs.
; amar nayegandhi 12/13/02.

if not keyword_set(filename) then begin
   ;search in the directory path to find all files with .bin extension
   if keyword_set(only_rcf) then begin
    spawn, 'find '+path+' -name "*_rcf.bin"', fn_arr
    spawn, 'find '+path+' -name "*_rcf.edf"', fn_arr1
   endif else begin  
    if keyword_set(only_no_rcf) then begin
     spawn, 'find '+path+' -name "*[0-9].bin"', fn_arr
     spawn, 'find '+path+' -name "*[0-9].edf"', fn_arr1
    endif else begin
     spawn, 'find '+path+' -name "*.bin"', fn_arr
     spawn, 'find '+path+' -name "*.edf"', fn_arr1
    endelse
   endelse
   fn_arr_new = fn_arr+fn_arr1
   fn_arr = fn_arr_new
endif else begin
   fn_arr = path+filename
endelse

for i = 0, n_elements(fn_arr)-1 do begin
   ;read one file at a time
   spfn = strsplit(fn_arr(i), "/", /extract)
   n_spfn = n_elements(spfn)
   fname_arr = spfn(n_spfn-1)
   path = '/'+strjoin(spfn(0:n_spfn-2), '/')+'/'
   ;prange = spfn(n_spfn-2)
   spp = strsplit(fname_arr, "_", /extract)
   if spp(0) eq 't' then range_off = 2000
   if spp(0) eq 'i' then range_off = 12000
   px = strmid(spp(1), 1)
   px = long(px)
   py = strmid(spp(2), 1)
   py = long(py)
   
   prange = [px, px + range_off, py-range_off, py]

   if stregex(spp(n_elements(spp)-1), "rcf", /boolean) eq 0 then begin
       dpos = strpos(spp(n_elements(spp)-1), ".")
       date = strmid(spp(n_elements(spp)-1), 0, dpos)
   endif else begin
       if keyword_set(rcf_meta) then begin
         rcf_params = spp(n_elements(spp)-3)+spp(n_elements(spp)-2)
       endif
       date = spp(n_elements(spp)-4)
   endelse

   if keyword_set(rcf_meta) then begin
     title = "Bathymetry Plot. Tile Location: "+spp(1)+"\n Date/RCF: "+date+" "+rcf_params
   endif else begin
     title = "Bathymetry Plot. Date: "+date+" Tile Location: "+spp(1)+" "+spp(2)
   endelse
     

   data_arr = read_yfile(path, fname_arr=fname_arr)

   ; make jpeg file name
   tfname = path+(strsplit(fname_arr, '.', /extract))[0]+".tif"
   
   
   plot_xyz_bath, data_arr, min_z_limit=min_z_limit, max_z_limit=max_z_limit, $
	plot_range=prange, title=title, win = win, bathy=1, make_tiff=tfname
   

   if keyword_set(print_all_to) then begin
        spawn, 'lp -d'+print_all_to+' '+tfname
   endif

   ptr_free, data_arr
   
endfor

return
end
   
