// vim: set ts=2 sts=2 sw=2 ai sr et:

func load_map(ffn=, color=, win=) {
/* DOCUMENT load_map(ffn=, color=, color=)
  Load a NOAA/USGS geographical coastline lat/lon map into the present
  window.  This is useful if you want to project some GPS positions
  onto a map easily.  Yorick lets you quickly and easily pan and zoom
  on the map and your data.

  Get the maps from: http://crusty.er.usgs.gov/coast/getcoast.html
  Use the "mapgen" format option. After you download the map, remove
  the first line (which is a comment beginning with a # sign).  This
  function expects the map files to end with a .pbd or .amap extension.

  SEE ALSO:   ll2utm, show_map, convert_map
*/
  extern utm;
  extern map_path;
  extern dllmap;          // array of pointers to digital map data

  // Set the following to where the maps are stored on your system.
  default, map_path, "~/lidar-processing/maps";
  default, color, "black";

  if(is_void(ffn))
    ffn = select_file(map_path, pattern="\\.pbd$");

  if(file_extension(ffn) == ".pbd") {
    mapf = openb(ffn);
    dllmap = [];
    restore, mapf;
  } else {
    convert_map, ffn=ffn, msave=0, utm=utm;
  }

  if(is_void(dllmap)) {
    write, "This does not appear to be a pbd map file";
    return;
  }
  show_map, dllmap, color=color, win=win;
}


func show_map(m, color=, width=, noff=, eoff=, win=) {
/* DOCUMENT show_map, m, color=, width=, noff=, eoff=, win=
  This function plots the base map in either lat lon or utm. For utm, if the
  map crosses 2 or more zones, the user is prompted for the zone number if
  curzone is not in the area covered.
*/
  extern curzone, utm;
  if (!is_array(m)) {
    write, "No map data is available.";
    return;
  }
  default, noff, 0;
  default, eoff, 0;
  default, width, 1.0;
  default, color, "black";
  sz = dimsof(m)(2);
  map_warning,m;
  if (utm) {
    // check for zone boundaries
    minlon = 361.0;
    maxlon = -361.0;
    for (i=1;i<=sz;i++) {
      if (min(*m(i))(1,) < minlon) minlon = min((*m(i))(,2));
      if (max(*m(i))(1,) > maxlon) maxlon = max((*m(i))(,2));
    }
    zmaxlon = int(maxlon+180)/6 + 1;
    zminlon = int(minlon+180)/6 + 1;
    zdiff = zmaxlon - zminlon;
    if (zdiff > 0) {
      // map data definitely crosses atleast 2 zones
      write, format="Selected Base Map crosses %d UTM Zones (%d to %d).\n",
        zdiff, zminlon, zmaxlon;
      if(zminlon <= curzone && curzone <= zmaxlon) {
        write, format="Using curzone (zone %d)\n", curzone;
      } else {
        write, format="Select Zone Number from %d to %d: \n", zminlon, zmaxlon;
        strzone = rdline( prompt="Enter Zone Number: ");
        sread, strzone, format="%d",curzone;
      }
    }
  }
  wbkp = current_window();
  window, win;
  for (i=1; i<=sz; i++ ) {
    a = *m(i);
    if (utm) {
      u = fll2utm(a(,1),a(,2));
      zone = u(3,);
      if (!curzone) curzone = u(3,1);
      idxcurzone = where(zone == curzone);
      if (is_array(idxcurzone)) {
        u = u(1:2,idxcurzone);
        a = transpose(u);
      } else {
        a = [];
      }
    }
    if (is_array(a)) {
      plg,a(,1)+noff,a(,2)+eoff,marks=0,color=color, width=width;
    }
  }
  window_select, wbkp;
}

func map_warning(m) {
/* DOCUMENT map_warning, m

  Test the size of a map variable (array of pointers) and if it's greater
 than 6000 print a warning.  This was tested on the pacific ocean where there
 are many small islands which cause a map to easily contain more than the
 ~6000 limit.  If you zoom way in on a feature, Yorick will give a
 "looping error" and crash.

*/
  if ( dimsof(m)(2) > 6000 ) {
    write,"***********************************************";
    write,"*              ** Warning **                  *";
    write,"* Your map is too large. It will crash Ytk if *";
    write,"* you zoom way in on small features.          *";
    write,format=" * Your map contains %d polygons. You       *\n", dimsof(m)(2);
    write,"* should not exceed 6000 polygons.            *";
    write,"***********************************************";
  }
}

