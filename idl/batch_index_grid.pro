; # vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab:
pro batch_index_grid, path, searchstr=searchstr, $
	cell=cell, mode=mode, z_grid_max = z_grid_max, z_grid_min=z_grid_min, $
	area_threshold=area_threshold, dist_threshold=dist_threshold, $
	missing = missing, $
	maxelv = maxelv, minelv = minelv, $
	plot_grids = plot_grids, max_elv_limit=max_elv_limit, min_elv_limit = min_elv_limit, $
	scale_down_by = scale_down_by, save_grid_plots = save_grid_plots, $
	write_geotiffs=write_geotiffs, GE_plots=GE_plots, colorbar_plot = colorbar_plot, $
	utmzone = utmzone, datamode=datamode
   ; this procedure does gridding of index tiles in a batch mode
   ; path: Input Path name to all index tiles
   ; searchstr = search string for file search.  Default="*.edf"
   ; cell = grid cell dimension (default = 5m)
   ; mode = Type of EAARL data.  1 = Surface Topography, 2 = Bathymetry, 3 = Bare Earth under Vegetation
   ; z_grid_max = Maximum z value to consider during gridding
   ; z_grid_min = Minimum z value to consider during gridding, default = -100m
   ; area_threshold = maximum allowable area of a triangulated facet.  
   ;		This keyword ensures that large gaps are not gridded. Default = 200m^2
   ; dist_threshold = maximum allowable distance between 2 vertices of triangulated facet.
   ;			Default = 50m.  Increase this value to reduce "holes" or "holidays" in the data.
   ; missing = Missing value for no data points during gridding, default = -100m
   ; GE_indx_plots = set to 1 to make png files for index tiles that can be used in Google Earth 
   ; max_elv_limit = the maximum elevation limit for the output (GE) plot
   ; min_elv_limit = the minimum elevation limit for the output (GE) plot
   ; scale_down_by = the value by which the output image will be scaled down by.
   ;		  if num=2, image is half the size. Default num=2.
   ; save_grid_plot = the output file name to which the image should be saved. 
   ; 		if geotif_file is set and save_grid_plot not set, 
   ;		then the filename is the same as geotif_file with a different extension (e.g. .gif).
   ; maxelv = the maximum elevation for the output (GE and zbuf) plot (overrides max_elv_limit)
   ; minelv = the minimum elevation for the output (GE and zbuf) plot (overrides min_elv_limit)
   ; colorbar_plot = set to 1 to write out a file that contains the colorbar with min and max values
   ;	
   ; datamode = set to 1 to run batch grid on a set of files that are not divided into the 
   ;    traditional index/data tile format.  Setting this will override and disable the
   ;    creation of gridplots and zbuf plots however. To use the traditional batch grid
   ;    function, do not set datamode at all.


   ; amar nayegandhi 06/08/06

start_time = systime(1)
if (not keyword_set(searchstr)) then searchstr="*.edf"
if (not keyword_set(cell)) then cell = 5
; find the number of index tile directories in the input directory
idirs = file_search(path, "i_e*", /test_directory)


if (idirs[0] eq "") then begin
   print, "No Index tile directories found. Goodbye."
   return
endif

