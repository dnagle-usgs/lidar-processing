// vim: set ts=2 sts=2 sw=2 ai sr et:

extern blockn, aw, sw;
/* DOCUMENT
  Externs used by sdist:
    blockn    Block number
    aw        Area width
    sw        Scan width in km (minus desired overlap)
*/
default, blockn, 1;
default, aw, 1.0;
default, sw, 0.2;

extern FB;
/* DOCUMENT FB
  Struct used for flight planning.

  struct FB {
    string name;    // block name
    int block;      // block number
    float aw;       // area width  (km)
    float sw;       // scan  spacing (km)
    float kmlen;    // length of block (km)
    double dseg(4); // defining segment
    float alat(5);  // lat corners of total area
    float alon(5);  // lon corners of total area
    pointer p;      // a pointer to the array of flightlines.
  };
*/

struct FB {
  string name;
  int block;
  float aw, sw, kmlen;
  double dseg(4);
  float alat(5), alon(5);
  pointer p;
};

struct FP {
  string name;
  double lat1, lon1, lat2, lon2;
}

func fb2fp(fb) {
/* DOCUMENT fb2fp(fb)
   Convert an FB variable to an FP variable.
   Inputs: a variable of type FB
   returns: FB data converted to FP type.
*/
  nbr = dimsof(*fb.p)(2);
  fp = array(FP, nbr);
  fp.name = fb.name;
  for(i=1; i<= nbr; i++) {
    pt = array(double, 4);
    fp(i).name = fb.name;
    pt = (*fb.p)(i,);
    fp(i).lon1 = pt(1);
    fp(i).lat1 = pt(2);
    fp(i).lon2 = pt(3);
    fp(i).lat2 = pt(4);
  }
  return fp;
}

func lldist(lat0, lon0, lat1, lon1) {
/* DOCUMENT lldist(lat0, lon0, lat1, lon1)
  -or- lldist([lat0, lon0, lat1, lon1])
  Calculates the great circle distance in nautical miles between two points
  given in geographic coordiantes. Input values may be conformable arrays;
  output will have dimensionality to match.

  To convert to kilometers, multiply by 1.852
  To convert to statute miles, multiply by 1.150779
*/
  if(is_void(lon0) && numberof(lat0) == 4) {
    assign, noop(lat0), lat0, lon0, lat1, lon1;
  }
  lat0 *= DEG2RAD;
  lon0 *= DEG2RAD;
  lat1 *= DEG2RAD;
  lon1 *= DEG2RAD;
  // Calculate the central angle between the two points, using the spherical
  // law of cosines
  ca = acos(sin(lat0)*sin(lat1) + cos(lat0)*cos(lat1)*cos(lon0-lon1));
  // Convert the central angle into degrees; then convert degrees into nautical
  // miles. A nautical mile is defined as a minute of arc along a meridian, so
  // we can approximate the conversion by multiplying by 60 (the number of
  // arcminutes in a degree).
  return ca * RAD2DEG * 60;
}

func mdist(&click, units=, win=, plot=, verbose=, nox=, noy=) {
/* DOCUMENT mdist(&click, units=, win=, plot=, verbose=, nox=, noy=)
  Measure the distance between two points as selected by mouse click and return
  the distance in meters. The distance in nautical miles, statue miles, and
  meters or kilometers will also be displayed to the console.

  Options:
    units= Specifies the units used in the input window.
        units="ll"  Geographic coordinates in degrees (default)
        units="m"   Meters
        units="cm"  Centimeters
        units="mm"  Millimeters
    win= Specifies a window. If omitted, the current window is used.
    plot= Can be used to turn on/off plotting of the line drawn.
        plot=0      Turn off plotting
        plot=1      Turn on plotting (default)
    verbose= Specifies whether to display text to the console.
        verbose=0   Display nothing to the console
        verbose=1   Display info to the console (default)
    nox= Eliminates X from the distance calculation. (Useful to get height
      differences in a transect window, for example.)
        nox=0   Include X (default)
        nox=1   Exclude X
    noy= Eliminates Y from the distance calculation.
        noy=0   Include Y (default)
        noy=1   Exclude Y

  Output parameters:
    click: The return result from mouse() obtained from the user.

  Returns:
    Scalar distance in meters.

  SEE ALSO: sdist, lldist, plrect, pip_fp
*/
  default, units, "ll";
  default, win, window();
  default, plot, 1;
  default, verbose, 1;

  msize = 0.3;
  prompt = swrite(format="Click and drag left mouse button in window %d:", win);

  wbkp = current_window();
  window, win;

  forever = 1;
  while(1) {
    click = mouse(1, 2, prompt);
    if(anyof(click(1:2) - click(3:4))) break;
    write, "You must keep the left mouse button down while dragging the line.";
    write, "Make sure you click in the correct window.";
  }

  result = [];

  if(units == "ll") {
    nm = lldist(click(2), click(1), click(4), click(3));
    sm = nm * 1.150779;
    km = nm * 1.852;
    m = km / 1000.;
  } else {
    dx = nox ? 0 : (click(3) - click(1));
    dy = noy ? 0 : (click(4) - click(2));
    m = sqrt(dx*dx + dy*dy);

    if(units == "cm")
      m *= 0.01;
    else if(units == "mm")
      m *= 0.001;
    else if(units != "m")
      error, "Unknown units= value";

    km = m / 1000.;
    nm = km / 1.852;
    sm = nm * 1.150779;
  }

  if(verbose) {
    write, "Distance is:";
    write, format="   %.3f nautical miles\n", nm;
    write, format="   %.3f statute miles\n", sm;
    if(km > 1)
      write, format="   %.3f kilometers\n", km;
    else
      write, format="   %.3f meters\n", m;
  }

  if(plot) {
    plmk, click(2), click(1), msize=msize;
    plmk, click(4), click(3), msize=msize;
    plg, [click(2),click(4)], [click(1),click(3)], color="red", marks=0;
  }

  window_select, wbkp;
  return m;
}

