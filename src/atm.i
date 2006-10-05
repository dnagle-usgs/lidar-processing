#include "plcm.i"
#include "sel_file.i"

/*
    atm.i	C. W. Wright 
 $Id$
		http://lidar.wff.nasa.gov

    Yorick functions to display atm data.
*/


// ATM2 structure has been designed to mimic the VEG__ structure.
// this allows most of the EAARL functions to work with ATM2.
struct ATM2 {
   long north;
   long east;
   long elevation;
   short fint; // intensity
   long least // passive channel latitude
   long lnorth // passive channel longitude
   double lint // passive intensity
   double soe // timestamp (may not be in soe format)
}

func load {
/* DOCUMENT load
*/
 extern fn, f, lat,lon, ilat,ilon, iz, z
 fn = sel_file(ss="*.pbd") (1)			// select the data file
 f = openb(fn);					// open selected file
 show,f						// display vars in file
 restore,f					// load the data to ram
 write,format="%s loaded %d points\n", fn, numberof(ilat);
 lat = ilat / 1.0e6;				// make a floating pt lat
 lon = ilon / 1.0e6 - 360.0;			// make fp lon 
}

func show_all( sz=)  {
/* DOCUMENT show_all

   Display an entire atm data file as sequencial images false color
   coded elevation maps.

 */
b = 1				// starting record number
inc = 50000			// number to adjust start pt by
n = 50000			// number of points to display/image 
// animate,1			// uncomment to only see completed images
 if ( is_void(sz) ) 		// if sz not set, use 0.001 for default
        sz = 0.001;
 for (b = 1; b< numberof(lat)-inc-1; b+= inc ) {	// loop thru file
  fma; 							// advance display frame
  write,format="%8d %8.4f %8.4f\n", b, lat(b), lon(b)	// print some stuff
  plcm,iz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=-41000, cmax=-30000, marker=1,msize=1.0 
//  plcm,ipz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=0, cmax=1000, shape=1, sz=sz
 }
// animate,0			// uncoment if animate,1 above is used
}


func show_frame (b, n, cmin=, cmax=, marker=, msize= ){
/* DOCUMENT show_all

    display a single atm display frame
 */
  if ( is_void( cmin) )
        cmin = -42000;
  if ( is_void(cmax) ) 
        cmax = -22000;
  if ( is_void( sz ) )
        sz = 0.0015
  if ( is_void(msize) )
        msize = 1.0;
  fma; 
  write,format="%8d %8.4f %8.4f\n", b, lat(b), lon(b)
  plcm,iz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=cmin, cmax=cmax, marker=1,msize=msize
}


func atm_rq_ascii_to_pbd(ipath, ifname=, columns=, searchstr=, opath=) {
  // amar nayegandhi
  // 10/05/2006

  if (is_void(ifname)) {
    s = array(string, 10000);
    if (searchstr) {
     ss = searchstr;
    } else {
      ss = ["*.txt", "*.xyz"];
    }
    scmd = swrite(format = "find %s -name '%s'",ipath, ss);
    fp = 1; lp = 0;
    for (i=1; i<=numberof(scmd); i++) {
      f=popen(scmd(i), 0);
      n = read(f,format="%s", s );
      close, f;
      lp = lp + n;
      if (n) fn_arr = s(fp:lp);
      fp = fp + n;
    }
  } else {
    fn_arr = ipath+ifname;
    n = numberof(ifname);
  }

  write, format="Number of files to read = %d \n", n

  for (i=1;i<=n;i++) {
    // read ascii file
    write, format="Reading file %d of %d\n",i,n;
    fn_split = split_path(fn_arr(i),0);
    asc_out = read_ascii_xyz(ipath=fn_split(1),ifname=fn_split(2),columns=columns);
    ncount = numberof(asc_out(1,));
    atm_out = array(ATM2,ncount);
    // convert lat lon to utm
    e_utm = fll2utm(asc_out(1,), asc_out(2,));
    atm_out.east = long(e_utm(2,)*100);
    atm_out.north = long(e_utm(1,)*100);
    atm_out.elevation = long(asc_out(3,)*100);
    atm_out.fint = short(asc_out(4,));
    e_utm = fll2utm(asc_out(5,), asc_out(5,));
    atm_out.least = long(e_utm(2,)*100);
    atm_out.lnorth = long(e_utm(1,)*100);
    atm_out.lint = short(asc_out(7,));
    atm_out.soe = asc_out(8,);
    // write atm_out to a pbd file
    ofn_split = split_path(fn_arr(i),0);
    ofn_split1 = split_path(ofn_split(2),0,ext=1)
    ofn = ofn_split1(1)+".pbd"
    write, format="Writing file %s\n",ofn;
    if (opath) {
    	f = createb(opath+ofn);
    } else {
	f = createb(ofn_split(1)+ofn);
    }
    save, f, atm_out;
    close, f
    
  }
    
    
return
}

  

func rcf_atm_pbds(ipath, ifname=, searchstr=, buf=, w=, opath=) {
  // amar nayegandhi
  // 10/05/2006

  if (is_void(buf)) buf = 1000;
  if (is_void(w)) w = 2000;
  if (is_void(ifname)) {
    s = array(string, 10000);
    if (searchstr) {
     ss = searchstr;
    } else {
      ss = ["*.pbd"];
    }
    scmd = swrite(format = "find %s -name '%s'",ipath, ss);
    fp = 1; lp = 0;
    for (i=1; i<=numberof(scmd); i++) {
      f=popen(scmd(i), 0);
      n = read(f,format="%s", s );
      close, f;
      lp = lp + n;
      if (n) fn_arr = s(fp:lp);
      fp = fp + n;
    }
  } else {
    fn_arr = ipath+ifname;
    n = numberof(ifname);
  }

  write, format="Number of files to read = %d \n", n

  for (i=1;i<=n;i++) {
    // read pbd file
    f = openb(fn_arr(i))
    restore, f;
    info, atm_out;
    close, f;
    atm_rcf = rcfilter_eaarl_pts(atm_out, buf=buf, w=w, mode=1);
    
    // write atm_rcf to a pbd file
    ofn_split = split_path(fn_arr(i),0);
    ofn_split1 = split_path(ofn_split(2),0,ext=1)
    ofn = ofn_split1(1)+"_rcf.pbd"
    write, format="Writing file %s\n",ofn;
    if (opath) {
    	f = createb(opath+ofn);
    } else {
	f = createb(ofn_split(1)+ofn);
    }
    save, f, atm_rcf;
    close, f
  }

}
