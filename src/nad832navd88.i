/* 
   $Id: nad832navd88.i
    amar nayegandhi, original nad832navd88.i
    charlene sullivan, modified form of nad832navd88.i for use of GEOID 96 model
    The following code has been adapted from the GEOID 99 model available at
    http://www.ngs.noaa.gov/GEOID/GEOID99/
    The original DISCLAIMER applies to this as well.
*/

require, "eaarl.i";
write, "$Id$";

func geoid_data_to_pbd(gfname=, pbdfname=, initialdir=, geoid_version=) {
   /*DOCUMENT geoid_data_to_pbd(gfname,pbdfname,initialdir,geoid_version)
    converts GEOIDxx ascii data files to pbd.  The ascii data files are available on the NGS website:
       ftp://ftp.ngs.noaa.gov/pub/pcsoft/geoid96
       http://www.ngs.noaa.gov/GEOID/GEOID99/dnldgeo99ot1.html
       http://www.ngs.noaa.gov/GEOID/GEOID03/download.html
    amar nayegandhi 07/10/03.
	modified 01/12/06 -- amar nayegandhi to add GEOID03
        modified 09/25/06 -- charlene sullivan to add GEOID96
   */

   if (!gfname) {
      if (is_void(initialdir)) initialdir = "/dload/geoid99_data/";
      gfname  = get_openfn( initialdir=initialdir, filetype="*.asc", title="Open GEOIDxx Ascii Data File" );
   }

   // split path and file name
   gpf = split_path(gfname,0);
   gpath = gpf(1);
   gfile = gpf(2);

   if (!pbdfname) 
       pbdfname = (split_path(gfname,0,ext=1))(1)+".pbd";

   // open geoid ascii data file to read
   write, "reading geoid ascii data";
   gf = open(gfname, "r");
   // read header data off the geoid data file
   glamn = glomn = dla = dlo = 0.0;
   nrows = ncols = itype =dla1 = dlo1 = 0;
   if (strmatch(geoid_version,"GEOID96",1)) {
       read, gf, ncols, nrows, itype, glomn, dlo, glamn, dla;
       // account for loss of precision in GEOID96 grid file headers
       dla1 = int(dla*3600.0) + 1;
       dlo1 = int(dlo*3600.0) + 1;
       dla = double(dla1)/3600.0;
       dlo = double(dlo1)/3600.0;
   } else {
       read, gf, glamn, glomn, dla, dlo;
       read, gf, nrows, ncols, itype;
   }
   data = array(double,ncols,nrows);
   read, gf, data;
   write, "writing geoid pbd data";
   pf = createb(pbdfname);
   vname = (split_path(gfile,0,ext=1))(1);
   save, pf, glamn, glomn, dla, dlo, nrows, ncols, itype, vname;
   add_variable, pf, -1, vname, structof(data), dimsof(data);
   get_member(pf,vname) = data;
   close, pf;
   return data;
}
   
func nad832navd88(data_in, gdata_dir=, geoid_version=) {
/* DOCUMENT nad832navd88(data_in, gdata_dir=, geoid_version=)
   Converts data from NAD83 to NAVD88. See nad832navd88offset for a description
   of the parameters. Returns the data with the elevations modified.
*/
   offset = nad832navd88offset(data_in, gdata_dir=gdata_dir, geoid_version=geoid_version);
   data_out = unref(data_in);
   data_out(3,) -= unref(offset);
   return data_out;
}

func navd882nad83(data_in, gdata_dir=, geoid_version=) {
/* DOCUMENT nad832navd88(data_in, gdata_dir=, geoid_version=)
   Converts data from NAVD88 to NAD83. See nad832navd88offset for a description
   of the parameters. Returns the data with the elevations modified.
*/
   offset = nad832navd88offset(data_in, gdata_dir=gdata_dir, geoid_version=geoid_version);
   data_out = unref(data_in);
   data_out(3,) += unref(offset);
   return data_out;
}

