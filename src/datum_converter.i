/*
  $Id: datum_converter.i
  original amar nayegandhi 07/15/03
*/
  
require, "wgs842nad83.i"
require, "nad832navd88.i"
func data_datum_converter(wdata, utmzone=, tonad83=, tonavd88=, type=) {
/* DOCUMENT data_datum_converter(wdata, utmzone=, tonad83=, tonavd88=, type=)
     This function converts eaarl data of structure type 'type' to nad83 and navd88.
     INPUT:
	wdata: data in wgs84 coordinates
	utmzone: current utm zone number
	tonad83= set to 1 to convert to nad83 horizontal datum, else set to 0 (default 1)
	tonavd88= set to 1 to convert to navd88 vertical datum using GEOID99 model, else set to 0 (default = 1).
	type= type of input data array (e.g. FS, VEG__, GEO)
     OUTPUT:
	returned data array after conversion.
     amar nayegandhi 07/15/03.
*/
   
   extern curzone;

   if (is_void(tonad83)) tonad83=1;
   if (is_void(tonavd88)) tonavd88=1;

   data = wdata;
   if (!utmzone) {
     if (curzone) {
       utmzone = curzone;
       write, "Using Current UTM Zone = %d\n",curzone;
     } else {
       utmzone = 0;
       f = read(prompt="Enter UTM Zone Number:", utmzone);
       curzone = utmzone;
     }
   }
   // since all the data sets will have data.east, data.north and data.elevation
   // and data.meast, data.mnorth and data.melevation; do the conversion without testing for type.

   //convert data to latlon
   write, "***  Converting Mirror Location  ***"
   write, "Converting data to lat/long..."
   data_in = utm2ll(data.north/100., data.east/100., utmzone);
   // put data in correct format for conversion
   data_in = transpose([data_in(,1), data_in(,2), data.elevation/100.]);
   // convert...
   if (tonad83) {
     write, "Converting to NAD83..."
     data_out = wgs842nad83(data_in);
     if (tonavd88) 
       data_in = data_out;
   }
   if (tonavd88) {
     write, "Converting to NAVD88..."
     data_out = nad832navd88(data_in);
   }
   // convert data back to utm
   write, "Converting data back to UTM..."
   utmdata_out = fll2utm(data_out(2,), data_out(1,));
   // put converted data in output format
   data.north = int(utmdata_out(1,)*100);
   data.east = int(utmdata_out(2,)*100);
   data.elevation = int(data_out(3,)*100);

   //convert data to latlon
   write, "***  Converting First Surface Location  ***"
   write, "Converting data to lat/long..."
   data_in = utm2ll(data.mnorth/100., data.meast/100., utmzone);
   // put data in correct format for conversion
   data_in = transpose([data_in(,1), data_in(,2), data.melevation/100.]);
   // convert...
   if (tonad83) {
     write, "Converting to NAD83..."
     data_out = wgs842nad83(data_in);
     if (tonavd88) 
       data_in = data_out;
   }
   if (tonavd88) {
     write, "Converting to NAVD88..."
     data_out = nad832navd88(data_in);
   }
   // convert data back to utm
   write, "Converting data back to UTM..."
   utmdata_out = fll2utm(data_out(2,), data_out(1,));
   // put converted data in output format
   data.mnorth = int(utmdata_out(1,)*100);
   data.meast = int(utmdata_out(2,)*100);
   data.melevation = int(data_out(3,)*100);
    
   // now look at type for the special case of veg
   if (type == VEG__) {
      write, "***  Converting Last Return Location  ***"
      write, "Converting data to lat/long..."
      //convert data to latlon
      data_in = utm2ll(data.lnorth/100., data.least/100., utmzone);
      // put data in correct format for conversion
      data_in = transpose([data_in(,1), data_in(,2), data.lelv/100.]);
      // convert...
      if (tonad83) {
        write, "Converting to NAD83..."
        data_out = wgs842nad83(data_in);
        if (tonavd88) 
          data_in = data_out;
      }
      if (tonavd88) {
        write, "Converting to NAVD88..."
        data_out = nad832navd88(data_in);
      }
      // convert data back to utm
      write, "Converting data back to UTM..."
      utmdata_out = fll2utm(data_out(2,), data_out(1,));
      // put converted data in output format
      data.lnorth = int(utmdata_out(1,)*100);
      data.least = int(utmdata_out(2,)*100);
      data.lelv = int(data_out(3,)*100);
   }
   return data
}


func pnav_datum_converter(tonad83=, tonavd88=, wpnav=,pnavfile=,outfile=,outfilename=) {
  /* DOCUMENT pnav_w842n83(pnav=,pnavfile=,outfile=,outfilename=)
     This function converts pnav data referenced to wgs84 to nad83 and navd88.
     amar nayegandhi 07/15/03.
  */
   if (pnavfile) {
     wpnav = rbpnav();
   } 
   if (!is_array(wpnav)) {
      write, "PNAV FILE NOT CHOSEN.  GoodBye."
      return
   }
   data_in = transpose([wpnav.lon, wpnav.lat, wpnav.alt]);
   if (tonad83) 
     data_out = wgs842nad83(data_in);
   if (tonavd88)
     data_out = nad832navd88(data_out);
   npnav = wpnav;
   npnav.lon = data_out(1,);
   npnav.lat = data_out(2,);
   npnav.alt = data_out(3,);

   if (outfile) {
     if (!outfilename) {
     	npnavf = split_path(pnavfile, 0, ext=1);
        outfilename = npnavf(1)+"-nad83.pbd";
     }
     save, createb(outfilename), npnav;
   } 
   return npnav;
}

