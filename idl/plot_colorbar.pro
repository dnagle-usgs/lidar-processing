pro plot_colorbar, elv_range, type, type1=type1, unit, other = other, block = block, color=color, $
	xx = xx, yy = yy

;colorbar
;amar nayegandhi, 02/25/02
;modified 10/02/02 to include xx and yy as keywords
;extracted from LaserMap v1.0
;keywords:  elv_range = the range of elevation values within the color bar
;	    type = title of the colorbar, e.g. "elevation"
;	    unit = units of the elv range e.g. "meters"
;	    xx = x screen position for the colorbar (0<xx<1)
;	    yy = y screen position for the colorbar (0<yy<1)

if not keyword_set(xx) then xx = 0.9
if not keyword_set(yy) then yy = 0.25
xnorm = xx+[.0, .03]
ynorm = yy+[.0, .45] 

z0 = float(elv_range[0])
z1 = float(elv_range[1])

if not keyword_set(color) then color = 0

colorscale = float(!D.n_colors-3)/(float(z1-z0))
nc = !D.n_colors-2
coords = convert_coord(xnorm, ynorm, /norm, /to_device)

tv, replicate(1, coords(0, 1)-coords(0, 0)+1)# bytscl(indgen(coords(1, 1)-coords(1, 0)+1), top = nc), $
        xnorm(0), ynorm(0), /norm

if not keyword_set(block) then begin
  if keyword_set(other) then begin
    xyouts, xx-0.03, ynorm[1]+0.05, other, /normal, color = color, charsize = 1, charthick = 1
  endif else begin
     ;xyouts, xx-0.025, ynorm[1]+0.08, '!3 Apparent', /normal, color=0, charsize=1, charthick = 1
     ;xyouts, xx-0.02, ynorm[1]+0.085,  '!3'+'NAVD88', /normal, color = color, charsize = 1.4, charthick = 1
     xyouts, xx-0.02, ynorm[1]+0.05,  '!3'+type, /normal, color = color, charsize = 1.3, charthick = 1
     if keyword_set(type1) then $
       xyouts, xx-0.025, ynorm[1]+0.04,  '!3'+type1, /normal, color = color, charsize = 1.1, charthick = 1
     ;xyouts, xx-0.02, ynorm[1]+0.055,  '!3'+type+' Range', /normal, color = color, charsize = 1.2, charthick = 1
    xyouts, xx-0.02, ynorm[1]+0.01, '('+unit+')', /normal, color = color, charsize = 1.3, charthick = 1
  endelse
endif else begin
  if block eq 'white' then begin
    	polyfill, [xnorm[0], xnorm[0], xnorm[1], xnorm[1]], [yy+0.25, yy+0.30, yy+0.3, yy+0.25], /normal, color = 255
	xyouts, xx+0.034, yy+0.27, 'Buildings', /normal, color = color, charsize = 1, charthick = 1
	xyouts, xx-0.02, yy+0.3+0.055, '!4 '+type, /normal, color = color, charsize = 1, charthick = 1
	xyouts, xx-0.02, yy+0.3+0.03, '('+unit+')', /normal, color = color, charsize = 1, charthick = 1
  endif
endelse
	

xyouts, xx+0.034, ynorm[0], strcompress(string(format='(F6.1)',z0), /remove_all), /normal, color = color, charsize = 1.1;, charthick = 1
xyouts, xx+0.034, ynorm[1]-0.02, strcompress(string(format='(F6.1)',z1), /remove_all), /normal, color = color, charsize = 1.1;, charthick = 1

return
end
