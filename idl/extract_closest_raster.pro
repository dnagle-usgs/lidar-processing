function extract_closest_raster, data, east, north, maxdist, minpt=minpt, rastdist=rastdist, $
	retdist=retdist
  ; this procedure extracts the closest raster from the given (east,north) location
  ; amar nayegandhi 10/08/03
  ; INPUT KEYWORDS:
  	;data:  EAARL data array
	;east: Easting location in meters
	;north: Northing location in meters
	;maxdist: Maximum distance (in meters) to perform search from given location
	;minpt: Minimum number of pulses in the selected raster required
	;rastdist: Distance along the raster from the closest point within which all points to be returned
  ;OUTPUT:
  	;retdata: Data array that contains all pulses from the selected raster
	;retdist= : set retdist=retdist to return the distance from the input location to the nearest point on the selected raster.
  
  if (not keyword_set(minpt)) then minpt = 10 ;no of points
  if (not keyword_set(rastdist)) then rastdist = 20 ;meters

  ; find all the points within 'maxdist' of the given point
  ; define box coordinates
  xmax = double(east + maxdist)*100.0
  xmin = double(east - maxdist)*100.0
  ymax = double(north + maxdist)*100.0
  ymin = double(north - maxdist)*100.0

  indx = where((data.east ge xmin) and (data.east le xmax) and (data.north ge ymin) and (data.north le ymax))
  if (indx[0] ne -1) then begin
     sel_data = data(indx)
  endif else begin
     print, "No data found within given distance.  Goodbye!"
     return, -1
  endelse

 success = 0
 while (1) do begin

  ;now find the closest point within this region
  each_dist = sqrt((sel_data.east-east*100.0)^2 + (sel_data.north-north*100.0)^2)
  mindist = min(each_dist, id)
  
  ;now find the raster number and all pulses in the same raster
  minrast = sel_data(id).rn AND 'ffffff'XL
  minpulseidx = where((sel_data.rn  AND 'ffffff'XL) eq minrast)
  if (n_elements(minpulseidx) lt minpt) then begin 
	sel_data = remove_this_raster(sel_data, id)
  	if (sel_data(0).rn ne -1) then begin
	   continue
	endif else begin
	    break
	endelse
  endif
  rast_data = sel_data(minpulseidx)
  rast_east = sel_data(id).east
  rast_north = sel_data(id).north
  ; rast_east and rast_north are the closest points on the raster to the given location

  ;now calculate the distance along the raster from rast_east and rast_north
  rast_dist = sqrt((rast_data.east-rast_east)^2 + (rast_data.north-rast_north)^2)
  ;now find the points that are retdist/2 away from the raster center point
  rastidx = where(rast_dist le (rastdist*100.)/2.)
  if (n_elements(rast_data(rastidx)) lt minpt) then begin
	sel_data = remove_this_raster(sel_data, id)
	if (sel_data(0).rn ne -1) then begin
	   continue
	endif else begin
	    break
	endelse
  endif
  success = 1
  break

 endwhile
 
 if (success eq 1) then begin
  retdist = mindist/100.
  retdata = rast_data(rastidx)

  return, retdata
 endif else begin
  print, 'No data found. Goodbye!'
  return, -1
 endelse
 
end

function remove_this_raster, sel_data, id
  ;this function removes all points that belong to raster sel_data.rn(id)
  ;amar nayegandhi 10/08/03
  rast = sel_data(id).rn AND 'ffffff'XL
  idx = where((sel_data.rn AND 'ffffff'XL) ne rast)
  if (idx(0) ne -1) then begin
    return, sel_data(idx)
  endif else begin
    sel_data(0).rn = -1
    return, sel_data(0)
  endelse
end
