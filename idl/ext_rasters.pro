function ext_rasters, data, east_arr=east_arr, north_arr=north_arr, retdata=retdata
 ; this functin extracts rasters from a data array.  If east_arr and north_arr are defined, the function extracts rasters only from the specified region.  retdata is the returned data array for the specified region.
 ; amar nayegandhi 10/09/02

    if (keyword_set(east_arr) and not keyword_set(north_arr))then begin
	indx = where(data.east/100. ge east_arr(0) and data.east/100. le east_arr(1))
	if (indx(0) ne -1 ) then retdata = data(indx);
    endif
    if (not keyword_set(east_arr) and keyword_set(north_arr))then begin
	indx = where(data.north/100. ge north_arr(0) and data.north/100. le north_arr(1))
	if (indx(0) ne -1 ) then retdata = data(indx)
    endif
    if (keyword_set(east_arr) and keyword_set(north_arr))then begin
	indx = where(((data.north/100. ge north_arr(0)) and (data.north/100. le north_arr(1))) and ((data.east/100. ge east_arr(0)) and (data.east/100. le east_arr(1))))
	if (indx(0) ne -1 ) then retdata = data(indx)
    endif
    if ( (not keyword_set(east_arr)) and (not keyword_set(north_arr))) then retdata = data
   if (indx ne -1) then begin 
    rn_indx = uniq(retdata.rn AND 'ffffff'XL) 
    rn_list = (retdata(rn_indx).rn AND 'ffffff'XL)
   endif else rn_list = -1

return, rn_list
end
