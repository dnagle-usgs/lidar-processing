pro batch_grid, path, filename=filename, rcfmode=rcfmode, searchstr=searchstr, $
	cell=cell, mode=mode, z_grid_max = z_grid_max, z_grid_min=z_grid_min, $
	area_threshold=area_threshold, dist_threshold=dist_threshold, $
	missing = missing, zbuf_plot=zbuf_plot, save_zbuf_plots = save_zbuf_plots, $
	zbuf_scale=zbuf_scale, maxelv = maxelv, minelv = minelv, $
	plot_grids = plot_grids, max_elv_limit=max_elv_limit, min_elv_limit = min_elv_limit, $
	scale_down_by = scale_down_by, save_grid_plots = save_grid_plots, $
	write_geotiffs=write_geotiffs, GE_plots=GE_plots, colorbar_plot = colorbar_plot, $
	utmzone = utmzone, datamode=datamode, datum_type=datum_type
   ; this procedure does gridding in a batch mode
   ; Set datamode to run batch grid on a set of files that are not divided into the 
   ;    traditional index/data tile format.  Setting this will override and disable the
   ;    creation of gridplots and zbuf plots however. To use the traditional batch grid
   ;    function, do not set datamode at all.
   ; added 11/14/2005:
   ; path: Path name where edf files are present
   ; filename = filename array if only 1 or a group of files are to be gridded. 
   ; rcfmode = (DEPRECATED) use keyword searchstr= instead
   ;		set to 0 to search for all edf or bin files
   ;		set to 1 to search for only rcf'd files
   ;		set to 2 to search for only ircf'd files 
   ; searchstr = search string for file search.  Default="*.edf"
   ; cell = grid cell dimension (default = 1m)
   ; mode = Type of EAARL data.  1 = Surface Topography, 2 = Bathymetry, 3 = Bare Earth under Vegetation
   ; z_grid_max = Maximum z value to consider during gridding
   ; z_grid_min = Minimum z value to consider during gridding, default = -100m
   ; area_threshold = maximum allowable area of a triangulated facet.  
   ;		This keyword ensures that large gaps are not gridded. Default = 200m^2
   ; dist_threshold = maximum allowable distance between 2 vertices of triangulated facet.
   ;			Default = 50m.  Increase this value to reduce "holes" in the data.
   ; missing = Missing value for no data points during gridding, default = -100m
   ; zbuf_plot = set to 1 to create the 'Z' buffer tif plots.
   ; save_zbuf_plots = set to 1 to save the tif plot to a file
   ; zbuf_scale = the scale of the zbuf plot.  Defaults to 1 (same scale as original grid).
   ; GE_plots = GE_plots set to 1 to make maps for Google Earth 
   ; max_elv_limit = the maximum elevation limit for the output (GE and zbuf) plot
   ; min_elv_limit = the minimum elevation limit for the output (GE and zbuf) plot
   ; scale_down_by = the value by which the output image will be scaled down by.
   ;		  if num=2, image is half the size. Default num=2.
   ; save_grid_plot = the output file name to which the image should be saved. 
   ; 		if geotif_file is set and save_grid_plot not set, 
   ;		then the filename is the same as geotif_file with a different extension (e.g. .gif).
   ; maxelv = the maximum elevation for the output (GE and zbuf) plot (overrides max_elv_limit)
   ; minelv = the minimum elevation for the output (GE and zbuf) plot (overrides min_elv_limit)
   ; colorbar_plot = set to 1 to write out a file that contains the colorbar with min and max values
   ; datum_type = data datum type 
   	; datum_type = 1 (default) for NAD83/NAVD88
   	; datum_type = 2 for WGS84/ITRF
   	; datum_type = 3 for NAD83/ITRF
   


   ; amar nayegandhi 05/14/03

start_time = systime(1)
if ((not keyword_set(rcfmode)) and (not keyword_set(searchstr))) then searchstr="*.edf"
if not keyword_set(filename) then begin
   if not keyword_set (searchstr) then begin
     if not keyword_set(rcfmode) then rcfmode = 0
     ;search in the directory path to find all files with .bin or .edf extension
     if (rcfmode eq 0) then begin
	   spawn, 'find '+path+' -name "*.bin"', fn_arr
	   spawn, 'find '+path+' -name "*.edf"', fn_arr1
     endif
     if (rcfmode eq 1) then begin 
     	   spawn, 'find '+path+' -name "*_rcf*.bin"', fn_arr
    	   spawn, 'find '+path+' -name "*_rcf*.edf"', fn_arr1
     endif
     if (rcfmode eq 2) then begin
	   spawn, 'find '+path+' -name "*_ircf*.bin"', fn_arr
	   spawn, 'find '+path+' -name "*_ircf*.edf"', fn_arr1
     endif
     fn_arr_new = fn_arr+fn_arr1
     fn_arr = fn_arr_new
   endif else begin
	spawn, 'find '+path+' -name "'+searchstr+'"', fn_arr
   endelse
endif else begin
    fn_arr = path+filename
endelse

if ((fn_arr[0] eq "") or (n_elements(fn_arr) eq 0)) then begin
	print, "No files selected to grid.  Goodbye."
	return
endif