func sdist( junk, block=, line= , mode=, fill=, in_utm=, out_utm=, ply=, silent=, debug=) {
/* DOCUMENT sdist(junk, block=, line= , mode=, fill=)
   Measure distance, and draw a proportional rectangle showing the
   resulting coverage.

   Develops a flightline block from the line segment.  If called
   as sdist(), it will expect the user to select the points with the
   mouse by clicking and holding down the left button over one endpoint
   and releasing the mouse over the other endpoint.

   If called with "block" it will expect a block of FB data. The block of
   FB data usually would be a previously returned FB block, but with
   altered values for sw, aw, etc. etc.


   If it is called as sdist( line="A B C D" ) then it expects a
   string of four floating point numbers as "A B C D" where A and B are
   the lat/lon pair for one endpoint and C D are the lat/lon pair for
   the other point.  All points are in decimal degrees and west longitudes
   are represented by negative numbers.

   fill=V   This controls what is displayed for a block.  Each bit in the
   values turns on/off pats of the diplay.  Not defining fill will default
   to everything being displayed. The bits are as follows:
   1  Display all flight lines in the block with alternating colors.
   2  Show the first flight line in Green.
   4  Show the centerline.
   8  Area filled with color.

   A structure of type FB is returned. Type FB at the command prompt to
   see the format of the structure.

   mode=[1,2,3]

   where:
   1 = right, bottom
   2 = center
   3 = left, top

   The mode option is used to specify the relationship of the input
   line segment is relative to the computed block of flightlines.

   7/3/02  -WW Added left/right selection lines

*/
  extern mission_time, aw, sw, sr, dv, rdv, lrdv, rrdv, blockn, segn, curzone;
  default, mission_time, 0.;
  default, in_utm, 0;
  default, out_utm, 0;
  // line mode
  // 1 = right, bottom
  // 2 = center
  // 3 = left, top
  default, mode, 2;

  if (is_array(ply)) {
    if (!in_utm) {
      //translate to zero longitude
      ply1 = ply;
      ply(1,) = ply(1,)-min(ply(1,));
    }
    box = boundBox(ply, noplot=1);
    if (!in_utm)
      box = fll2utm(box(2,), box(1,))(1:2,);
    dist1 = sqrt((box(1,3)-box(1,1))^2+(box(2,3)-box(2,1))^2);
    dist2 = sqrt((box(1,2)-box(1,4))^2+(box(2,2)-box(2,4))^2);
    aw = 2*max(dist1,dist2)/1000.; //multiply by 2 to ensure entire rgn is included.
  } else {
    aw = float(aw);
  }
  sw = float(sw);
  segs = aw / sw;   // compute number of segments
  sega = array(float, int(segs),4);
  sr = array(float, 7, 2);    //the array to hold the rectangle

  if ( is_void( line ) ) {
    if (in_utm) {
      res = mdist(click,plot=0,units="m"); // get the segment from the user in utm
    } else {
      res = mdist(click,plot=0);  // get the segment from the user in ll
    }
    km = res / 1000.;
    sf = aw / (km/1.852); // determine scale factor
  } else {
    click = array(float, 4 );
    n = sread(line,format="%f %f %f %f", click(2), click(1), click(4), click(3) );
    // lldist output is in nautical miles, x by 1.852 for km
    km = lldist( click(2), click(1), click(4), click(3) ) * 1.852;
    sf = aw / km;   // determine scale factor
  }
  write, format="Scale factor before = %5.3f\n",sf;

  if (in_utm == 1) {
    //convert to latlon to continue using the code below
    if (!curzone) {
      curzone = 0;
      czone = "";
      read, prompt="Could not determine UTM Zone Number.\nPlease enter zone number: ",czone;
      sread, czone, format="%d",curzone;
    }
    ll = utm2ll([click(2), click(4)], [click(1), click(3)], [curzone, curzone]);
    click(1) = ll(1,1);
    click(2) = ll(1,2);
    click(3) = ll(2,1);
    click(4) = ll(2,2);
  }

  // adjust so all segments are from left to right
  // only the user coords. are changed

  //if (mode != 4) {
  if ( click(1) > click(3) ) {
    temp = click;
    click(1) = temp(3);
    click(2) = temp(4);
    click(3) = temp(1);
    click(4) = temp(2);
    sf = -sf;   // keep block on same side
  }
  //}
  click;

  llat = [click(2), click(4)];
  llon = [click(1), click(3)] - click(1);   // translate to zero longitude
  fll2utm, llat, llon, UTMNorthing, UTMEasting, ZoneNumber; // convert to utm
  zone = ZoneNumber(1); // they are all the same cuz we translated


  w = current_window();
  if (mode == 4) {
    if (debug) {
      window, 5; fma;
      plmk, uply(1,), uply(2,), marker=4, width=10, color="black", msize=0.3;
    }
    // user can plot the line anywhere to define slope.  Use the pip coords to
    // define region.
    slope = (UTMNorthing(2)-UTMNorthing(1))/(UTMEasting(2)-UTMEasting(1));
    // find the leftmost ply point in translated utm coords
    uply = fll2utm(ply(2,), ply(1,));
    minleftidx = (uply(2,))(mnx);
    leftpt = [uply(2,minleftidx), uply(1,minleftidx)]; // xy format
    /*
    // now find the northernmost ply translated pt
    //minnorthidx = (uply(1,))(mxx);
    //northpt = [uply(2,minnorthidx), uply(1,minnorthidx)]; // xy format

    // now loop through each uply pt and find the line passing through it with
    // slope "slope"

    npty = northpt(2);
    spty = southpt(2);
    nptx = array(double,numberof(uply(2,)));
    sptx = array(double,numberof(uply(2,)));
    for (i=1;i<=numberof(uply(2,));i++) {
    nptx(i) = uply(2,i)-(uply(1,i)-npty)/slope;
    sptx(i) = uply(2,i)-(uply(1,i)-spty)/slope;
    }

    sptxidx = sptx(mnx);
    fsouthpt = [sptx(sptxidx), spty];

    //UTMNorthing = [spty,npty];
    //UTMEasting = [sptx(sptxidx),nptx(sptxidx)];

     */
    // the slope of the line perpedicular to this line is -1/slope
    pslope = -1.0/slope;
    // now loop through each uply pt and find the intersecting pt of the 2
    // perpendicular lines -- one line is the line passing through leftpt
    // with slope "slope" and other line is passing through a ply pt with
    // slope "pslope".

    px = array(double,numberof(uply(2,)));
    py = array(double,numberof(uply(2,)));
    for (i=1;i<=numberof(uply(2,));i++) {
      px(i) = (leftpt(2)-uply(1,i) + slope*uply(2,i) - pslope*leftpt(1))/(slope-pslope);
      py(i) = leftpt(2)+pslope*(px(i)-leftpt(1));
    }
    // now find the leftmost px
    pxidx = px(mnx);
    fleftpt = [px(pxidx), py(pxidx)];

    if (debug) {
      write, "Plotted leftpt in blue";
      plmk, fleftpt(2), fleftpt(1), marker=4, width=10, color="blue", msize=0.3;
    }

    // now this is the left most point but we still need to find the north and south extent
    // again find intersecting pt of perpendiculars to this line and take the southermost
    // and northernmost points as end points
    px = array(double,numberof(uply(2,)));
    py = array(double,numberof(uply(2,)));
    for (i=1;i<=numberof(uply(2,));i++) {
      px(i) = (uply(1,i)-(fleftpt(2)) + slope*fleftpt(1) - pslope*uply(2,i))/(slope-pslope);
      py(i) = uply(1,i)+pslope*(px(i)-uply(2,i));
    }
    f1idx = py(mnx);
    f1pt = [px(f1idx),py(f1idx)];
    f2idx = py(mxx);
    f2pt = [px(f2idx),py(f2idx)];

    if (debug) {
      write, "Plotted f1pt and f2pt in green";
      plmk, f2pt(2), f2pt(1), marker=4, width=10, color="green", msize=0.3;
      plmk, f1pt(2), f1pt(1), marker=4, width=10, color="green", msize=0.3;
    }
    if (f1pt(1) < f2pt(1)) {
      UTMNorthing = [f1pt(2),f2pt(2)];
      UTMEasting = [f1pt(1), f2pt(1)];
    } else {
      UTMNorthing = [f2pt(2),f1pt(2)];
      UTMEasting = [f2pt(1), f1pt(1)];
    }

    // now extend the line by 5*sw on both ends such that it covers the entire
    // polygon.
    s = 5*sw*1000;
    xc = UTMEasting(2)+sqrt(s*s/(slope*slope+1));
    yc = UTMNorthing(2)+slope*(xc-UTMEasting(2));

    UTMNorthing(2) = yc;
    UTMEasting(2) = xc;

    xc = UTMEasting(1)-sqrt(s*s/(slope*slope+1));
    yc = UTMNorthing(1)+slope*(xc-UTMEasting(1));

    UTMNorthing(1) = yc;
    UTMEasting(1) = xc;

    if (debug) {
      write, "plotted extended points in red";
      plmk, UTMNorthing(1), UTMEasting(1), marker=4, msize=0.3, color="red", width=10;
      plmk, UTMNorthing(2), UTMEasting(2), marker=4, msize=0.3, color="red", width=10;
      window_select, w;
    }
    if (slope > 0) {
      mode = 1;
    } else {
      mode = 3;
    }
    // redefine scale factor sf
    km = sqrt((UTMNorthing(2)-UTMNorthing(1))^2+(UTMEasting(2)-UTMEasting(1))^2);
    km = km/1000.;
    sf = aw/km;
    write, format="Scale factor after = %5.3f\n",sf;
  }
  dv = [UTMNorthing (dif), UTMEasting(dif)];
  dv = [dv(1),dv(2)];

  sf2 = sf/2.0;   // half the scan width

  if ( (mode == 1) || (mode==3) ) {
    if ( mode == 3) {
      dv = -dv;
    }
    lrdv = [-dv(2), dv(1)] * sf;  // 90 deg left rotated difs
    sr(1,) = [UTMNorthing(1),UTMEasting(1)];  // first point
    sr(2,) = [UTMNorthing(2),UTMEasting(2)];  // end point
    sr(3,) = [UTMNorthing(1),UTMEasting(1)];  // first point
    sr(4,) = [UTMNorthing(1),UTMEasting(1)] +lrdv;  // end point
    sr(5,) = [UTMNorthing(2),UTMEasting(2)] +lrdv;  // end point
    sr(6,) = [UTMNorthing(2),UTMEasting(2)];  // end point
    sr(7,) = sr(3,);      // end point
    ssf = (sw/aw) * lrdv; // scale for one scan line
    sega(1,1:2) = sr(3,) + ssf/2.0;
    sega(1,3:4) = sr(6,) + ssf/2.0;
  } else if ( mode == 2 ) {
    lrdv = [-dv(2), dv(1)] * sf2; // 90 deg left rotated difs
    rrdv = [dv(2), -dv(1)] * sf2; // 90 deg right rotated difs
    sr(1,) = [UTMNorthing(1),UTMEasting(1)];  // first point
    sr(2,) = [UTMNorthing(2),UTMEasting(2)];  // end point
    sr(3,) = [UTMNorthing(1),UTMEasting(1)] + lrdv; // end point
    sr(4,) = [UTMNorthing(2),UTMEasting(2)] + lrdv; // end point
    sr(5,) = [UTMNorthing(2),UTMEasting(2)] - lrdv; // end point
    sr(6,) = [UTMNorthing(1),UTMEasting(1)] - lrdv; // end point
    sr(7,) = sr(3,);    // end point
    ssf = (sw/aw) * -lrdv * 2.0;  // scale for one scan line
    sega(1,1:2) = sr(3,) + ssf/2.0;
    sega(1,3:4) = sr(4,) + ssf/2.0;
  }

  for (i=2; i<=int(segs); i++ ) {
    sega(i,1:2) = sega(i-1,1:2) +ssf;
    sega(i,3:4) = sega(i-1,3:4) +ssf;
  }

  // Make a conformal zone array
  zone = array(ZoneNumber(1), dimsof( sr) (2) );

  // Convert it back to lat/lon
  utm2ll, sr(,1), sr(,2), zone, Long, Lat;

  // Add the longitude back in that we subtrated in the beginning.
  // to keep it all i the same utm zone
  if (is_array(ply1))
    click(1) = min(ply1(1,));
  Long += click(1);
  //Long += min(ply1(1,));

  // save previous zone number
  pZoneNumber = ZoneNumber(1);

  if (in_utm == 1) {
    // convert to utm so as to plot it on the window
    u = fll2utm(Lat, Long);
  }
  // Plot the scan rectangle.  Points 3:7 have the vertices of
  // the scan rectangle.  1:2 have the end points.
  r = 3:7;

  // plot a filled rectangle
  if ( is_void( fill ) )
    fill = 0xf;

  if ( (fill & 0x8)  == 8 ) {
    n = [5];
    z = [char(185)];
    if (in_utm == 1) {
      plfp, z, u(1,r), u(2,r), n;
    } else {
      plfp,z,Lat(r),Long(r), n;
    }
  }

  if (is_void(stturn) )
    stturn = 300.0; // seconds to turn
  if (is_void(msec) )
    msec = 50.0;    // speed in meters/second

  if (!silent) {
    write,format="# set sw %f; set aw %f;  set msec %f; set ssturn %f set block %d\n",
      sw, aw, msec, stturn, blockn;
    write,format="# %f %f %f %f \n", click(2),click(1), click(4), click(3);
  }
  segsecs = km*1000.0 / msec;
  blocksecs = (segsecs + stturn ) * int(segs);
  if (!silent) {
    write, format="# set Seglen %5.3fkm; set segtime %4.2f; (min) set Total_time %3.2f(hrs)\n",
      km, segsecs/60.0, blocksecs/3600.0;
  }

  /////////// Now convert the actual flight lines
  Xlong = Long; // save Long cuz utm2ll clobbers it
  Xlat  = Lat;
  zone = array(pZoneNumber, dimsof( sega) (2) );
  utm2ll, sega(,1), sega(,2), zone, Long, Lat;
  sega(,1) = Lat;
  sega(,2) = Long + click(1);
  //sega(,2) = Long + min(ply1(1,));
  utm2ll, sega(,3), sega(,4), zone, Long, Lat;
  sega(,3) = Lat;
  sega(,4) = Long + click(1);
  //sega(,4) = Long + min(ply1(1,));
  rg = 1:0:2;

  /* See if the user want's to display the lines */
  if ( (fill & 0x1 ) == 1 ) {
    if (in_utm) {
      useg1 = fll2utm(sega(,1), sega(,2));
      useg2 = fll2utm(sega(,3), sega(,4));
      usega = [useg1(1,), useg1(2,), useg2(1,), useg2(2,)];
      pldj,usega(rg,2),usega(rg,1),usega(rg,4),usega(rg,3),color="yellow";
    } else {
      pldj,sega(rg,2),sega(rg,1),sega(rg,4),sega(rg,3),color="yellow";
    }
    rg = 2:0:2;
    if ( (dimsof(sega)(2)) > 1 ) {
      if (in_utm) {
        pldj,usega(rg,2),usega(rg,1),usega(rg,4),usega(rg,3),color="white";
      } else {
        pldj,sega(rg,2),sega(rg,1),sega(rg,4),sega(rg,3),color="white";
      }
    }
  }

  rg = 1;
  if ( (fill & 0x2 ) == 2 ) {
    if (in_utm) {
      pldj,usega(rg,2),usega(rg,1),usega(rg,4),usega(rg,3),color="green";
    } else {
      pldj,sega(rg,2),sega(rg,1),sega(rg,4),sega(rg,3),color="green";
    }
  }
  //  write,format="%12.8f %12.8f %12.8f %12.8f\n", sega(,1),sega(,2),sega(,3),sega(,4)
  if (!silent) {
    if (out_utm) {
      write,format="utmseg %d-%d e%8.2f:n%9.2f e%8.2f:n%9.2f\n", blockn, indgen(1:int(segs)),
        usega(,2),
        usega(,1),
        usega(,4),
        usega(,3);
    } else {
      segd = abs(double(int(sega)*100 + ((sega - int(sega)) * 60.0) ));
      nsew = ( sega < 0.0 );
      nsewa = nsew;
      nsewa(, 1) = nsewa(, 3) = 'n';
      nsewa(, 2) = nsewa(, 4) = 's';
      q = where( nsew(, 1) == 1 );
      if ( numberof(q) ) nsewa(q,1) = 's';
      q = where( nsew(, 3) == 1 );
      if ( numberof(q) ) nsewa(q,3) = 's';
      q = where( nsew(, 2) == 1 );
      if ( numberof(q) ) nsewa(q,2) = 'w';
      q = where( nsew(, 4) == 1 );
      if ( numberof(q) ) nsewa(q,4) = 'w';
      write,format="llseg %d-%d %c%013.8f:%c%12.8f %c%013.8f:%c%12.8f\n", blockn, indgen(1:int(segs)),
        nsewa(,1),segd(,1),
        nsewa(,2),segd(,2),
        nsewa(,3),segd(,3),
        nsewa(,4),segd(,4);
    }

  }
  // put a line around it
  r = 3:7;
  /// plg,Lat(r),Long(r)
  if (!in_utm) {
    if ( (fill & 0x4 ) == 4 ) {
      plg, [click(2),click(4)], [click(1),click(3)],color="red",marks=0;
    }
  }

  rs = FB();
  rs.kmlen = km;
  rs.alat = Xlat(r);
  rs.alon = Xlong(r);
  rs.block = blockn;
  rs.p = &sega; // pointer to all the segments
  rs.sw = sw;   // flight line spacing (swath width)
  rs.aw = aw;   // area width
  rs.dseg = click(1:4); // block definition segment

  blockn++;
  mission_time += blocksecs/3600.0;
  return rs;
}

