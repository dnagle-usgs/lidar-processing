pro  grid_eaarl_data, data, cell=cell, mode=mode, zgrid=zgrid, xgrid=xgrid, ygrid=ygrid, $
	z_max = z_max, z_min=z_min, missing = missing, limits=limits
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
	; missing = Missing value for no data points during gridding, default = -100m


  if (not keyword_set(cell)) then cell = 1  
  if (not keyword_set(z_min)) then z_min = -100L
  if (not keyword_set(missing)) then missing = -100L

  print, "    triangulating..."
  if ((mode eq 1) OR (mode eq 2)) then begin
    triangulate, float(data.east/100.), float(data.north/100.), tr, b
  endif else begin
    triangulate, float(data.least/100.), float(data.lnorth/100.), tr, b
  endelse

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

return
end

pro plot_eaarl_grids, xgrid, ygrid, zgrid, max_elv_limit=max_elv_limit, $
		      min_elv_limit = min_elv_limit, num=num, save_grid_plot=save_grid_plot
  ; this procedure will make a color coded grid plot
  ; amar nayegandhi 5/14/03
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
