pro  grid_eaarl_data, data, cell=cell, mode=mode, zgrid=zgrid, xgrid=xgrid, ygrid=ygrid, $
	z_max = z_max, z_min=z_min, missing = missing, limits=limits, $
	area_threshold=area_threshold, dist_threshold = dist_threshold, $
	datamode=datamode
  ; this procedure does tinning / gridding on eaarl data
  ; amar nayegandhi 5/14/03.
  ; INPUT KEYWORDS:
	; data = EAARL data_array 
	; cell = grid cell size, default = 1 (1mx1m)
	; mode = Type of EAARL data.  1 = Surface Topography, 2 = Bathymetry, 3 = Bare Earth under Vegetation
	; zgrid = Returned zgrid array containing gridded elevation values in meters
  	; xgrid = Returned xgrid array containing gridded x values in meters
	; ygrid = Returned ygrid array containing gridded y values in meters
	; z_max = Maximum z value to consider during gridding
	; z_min = Minimum z value to consider during gridding, default = -100m
	; missing = Missing value for no data points during gridding, default = -32767m
	; datamode = set to 3 if you want to use the function in index tile mode
	;	     set to 2 if you want to use the function in data tile mode 	
	;	     set to 1 if you want to use the function in non-data or non-index tile mode


  if (not keyword_set(cell)) then cell = 1  
  if (not keyword_set(z_min)) then z_min = -100L
  if (not keyword_set(missing)) then missing = -32767L
  if (not keyword_set(area_threshold)) then area_threshold = 200
  if (not keyword_set(dist_threshold)) then dist_threshold = 50
  if (not keyword_set(limits)) then begin
	; get the limits from the input data set
	limits = [min(data.east),min(data.north),max(data.east),max(data.north)]/100.
  endif

  print, "    triangulating..."
  if ((mode eq 1) OR (mode eq 2)) then begin
    triangulate, float(data.east/100.), float(data.north/100.), tr, b
  endif else begin
    triangulate, float(data.least/100.), float(data.lnorth/100.), tr, b
  endelse

  ; now remove the large triangles by comparing the area to the threshold
  ; tr returns the indices of the array
  print, "    removing large triangles using area threshold..."
  xa = double(data(tr(0,*)).east/100.)
  xb = double(data(tr(1,*)).east/100.)
  xc = double(data(tr(2,*)).east/100.)
  ya = double(data(tr(0,*)).north/100.)
  yb = double(data(tr(1,*)).north/100.)
  yc = double(data(tr(2,*)).north/100.)
  area = abs((xb*ya-xa*yb)+(xc*yb-xb*yc)+(xa*yc-xc*ya))/2

  aidx = where(area lt area_threshold)
  tr = tr(*,aidx)

  print, "    removing spiderweb effects using distance threshold..."
  ; find the lengths of the 3 sides of the triangle using the distance formula
  d1sq = reform((double(data(tr(0,*)).east/100. - data(tr(1,*)).east/100.))^2 + $
	    (double(data(tr(0,*)).north/100. - data(tr(1,*)).north/100.))^2)
  d2sq = reform((double(data(tr(1,*)).east/100. - data(tr(2,*)).east/100.))^2 + $
	    (double(data(tr(1,*)).north/100. - data(tr(2,*)).north/100.))^2)
  d3sq = reform((double(data(tr(2,*)).east/100. - data(tr(0,*)).east/100.))^2 + $
	    (double(data(tr(2,*)).north/100. - data(tr(0,*)).north/100.))^2)
  dsq = max([transpose(d1sq), transpose(d2sq), transpose(d3sq)], dimension=1)
  didx = where(dsq le dist_threshold^2)
  tr = tr(*,didx)
  
  print, "    gridding..."
  case mode of 
  1: begin
	  zgrid = trigrid(float(data.east/100.), float(data.north/100.), $
	    float(data.elevation/100.), tr, [cell,cell], [limits], $
	    xgrid=xgrid, ygrid=ygrid, missing=missing, max_value = z_max, min_value = z_min)
     end
  2: begin
	  zgrid = trigrid(float(data.east/100.), float(data.north/100.), $
	    float((data.depth+data.elevation)/100.), tr, [cell,cell], [limits], $
	    xgrid=xgrid, ygrid=ygrid, missing=missing, max_value = z_max, min_value = z_min)
     end
  3:begin
	  zgrid = trigrid(float(data.east/100.), float(data.north/100.), $
	    float(data.lelv/100.), tr, [cell,cell], [limits], $
	    xgrid=xgrid, ygrid=ygrid, missing=missing, max_value = z_max, min_value = z_min)
    end
  endcase

  if (not keyword_set(datamode)) then datamode = 2  

  if (datamode eq 2) then begin
     c1 = 100/cell
     c2 = 2000/cell + 100/cell 
     zgrid = zgrid(c1:c2, c1:c2)
     xgrid = xgrid(c1:c2)
     ygrid = ygrid(c1:c2)
  endif

  if (datamode eq 3) then begin
     c1 = 100/cell
     c2 = 10000/cell + 100/cell
     zgrid = zgrid(c1:c2, c1:c2)
     xgrid = xgrid(c1:c2)
     ygrid = ygrid(c1:c2)
  endif