func pl_fp( fp, win=, color= , width=, skip=, labels=) {
/* DOCUMENT pl_fp(fp, color=)

  Plot the given flight plan on win= using color=.  Default
window is 6, and color is magenta.

  Inputs:
  fp  Array of Flight plan (FP) structures
  win=  Window number for display. Default=6
  color=  Set the color of the displayed flight plan.
  skip =  the line numbers to skip before plotting thicker flight line.
  labels = write the label name on the plot

  Orginal W. Wright
*/
  default, win, 6;
  default, color, "magenta";
  default, width, 1;
  default, skip, 5;

  bb = strtok(fp.name, "-");
  if (numberof(bb) > 2) {
    mask = grow([1n], bb(1,1:-1) != bb(1,2:0), [1n]);
    idx = where(mask);
  } else {
    idx = [1,2];
  }
  w = current_window();
  window,win;
  for (i=1;i<numberof(idx);i++) {
    fpx = fp(idx(i):idx(i+1)-1);
    cc = strtok(fpx.name, "-");
    dd = array(string, numberof(fpx.name));
    sread, cc(2,), dd;
    //idx1 = sort(dd);
    //fpx = fpx(idx1);
    r = 1:0;
    pldj, fpx.lon1(r),fpx.lat1(r),fpx.lon2(r),fpx.lat2(r),color=color, width=width;
    r = 1:0:skip;
    if (labels) {
      for (j=1;j<=numberof(dd(r));j++) {
        plt, dd(r)(j), fpx.lon1(r)(j), fpx.lat1(r)(j), tosys=1, height=15, justify="CC", color="black";
        pldj, fpx.lon1(r)(j),fpx.lat1(r)(j),fpx.lon2(r)(j),fpx.lat2(r)(j),color=color, width=5*width;
      }
    }
  }
  //pldj, fpx.lon1(1),fpx.lat1(1),fpx.lon2(1),fpx.lat2(1),color="green", width=2*width;

  window_select, w;
}

