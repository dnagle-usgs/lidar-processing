pro plot_xyz_bath, data_arr, min_z=min_z, max_z=max_z, $
	min_z_limit=min_z_limit, max_z_limit = max_z_limit, $
	plot_range=plot_range, title=title, win = win, bathy=bathy, make_tiff=make_tiff

;this procedure plots xyz bathymetry data
;amar nayegandhi 03/25/02
; modified on 12/13/02 to automatically define min_z and max_z

symbol_circle
n_arr = n_elements(data_arr)
!p.background=255
!p.color=0
!p.font=1
!p.region = [0.03,0,0.9,0.94]
!p.psym=8
!p.symsize=0.4
!p.thick=2.0

if ((not keyword_set(min_z)) or (not keyword_set(max_z))) then begin

 max_z_all = -999999L
 min_z_all = 999999L

 for i = 0L, n_arr-1L do begin

   if not keyword_set(min_z) then begin
    ; statistically determine min_z from data_arr
    min_z = min((*data_arr[i]).depth[0] + (*data_arr[i]).elevation[0])/100.
   endif

   if not keyword_set(max_z) then begin
    ; statistically determine max_z from data_arr
    max_z = max((*data_arr[i]).depth[0] + (*data_arr[i]).elevation[0])/100.
   endif
   
   if (min_z_all gt min_z) then min_z_all = min_z
   if (max_z_all lt max_z) then max_z_all = max_z

 endfor

 min_z = min_z_all
 max_z = max_z_all

endif

if (keyword_set(min_z_limit) and keyword_set(max_z_limit)) then begin
  if (min_z lt min_z_limit) then min_z = min_z_limit
  if (max_z gt max_z_limit) then max_z = max_z_limit
endif

if not keyword_set(win) then win = 0

window, win, xsize=650, ysize=550, color = -1

if keyword_set(plot_range) then begin
   x0_all = plot_range[0]
   x1_all = plot_range[1]
   y0_all = plot_range[2]
   y1_all = plot_range[3]
endif else begin

  x0_all = 99999999L
  x1_all = -99999L
  y0_all = 99999999L
  y1_all = -99999L

  for i = 0L, n_arr-1L do begin

   ;find the lowest and highest easting/northing value
   x0 = min((*data_arr[i]).east[0])/100. 
   x1 = max((*data_arr[i]).east[0])/100.
   y0 = min((*data_arr[i]).north[0])/100.
   y1 = max((*data_arr[i]).north[0])/100.

   if x0 lt x0_all then x0_all=x0
   if x1 gt x1_all then x1_all=x1
   if y0 lt y0_all then y0_all=y0
   if y1 gt y1_all then y1_all=y1

  endfor

endelse


;loadct_rainbow, /topwhite
loadct, 39
if not keyword_set(title) then title = " "
plot, [x0_all,x1_all],[y0_all,y1_all],xrange=[x0_all,x1_all],yrange=[y0_all,y1_all], $
;plot, [583773,584765],[2807564,2808734],xrange=[583773,584765],yrange=[2807564,2808734], $
	 /nodata, /noerase, xstyle=1, ystyle=1,$
	 ticklen = .01, title=title, xtitle="!4 UTM Easting (m) !3", ytitle = "!4 UTM Northing (m) !3", $
	 charsize=1.8, xtickformat = '(I6)', ytickformat = '(I7)', xtickinterval=400, ytickinterval=400, $
	 xticklayout=0, /isotropic

for i = 0, n_arr-1 do begin
    bathy = (*data_arr[i]).depth[0]/100. + (*data_arr[i]).elevation[0]/100.
    indx = where( (bathy gt min_z) and (bathy lt max_z) )
   ;indx = where((((*data_arr[i]).elevation[0])/100. ne 0) and ((((*data_arr[i]).elevation[0])) ne -10000))
   ;indx = where(((*data_arr[i]).elevation[0])/100. ne 0)
   if (indx(0) ne -1) then begin
     color_plot = bytscl(((*data_arr[i]).elevation[0]+(*data_arr[i]).depth[0])[indx]/100.,$
  			min=min_z,max=max_z)
     plots, [((*data_arr[i]).east[0])[indx]/100.], [((*data_arr[i]).north[0])[indx]/100.], $
			color=color_plot, noclip=0
   endif
endfor

!p.region=[0,0,1,1]
plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", "!3 meters !3", yy=0.15

if keyword_set(make_tiff) then $
   write_tiff, make_tiff, tvrd(/true, /order)
return
end
