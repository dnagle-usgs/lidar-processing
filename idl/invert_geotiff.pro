pro invert_geotiff, fname

  ; this procedure inverts the geotiff made in QT viewer so that it is correctly oriented in 
  ; other GIS packages such as ESRI.
  ; amar nayegandhi 01/31/05

  image = read_tiff(fname, geotiff=geo, orientation=orient)
  image = reverse(image, 2, /overwrite)
  spfn = strsplit(fname, ".", /extract)
  new_fname = spfn(0)+"_reversed."+spfn(1)
  write_tiff, new_fname, image, geotiff=geo, orientation=0, /float
  print, "Reversed file written to file:",new_fname

return
end