func read_fp(fname, in_utm=, out_utm=, fpoly=, plot=, win=) {
/* DOCUMENT read_fp(fname, in_utm, out_utm=, fploy=, plot=, win=)
  This function reads a .fp file which was generated by the sdist() flight
  planning function.

  Parameter:
    fname: The input .fp filename.
  Options:
    in_utm= If set (in_utm=1), the input file is in UTM format. Otherwise, it
      is in lat/lon.
    out_utm= If set (out_utm=1), the output file should be in UTM format.
      Otherwise, it will be in lat/lon.
    fploy= ??
    plot= Plot the flightline lines if plot=1. Otherwise, don't.
    win= Specifies the window to plot in, defaulting to the current.

  Orginal: amar nayegandhi 07/22/02

  9/4/2002 -ww Modified so you don't need to know how many lines in the
               file.  I will stop reading the file when 50 null lines
               are detected in a sequence.
*/
  default, plot, 0;
  extern a;

  fp = open(fname, "r");

  fp_arr = array(FP,10000);

  i = 0;
  nc = 0; // null line counter
  loop=1;

  while (loop) {
    i++;
    if ( nc > 50 ) break;
    a = rdline( fp) (1);
    if ( strlen(a) == 0 ) // null counter
      nc++;
    else
      nc = 0;
    w="";x="";y="";z="";
    if ((a > "") && !(strmatch(a,"#"))) {
      sread, a, w,x,y,z;
      yarr = strtok(y,":");
      yarr = strpart(yarr,2:);
      ylat = 0.0; ylon=0.0;
      sread, yarr(1), ylat;
      sread, yarr(2), ylon;
      if (!in_utm) {
        ylat1=ylat/100.; ylon1 = ylon/100.;
        ydeclat = (ylat1-int(ylat1))*100./60.;
        ydeclon = (ylon1-int(ylon1))*100./60.;
        ylat = int(ylat1) + ydeclat;
        ylon = int(ylon1) + ydeclon;
      }
      zarr = strtok(z,":");
      zarr = strpart(zarr,2:);
      zlat = 0.0; zlon=0.0;
      sread, zarr(1), zlat;
      sread, zarr(2), zlon;
      if (!in_utm) {
        zlat1=zlat/100.; zlon1 = zlon/100.;
        zdeclat = (zlat1-int(zlat1))*100./60.;
        zdeclon = (zlon1-int(zlon1))*100./60.;
        zlat = int(zlat1) + zdeclat;
        zlon = int(zlon1) + zdeclon;
      }

      // now write information to structure FP
      fp_arr(i).name = x;
      if (!in_utm) {
        fp_arr(i).lat1 = ylat;
        fp_arr(i).lon1 = -ylon;
        fp_arr(i).lat2 = zlat;
        fp_arr(i).lon2 = -zlon;
      } else {
        fp_arr(i).lat1 = ylon;
        fp_arr(i).lon1 = ylat;
        fp_arr(i).lat2 = zlon;
        fp_arr(i).lon2 = zlat;
      }
    }
  }

  indx = where( strlen(fp_arr.name) != 0);
  fp_arr = fp_arr(indx);
  close, fp;

  if (out_utm) {
    if (!in_utm) {
      u1 = fll2utm(fp_arr.lat1, fp_arr.lon1);
      u2 = fll2utm(fp_arr.lat2, fp_arr.lon2);
      fp_arr.lat1 = u1(1,);
      fp_arr.lat2 = u2(1,);
      fp_arr.lon1 = u1(2,);
      fp_arr.lon2 = u2(2,);
    }
  } else {
    if (in_utm) {
      ll1 = utm2ll(fp_arr.lat1, fp_arr.lon1, curzone);
      ll2 = utm2ll(fp_arr.lat2, fp_arr.lon2, curzone);
      fp_arr.lat1 = ll1(,1);
      fp_arr.lat2 = ll2(,1);
      fp_arr.lon1 = ll1(,2);
      fp_arr.lon2 = ll2(,2);
    }
  }

  if ( plot ) {
    pl_fp(fp_arr, win=win);
  }

  if (fpoly) {
    fp_arr1 = array(float, 2, 2*numberof(fp_arr));
    for (i = 1; i <= numberof(fp_arr); i++) {
      if (i%2) {
        fp_arr1(1,2*i-1) = fp_arr(i).lon1;
        fp_arr1(2,2*i-1) = fp_arr(i).lat1;
        fp_arr1(1,2*i) = fp_arr(i).lon2;
        fp_arr1(2,2*i) = fp_arr(i).lat2;
      } else {
        fp_arr1(1,2*i-1) = fp_arr(i).lon2;
        fp_arr1(2,2*i-1) = fp_arr(i).lat2;
        fp_arr1(1,2*i) = fp_arr(i).lon1;
        fp_arr1(2,2*i) = fp_arr(i).lat1;
      }
    }
    fw_arr = strtok(fname, ".");
    fw_name = fw_arr(1)+"_utm_poly.txt"
      fp = open(fw_name, "w");
    for (i=1;i<=numberof(fp_arr1(1,));i++) {
      write, fp, format="%9.4f  %8.4f\n", fp_arr1(1,i), fp_arr1(2,i);
    }
    close, fp;
  }

  if (!fpoly) {
    return fp_arr;
  } else {
    return fp_arr1;
  }
}