func convert_map(ffn=, utm=, msave=, arcview=) {
/* DOCUMENT convert_map(ffn=, utm=, msave=, arcview=)

  Convert a NOAA/USGS ASCII geographical coastline lat/lon map into
  a pbd file.

  This is useful if you want to project some GPS positions
  onto a map easily within Yorick.  Yorick lets you quickly and
  easily pan and zoom on the map and your data.

  After you convert the map, use load_map to select and display the
  resulting pbd map file.

  Get the maps from: http://crusty.er.usgs.gov/coast/getcoast.html
  Use the "mapgen" format option. After you download the map, remove
  the first line (which is a comment beginning with a # sign).  This
  function expects the map files to end with a .amap extension.

  SEE ALSO: ll2utm
*/
  extern map_path;
  extern dllmap;		// array of pointers to digital map data

  default, msave, 1;
  default, utm, 0;

  // Set the following to where the maps are stored on your system.
  default, map_path, "./maps";

  if(is_void(ffn))
    ffn = select_file(map_path, pattern="\\.(amap|pbd)$");

  mapf = open(ffn, "r" );
  dllmap = [];
  lsegs = 0;
  str = array(string,1);
  lat = array(float, 1000);
  lon = array(float, 1000);
  segnum = array(long, 1);

  if (catch(0x02)) {
    close,mapf;
    return;
  }

  // load upto 100,000 line segments
  for (i=0; i<100000; i++) {
    if (arcview) {
      n = read(mapf, format="%d",segnum);
      n = read(mapf, format="%f,%f",lon,lat);
    } else {
      n = read(mapf,format="%f %f", lon,lat)
    }
    if ( n == 0 ) {
      close,mapf;
      write,i," line segments loaded";
      if ( msave != 0 ) {
        ofn = strtok( ffn, ".") (1);
        ofn += ".pbd";
        ofd = createb(ofn);
        save,ofd,dllmap;
        close,ofd;
        write,format="Binary map saved to: %s\n", ofn;
      }
      return;
    }
    n = n/2;
    lsegs++;
    if ( lat(1) == 0 ) break;
    if ( (i % 1000) == 0  ) {
      print,i;
      redraw;
    }
    if ( utm == 0 ) {
      ll = array(float, n, 2);		  // create temp array for this seg
      ll(,1) = lat(1:n); ll(,2) = lon(1:n);  // populate with lat/lon
      grow, dllmap, &ll;			  // concat to list of pointers
      plg,lat(1:n),lon(1:n),marks=0;	  // show the segment
    } else {
      fll2utm, lat, lon, UTMNorthing, UTMEasting, ZoneNumber;
      plg,UTMNorthing(1:n),UTMEasting(1:n),marks=0;
    }
    gridxy,0,0;
  }
  n=write(format="%d line segments read from %s\n", lsegs, fn);
  close,mapf;
}

func make_submap(utmzone, filename) {
/* DOCUMENT make_submap(utmzone, filename)
Lance Mosher 20050708
This function pulls a submap of the current dllmap variable and saves the
output to filename.  The current dllmap must be plotted in UTM in the
current window
*/
  extern dllmap;

//in case you ever want to use the GGA limits...
/*
  extern gga
  latmin = min(gga.lat);
  latmax = max(gga.lat);
  lonmin = min(gga.lon);
  lonmax = max(gga.lon);
  llarr = fll2utm([latmin, latmax],[lonmin, lonmax]);
  emin = llarr(2,1);
  emax = llarr(2,2);
  nmin = llarr(1,1);
  nmax = llarr(1,2);
*/

  a = mouse(1,1, "Hold the left mouse button down, select a region:");
  emin = min( [ a(1), a(3) ] );
  emax = max( [ a(1), a(3) ] );
  nmin = min( [ a(2), a(4) ] );
  nmax = max( [ a(2), a(4) ] );

  sz = numberof(dllmap);
  smap = array(pointer, sz);
  for (i=1; i<=sz; i++ ) {
    a = *dllmap(i);
    u = fll2utm(a(,1),a(,2));
    zone = u(3,);
    idxcurzone = where(zone == utmzone);
    if (is_array(idxcurzone)) {
      u = u(1:2,idxcurzone);
      a = transpose(u);
      //if (a(,1)(max) >= 4200000) lance();
      //plmk, a(,1), a(,2), marker=4, msize=0.6, width=10, color="cyan"
      boxidx = data_box(a(,2),a(,1),emin,emax,nmin,nmax);
      if (is_array(boxidx)) {
        a = a(boxidx,1:2);
        u = utm2ll(a(,1), a(,2), utmzone);
        a = [u(,2), u(,1)];
        smap(i) = &a;
      }
    }
  }
  dllmap = smap(where(smap));
  if (is_array(dllmap)) {
    f = createb(filename);
    save, f, dllmap;
    close, f;
  } else {
    write, "Could not find data from dllmap within selected region!";
  }
}
