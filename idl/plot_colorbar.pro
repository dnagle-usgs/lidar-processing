pro plot_colorbar, elv_range, type, other=other, unit, color=color, $
	xx = xx, yy = yy, textcharsize=textcharsize, rangecharsize=rangecharsize, $
	xnorm=xnorm, ynorm=ynorm

;colorbar
;amar nayegandhi, 02/25/02
;modified 10/02/02 to include xx and yy as keywords
;modified 12/20/2005 to include xnorm and ynorm as keywords and improve the colorbar plot
;extracted from LaserMap v1.0
;keywords:  elv_range = the range of elevation values within the color bar
;	    type = title of the colorbar, e.g. "elevation"
;	    unit = units of the elv range e.g. "meters"
;	    xx = x screen position for the colorbar (0<xx<1)
;	    yy = y screen position for the colorbar (0<yy<1)
;	    xnorm = the width of the colorbar in normalized coords along x axis, e.g. [0.1,0.9]
;	    ynorm = the height of the colorbar in normalized coords along y axis, e.g. [0.1,0.9]
;	xnorm and ynorm includes the colorbar and the text associated with it
;	if xnorm and ynorm are set, xx and yy are not considered

if not keyword_set(xx) then xx = 0.9
if not keyword_set(yy) then yy = 0.25
if not keyword_set(textcharsize) then textcharsize = 1.4
if not keyword_set(rangecharsize) then rangecharsize = 1.3

if not keyword_set(xnorm) then xnorm = xx+[.0, .05]
if not keyword_set(ynorm) then ynorm = yy+[.0, .50] 

xdif = xnorm[1]-xnorm[0]
ydif = ynorm[1]-ynorm[0]

z0 = float(elv_range[0])
z1 = float(elv_range[1])

if not keyword_set(color) then color = 0

colorscale = float(!D.n_colors-3)/(float(z1-z0))
nc = !D.n_colors-2

; define extent for the actual colorbar
; assumes colorbar will span 5-85% of defined xnorm &
;	5-80% of defined ynorm
xnorm_cb = [xnorm[0]+0.05*xdif,xnorm[0]+0.65*xdif]
ynorm_cb = [ynorm[0]+0.05*ydif,ynorm[0]+0.78*ydif]

coords = convert_coord(xnorm_cb, ynorm_cb, /norm, /to_device)

tv, replicate(1, coords(0, 1)-coords(0, 0)+1)# bytscl(indgen(coords(1, 1)-coords(1, 0)+1), top = nc), $
        xnorm_cb(0), ynorm_cb(0), /norm

if keyword_set(other) then begin
     xyouts, xnorm[0], ynorm[0]+0.80*ydif, other, /normal, color = color, charsize = 1, charthick = 1
endif else begin
     ; 'type' will be printed at 90% mark on yaxis and 0% mark on x-axis
     xyouts, xnorm[0], ynorm[0]+0.90*ydif,  '!3'+type, /normal, color = color, $
		charsize = textcharsize, charthick = 1
     ; 'type1' will be printed at 85% mark on yaxis and 0% mark on x-axis
     if keyword_set(type1) then $
       xyouts, xnorm[0], ynorm[0]+0.85*ydif,  '!3'+type1, /normal, color = color, $
		charsize = textcharsize, charthick = 1
     ; 'unit' will be printed at 80% mark on yaxis and 0% mark on x-axis
     xyouts, xnorm[0], ynorm[0]+0.80*ydif, '('+unit+')', /normal, color = color, $
		charsize = textcharsize, charthick = 1
endelse


xyouts, xnorm_cb[1], ynorm_cb[0], strcompress(string(format='(F6.1)',z0), /remove_all), /normal, $
		color = color, charsize = rangecharsize;, charthick = 1
xyouts, xnorm_cb[1], ynorm_cb[1], strcompress(string(format='(F6.1)',z1), /remove_all), /normal, $
		color = color, charsize = rangecharsize;, charthick = 1

return
end


pro save_colorbar_plot, min_elv, max_elv, outfile, type=type, unit=unit, $
	xsize=xsize, ysize=ysize
; this function writes out a file containing a plot of the colorbar in zbuffer
; amar nayegandhi 12/20/05
; INPUT:
;	min_elv = minimum elevation value
;	max_elv = maximum elevation value
;	infile = file name to be used to write out the colorbar plot


if (not keyword_set(type)) then type="Elevation"
if (not keyword_set(unit)) then unit="m"
if (not keyword_set(xsize)) then xsize=100
if (not keyword_set(ysize)) then ysize=275
 
  ; set current device to z buffer
  thisdevice = !D.name
  set_plot, 'Z', /copy
  loadct, 39
  symbol_circle
  !p.background=255
  !p.color=0
  !p.font=1
  !p.psym=8
  !p.symsize=0.4
  !p.thick=2.0
  !p.region=[0,0,1,1]


  device, set_resolution=[xsize,ysize]
  ; window, 0, xsize=xsize, ysize=ysize

  ; define all-white image as backdrop
  img = intarr(xsize,ysize)
  img(*) = 255
  tv, img

  plot_colorbar, [min_elv,max_elv], type, unit, xnorm=[0,1], $
	ynorm=[0,1], textcharsize=textcharsize, rangecharsize=rangecharsize

  tvlct, r,g,b,/get

  ; find filetype from outfile extension
  file_ext_pos = strpos(outfile,".", /reverse_search)
  filetype = strmid(outfile,file_ext_pos+1)
  case filetype of
    "gif": write_gif, outfile, tvrd(), r, g, b
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
    "tif": write_tiff, outfile, tvrd(/order), red=r, green=g, blue=b
    "png": write_png, outfile, tvrd(), r, g, b
  endcase
 
  set_plot, thisdevice
return 
end



 
;
