/********************************************************************


  Original by W. Wright 12/09/02

 This code is intended to correct EAARL water surface elevation data 
 for two observed effects: 

   1) differences between elevations determined from 
      waveforms dominated by fresnel surface reflections and those 
      dominated by volumetric water column backscatter, 

   2) geometric return backscatter stretching which occurs as a 
      function of angle-of-incidence or AOI. 



*********************************************************************/


func correct_fs( r, aoi= ) {
/* DOCUMENT correct_fs( r, aoi= )

 Only use this function for water surface data.  It correct a 
 an array of type "R" structure elevations for angle of 
 incidence and watern volumn vs fresnel reflections fro the 
 surface.

 Original W. Wright 12/9/02

*/
  n = numberof(r);
  if ( is_void( aoi ) )
	aoi = compute_aoi( r );
  rtn = r;
  for ( i=1; i< n; i++ ) {
    vbs     = where( r(i).intensity < 90 );
    sr      = where( r(i).intensity > 90 );
    if ( numberof(vbs) )
       rtn(i).elevation(vbs) = r(i).elevation(vbs) + aoi(vbs, i) * 0.821321 + 11.2; 
    if ( numberof(sr ) )
       rtn(i).elevation( sr) = r(i).elevation( sr) + aoi( sr, i) * 0.279269;
  }
 return rtn;
}



 func compute_aoi( r ) {
////// extern aoi, hyp; 
 n = numberof( r );
 hyp = array( float, 120, n ); 
 aoi = array( float, 120, n ); 
 for (i=1; i<n; i++ ) { 
    a = b = c = d = array( double, 120 );
    de = r(i).melevation - r(i).elevation;
    lst = where( (de > 100) & (de < 90000 ));
    if ( numberof(lst) ) {
      a(lst) = (de(lst))^2;
      b(lst) = double(r(i).meast(lst)      - r(i).east(lst))^2;
      c(lst) = double(r(i).mnorth(lst)     - r(i).north(lst))^2;
      hyp(lst,i) = sqrt( a(lst) + b(lst) + c(lst));

      aoi(lst,i) = acos( (r(i).melevation(lst) - 
                     r(i).elevation(lst)) / hyp(lst,i) )*rad2deg; 
    }
 }
 return aoi;
}





