// vim: set ts=2 sts=2 sw=2 ai sr et:
func write_gga_ascii (ofname, utm=, uniq=, write_time=) {
/* DOCUMENT write_gga_ascii (ofname, utm=, uniq=, write_time=)
  amar nayegandhi
  updated 06/29/05
  This function writes out the pnav/gga data in ascii format.  Used
  primarily for converting the pnav data to a shapefile. The function
  will prompt for pnav/gga file to be loaded.
  INPUT:
    ofname = output file name
    utm = set to 1 if output should be in UTM coords
    uniq = set to 1 if unique locations are required
    write_time = writes GMT time of day in hhmmss as an attribute. Useful
    		when using with cir or rgb images.
*/
  extern gga;
  gga = rbpnav();

  f = open(ofname, "w");
  if (utm) {
    if (write_time) {
      write, f, "Easting, Northing, Attribute"
    } else {
      write, f, "Easting, Northing"
    }
    u = fll2utm(gga.lat, gga.lon)
    if (write_time) {
      u1 = array(double,4,numberof(u(1,)));
      u1(1:3,) = u;
      u1(4,) = sod2hms(gga.sod, noary=1);
      u = u1; u1 = [];
    }
    if (uniq) {
      uqu = multi_unique(u);
    } else {
      uqu = u
    }
    if (write_time) {
      if (write_time) {
        // sort by sod
	indx = sort(uqu(4,));
	uqu = uqu(,indx);
      }
      write, f, format="%9.2f, %10.2f, %6.0f\n", uqu(2,), uqu(1,), uqu(4,);
    } else {
      write, f, format="%9.2f, %10.2f\n", uqu(2,), uqu(1,);
    }
  } else {
    if (write_time) {
      write, f, "Longitude, Latitude, Attribute"
    } else {
      write, f, "Longitude, Latitude"
    }
    ll = transpose([gga.lon, gga.lat, sod2hms(gga.sod, noary=1)]);
    if (uniq) {
      uql = multi_unique(ll);
    } else {
      uql = ll;
    }
    if (write_time) {
      if (write_time) {
        // sort by sod
	indx = sort(uql(3,));
	uql = uql(,indx);
      }
      write, f, format="%10.7f, %10.7f, %6.0f\n", uql(1,), uql(2,), uql(3,);
    } else {
      write, f, format="%10.7f, %10.7f\n", uql(1,), uql(2,);
    }

  }
  close, f
  return
}

func multi_unique(lonlat) {
  require, "msort.i"
  dims = dimsof(lonlat);
  no_dims = dims(1);
  n1 = dims(2);
  indx = msort(lonlat(1,), lonlat(2,));
  lonlat = lonlat( ,indx);
  indx = where((lonlat(1,1:-1) != lonlat(1,2:0)) | (lonlat(2,1:-1) != lonlat(2,2:0)));
  lonlat = lonlat(,indx);
  return lonlat;
}
