pro plot_xyz_veg, data_arr, min_z=min_z, max_z=max_z, make_tiff = make_tiff, $
	plot_range=plot_range, title=title, win = win, pmode = pmode, $
	min_z_limit=min_z_limit, max_z_limit = max_z_limit 


;this procedure plots the xyz points of one or more  3-D arrays representing flight swaths
;the z value is that of data.bath
;amar nayegandhi 03/25/02
;modified amar nayegandhi 02/13/03 to work with batch_plot.pro
; pmode = 1 for bare earth elevations
; pmode = 2 for first surface elevations
; pmode = 3 for canopy height elevations
; pmode = 4 for bare earth intensity plot

n_arr = n_elements(data_arr)
!p.background=255
!p.color=0
!p.font=1
!p.region = [0.03,0,0.9,0.94]
!p.psym=8
!p.symsize=0.4
!p.thick=2.0

symbol_circle

if ((not keyword_set(min_z)) or (not keyword_set(max_z))) then begin

 max_z_all = -999999L
 min_z_all = 999999L

 for i = 0L, n_arr-1L do begin

   if not keyword_set(min_z) then begin
    ; statistically determine min_z from data_arr
    if (pmode eq 1) then $
      min_z = min((*data_arr[i]).lelv[0])/100.
    if (pmode eq 2) then $
      min_z = min((*data_arr[i]).elevation[0])/100.
    if (pmode eq 3) then $
      min_z = min((*data_arr[i]).elevation[0] - (*data_arr[i]).lelv[0])/100.
    if (pmode eq 4) then $
      min_z = min((*data_arr[i]).lint[0])
   endif

   if not keyword_set(max_z) then begin
    ; statistically determine max_z from data_arr
    if (pmode eq 1) then $
      max_z = max((*data_arr[i]).lelv[0])/100.
    if (pmode eq 2) then $
      max_z = max((*data_arr[i]).elevation[0])/100.
    if (pmode eq 3) then $
      max_z = max((*data_arr[i]).elevation[0] - (*data_arr[i]).lelv[0])/100.
    if (pmode eq 4) then $
      max_z = max((*data_arr[i]).lint[0])
   endif
   
   if (min_z_all gt min_z) then min_z_all = min_z
   if (max_z_all lt max_z) then max_z_all = max_z

 endfor

 min_z = min_z_all
 max_z = max_z_all

endif

if (keyword_set(min_z_limit) and keyword_set(max_z_limit)) then begin
  if min_z < min_z_limit then min_z = min_z_limit
  if max_z > max_z_limit then max_z = max_z_limit
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
   if (pmode eq 2) then begin
     x0 = min((*data_arr[i]).east[0])/100. 
     x1 = max((*data_arr[i]).east[0])/100.
     y0 = min((*data_arr[i]).north[0])/100.
     y1 = max((*data_arr[i]).north[0])/100.
   endif else begin
     x0 = min((*data_arr[i]).least[0])/100. 
     x1 = max((*data_arr[i]).least[0])/100.
     y0 = min((*data_arr[i]).lnorth[0])/100.
     y1 = max((*data_arr[i]).lnorth[0])/100.
   endelse

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
	 /nodata, /noerase, xstyle=1, ystyle=1,$
	 ticklen = .01, title=title, xtitle="!4 UTM Easting (m) !3", ytitle = "!4 UTM Northing (m) !3", $
	 charsize=1.8, xtickformat = '(I6)', ytickformat = '(I7)', xtickinterval=400, ytickinterval=400, $
	 xticklayout=0, /isotropic

for i = 0, n_arr-1 do begin
    if (pmode eq 1) then begin
     z = ((*data_arr[i]).elevation[0])/100.
     indx = where( (z gt min_z) and (z lt max_z) )
    endif
    if (pmode eq 2) then begin
      z = ((*data_arr[i]).lelv[0])/100.
      indx = where( (z gt min_z) and (z lt max_z) )
    endif
    if (pmode eq 3) then begin
      z = ((*data_arr[i]).lelv[0] - (*data_arr[i]).elevation[0])/100.
      indx = where( (z gt min_z) and (z lt max_z) and ((*data_arr[i]).nx[0] gt 0))
    endif
    if (pmode eq 4) then begin
      z = (*data_arr[i]).lint
      indx = where( (z gt min_z) and (z lt max_z) )
    endif
    if (indx(0) ne -1) then begin
      color_plot = bytscl(z[indx],$
			min=min_z,max=max_z)
      if (pmode eq 2) then begin
       plots, [((*data_arr[i]).east[0])[indx]/100.], [((*data_arr[i]).north[0])[indx]/100.], color=color_plot, noclip=0
      endif else begin 
       plots, [((*data_arr[i]).least[0])[indx]/100.], [((*data_arr[i]).lnorth[0])[indx]/100.], color=color_plot, noclip=0
      endelse
    endif
endfor

!p.region=[0,0,1,1]
plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", "!3 meters !3"

if keyword_set(make_tiff) then $
  write_tiff, make_tiff, tvrd(/true, /order)

;if (word_set(fs)) then $
;plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", type1="!3First Surface!3", "!3 meters !3"
;if (keyword_set(ch)) then $
;plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", type1="!3Canopy Height!3", "!3 meters !3"
;if (keyword_set(fint)) then $
;plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", type1="!3Surface Intensity!3", "!3 counts !3"

return
end
