pro multibatch, directory, mineast, maxnorth, maxeast, minnorth, tag=tag

;Takes the northwest and southeast corners of a region overwhich the users 
;wishes to make batchfiles  and dirctories and then adjusts these cordinates to cover a 
;slightly larger region in such a way that the index tiles created all line
;up with a given Key West index tile.  The idea is that all index tiles created
;in all regions will line up without overlap.  The dircectory is the root
;directory the batchdirectories and files will be created in and tag is a string;appended to the end of the batchfiles -BP 06/25/2003

;This is the reference index tile that the tiles created by this prog will 
;line up with
eindex = 484000L
nindex = 2734000L

mineast = long(mineast)
maxnorth = long(maxnorth)
maxeast = long(maxeast)
minnorth = long(minnorth)


ediff = mineast-eindex
esteps = ediff/12000
efirstspot = eindex + (12000 *esteps)
if ((ediff mod 12000) eq 0) then begin efinalspot = efirstspot
endif else begin
	if (mineast lt eindex) then efinalspot = efirstspot - 12000
	if (mineast gt eindex) then efinalspot = efirstspot
endelse

ndiff = maxnorth - nindex
nsteps = ndiff/12000
nfirstspot = nindex + (12000 * nsteps)
if ((ndiff mod 12000) eq 0) then begin nfinalspot = nfirstspot
endif else begin
	if (maxnorth lt nindex) then nfinalspot = nfirstspot
	if (maxnorth gt nindex) then nfinalspot = nfirstspot + 12000
endelse


ediff = maxeast - efinalspot
esteps = ediff/12000
esteps = esteps +1
finalmaxeast = efinalspot + (esteps*12000)

ndiff = nfinalspot - minnorth
nsteps = ndiff/12000
nsteps = nsteps+1
finalminnorth = nfinalspot -(nsteps*12000)

print, efinalspot, nfinalspot, finalmaxeast, finalminnorth

for emin = efinalspot, finalmaxeast-12000, 12000 do begin
	for nmax = finalminnorth+12000, nfinalspot, 12000 do begin
		if keyword(tag) then batchmaker, directory, emin, nmax, tag=tag $ 
	        else batchmaker, directory, emin, nmax   
	endfor
endfor
spawn, "cat "+directory+"*.bat >"+directory+"merged.txt"
print, 'Pilotbatch completed....'
return
end
