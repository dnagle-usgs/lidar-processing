pro batch_grid, path, filename=filename, only_merged=only_merged, cell=cell, mode=mode, $
	z_grid_max = z_grid_max, z_grid_min=z_grid_min, area_threshold=area_threshold, $
	missing = missing, $
	plot_grids = plot_grids, max_elv_limit=max_elv_limit, min_elv_limit = min_elv_limit, $
	scale_down_by = scale_down_by, save_grid_plots = save_grid_plots, $
	write_geotiffs=write_geotiffs, utmzone = utmzone
   ; this procedure does gridding in a batch mode
   ; amar nayegandhi 05/14/03

start_time = systime(1)

if not keyword_set(filename) then begin
   ;search in the directory path to find all files with .bin or .edf extension
   if keyword_set(only_merged) then begin
    spawn, 'find '+path+' -name "*_merged*.bin"', fn_arr
    spawn, 'find '+path+' -name "*_merged*.edf"', fn_arr1
   endif else begin 
    spawn, 'find '+path+' -name "*.bin"', fn_arr
    spawn, 'find '+path+' -name "*.edf"', fn_arr1
   endelse	
    fn_arr_new = fn_arr+fn_arr1
    fn_arr = fn_arr_new
endif else begin
    fn_arr = path+filename
endelse

print, 'Number of files to grid: '+strcompress(string(n_elements(fn_arr)))
for i = 0, n_elements(fn_arr)-1 do begin
   ;read one file at a time
   spfn = strsplit(fn_arr(i), "/", /extract)
   n_spfn = n_elements(spfn)
   fname_arr = spfn(n_spfn-1)
   path = '/'+strjoin(spfn(0:n_spfn-2), '/')+'/'
   
   print, 'File number :'+strcompress(string(i+1))
   print, 'File name: '+fname_arr

   data_arr = read_yfile(path, fname_arr=fname_arr)
   
   ; find the corner points for the data tile
   spfn = strsplit(fname_arr, "_", /extract)
   we = long( strmid(spfn(1), 1))+1
   no = long(strmid(spfn(2), 1))
   print, 'Grid locations: West:'+strcompress(string(we))+'  North:'+strcompress(string(no))
   ;call gridding procedure
   grid_eaarl_data, *data_arr[0], cell=cell, mode=mode, zgrid=zgrid, xgrid=xgrid, ygrid=ygrid, $
	z_max = z_grid_max, z_min=z_grid_min, missing = missing, limits=[we-100,no-2099,we+2099,no+100], $
	area_threshold = area_threshold

   ptr_free, data_arr

   if (keyword_set(plot_grids)) then begin
	
	if not keyword_set(scale_down_by) then scale_down_by = 4
	if keyword_set(save_grid_plots) then begin
	  if (mode eq 1) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_fs_gridplot.tif"
	  if (mode eq 2) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_ba_gridplot.tif"
	  if (mode eq 3) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_be_gridplot.tif"
	    plot_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
			min_elv_limit = min_elv_limit, num=scale_down_by, save_grid_plot = pfname
	endif else begin
	    plot_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
			min_elv_limit = min_elv_limit, num=plotsize
	endelse
   endif

   if (keyword_set(write_geotiffs)) then begin
   	; make geotiff file name
	if not keyword_set(utmzone) then utmzone = 17
      if (mode eq 1) then $
        tfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_fs_geotiff.tif"
      if (mode eq 2) then $
	tfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_ba_geotiff.tif"
      if (mode eq 3) then $
	tfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_be_geotiff.tif"
	write_geotiff, tfname, xgrid, ygrid, zgrid, utmzone, cell
   endif

endfor

print, "Batch Gridding Complete.  Adios!"
end_time = systime(1)
run_time = (end_time - start_time)/60
print, 'Elapsed Time in minutes = ',strcompress(run_time, /remove_all)

return
end