func nad832navd88offset(_data_in, gdata_dir=, geoid_version=) {
/*DOCUMENT nad832navd88(data, gdata_dir=, geoid_version=)
   This function provides the offset between NAD83 and NAVD88 data at a given
   lat/lon location using the GEOIDxx model.

   Input:
      data: A two-dimensional array (3,n) in the format (lon, lat, alt).
      gdata_dir= Location where geoid data resides. Defaults to
         lidar-processing/GEOID03/pbd_data/.
      geoid_version= Shortcut for specifying an alternate GEOID in the
         default location. Will use lidar-processing/XXX/pbd_data/. This is
         ignored if gdata_dir is provided.

   Output:
      An array of offsets between NAD83 and NAVD88 for each location. To
      convert from NAD83 to NAVD88, use elevation - offset. To convert from
      NAVD88 to NAD83, use elevation + offset.

   amar nayegandhi 07/10/03, original nad832navd88
   charlene sullivan 09/21/06, modified for use of GEOID96 model
   david nagle 11/21/07, modified to provide offset to facilate 2-way
      conversions
*/
   default, geoid_version, "GEOID03";
   default, gdata_dir, split_path(get_cwd(),-1)(1)+geoid_version+"/pbd_data/";
  
  //read the header values for each GEOIDxx pbd data file.
  scmd = swrite(format="ls -1 %s*.pbd | wc -l",gdata_dir);
  f = popen(scmd,0);
  s = ""; npbd = 0;
  n = read(f,format="%s", s );
  if (n) sread, s, format="%d", npbd;
  if (!n) { 
	write, "No GEOID PBD Data files.  Quitting. ";
        return;
  }
  close, f;

  data_in = _data_in;
  if (data_in(1,1) < 0) data_in(1,) += 360.0;

  // now we know the number of geoid pbd data files in directory gdata_dir
  apbdfile = array(string, npbd);
  scmd = swrite(format="ls -1 %s*.pbd", gdata_dir);
  f = popen(scmd,0); 
  n = read(f,format="%s",apbdfile);
  aglamn = aglomn = adla = adlo = array(double, npbd);
  anrows = ancols = aitype =  array(int, npbd);
  avname = array(string, npbd);

  // open each pbd file and extract the header
  for (i = 1; i <= npbd; i++) {
     f = openb(apbdfile(i));
     restore, f, glamn, glomn, dla, dlo, nrows, ncols, itype, vname;
     // did I ? YES YOU DID
     aglamn(i) = glamn;
     aglomn(i) = glomn;
     adla(i) = dla;
     adlo(i) = dlo;
     ancols(i) = ncols;
     anrows(i) = nrows;
     aitype(i) = itype;
     avname(i) = vname;
     close, f;
   }

  // now find which geoid pbd file to use
  aglomx = aglomn+dlo*ncols-dlo;
  aglamx = aglamn+dla*nrows-dla;
  data_wpbd = array(int,numberof(data_in(1,)));
  for (i=1;i<=npbd;i++) {
    idx = where(data_in(1,) > aglomn(i));
    if (is_array(idx)) {
       iidx = where(data_in(1,idx) <= aglomx(i));
       if (is_array(iidx)) {
          idy = where(data_in(2,idx(iidx)) > aglamn(i));
          if (is_array(idy)) {
            iidy = where(data_in(2,idx(iidx(idy))) <= aglamx(i));
            if (is_array(iidy)) {
                data_wpbd(idx(iidx(idy(iidy)))) = i;
            }
	  }
       }
    }
  }
  dw_idx = where(data_wpbd != 0);
  if (is_array(dw_idx)) {
   data_wpbd = data_wpbd(dw_idx);
  } else return [];
 
  if (numberof(data_wpbd) > 1) {
     // diff for which pbd files to use
     wpbd_diff = where(data_wpbd(dif) > 0); 
     if (is_array(wpbd_diff)) {
       // data required 2 geoid pbd file... 
      // find the locations of the dif and the one before it
	// that way we will have all the unique ids in wpbd_idx
       wpbd_idx = grow(data_wpbd(wpbd_diff), data_wpbd(wpbd_diff-1));
       uidx = unique(wpbd_idx, ret_sort=1);
     } else uidx = [1];
  } else uidx = [1];

  
  for (i=1;i<=numberof(uidx);i++) {
    if (is_array(wpbd_idx)) {
	ik = wpbd_idx(uidx(i));
    } else {
	ik = data_wpbd(uidx(i));
    }
    // find the row/col of the nearest point to the data_in lat/lon points
    irown = int((data_in(2,) - aglamn(ik)) / adla(ik))+1;
    icoln = int((data_in(1,) - aglomn(ik)) / adlo(ik))+1;
    // find the lat/lon of the nearest grid point
    xlatn = aglamn(ik) + (irown-1)*adla(ik);
    xlonn = aglomn(ik) + (icoln-1)*adlo(ik);
   
    // check to see if we are on an edge; if so, move the center point
    cidx = where((irown == 1) > 0);
    if (is_array(cidx)) irown(cidx) = 2;
    cidx = where((icoln == 1) > 0);
    if (is_array(cidx)) icoln(cidx) = 2;
    cidx = where((irown == nrows) > 0);
    if (is_array(cidx)) irown(cidx) = nrows-1;
    cidx = where((icoln == ncols) > 0);
    if (is_array(cidx)) icoln(cidx) = ncols-1;

    // at this point, whether we are on an edge or not, the irown/icoln values reflect
    // the center node of the 3x3 points we have to use for biquadratic interpolation
    // now extract the geoid data within min and max values of irown and icoln +/- 1;
    

    // the four points below represent the min/max locations of the corners of the 3x3 array. 
    // we need to extract only the range of data given by these corners.
    mnirown = min(irown)-1;
    mxirown = max(irown)+1;
    mnicoln = min(icoln)-1;
    mxicoln = max(icoln)+1;
   
    if (mxirown > nrows) mxirown = nrows;
    if (mxicoln > ncols) mxicoln = ncols;

    // extracting the geoid data
    write, format="grid file = %s\n", apbdfile(ik)
    f = openb(apbdfile(ik));
    restore,f,vname;
    gdata = get_member(f,vname)(mnicoln:mxicoln, mnirown:mxirown);
    close, f;

    if (mxirown >= nrows) {
        gdata1 = array(double, numberof(gdata(,1)), max(irown)+1-mnirown+1);
   	gdata1(,1:numberof(gdata(1,))) = gdata;
	gdata1(,numberof(gdata(1,)):) = gdata(,numberof(gdata(1,)));
        gdata = gdata1;
    }
    if (mxicoln >= ncols) {
        gdata1 = array(double, max(icoln)+1-mnicoln+1, numberof(gdata(1,)));
   	gdata1(1:numberof(gdata(,1)), ) = gdata;
	gdata1(numberof(gdata(,1)):,) = gdata(numberof(gdata(,1)),);
        gdata = gdata1;
    }
    xx = (data_in(1,)-(aglomn(ik)+(icoln-2)*adlo(ik)))/ adlo(ik);
    yy = (data_in(2,)-(aglamn(ik)+(irown-2)*adla(ik)))/ adla(ik)

    // finding the 3x3 grid points for the interpolation
    f1=f2=f3=f4=f5=f6=f7=f8=f9=array(double, numberof(xx));
    for (j=1;j<=numberof(xx);j++) {
         f1(j) = gdata(icoln(j)-mnicoln,irown(j)-mnirown);
         f2(j) = gdata(icoln(j)-mnicoln+1,irown(j)-mnirown);
         f3(j) = gdata(icoln(j)-mnicoln+2,irown(j)-mnirown);
         f4(j) = gdata(icoln(j)-mnicoln,irown(j)-mnirown+1);
         f5(j) = gdata(icoln(j)-mnicoln+1,irown(j)-mnirown+1);
         f6(j) = gdata(icoln(j)-mnicoln+2,irown(j)-mnirown+1);
         f7(j) = gdata(icoln(j)-mnicoln,irown(j)-mnirown+2);
         f8(j) = gdata(icoln(j)-mnicoln+1,irown(j)-mnirown+2);
         f9(j) = gdata(icoln(j)-mnicoln+2,irown(j)-mnirown+2);
    }

    fx1 = qfit(xx,unref(f1),unref(f2),unref(f3));
    fx2 = qfit(xx,unref(f4),unref(f5),unref(f6));
    fx3 = qfit(unref(xx),unref(f7),unref(f8),unref(f9));

    data_out = qfit(unref(yy),unref(fx1),unref(fx2),unref(fx3));
  }

  return data_out;
} 

func qfit(x,f0,f1,f2) {
 /*DOCUMENT qfit(x,f1,f2,f3)
   amar nayegandhi 07/14/03
   parabola fit through 3 points (x=0,x=1,x=2) with values f0 = f(0), f1=f(1), f2=f(2)
   and returning the value qfit = f(x) where 0<=x<=2.
   adapted from GEOID99 model.
*/
/* Original:
  df0 = f1 - f0;
  df1 = f2 - f1;
  d2f0 = df1 - df0;

  qfitval = f0 + x*df0 + 0.5*x*(x-1)*d2f0;
*/
// Rewrote by David Nagle 2009-02-26 to reduce memory impact

  t1 = f1 - f0;
  x2 = 0.5 * x * (x-1);
  t2 = unref(f2) - 2 * unref(f1) + f0;
  qfitval = unref(f0) + unref(x) * unref(t1) + unref(x2) * unref(t2);

  return qfitval;
}
