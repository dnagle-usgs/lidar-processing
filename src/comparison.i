/*
   $Id$
         */
    write, "$Id$"
/* 
  Routines to compare sonar data with eaarl bathymetric data
  amar nayegandhi 05/03
  */

func closest_point(sdata, ldata, r=) {
  //search for the closest lidar data point to a given sonar data point for radius r
  if (is_void(r)) r = 10;

  for (i=1;i<=numberof(sdata(1,));i++) {
    indx = where((ldata(1,)>=(sdata(1,i)-r)) & (ldata(1,) <= (sdata(1,i)+r)) & (ldata(2,) >= (sdata(2,i)-r)) & (ldata(2,) <= (sdata(2,i)+r)));
    if (is_array(indx)) {
      min_dist = min(sqrt((ldata(1,indx)-sdata(1,i))^2 + (ldata(2,indx)-sdata(2,i))^2));
      write, format="Minimum Distance from Sonar Point %d = %8.4f \n", i, min_dist;
      min_pos = ((ldata(1,indx)-sdata(1,i))^2 + (ldata(2,indx)-sdata(2,i))^2)(mnx);
      //grow, min_ldata, ldata(,indx(min_pos));
      grow, min_depth, (sdata(3,i)-ldata(3,indx(min_pos)));
      } else write, format="No point is within radius %d for sonar point %d \n",r,i;
    }
    return min_depth;
    }
