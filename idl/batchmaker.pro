pro batchmaker, path_name, index_easting, index_northing, tag=tag
; batchmaker is a utility to generate batch files to process EAARL data using the ALPS processing system.  
; To run, compile and then type <batchmaker, "path_name", mineasting, maxnorthing, tag="tag">
; The <>'s are not needed but the quote marks ARE needed.
; path_name = the root path from where all the tile directories and files will be saved I.E ~/Data/EAARL/KEYS/
; mineasting and maxnorthing are the UTM coordinates of the northwest corner of the 12x12 km index tile
; tag is an option to define the type of data being processed. It is a single character string only. 
; Set tag to "b" for bathymetry and "v" for vegetation
; Program by Lance Mosher updated 12/03/02
; Last modified June 03, 2003.

file = path_name + string(index_easting, index_northing, format='("i_e", i6, "_n", i7, ".bat")') ;specefies file to be created

if keyword_set(tag) then file = path_name + string(index_easting, index_northing, tag, format='("i_e", i6, "_n", i7, "_", a1, "_.bat")')

OpenW, lun, file, /Get_Lun                                ; opens 'file'

eminstart = index_easting                                 ; Defines the NW corner range for a 12x12 km tile
eminend = index_easting + 10000
nmaxstart = index_northing - 10000
nmaxend = index_northing
			          
index_tile_dir = path_name + string(index_easting, index_northing, format='("i_e", i6, "_n", i7, "/")')
spawn, "mkdir " + index_tile_dir                          ; Creates index tile directory defined above

for emin = eminstart, eminend, 2000 do begin     	  ; Selects a starting easting, going up 2000 until eminend 
	for nmax = nmaxstart, nmaxend, 2000 do begin      ; Selects a starting northing, going up 20000 until nmaxend
		dirtoadd= string(emin, nmax, format='("t_e", i6, "_n", i7)') ; Specefies directory to be created
		coords = string(emin, nmax, emin, nmax, emin, (emin + 2000), (nmax - 2000), nmax, $
   		 format='("t_e", i6, "_n", i7, "/t_e", i6, "_n", i7, "_", ".edf", " ", i6, " ", i6, " ", i7, " ", i7)') ; This line is really ugly b/c emin and nmax must be converted to strings.
		if keyword_set(tag) then coords = string(emin, nmax, emin, nmax, tag, emin, (emin + 2000), (nmax - 2000), nmax, $
		 format='("t_e", i6, "_n", i7, "/t_e", i6, "_n", i7, "_", a1, "_", ".edf", " ", i6, " ", i6, " ", i7, " ", i7)')		
		strtoadd = string(index_tile_dir + coords)  ; Defines the string that will be added to command file		
		PrintF, lun, strtoadd ; Adds the tile to the batch file
		spawn, "mkdir " + index_tile_dir + dirtoadd ; Makes the directory for the .edf to be created
	endfor
endfor
Free_Lun, lun
Print, 'Batch Process File Generated...'
return
end