for i=0, n_elements(idirs)-1 do begin
   print, 'Index Tile name: '+idirs(i);
   ;read all the edf files (defined by searchstr) in this directory
   tfiles = file_search(idirs(i), searchstr);
   if (tfiles[0] eq "") then begin
      print, "No data tile files found in this index directory"
      continue;
   endif
   
   ; read one file at a time
   fname_arr = file_basename(tfiles);
   fname_dirs = file_dirname(tfiles);
   fname_tile_dir = file_basename(fname_dirs);
   fname_arr = fname_tile_dir+"/"+fname_arr;

   ; find number of records in the index tile
   nsamples = read_nrecords(idirs(i)+'/', fname_arr=fname_arr)
   
   if nsamples le 10 then continue;

   if nsamples lt 1000000 then begin
	ndim = 1
   endif else begin
        ndim = nsamples/1000000
   endelse

   data_arr = read_yfile(idirs(i)+'/', fname_arr=fname_arr, ndim=ndim)

   print, 'Data should be loaded. Continuing...'

   itile = file_basename(idirs(i));
   iname_arr = idirs(i)+"/"+itile+".pbd"

   nsamples_orig = nsamples

   nsamples = 0

   for j=0, n_elements(data_arr)-1 do begin
      nsamples += n_elements(*data_arr[j]);
   endfor


   str_data_arr = (*data_arr[0])[0];
  
   data_all = replicate(str_data_arr, nsamples);
   dall_beg = 0;
   for j=0, n_elements(data_arr)-1 do begin
         ndata = n_elements(*data_arr(j))
         datan = *data_arr[j];
         datan = datan[0:n_elements(datan)-1];
         dall_end = dall_beg + n_elements(datan) -1;
         data_all(dall_beg:dall_end) = datan;
         dall_beg += n_elements(datan);
   endfor
   data_all = data_all[0:dall_end];
   nsamples = n_elements(data_all);

   ptr_free, data_arr

   ; find the corner points for the index tile
   spfn = strsplit(itile, "_", /extract)
   we = long( strmid(spfn(1), 1))+1
   no = long(strmid(spfn(2), 1))
   print, 'Grid locations: West:'+strcompress(string(we))+'  North:'+strcompress(string(no))
   ;call gridding procedure
   grid_eaarl_data, data_all,cell=cell,mode=mode,zgrid=zgrid,xgrid=xgrid,ygrid=ygrid, $
        z_max = z_grid_max, z_min=z_grid_min, missing = missing, $
	limits=[we-100,no-10099, we+10099, no+100],$
        area_threshold = area_threshold, dist_threshold=dist_threshold, datamode=2

   
   ; Make sure grid_eaarl_data returned a grid..

   if not (keyword_set(xgrid)) then begin
	   print, "No grids found, continuing to next file..."
	   colin = 0
	   continue
   endif
   if (keyword_set(plot_grids)) then begin
	   if not keyword_set(scale_down_by) then scale_down_by = 4
	   if keyword_set(save_grid_plots) then begin
	      if (mode eq 1) then $
	         pfname = path+(strsplit(iname_arr, '.', /extract))[0]+"_fs_gridplot.tif"
	      if (mode eq 2) then $
	         pfname = path+(strsplit(iname_arr, '.', /extract))[0]+"_ba_gridplot.tif"
	      if (mode eq 3) then $
	         pfname = path+(strsplit(iname_arr, '.', /extract))[0]+"_be_gridplot.tif"

 	      plot_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
			   min_elv_limit = min_elv_limit, num=scale_down_by, save_grid_plot = pfname
	   endif else begin
	         plot_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
		      	min_elv_limit = min_elv_limit, num=scale_down_by
	   endelse
   endif
  

   if (keyword_set(write_geotiffs)) then begin
   	; make geotiff file name
	   if not keyword_set(utmzone) then utmzone = 17
      if (mode eq 1) then $
         tfname = (strsplit(iname_arr, '.', /extract))[0]+"_fs_geotiff.tif"
      if (mode eq 2) then $
	      tfname = (strsplit(iname_arr, '.', /extract))[0]+"_ba_geotiff.tif"
      if (mode eq 3) then $
	      tfname = (strsplit(iname_arr, '.', /extract))[0]+"_be_geotiff.tif"
	   write_geotiff, tfname, xgrid, ygrid, zgrid, utmzone, cell
   endif

   if (keyword_set(GE_plots)) then begin
	   ; make plots for Google Earth
	   if (not keyword_set(GE_scale)) then GE_scale=2
	   if (not keyword_set(filetype)) then filetype="png"
	   if (mode eq 1) then $
	       pfname = (strsplit(iname_arr, '.', /extract))[0]+"_fs_GE."+filetype
	   if (mode eq 2) then $
	       pfname = (strsplit(iname_arr, '.', /extract))[0]+"_ba_GE."+filetype
	   if (mode eq 3) then $
	       pfname = (strsplit(iname_arr, '.', /extract))[0]+"_be_GE."+filetype
	   make_GE_plots, xgrid=xgrid, ygrid=ygrid, zgrid=zgrid, max_elv_limit=max_elv_limit, $
		   min_elv_limit = min_elv_limit, save_grid_plot = pfname, num=GE_scale, $
		   minelv = minelv, maxelv = maxelv, filetype=filetype, topmax=1, botmin=1,$
		   colorbar_plot = colorbar_plot
   endif
   ptr_free, data_arr

endfor

print, "Batch Gridding Complete.  Adios!"
end_time = systime(1)
run_time = (end_time - start_time)/60
print, 'Elapsed Time in minutes = ',strcompress(run_time, /remove_all)

return
end