;noaa = read_noaa_records('/home/anayegan/lidar-processing/noaa/bathy_data_keys_0_40m_min_max.txt')
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
   print, 'Data should be loaded. Continuing...'

   if (n_elements(*data_arr[0]) le 10) then continue
   
   if not keyword_set(datamode) then begin
     ; find the corner points for the data tile
     spfn = strsplit(fname_arr, "_", /extract)
     we = long( strmid(spfn(1), 1))+1
     no = long(strmid(spfn(2), 1))
     print, 'Grid locations: West:'+strcompress(string(we))+'  North:'+strcompress(string(no))
   endif
   ;call gridding procedure
   if keyword_set(datamode) then begin
      grid_eaarl_data, *data_arr[0],cell=cell,mode=mode,zgrid=zgrid,xgrid=xgrid,ygrid=ygrid, $
        z_max = z_grid_max, z_min=z_grid_min, missing = missing, $
        area_threshold = area_threshold, dist_threshold=dist_threshold, datamode=datamode
   endif else begin
      grid_eaarl_data, *data_arr[0], cell=cell, mode=mode, zgrid=zgrid, xgrid=xgrid, ygrid=ygrid, $
	z_max = z_grid_max, z_min=z_grid_min, missing = missing, limits=[we-100,no-2099,we+2099,no+100], $
	area_threshold = area_threshold, dist_threshold=dist_threshold
   endelse

   ptr_free, data_arr
   
  ; add_noaa_to_eaarl_grid, zgrid=zgrid, xgrid=xgrid, ygrid=ygrid, noaa=noaa

; Make sure grid_eaarl_data returned a grid..

   if not (keyword_set(xgrid)) then begin
	print, "No grids found, continuing to next file..."
	colin = 0
	continue
   endif
   if keyword_set(datamode) then begin
      print, "Cannot batch plot grids with datamode=1..."
   endif else begin
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
			min_elv_limit = min_elv_limit, num=scale_down_by
	endelse
   endif
   endelse

   if keyword_set(datamode) then begin
      print, "Cannot batch plot zbuf plots with datamode=1"
   endif else begin
   if (keyword_set(zbuf_plot)) then begin
	if not keyword_set(zbuf_scale) then zbuf_scale = 1
	if keyword_set(save_zbuf_plots) then begin
	  if (mode eq 1) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_fs_zbuf_gridplot.tif"
	  if (mode eq 2) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_ba_zbuf_gridplot.tif"
	  if (mode eq 3) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_be_zbuf_gridplot.tif"
	  plot_zbuf_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
		min_elv_limit = min_elv_limit, save_grid_plot = pfname, num=zbuf_scale, $
		minelv = minelv, maxelv = maxelv
	endif else begin
	    plot_zbuf_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
			min_elv_limit = min_elv_limit, num=zbuf_scale, $
			minelv = minelv, maxelv = maxelv
	endelse
   endif
   endelse


   if (keyword_set(write_geotiffs)) then begin
   	; make geotiff file name
	if not keyword_set(utmzone) then begin
		print, "UTM Zone Number not defined"
		return
	endif
      if (mode eq 1) then $
        tfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_fs_geotiff.tif"
      if (mode eq 2) then $
	tfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_ba_geotiff.tif"
      if (mode eq 3) then $
	tfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_be_geotiff.tif"
	write_geotiff, tfname, xgrid, ygrid, zgrid, utmzone, cell, datum_type=datum_type
   endif

  if (keyword_set(GE_plots)) then begin
	; make plots for Google Earth
	if (not keyword_set(GE_scale)) then GE_scale=2
	if (not keyword_set(filetype)) then filetype="png"
	if (mode eq 1) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_fs_GE."+filetype
	if (mode eq 2) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_ba_GE."+filetype
	if (mode eq 3) then $
	    pfname = path+(strsplit(fname_arr, '.', /extract))[0]+"_be_GE."+filetype
	make_GE_plots, xgrid=xgrid, ygrid=ygrid, zgrid=zgrid, max_elv_limit=max_elv_limit, $
		min_elv_limit = min_elv_limit, save_grid_plot = pfname, num=GE_scale, $
		minelv = minelv, maxelv = maxelv, filetype=filetype, topmax=1, botmin=1,$
		colorbar_plot = colorbar_plot
  endif

endfor

print, "Batch Gridding Complete.  Adios!"
end_time = systime(1)
run_time = (end_time - start_time)/60
print, 'Elapsed Time in minutes = ',strcompress(run_time, /remove_all)

return
end

pro batch_make_GE_plots, path, filename=filename, searchstr=searchstr, $ 
	max_elv_limit=max_elv_limit, min_elv_limit = min_elv_limit, num=num, $
	save_grid_plot=save_grid_plot, maxelv = maxelv, minelv = minelv, filetype=filetype,$
	topmax=topmax, botmin=botmin, settrans=settrans, colorbar_plot=colorbar_plot

; amar nayegandhi 11/16/2005

if (not keyword_set(searchstr)) then searchstr="*geotif*.tif"
if (not keyword_set(filename))  then begin
  spawn, 'find '+path+' -name "'+searchstr+'" ', fn_arr1
endif else begin
  fn_arr1 = path+filename
endelse

nfn = n_elements(fn_arr1)

print, 'Number of files to convert to GE plots: '+strcompress(string(nfn))
for i = 0, nfn-1 do begin
   ;read one file at a time
   print, "converting file "+strcompress(string(i+1))+" of "+strcompress(string(nfn)) 
   make_GE_plots, geotif_file=fn_arr1(i), $
   	max_elv_limit=max_elv_limit, min_elv_limit = min_elv_limit, num=num, $
	save_grid_plot=save_grid_plot, maxelv = maxelv, minelv = minelv, filetype=filetype,$
	topmax=topmax, botmin=botmin, settrans=settrans, colorbar_plot=colorbar_plot
endfor
   
print, "Batch conversion complete."

return 
end
