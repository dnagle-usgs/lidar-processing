func write_gga_ascii (ofname, utm=, uniq=) {
   extern gga;
   gga = rbgga();
   f = open(ofname, "w");
   if (utm) {
     write, f, "Easting, Northing\n"
     u = fll2utm(gga.lat, gga.lon)
     if (uniq) {
       uqu = multi_unique(transpose([u(1,),u(2,)]));
     } else {
       uqu = transpose([u(2,), u(1,)]);
     }
     write, f, format="%12.2f,  %12.2f\n", uqu(2,), uqu(1,);
   } else {
     write, f, "Longitude, Latitude\n"
     if (uniq) {
       uql = multi_unique(transpose([gga.lon, gga.lat]));
       write, f, format="%10.7f,  %10.7f\n", uql(1,), uql(2,);
     } else {
       write, f, format="%10.7f,  %10.7f\n", gga.lon, gga.lat;
     }
   }
   close, f
   return
}



func multi_unique(lonlat) {
   require, "msort.i"
   dims = dimsof(lonlat);
   no_dims = dims(1);
   indx = msort(lonlat(1,), lonlat(2,));
   lonlat = transpose([lonlat(1,indx), lonlat(2,indx)]);
   indx = where((lonlat(1,1:-1) != lonlat(1,2:0)) | (lonlat(2,1:-1) != lonlat(2,2:0)));
   lonlat = transpose([lonlat(1,indx), lonlat(2,indx)]);
   return lonlat;
}
