func fl1utm2ll(l1_path, l1_file, zone, opath=, ofname=) {
  /* DOCUMENT fl1utm2ll(l1_path, l1_file, zone) 
     this function converts a level 1 file from utm to latlon.  It writes out the file in the same format as the l1 file.  It just replaces the northings with the latitude and eastings with the longitude.  The lat and lon are in microdegrees.
     amar nayegandhi 06/18/2002.

     see also: ll2utm, utm2ll, read_yfile
  */

  /* read the level 1 file using function read_yfile */
  data_ptr = read_yfile(l1_path, fname_arr=l1_file);
  data = *data_ptr(1);
  /* convert utm to latlon using function utm2ll */
  write, "Converting UTM to latlon... "
  ll_arr = utm2ll(data.north/100., data.east/100., zone);
  /* change degrees to long integer in microdegrees */
  ll_arr = long(ll_arr * 1000000);
  data.east = ll_arr(*,1);
  data.north = ll_arr(*,2);

  /* now write output to file if asked */
  if (opath) {
    if (!ofname) {
      /* make new file name */
      l1_file_arr = strtok(l1_file, ".");
      ofname = l1_file_arr(1)+"_ll."+l1_file_arr(2);
    }
    write, "Output Data in Latitude/Longitude format being written to file: ";
    write, format="%s \n",ofname;
    write_geoall, data, opath=opath, ofname=ofname;
  } 
  if (!(opath)) return data;
}

  
func fl1ll2utm(l1_path, l1_file, opath=,ofname=) {
  /* DOCUMENT fl1ll2utm(l1_path, l1_file, opath=, ofname=) 
     this function converts a level 1 file from latlon to utm.  It writes out the file in the same format as the l1 file.  It just replaces the latitudes with the northings and longitudes with the eastings.  The lat and lon are in microdegrees and easting/northing in centimeters.
     amar nayegandhi 06/24/2002.

     see also: ll2utm, utm2ll, read_yfile, fl1utm2ll
  */

  /* read the level 1 file using function read_yfile */
  data_ptr = read_yfile(l1_path, fname_arr=l1_file);
  data = *data_ptr(1);
  /* convert utm to latlon using function utm2ll */
  write, "Converting latlon to UTM ... "
  ll_arr = ll2utm(data.north/1000000., data.east/1000000., retarr=1);
  /* change degrees to long integer in microdegrees */
  ll_arr = long(ll_arr * 100);
  data.east = ll_arr(*,1);
  data.north = ll_arr(*,2);

  /* now write output to file if asked */
  if (opath) {
    if (!ofname) {
      /* make new file name */
      l1_file_arr = strtok(l1_file, ".");
      ofname = l1_file_arr(1)+"_utm."+l1_file_arr(2);
    }
    write, "Output Data in UTM Easting/Northing format being written to file: ";
    write, format="%s \n",ofname;
    write_geoall, data, opath=opath, ofname=ofname;
  } 
  if (!(opath)) return data;
}

  