return
end

pro plot_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
		      min_elv_limit = min_elv_limit, num=num, save_grid_plot=save_grid_plot, $
		      datamode=datamode
  ; this procedure will make a color coded grid plot
  ; amar nayegandhi 5/14/03
  thisdevice = !d.name
  set_plot, 'X'
  symbol_circle
  !p.background=255
  !p.color=0
  !p.font=1
  !p.region = [0.03,0,0.9,0.94]
  !p.psym=8
  !p.symsize=0.4
  !p.thick=2.0
  loadct, 39 
  print, "    plotting gridded data..."
  if (not keyword_set (max_elv_limit)) then max_elv_limit = 100000L
  if (not keyword_set (min_elv_limit)) then min_elv_limit = -100000L 
  if (not keyword_set (num)) then num = 1

  grid_we_limit = xgrid[0]
  grid_ea_limit = xgrid[n_elements(xgrid)-1]
  grid_so_limit = ygrid[0]
  grid_no_limit = ygrid[n_elements(ygrid)-1]
  idx = where(zgrid ne -100, complement=idx1)
  if idx[0] ne -1 then begin
    max_elv = max(zgrid[idx], min = min_elv)
  endif else begin
     max_elv = -100
     min_elv = -100
  endelse

  if max_elv gt max_elv_limit then max_elv = max_elv_limit
  if min_elv lt min_elv_limit then min_elv = min_elv_limit
 
  case num of 
      4: begin
	xsize = 850 & ysize = 650
      end
      6: begin
	xsize = 700 & ysize = 500
      end
   else: begin
	xsize = 900 & ysize = 700
      end
  endcase
   
  window, 0, xsize = xsize, ysize = ysize, retain=2, title = 'Gridded Image'

  zgrid_i = bytscl(zgrid, max=max_elv, min=min_elv, top=255)

  ; make missing values white
  if (idx1[0] ne -1) then zgrid_i[idx1] = 255

  zgrid_i_sb2 = congrid(zgrid_i,n_elements(xgrid)/num,n_elements(ygrid)/num)

  ;Set up the overview image plot area (ie, nodata call to plot):
  plot, [grid_we_limit-1,grid_ea_limit], [grid_so_limit-1,grid_no_limit], $
        /nodata, xstyle=1, ystyle=1, ticklen = -0.02, xtitle= 'UTM Easting (m)', $
        ytitle= 'UTM Northing (m)', charsize=1.5, charthick=1.5, $
        position = [199,99,(n_elements(xgrid)/num)+200,(n_elements(ygrid)/num)+100], /device, $
        ytickformat = '(I10)', ycharsize = 1.5, xtickformat = '(I10)', xcharsize = 1.5, background = 255
  tv, zgrid_i_sb2, 200,100
  !p.region=[0,0,1,1]
  plot_colorbar, [min_elv, max_elv], "!3  NAVD88  !3", "!3 meters !3", yy=0.15
  if keyword_set(save_grid_plot) then begin
   write_tiff, save_grid_plot, tvrd(/true, /order)
  endif

  set_plot, thisdevice

return
end

