// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_msort_obj(obj) { 
/* DOCUMENT idx = msort_obj(obj) 
  This is like msort, but instead of operating over multiple arrays, it 
  operates over the arrays in an oxy object. Thus, this: 
    > data = save(raster, pulse) 
    > idx = msort(data.raster, data.pulse) 
  Is equivalent to this: 
    > data = save(raster, pulse) 
    > idx = msort_obj(data) 
 
  If any fields are void, they will be skipped. Otherwise, all fields must be 
  one-dimensional arrays of the same size. 
*/ 
  local list; 
  
  count = obj(*); 
 
  // Get rid of any void members 
  keep = array(1, count); 
  for(i = 1; i <= count; i++) { 
    keep(i) = !is_void(obj(noop(i))); 
  } 
  if(noneof(keep)) return []; 
  obj = obj(where(keep)); 
  count = obj(*); 
 
  mxrank = numberof(obj(1))-1; 
  _rank = msort_rank(obj(1), list); 
  if(max(_rank) == mxrank) return list; 
 
  norm = 1./(mxrank+1.); 
  if(1.+norm == 1.) error, pr1(mxrank+1)+" is too large an array"; 
  
  for(i = 2; i <= count; i++) { 
    _rank += msort_rank(obj(noop(i)))*norm; 
    _rank = msort_rank(_rank, list); 
    if(max(_rank) == mxrank) return list; 
  } 
 
  return sort(_rank+indgen(0:mxrank)*norm); 
}

if(!is_func(msort_obj)) msort_obj = nocalps_msort_obj;
