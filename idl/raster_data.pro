function raster_data, data, raster_no

;this procedure extracts data for all pulses in raster raster_no
;amar nayegandhi 10/07/2002.


indx = where(raster_no eq (data.rn AND 'ffffff'XL))


return, data(indx)
end