pro plot_zbuf_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
		      min_elv_limit = min_elv_limit, num=num, save_grid_plot=save_grid_plot, $
			maxelv = maxelv, minelv = minelv
  ; this procedure will make a color coded grid plot
  ; amar nayegandhi 5/14/03

  ; set current device to z buffer
  thisdevice = !D.name
  set_plot, 'Z', /copy
  symbol_circle
  !p.background=255
  !p.color=0
  !p.font=1
  !p.region = [0.03,0,0.9,0.94]
  !p.psym=8
  !p.symsize=0.4
  !p.thick=2.0
  loadct, 39 
  print, "    plotting gridded data in Z Buffer ..."
  if (not keyword_set (max_elv_limit)) then max_elv_limit = 100000L
  if (not keyword_set (min_elv_limit)) then min_elv_limit = -100000L 
  if (not keyword_set (num)) then num = 1

  grid_we_limit = xgrid[0]
  grid_ea_limit = xgrid[n_elements(xgrid)-1]
  grid_so_limit = ygrid[0]
  grid_no_limit = ygrid[n_elements(ygrid)-1]
  idx = where(zgrid ne -100, complement=idx1)
  if ((not keyword_set (maxelv)) and (not keyword_set (minelv))) then begin
    if idx[0] ne -1 then begin
      max_elv = max(zgrid[idx], min = min_elv)
    endif else begin
       max_elv = -100
       min_elv = -100
    endelse
    if max_elv gt max_elv_limit then max_elv = max_elv_limit
    if min_elv lt min_elv_limit then min_elv = min_elv_limit
  endif else begin
    max_elv = maxelv
    min_elv = minelv
  endelse

  xsize = 2400/num & ysize = 2400/num
  device, set_resolution=[xsize,ysize]

  zgrid_i = bytscl(zgrid, max=max_elv, min=min_elv, top=255)

  ; make missing values white
  if (idx1[0] ne -1) then zgrid_i[idx1] = 255

  zgrid_i_sb2 = congrid(zgrid_i,n_elements(xgrid)/num,n_elements(ygrid)/num)

  if (keyword_set(save_grid_plot)) then begin
	atitle = (strsplit(save_grid_plot, '/', /extract))
	title = atitle(n_elements(atitle)-1)
  endif else title = "Grid Plot"
	
  ;Set up the overview image plot area (ie, nodata call to plot):
  plot, [grid_we_limit-1,grid_ea_limit], [grid_so_limit-1,grid_no_limit], $
        /nodata, xstyle=1, ystyle=1, ticklen = -0.02, xtitle= 'UTM Easting (m)', $
        ytitle= 'UTM Northing (m)', charsize=1.5, charthick=2.5, $
        position = [199,199,(n_elements(xgrid)/num)+200,(n_elements(ygrid)/num)+200], /device, $
        ytickformat = '(I10)', ycharsize = 1.5, xtickformat = '(I10)', xcharsize = 1.5, background = 255
  tv, zgrid_i_sb2, 200,200
  plot_colorbar, [min_elv, max_elv], "!3 NAVD88 Elevations!3", "!3 meters !3", $
		xx= 0.95, yy=0.2, textcharsize=2.0, rangecharsize=1.6
  if keyword_set(save_grid_plot) then begin
   tvlct, r,g,b,/get
   write_tiff, save_grid_plot, tvrd(/order), red=r, green=g, blue=b
  endif
  set_plot, thisdevice

return
end

