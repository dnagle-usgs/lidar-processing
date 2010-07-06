function read_yfile, path, fname_arr=fname_arr, ndim=ndim

;this procedure reads an EAARL yorick-written binary processing file.
;amar nayegandhi 02/23/02
;Input parameters:
;    path         - Path name where the file(s) are located. Don't forget the '/' at the end of the path name.
; fname_arr    - An array of file names to be read.  This may be just 1 file name.
;    ndim	- number of samples to skip
; Output:
;    This function returns a an array of pointers.  Each pointer can be dereferenced like this:
;  IDL> data_ptr = read_yfile("~/input_files/")
;  IDL> data1 = *data_ptr(0)
;  IDL> help, data1, /struc
;  IDL> data2 = *data_ptr(1)

if not keyword_set(ndim) then ndim = 1

if not keyword_set(fname_arr) then begin
    ;search in the directory path to find all files with .bin extension
    spawn, 'find '+path+' -name "*.bin"', fn_arr
    spawn, 'find '+path+' -name "*.edf"', fn_arr1
    fn_arr_new = fn_arr+fn_arr1
    fn_arr = fn_arr_new
endif else fn_arr = path+fname_arr
bytord = 0L
type =0L
nwpr = 0L
recs = 0L
nfiles = n_elements(fn_arr)
data_ptr = ptrarr(nfiles, /allocate_heap)

for i = 0, nfiles-1 do begin
  openr, rlun, fn_arr[i], /get_lun

  ;read the byte order of the file
  readu, rlun, bytord
  if (bytord eq 65535L) then order = 1 else order = 0

  ;read the output type of the file
  readu, rlun, type

  ;read the number of words in each record
  readu, rlun, nwpr

  ;read the total number of records
  readu, rlun, recs

  ;define the array of data structures using the value of type.  
  data = define_struc(type, nwpr, recs)

  ;now read the data
  A = assoc(rlun, data, 16, /packed)
  data = A(0)
  if (ndim ne 1) then begin
	data = data(1:n_elements(data)-1:ndim)
  endif

  *data_ptr[i]=data

  free_lun, rlun
  close, rlun

endfor

return, data_ptr

ptr_free, data_ptr
end


function read_nrecords, path, fname_arr=fname_arr
;this procedure reads and outputs the number of records in an 
; EAARL yorick-written binary processed file.
;amar nayegandhi 07/12/06
;Input parameters:
;    path         - Path name where the file(s) are located. Don't forget the '/' at the end of the path name.
; fname_arr    - An array of file names to be read.  This may be just 1 file name.
; Output:
; 	nrecs  - number of records in the file
if not keyword_set(fname_arr) then begin
    ;search in the directory path to find all files with .bin extension
    spawn, 'find '+path+' -name "*.bin"', fn_arr
    spawn, 'find '+path+' -name "*.edf"', fn_arr1
    fn_arr_new = fn_arr+fn_arr1
    fn_arr = fn_arr_new
endif else fn_arr = path+fname_arr
bytord = 0L
type =0L
nwpr = 0L
recs = 0L
nfiles = n_elements(fn_arr)

nrecs = 0

for i = 0, nfiles-1 do begin
  openr, rlun, fn_arr[i], /get_lun
  ;read the byte order of the file
  readu, rlun, bytord
  if (bytord eq 65535L) then order = 1 else order = 0

  ;read the output type of the file
  readu, rlun, type

  ;read the number of words in each record
  readu, rlun, nwpr

  ;read the total number of records
  readu, rlun, recs

  free_lun, rlun
  close, rlun

  nrecs += recs

endfor

return, nrecs
end
