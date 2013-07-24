pro make_nodata_shp, image, nodata=nodata, update=update
;- generate no-data vector file from tiff image
   ;- image  = full path to image to be vectorized
   ;- nodata = nodata value. default value is -32767
   ;- update = set to 1 to skip file if output file exists

;- 05/01/2013  Christine Kranenburg

  if (nodata eq !NULL) then nodata = -32767
  if (not keyword_set(update)) then update=0
  pos=-1

  if (image ne !NULL) then envi_open_file, image, r_fid=fid $
  else $
   envi_select, fid=fid, pos=pos, dims=dims, file_type=ft
  if fid[0] eq -1 then return

  envi_file_query, fid, dims=dims, ns=ns, nl=nl, nb=nb, fname=fname, file_type=ft
  map_info=query_tiff(image, geotiff=geotiff)

  out_name = (strsplit(image, '.', /extract))[0] + '.evf'
  if (not(update && file_test(out_name))) then begin
    envi_doit, 'rtv_doit', dims=dims, fid=fid, pos=0, out_name=[out_name], $
      values=[nodata], l_name=[strmid(file_basename(out_name),0,18)], in_memory=[0]
  endif

  envi_file_mng, id=fid, /remove
  evf_ids = envi_evf_available_vectors()      ;-undocumented functions
  envi_vector_close_file, evf_ids    
end


pro evf2ascii, evf_name, update=update
;- convert evf to Global Mapper formatted shapefile (*.xyz)
;- update = set to 1 to skip file if output file exists
;-

  if (not keyword_set(update)) then update=0
  evf_id = envi_evf_open(evf_name)
  envi_evf_info, evf_id, num_recs=n_recs, data_type=dt
  out_name = strmid(evf_name, 0, strlen(evf_name)-4) + '.xyz'
  if (update && file_test(out_name)) then return
  
; open ascii text file  
  openw, lun, out_name, /GET_LUN
  
  for i=0, n_recs-1 do begin
    ply = envi_evf_read_record(evf_id, i, parts_ptr=pptr, type=dt)
    for j=0, n_elements(pptr)-2 do begin
      printf, lun, 'DESCRIPTION=Unknown Area Type'
      printf, lun, 'CLOSED=YES'
      if pptr[j+1] ge 0 then printf, lun, 'ID=', strtrim(i+1,2) $
      else printf, lun, 'ISLAND=YES'
      coords = strarr(2, abs(pptr[j+1])-abs(pptr[j]))
      coords[0,*] = strtrim(ply[0,abs(pptr[j]):abs(pptr[j+1])-1], 2)+','
      coords[1,*] = strtrim(ply[1,abs(pptr[j]):abs(pptr[j+1])-1], 2)+', -999999'
      printf, lun, coords
      printf, lun, ''
    endfor
  endfor
  envi_evf_close, evf_id
  close, lun & free_lun, lun
end


pro batch_nodata_shp, path, searchstr=searchstr, nodata=nodata, update=update
;- this procedure performs batch raster-to-vector conversion of nodata pixels  
;- in the gridded input files and converts the resulting evfs to Global Mapper 
;- formatted shapefiles 
   ;- path = full path to gridded data
   ;- nodata = nodata value. default value is -32767
   ;- update = set to 1 to skip file if output file exists

  if (not keyword_set(searchstr)) then searchstr='*.tif'
  tifs = file_search(path, searchstr, count=count)
  if (count eq 0) then begin
    print, 'No files found. Exiting...'
    return
  endif

  for i=0, count-1 do make_nodata_shp, tifs[i], nodata=nodata, update=update
  evfs = file_search(path, '*.evf', count=count)
  for i=0, count-1 do evf2ascii, evfs[i], update=update

end
