/* 
   $Id: nad832navd88.i
    amar nayegandhi
    The following code has been adapted from the GEOID 99 model available at
    http://www.ngs.noaa.gov/GEOID/GEOID99/
    The original DISCLAIMER applies to this as well.
*/


func geoid_data_to_pbd(gfname=,pbdfname=, initialdir=) {
   /*DOCUMENT geoid_data_to_pbd(gfname,pbdfname)
    converts GEOID99 ascii data files to pbd.  The ascii data files are available on the NGS website:
    http://www.ngs.noaa.gov/GEOID/GEOID99/dnldgeo99ot1.html
    amar nayegandhi 07/10/03.
   */

   if (!gfname) {
      if (is_void(initialdir)) initialdir = "/dload/geoid99_data/";
      gfname  = get_openfn( initialdir=initialdir, filetype="*.asc", title="Open GEOID99 Ascii Data File" );
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
   nrows = ncols = itype = 0;
   read, gf, glamn, glomn, dla, dlo;
   read, gf, nrows, ncols, itype;
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
   
func nad832navd88(data_in, gdata_dir=) {
 /*DOCUMENT nad832navd88(data_in)
   This function converts nad83 data to NAVD88 data using the GEOID99 model.
   INPUT:  data_in = a 2 dimensional array (3,n) in the format (lon, lat, alt).
 	   gdata_dir = location where geoid data resides.  Defaults to
			~/lidar-processing/GEOID99/pbd_data/
   OUTPUT: data_out = NAVD88 referenced data in the same format as the input format (3,n).
   amar nayegandhi 07/10/03
*/
  if (!gdata_dir) gdata_dir = "~/lidar-processing/GEOID99/pbd_data/";
  
  //read the header values for each geoid99 pbd data file.
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
  if (is_array(where(data_wpbd(dif) > 0))) {
    // data required 2 geoid pbd file... 
    uidx = unique(data_wpbd);
  } else uidx = [1];
  
  for (i=1;i<=numberof(uidx);i++) {
    ik = data_wpbd(uidx(i));
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
    
    // extracting the geoid data
    f = openb(apbdfile(ik));
    restore,f,vname;
    gdata = get_member(f,vname)(mnicoln:mxicoln, mnirown:mxirown);
    close, f;
    
    xx = (data_in(1,)-(aglomn(ik)+(icoln-2)*adlo(ik)))/ adlo(ik);
    yy = (data_in(2,)-(aglamn(ik)+(irown-2)*adla(ik)))/ adla(ik)
    
    // finding the 3x3 grid points for the interpolation
    f1=f2=f3=f4=f5=f6=f7=f8=f9=array(double, numberof(xx));
    for (j=1;j<numberof(xx);j++) {
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
       
    
    fx1 = qfit(xx,f1,f2,f3);
    fx2 = qfit(xx,f4,f5,f6);
    fx3 = qfit(xx,f7,f8,f9);
    data_out = qfit(yy,fx1,fx2,fx3);

  }

  data_out = [data_in(1,)-360, data_in(2,), data_in(3,)-data_out];
  data_out = transpose(data_out);
  
  return data_out;
} 

func qfit(x,f0,f1,f2) {
 /*DOCUMENT qfit(x,f1,f2,f3)
   amar nayegandhi 07/14/03
   parabola fit through 3 points (x=0,x=1,x=2) with values f0 = f(0), f1=f(1), f2=f(2)
   and returning the value qfit = f(x) where 0<=x<=2.
   adapted from GEOID99 model.
*/

  df0 = f1 - f0;
  df1 = f2 - f1;
  d2f0 = df1 - df0;

  qfitval = f0 + x*df0 + 0.5*x*(x-1)*d2f0;

  return qfitval
}