func utmfp2ll (fname, zone=) {
  //amar nayegandhi 06/14/03

  if (!zone) zone = 19;
  // read the input ascii file
  fp = open(fname, "r");

  i = 0;
  nc = 0; // null line counter
  loop=1;

  while (loop) {
    i++;
    if ( nc > 50 ) break;
    a = rdline(fp) (1);
    if ( strlen(a) == 0 ) // null counter
      nc++;
    else
      nc = 0;
    st = ""; w=0.0;x=0.0;y=0.0;z=0.0;
    if ((a > "") && !(strmatch(a,"#"))) {
      sread, a, st, w,x,y,z;
      ll = utm2ll([w,y], [x,z], zone);
      lldm = abs(ll-int(ll))*60.0;
      write,format="llseg %s %c%02d%10.8f:%c%d%10.8f %c%02d%10.8f:%c%d%10.8f\n", st, 'n',int(ll(3)),lldm(3), 'w', abs(int(ll(1))), lldm(1), 'n', int(ll(4)), lldm(4), 'w', abs(int(ll(2))), lldm(2);
    }
  }
}

func read_xy(file,yx=, utm=, zone=, color=, win=, plot=, writefile=) {
/* read_xy(file,yx=, utm=, zone=)
  amar nayegandhi 11/17/03
*/

  f = open(file,"r");

  if (!color) color="blue";

  i = 0;
  nc = 0; // null line counter
  loop=1;

  x = 0.0;
  y = 0.0;
  xarr = yarr = [];

  while (loop) {
    i++;
    if ( nc > 50 ) break;
    a = rdline(f);
    if ( strlen(a) == 0 ) {
      // null counter
      nc++;
      continue;
    } else {
      nc = 0;
    }
    if (a > "") {
      if (yx) {
        sread, a, x,y;
      } else {
        sread, a, y,x;
      }
    }
    if (utm) {
      llxy = utm2ll(x,y,zone);
      xarr = grow(xarr,llxy(1));
      yarr = grow(yarr,llxy(2));
    } else {
      xarr = grow(xarr,x);
      yarr = grow(yarr,y);
    }
  }

  if (plot) {
    if (is_void(win)) win = window();
    window, win;

    for (i=1;i<numberof(xarr);i++){
      pldj, xarr(i), yarr(i), xarr(i+1), yarr(i+1), color=color, width=2.0;
    }
    pldj, xarr(1), yarr(1), xarr(0), yarr(0), color=color, width=2.0;
  }

  if (writefile) {
    ff = split_path(file,1,ext=1);
    fout = ff(1)+"_ll"+ff(2);
    f = open(fout, "w");
    write, f,format="%12.8f %12.8f\n", yarr, xarr;
    close, f;
  }
  return [xarr, yarr]
}

