pro plot_xyz_veg, data_arr, min_z=min_z, max_z=max_z, $
	plot_range=plot_range, title=title, win = win, be=be, fs=fs, ch=ch, fint=fint

;this procedure plots the xyz points of one or more  3-D arrays representing flight swaths
;the z value is that of data.bath
;amar nayegandhi 03/25/02

n_arr = n_elements(data_arr)
!p.background=255
!p.color=0
!p.font=1
!p.region = [0.03,0,0.9,0.94]
!p.psym=8
!p.symsize=0.3
!p.thick=1.0

symbol_circle

if not keyword_set(min_z) then min_z = -50
if not keyword_set(max_z) then max_z = -35
if not keyword_set(win) then win = 0

window, win, xsize=1000, ysize=550, color = -1

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
	 charsize=1.2, xtickformat = '(I6)', ytickformat = '(I7)', xtickinterval=500, ytickinterval=500, $
	 xticklayout=0, /isotropic

for i = 0, n_arr-1 do begin
    if keyword_set(fs) then begin
     z = ((*data_arr[i]).elevation[0]/100.)
     indx = where( (z gt min_z) and (z lt max_z) )
    endif
    if (keyword_set(be)) then begin
      z = ((*data_arr[i]).elevation[0]/100. - ((*data_arr[i]).lelv[0] - (*data_arr[i]).felv[0])/100.)
      indx = where( (z gt min_z) and (z lt max_z) )
    endif
    if (keyword_set(ch)) then begin
      z = ((*data_arr[i]).lelv[0] - (*data_arr[i]).felv[0])/100.
      indx = where( (z gt min_z) and (z lt max_z) and ((*data_arr[i]).nx[0] gt 0))
    endif
    if (keyword_set(fint)) then begin
      z = (*data_arr[i]).fint
      indx = where( (z gt min_z) and (z lt max_z) )
    endif
   ;indx = where((((*data_arr[i]).elevation[0])/100. ne 0) and ((((*data_arr[i]).elevation[0])) ne -10000))
   ;indx = where(((*data_arr[i]).elevation[0])/100. ne 0)
   color_plot = bytscl(z[indx],$
			min=min_z,max=max_z)
   plots, [((*data_arr[i]).east[0])[indx]/100.], [((*data_arr[i]).north[0])[indx]/100.], color=color_plot, noclip=0
endfor

!p.region=[0,0,1,1]
if (keyword_set(be)) then $
plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", type1="Bald Earth", "!3 meters !3"
if (keyword_set(fs)) then $
plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", type1="!3First Surface!3", "!3 meters !3"
if (keyword_set(ch)) then $
plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", type1="!3Canopy Height!3", "!3 meters !3"
if (keyword_set(fint)) then $
plot_colorbar, [min_z, max_z], "!3  NAVD88  !3", type1="!3Surface Intensity!3", "!3 counts !3"

return
end
