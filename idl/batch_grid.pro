pro batch_grid, path, filename=filename, only_merged=only_merged, cell=cell, mode=mode, $
	z_grid_max = z_grid_max, z_grid_min=z_grid_min, missing = missing, $
	plot_grids = plot_grids, max_elv_limit=max_elv_limit, min_elv_limit = min_elv_limit, $
	scale_down_by = scale_down_by, save_grid_plots = save_grid_plots, $
	write_geotiffs=write_geotiffs, utmzone = utmzone
   ; this procedure does gridding in a batch mode
   ; amar nayegandhi 05/14/03

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
   so = long(strmid(spfn(2), 1))+1
   ;call gridding procedure
   grid_eaarl_data, *data_arr[0], cell=cell, mode=mode, zgrid=zgrid, xgrid=xgrid, ygrid=ygrid, $
	z_max = z_grid_max, z_min=z_grid_min, missing = missing, limits=[we,so,we+1999,so+1999]

   ptr_free, data_arr

   if (keyword_set(plot_grids)) then begin
	symbol_circle
	!p.background=255
	!p.color=0
	!p.font=1
	!p.region = [0.03,0,0.9,0.94]
	!p.psym=8
	!p.symsize=0.4
	!p.thick=2.0
	loadct, 39
	if not keyword_set(scale_down_by) then scale_down_by = 4
	if keyword_set(save_grid_plots) then begin
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_gridplot.tif"
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
        tfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_geotiff.tif"
	write_geotiff, tfname, xgrid, ygrid, zgrid, utmzone, cell
   endif

endfor

print, "Batch Gridding Complete.  Adios!"
return
end