func pip_fp(junk,fp=, ply=, win=, mode=,in_utm=,out_utm=, debug=) {
/* DOCUMENT pip_fp(fp, ply=, win=)
  This function allows the user to make a flight plan by selecting a polygon
  with a series of mouse clicks and defining the orientation...
  The orientation can be defined anywhere in the window by drawing a line.
  The orientation MUST be defined south->north.
  amar nayegandhi 07/11/04.
  updated by AN on 09/15/04 to include pip and orientation feature.
  Intersection point of 2 lines equation described by Paul Bourke at
  http://astronomy.swin.edu.au/~pbourke/geometry/lineline2d/

  Inputs:
  fp=     The input fp variable.  This is generated by sdist().
    It can by of type FP or FB.  If fp is not set, the user
    can select the polygon with a series of mouse clicks.
  ply=    If specified, then use an already defined polygon.
  win=  Default=6. Window you want to work in.
        mode=  set to 4 to use the pip feature. Use function sdist() for
              modes 1 through 3. see help, sdist()
        in_utm= set to 1 if input window is in utm coords
  out_utm= set to 1 if you want output in utm coords
  debug = set to 1 to work in debug mode.

  Output:  Variable of type FB.  Also writes out the flight plan lines
           to terminal.
*/
  extern curzone, lply1;
  default, mode, 4;
  default, win, 6;
  window, win;

  //ply = lply1;
  if (is_void(ply))
    ply = getPoly();
  lply1 = ply;
  plpoly, lply1, marker=4;

  if (!is_array(fp)) {
    write, "Please define flight plan orientation";
    fp = sdist(mode=mode, block=block, line=line,in_utm=in_utm, out_utm=out_utm, ply=ply, silent=1, fill=0, debug=debug);
  }
  fpxy = *fp.p;
  // convert to utm
  ufpxy1 = transpose(fll2utm(fpxy(,1), fpxy(,2), force_zone=curzone));
  ufpxy2 = transpose(fll2utm(fpxy(,3), fpxy(,4), force_zone=curzone));
  fpxy(,1:2) = ufpxy1(,1:2);
  fpxy(,3:4) = ufpxy2(,1:2);
  //curzone = ufpxy1(1,3);

  if (!in_utm) {
    ply = lply1;
    ply1 = (fll2utm(ply(2,), ply(1,),force_zone=curzone))(1:2,);
    ply(1,) = ply1(2,);
    ply(2,) = ply1(1,);
  }


  new_fpxy = fpxy;
  new_fpxy(*) = 0;
  nlines = numberof(fpxy(,1));
  // define array to tag for selected lines within pip
  tag_arr = array(int,nlines);
  ply = grow(ply, ply(,1));
  fp_new = array(FB);

  if ( !fp.name  )
    fp.name = "noname";

  fp_new.name = fp.name;
  fp_new.block = fp.block;
  fp_new.aw = fp.aw;
  fp_new.sw = fp.sw;
  fp_new.kmlen = fp.kmlen;
  fp_new.dseg = fp.dseg;
  fp_new.alat = fp.alat;
  fp_new.alon = fp.alon;

  for (i=1; i<numberof(ply(1,));i++) {
    x1 = ply(1,i);
    y1 = ply(2,i);
    x2 = ply(1,i+1);
    y2 = ply(2,i+1);

    for (j=1; j<=nlines;j++) {
      x3 = fpxy(j,2);
      y3 = fpxy(j,1);
      x4 = fpxy(j,4);
      y4 = fpxy(j,3);

      denom = ((y4-y3)*(x2-x1)-(x4-x3)*(y2-y1));


      // Check for zero denominator where perfect north/south or east/west line
      // drawn. If it is zero, make it 1.0 for now. This should be fixed by
      // modifying the algo.  -WW.
      if ( denom == 0 ) denom = 1.0;

      ua = ((x4-x3)*(y1-y3)-(y4-y3)*(x1-x3))/ denom;
      if ((ua < 0) || (ua > 1)) continue;

      ub = ((x2-x1)*(y1-y3)-(y2-y1)*(x1-x3))/ denom;
      if ((ub < 0) || (ub > 1)) continue;

      x = x1+ua*(x2-x1);
      y = y1+ua*(y2-y1);

      tag_arr(j) = 1;
      if (new_fpxy(j,2) == 0) {
        new_fpxy(j,2) = x;
        new_fpxy(j,1) = y;
      } else {
        if (new_fpxy(j,4) == 0) {
          new_fpxy(j,4) = x;
          new_fpxy(j,3) = y;
        } else {
          // select the segment that makes the longest distance
          d1 = ((new_fpxy(j,4)-new_fpxy(j,2))^2+(new_fpxy(j,3)-new_fpxy(j,1))^2);
          d2 = ((new_fpxy(j,4)-x)^2+(new_fpxy(j,3)-y)^2);
          d3 = ((new_fpxy(j,2)-x)^2+(new_fpxy(j,1)-y)^2);
          didx = [d1,d2,d3](mxx);
          if (didx == 2) {
            new_fpxy(j,2) = x;
            new_fpxy(j,1) = y;
          }
          if (didx == 3) {
            new_fpxy(j,4) = x;
            new_fpxy(j,3) = y;
          }
        }
      }
    }
  }

  idx = where(tag_arr);

  widx = where(new_fpxy(idx,1) == 0);
  if (is_array(widx)) new_fpxy(idx(widx),1) = fpxy(idx(widx),1);

  widx = where(new_fpxy(idx,2) == 0);
  if (is_array(widx)) new_fpxy(idx(widx),2) = fpxy(idx(widx),2);

  widx = where(new_fpxy(idx,3) == 0);
  if (is_array(widx)) new_fpxy(idx(widx),3) = fpxy(idx(widx),3);

  widx = where(new_fpxy(idx,4) == 0);
  if (is_array(widx)) new_fpxy(idx(widx),4) = fpxy(idx(widx),4);

  new_fpxy = new_fpxy(idx,);

  //convert back to latlon
  xy1 = utm2ll(new_fpxy(,1), new_fpxy(,2), curzone);
  xy2 = utm2ll(new_fpxy(,3), new_fpxy(,4), curzone);
  new_fpxy(,1:2) = xy1;
  new_fpxy(,3:4) = xy2;

  fp_new.p = &new_fpxy;

  write_fp, fp_new, plot=1;

  return fp_new;
}