pro make_GE_plots, xgrid=xgrid, ygrid=ygrid, zgrid=zgrid, geotif_file=geotif_file, $
		max_elv_limit=max_elv_limit, min_elv_limit = min_elv_limit, num=num, $
		save_grid_plot=save_grid_plot, maxelv = maxelv, minelv = minelv, filetype=filetype,$
		topmax=topmax, botmin=botmin, settrans=settrans, $
		colorbar_plot=colorbar_plot
  ; this procedure will make a color coded plot of the grid without any boundary lines and coordinates
  ; this procedure uses the Z Buffer... no actual image will be plotted on the window
  ; very useful for making gifs that will be used in Google Earth
  ; amar nayegandhi 11/14/2005
  ; INPUT KEYWORDS:
  ; xgrid = 1-d array of UTM Eastings
  ; ygrid = 1-d array of UTM Northings
  ; zgrid = 2-d array of gridded elevation data
  ; geotif_file = file name (including path) of the already created geotif file
  ; max_elv_limit = the maximum elevation limit for the output plot
  ; min_elv_limit = the minimum elevation limit for the output plot
  ; num = the value by which the output image will be scaled down by.  if num=2, image is half the size. Default num=2.
  ; save_grid_plot = the output file name to which the image should be saved. 
  ; 			if geotif_file is set and save_grid_plot not set, then the filename is the same as geotif_file with a different extension (e.g. .gif).
  ; maxelv = the maximum elevation for the output plot (overrides max_elv_limit)
  ; minelv = the minimum elevation for the output plot (overrides min_elv_limit)
  ; filetype = the type of file to output.  The options supported are ("gif","jpg","tif").  Defaults to "gif"
  ; topmax = set to 1 to set the elevations values beyond maxelv = maxelv
  ; botmin = set to 1 to set the elvations lower than minelv = minelv
  ; settrans = set to 1 to include transparency in gif images.  Transparency will take place only when missing value is greater than 5% of image.
  ; colorbar_plot = set to 1 to write out a file that contains the colorbar with min and max values


  ; set current device to z buffer
  thisdevice = !D.name
  set_plot, 'Z', /copy
  symbol_circle
  !p.background=255
  !p.color=0
  !p.font=1
  !p.psym=8
  !p.symsize=0.4
  !p.thick=2.0
  !p.region=[0,0,1,1]

  if ((not keyword_set (xgrid)) and (not keyword_set(geotif_file))) then begin
    print, "Please define either xgrid,ygrid,zgrid or provide geotif_file name."
    print, "Nothing to do.  Goodbye"
    return
  endif

  loadct, 39 
  print, "    plotting gridded data in Z Buffer ..."
  if (not keyword_set (max_elv_limit)) then max_elv_limit = 100000L
  if (not keyword_set (min_elv_limit)) then min_elv_limit = -100000L 
  if (not keyword_set (num)) then num = 1
  if (not keyword_set (filetype)) then filetype = "png"

  if (keyword_set (xgrid)) then begin
    grid_we_limit = xgrid[0]
    grid_ea_limit = xgrid[n_elements(xgrid)-1]
    grid_so_limit = ygrid[0]
    grid_no_limit = ygrid[n_elements(ygrid)-1]
    celldim = xgrid[1]-xgrid[0]
    idx = where(zgrid ne -100, complement=idx1)
    xn = n_elements(zgrid[0,*]);
    yn = n_elements(zgrid[*,0]); 
  endif 

  if (keyword_set (geotif_file)) then begin
    zgrid = read_tiff(geotif_file, geotiff=geovar, orientation=orient)
    if (orient eq 1) then zgrid = reverse(zgrid,2)
    grid_we_limit = geovar.MODELTIEPOINTTAG[3]
    grid_no_limit = geovar.MODELTIEPOINTTAG[4]
    celldim = geovar.MODELPIXELSCALETAG[0]
    xn = n_elements(zgrid[0,*]);
    yn = n_elements(zgrid[*,0]); 
    grid_ea_limit = grid_we_limit + xn*celldim
    grid_so_limit = grid_no_limit - yn*celldim
    idx = where(zgrid ne -100, complement=idx1)
  endif

  if (idx[0] eq -1) then begin
    print, "This file has only missing data.  No output file"
    set_plot, thisdevice
    return
  endif

  if ((not keyword_set (maxelv)) and (not keyword_set (minelv))) then begin
    if idx[0] ne -1 then begin
      max_elv = max(zgrid[idx], min = min_elv)
    endif else begin
       max_elv = -100
       min_elv = -100
    endelse
    if max_elv gt max_elv_limit then max_elv = max_elv_limit
    if min_elv lt min_elv_limit then min_elv = min_elv_limit
  endif else begin
    max_elv = maxelv
    min_elv = minelv
  endelse

  xsize = 2000/(num) + 1 
  ysize=2000/(num) + 1
  device, set_resolution=[xsize,ysize]

  if (keyword_set (topmax)) then begin
    ; let all elevations above max_elv = max_elv
    idxmax = where(zgrid(idx) gt max_elv, count)
    if count ne 0 then zgrid[idx[idxmax]] = max_elv
  endif

  if (keyword_set (botmin)) then begin
    ; let all elevations below min_elv = min_elv
    idxmin = where(zgrid[idx] lt min_elv, count)
    if count ne 0 then zgrid[idx[idxmin]] = min_elv
  endif

  zgrid_i = bytscl(zgrid, max=max_elv+0.1, min=min_elv-0.1, top=255)

  ; make missing values white
  if (idx1[0] ne -1) then zgrid_i[idx1] = 255

  zgrid_i_sb2 = congrid(zgrid_i,xn/num,yn/num)

  tv, zgrid_i_sb2, 0,0


  if keyword_set(save_grid_plot) then begin
    outfile = save_grid_plot
  endif else begin
    ;get file name from geotif_file
    if not keyword_set(geotif_file) then begin
      print, "No output file name specified.  Nothing to write."
      return
    endif
    file_ext_pos = strpos(geotif_file,".", /reverse_search)
    outfile = strmid(geotif_file,0,file_ext_pos-1)+"_GE."+filetype
  endelse

  tvlct, r,g,b,/get

  case filetype of
    "gif": begin
	   write_gif, outfile, tvrd(), r,g,b
	   if (keyword_set(settrans)) then begin
    	   	; set transparency if more than 10% contain missing value
    		idxtrans = where(zgrid_i_sb2 eq 255, count)
    		if ((float(count)/n_elements(zgrid_i)) ge 0.1) then begin
      		   ; call external convert command to convert with transparency
      		   print, "Using transparency feature for this image..."
      		   spawn, "convert -transparent white "+ outfile+ " "+outfile
    		endif
	   endif
	  end
    "jpg": begin
	   img = tvrd()
	   ximg = n_elements(img(*,0))
	   yimg = n_elements(img(0,*))
	   imgRGB = bytarr(3, ximg, yimg)
	   imgRGB[0, *, *] = r[img]  
	   imgRGB[1, *, *] = g[img]
	   imgRGB[2, *, *] = b[img]
	   write_jpeg, outfile, imgRGB, true=1
	   end
    "tif": write_tiff, outfile, tvrd(/order), red=r,green=g,blue=b
    "png": begin
	   write_png, outfile, tvrd(), r,g,b
	   spawn, "convert -transparent gray100 "+ outfile+ " "+outfile
 	  end
  endcase
 
  set_plot, thisdevice

  if (keyword_set(colorbar_plot)) then begin
	; define file name
	file_ext_pos = strpos(outfile,".", /reverse_search)
	cb_outfile = strmid(outfile,0,file_ext_pos-1)+"_cb."+filetype
	save_colorbar_plot, min_elv, max_elv, cb_outfile
  endif

