pro jpg_to_gtiff, ipath, ifname=ifname, opath=opath, ofname=ofname, searchstr=searchstr

;this procedure reads a jpg with jgw file, and converts it to a geotiff file.
;
;amar nayegandhi 03/14/06
;INPUT KEYWORDS:
;	ipath = input path name where the gdf files reside
;	ifname = optional; input file name that needs to be converted
;	opath = optional; writes output geotiff files to opath; defaults to the same path where input file
;	ofname = optional; output file name... should be used only when ifname is used
;	searchstr = search string for finding input files.  Defaults to "*.gdf"
;OUTPUT:
;	writes out output geotiff file(s).  ASSUMES UTM Projection

start_time = systime(1)

if not keyword_set(ipath) then begin
    print, "You need to define the input path..."
    return
endif

if not keyword_set(searchstr) then $
      searchstr = "*.jpg" 
if not keyword_set(ifname) then begin 
  ;search in the directory path to find all files with .gdf extension
  spawn, 'find '+ipath+' -name "'+searchstr+'"', fn_arr
endif else begin
  fn_arr = ipath+ifname
endelse

jgw_ss = "*.jgw"
; search for associated jgw file
spawn, 'find '+ipath+' -name "'+jgw_ss+'"',jgw_arr

print, 'Number of files to convert: '+strcompress(string(n_elements(fn_arr)))


for i = 0, n_elements(fn_arr)-1L do begin
    ; read 1 file at a time
    img = read_jpeg(fn_arr[i])
    openr, rlun, jgw_arr[i]
    readu, rlun, dim3
    if (dim3 eq 0) then begin
	mets = dblarr(xn,yn)
    endif else begin
	mets = dblarr(dim3,xn,yn)
    endelse
    readu, rlun, mets
    free_lun, rlun
    close, rlun
    for j = 0, n_elements(indx)-1L do begin
	zgrid = reform(mets(indx(j),*,*))
	print, "    writing geotiff for index j..."
	proj_cs_key = '269'+strcompress(string(zone_val), /remove_all)
	proj_cs_key = fix(proj_cs_key)
	proj_cit_key = 'PCS_NAD83_UTM_zone_'+strcompress(string(zone_val),/remove_all)+'N'

    	MODELPIXELSCALETAG = [binsize, binsize, 1]    

	zgrid1 = reverse(zgrid, 2)
	zgrid1 = float(zgrid1)

	fnsplit = strsplit(fn_arr(i), '/', /extract)
	if not keyword_set(opath) then begin
	   opath1 = '/'+strjoin(fnsplit[0:n_elements(fnsplit)-2], '/')+'/'
	   fname = fnsplit(n_elements(fnsplit)-1)
	endif else begin
	   opath1 = opath
	endelse

	if not keyword_set(ofname) then begin
	   strindx = strcompress(string(indx(j)), /remove_all)
	   ofname1 = (strsplit(fname, '.', /extract))[0]+"_"+strindx+".tif"
 	endif else begin
	   ofname1 = ofname
	endelse

	MODELTIEPOINTTAG = [0, 0, 0, mets_pos(0,0), mets_pos(1,1), 0]
	write_tiff, opath1+ofname1, zgrid1, orientation=1, /float, /verbose, geotiff = { $
                        MODELPIXELSCALETAG: MODELPIXELSCALETAG, $
                        MODELTIEPOINTTAG: MODELTIEPOINTTAG, $
                        GTMODELTYPEGEOKEY: 1, $
                        PROJECTEDCSTYPEGEOKEY: proj_cs_key, $
                        GTRASTERTYPEGEOKEY: 1, $
                        PCSCITATIONGEOKEY: proj_cit_key, $
                        PROJLINEARUNITSGEOKEY: 9001, $
                        VERTICALCSTYPEGEOKEY: 5103, $
                        VERTICALCITATIONGEOKEY: 'NAVD88' $
                        }
    endfor
endfor

return
end