func write_fp(fp, sw=, aw=, plot=) {
/* DOCUMENT write_fp(fp)
   This function writes out the flight plan to the standard output
   amar nayegandhi 07/12/04
*/
  default, sw, 0.12;
  default, aw, 15.;
  default, msec, 50.; // speed of aircraft 50m/s
  default, ssturn, 300.; // 300 seconds to turn
  default, blockn, 7;

  sw = fp.sw;
  aw = fp.aw;

  fpxy = *fp.p;
  fpxy = transpose(fpxy);

  counter = int(span(1,numberof(fpxy(1,)), numberof(fpxy(1,))));
  res = array(double, 4);
  res(1) = min(fpxy(1,));
  res(2) = min(fpxy(2,));
  res(3) = max(fpxy(3,));
  res(4) = max(fpxy(4,));

  write,format="# sw=%f aw=%f msec=%f ssturn=%f block=%d\n", sw, aw, msec, ssturn, blockn;
  write,format="# %f %f %f %f \n", res(2),res(1), res(4), res(3);

  // now calculate the new total segment length and total time
  segdist = lldist(fpxy(2,), fpxy(1,), fpxy(4,), fpxy(3,));

  km = sum(segdist);
  segsecs = sum(segdist*1000./msec);
  blocksecs = segsecs+(ssturn*numberof(segdist));

  write, format="# Total Seglen=%5.3fkm Total segtime=%4.2f(min) Total time=%3.2f(hrs)\n",
    km, segsecs/60.0, blocksecs/3600.0;

  lat1d = abs(double(int(fpxy(2,))*100 + ((fpxy(2,) - int(fpxy(2,))) * 60.0) ));
  lon1d = abs(double(int(fpxy(1,))*100 + ((fpxy(1,) - int(fpxy(1,))) * 60.0) ));
  lat2d = abs(double(int(fpxy(4,))*100 + ((fpxy(4,) - int(fpxy(4,))) * 60.0) ));
  lon2d = abs(double(int(fpxy(3,))*100 + ((fpxy(3,) - int(fpxy(3,))) * 60.0) ));

  write, format="llseg %s-%d n%013.8f:w%12.8f n%13.8f:w%12.8f\n", fp.name, counter, lat1d, lon1d, lat2d, lon2d;

  if (plot) {
    fpfp = array(FP,numberof(fpxy(2,)));
    fpfp.lat1 = fpxy(2,);
    fpfp.lon1 = fpxy(1,);
    fpfp.lat2 = fpxy(4,);
    fpfp.lon2 = fpxy(3,);
    pl_fp, fpfp, win=win, color="blue";
  }
}