return
end

pro write_geotiff, fname, xgrid, ygrid, zgrid, zone_val, cell_dim
    ; this procedure write a geotiff for the array zgrid
    ; amar nayegandhi 05/14/03
   
    print, "    writing geotiff..."
    proj_cs_key = '269'+strcompress(string(zone_val), /remove_all)
    proj_cs_key = fix(proj_cs_key)
    proj_cit_key = 'PCS_NAD83_UTM_zone_'+strcompress(string(zone_val), /remove_all)+'N'


    MODELPIXELSCALETAG = [cell_dim, cell_dim, 1]
    

    zgrid1 = reverse(zgrid, 2)
    
    ;min_z = min(zgrid1)

    ;zgrid1(where(zgrid1 eq -1e6)) = min_z-10
    ;zgrid1(where(zgrid1 gt 0)) = 0

    ;min_z = fix(min_z*100)
    ;zgrid1 = zgrid1 - min_z

    MODELTIEPOINTTAG = [0, 0, 0, xgrid[0], ygrid[n_elements(ygrid)-1], 0]
    write_tiff, fname, zgrid1, orientation=1, /float, /verbose, geotiff = { $
                        MODELPIXELSCALETAG: MODELPIXELSCALETAG, $
                        MODELTIEPOINTTAG: MODELTIEPOINTTAG, $
                        GTMODELTYPEGEOKEY: 1, $
                        PROJECTEDCSTYPEGEOKEY: proj_cs_key, $
                        GTRASTERTYPEGEOKEY: 1, $
                        PCSCITATIONGEOKEY: proj_cit_key, $
                        PROJLINEARUNITSGEOKEY: 9001, $
                        VERTICALCSTYPEGEOKEY: 5103, $
                        VERTICALCITATIONGEOKEY: 'NAVD88' $
                        }

return
end
