pro multibatch, directory, mineasting, maxnorthing, number_east, number_south, tag=tag
; Multibatch will call batchmaker to automatically generate several index tiles at one time
; to use, type: multibatch, "directory", mineasting, maxnorthing, number_east, number_south, tag="tag"
; where "directory" is the root directory where index tiles are to be created
; mineasting/maxnorthing are the UTM coordinates of the northwest corner of the northwest index tile
; nuber_east/number_south are the number of index tiles to generate east and south of the northwest tile
; tag is an optional single-character tag appended to the filename of the tile.
; Set "tag" to "b" for bathymetry and "v" for vegetation
; Program by Lance Mosher, June 3, 2003
number_east=long(number_east)
number_south=long(number_south)
for emin = mineasting, (mineasting+((number_east-1)*12000)), 12000 do begin	
	for nmax = (maxnorthing-((number_south-1)*12000)), maxnorthing, 12000 do begin
		if not keyword_set(tag) then begin
			print, 'sending: ', directory, ' ', emin, ' ', nmax
        		batchmaker, directory, emin, nmax
		endif
		if keyword_set(tag) then begin
			print, 'sending: ', directory, ' ', emin, ' ', nmax, ' tag="', tag, '"'
        		batchmaker, directory, emin, nmax, tag=tag
		endif
	endfor	
endfor
Print, 'Pilotbatch Completed...'
return
end