func write_globalmapper_fp(input, fp=, ifname=, ofname=, outfile=, out_utm=) {
/* DOCUMENT write_globalmapper_fp(fp, outfile=, out_utm=)
  This function writes out the flight plan to an ascii file formatted for
  Global Mapper.

  Parameters:
    input: The flight plan array (in FB or FP struct) or the name of a flight
      planning file.
  Options:
    fp= Flight plan array. (deprecated, ignored if INPUT provided)
    ifname= Input file name for flight planning file. (deprecated, ignored if
      INPUT provided)
    outfile= Output file name. If an input file name was given, this defaults to
      the input file with _globalmapper or _globalmapper_utm inserted before
      the extension.
    out_utm= Set to 1 to make output in UTM coordinates.

  Deprecated:
  The following old options are still accepted, but are deprecated:
    fp= Flight plan array. (deprecated, ignored if INPUT provided)
    ifname= Input file name for flight planning file. (deprecated, ignored if
      INPUT provided)
    ofname= Output file name. If an input file name was given, this defaults to
      the input file with _globalmapper or _globalmapper_utm inserted before
      the extension. (deprecated, ignored if OUTFILE= is given)
*/
// Deprecated 2012-06-15: fp=, ifname=, and ofname
  default, input, ifname;
  default, input, fp;
  default, outfile, ofname;

  if(is_string(input)) {
    default, outfile,
      file_rootname(input)+"_globalmapper"+(out_utm?"_utm":"")+file_tail(input);
    input = read_fp(input, out_utm=out_utm);
  }

  if(structeq(structof(input), FB))
    input = fb2fp(input);

  count = numberof(input);
  shp = array(pointer, count);
  meta = array(string, count);
  for(i = 1; i <= count; i++) {
    ply = [[input(i).lon1,input(i).lat1],[input(i).lon2,input(i).lat2]];
    shp(i) = &ply;
    meta(i) = "BORDER_COLOR=RGB(0,255,0)\n"+
      "BORDER_WIDTH=3\n"+
      "BORDER_STYLE=Solid\n"+
      "FILL_COLOR=RGB(0,0,0)\n"+
      "FILL_STYLE=No Fill\n"+
      swrite(format="LABEL_POS=%g,%g\n", ply(1,avg), ply(2,avg))+
      "CLOSED=YES\n"+
      "FONT_SIZE=12\n"+
      "FONT_COLOR=RGB(0,0,0)\n"+
      "FONT_CHARSET=0\n"+
      swrite(format="FLIGHTLINE_NUMBER=%d\n", i)+
      swrite(format="FLIGHTLINE_LENGTH=%.2f km\n", lldist(ply(*))*1.852);
  }
  write_ascii_shapefile, shp, outfile, meta=meta;
}
