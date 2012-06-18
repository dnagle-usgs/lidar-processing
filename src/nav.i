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

extern FP;
/* DOCUMENT FP
  Struct used for flight planning.

  struct FP {
    string name;    // block name
    int block;      // block number
    float aw;       // area width  (km)
    float sw;       // scan spacing (km)
    float msec;     // meters-per-second flight speed
    float ssturn;   // seconds to allocate per turn
    float kmlen;    // length of block (km)
    double dseg(4); // defining segment
    float alat(5);  // lat corners of total area
    float alon(5);  // lon corners of total area
    pointer p;      // a pointer to the array of flightlines.
  };
*/

struct FP {
  string name;
  int block;
  float aw, sw, msec, ssturn, kmlen;
  double dseg(4);
  float alat(5), alon(5);
  pointer p;
};

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

   If called with "block" it will expect a block of FP data. The block of
   FP data usually would be a previously returned FP block, but with
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

   A structure of type FP is returned. Type FP at the command prompt to
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

  if ( click(1) > click(3) ) {
    temp = click;
    click(1) = temp(3);
    click(2) = temp(4);
    click(3) = temp(1);
    click(4) = temp(2);
    sf = -sf;   // keep block on same side
  }
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

    // now this is the left most point but we still need to find the north and
    // south extent again find intersecting pt of perpendiculars to this line
    // and take the southermost and northernmost points as end points
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

  if (is_void(ssturn) )
    ssturn = 300.0; // seconds to turn
  if (is_void(msec) )
    msec = 50.0;    // speed in meters/second

  if (!silent) {
    write,format="# set sw %f; set aw %f;  set msec %f; set ssturn %f set block %d\n",
      sw, aw, msec, ssturn, blockn;
    write,format="# %f %f %f %f \n", click(2),click(1), click(4), click(3);
  }
  segsecs = km*1000.0 / msec;
  blocksecs = (segsecs + ssturn ) * int(segs);
  if (!silent) {
    write, format="# set Seglen %5.3fkm; set segtime %4.2f; (min) set Total_time %3.2f(hrs)\n",
      km, segsecs/60.0, blocksecs/3600.0;
  }

  // Now convert the actual flight lines
  Xlong = Long; // save Long cuz utm2ll clobbers it
  Xlat  = Lat;
  zone = array(pZoneNumber, dimsof( sega) (2) );
  utm2ll, sega(,1), sega(,2), zone, Long, Lat;
  sega(,1) = Lat;
  sega(,2) = Long + click(1);
  utm2ll, sega(,3), sega(,4), zone, Long, Lat;
  sega(,3) = Lat;
  sega(,4) = Long + click(1);
  rg = 1:0:2;

  // See if the user want's to display the lines
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
  if (!in_utm) {
    if ( (fill & 0x4 ) == 4 ) {
      plg, [click(2),click(4)], [click(1),click(3)],color="red",marks=0;
    }
  }

  rs = FP();
  rs.kmlen = km;
  rs.alat = Xlat(r);
  rs.alon = Xlong(r);
  rs.block = blockn;
  rs.p = &sega; // pointer to all the segments
  rs.sw = sw;   // flight line spacing (swath width)
  rs.aw = aw;   // area width
  rs.msec = msec;
  rs.ssturn = ssturn;
  rs.dseg = click(1:4); // block definition segment

  blockn++;
  mission_time += blocksecs/3600.0;
  return rs;
}

func pl_fp(fp, win=, color=, width=, labels=, skip=) {
/* DOCUMENT pl_fp(fp, win=, color=, width=, labels=, skip=)
  Plots the given flight plan.

  Parameter:
    fp: A flight plan variable in FP struct.
  Options:
    win= The window to plot in, default win=6.
    color= Color to draw the lines, default color="magenta".
    width= The width to make each line, default width=1.
    labels= If labels=1, make every SKIP lines 5x thicker and place a label
      next to it for the line number. Default is labels=0.
    skip= Specifies the interval at which to place line labels, default skip=5.

  The input FP may be an array of FP structs, in which case each will be
  plotted. The flightline numbers will start at 1 for each.
*/
  if(numberof(fp) > 1) {
    for(i = 1; i <= numberof(fp); i++) {
      pl_fp, fp(i), win=win, color=color, width=width, labels=labels, skip=skip;
    }
  }

  default, win, 6;
  default, color, "magenta";
  default, width, 1;
  default, skip, 5;
  default, labels, 0;

  wbkp = current_window();
  window, win;

  lon1 = (*fp.p)(,1);
  lat1 = (*fp.p)(,2);
  lon2 = (*fp.p)(,3);
  lat2 = (*fp.p)(,4);

  pldj, lon1, lat1, lon2, lat2, color=color, width=width;
  if(labels) {
    idx = indgen(1:numberof(lon1):skip);
    for(i = 1; i <= numberof(idx); i++) {
      plt, swrite(format="%d", idx(i)), lon1(idx(i)), lat1(idx(i)), tosys=1,
        height=15, justify="CC";
    }
    pldj, lon1(idx), lat1(idx), lon2(idx), lat2(idx), color=color, width=5*width;
  }

  window_select, wbkp;
}

func read_fp(fname, utm=, plot=, win=) {
/*
  A .fp file will generally have a format like this:

  # sw=0.160000 aw=36.937405 msec=50.000000 ssturn=300.000000 block=6
  # 18.244188 -65.265854 18.271564 -65.136681
  # Total Seglen=305.451km Total segtime=101.82(min) Total time=7.28(hrs)
  llseg noname-1 n1814.65129852:w6514.09179688 n1812.83466339:w6513.03894043
  llseg noname-2 n1818.03611755:w6515.95123291 n1812.89222717:w6512.96890259

  Subsequent lines will have the same foramt as the last two.
*/

  fp = FP();

  // Initialize fp using info in the first three lines which are usually header
  // comments in a specific format. If they're not in the right format, the
  // values just get left as 0.
  lines = rdfile(fname, 3);

  sw = aw = msec = ssturn = 0.;
  block = 0;
  sread, lines(1),
    format="# sw=%f aw=%f msec=%f ssturn=%f block=%d", sw, aw, msec, ssturn, block;
  fp.sw = sw;
  fp.aw = aw;
  fp.msec = msec;
  fp.ssturn = ssturn;
  fp.block = block;

  kmlen = 0.;
  sread, lines(3), format="# Total Seglen=%fkm", kmlen;
  fp.kmlen = kmlen;

  // Load in flightlines data and the block name
  cols = rdcols(fname, delim=" :");
  count = numberof(*cols(1));
  fp.name = strtrim(longest_common_prefix(*cols(2)), 2, blank="-");

  y1 = dm2deg(atod(strpart(*cols(3), 2:)));
  south = strpart(*cols(3), :1) == "s";
  y1 *= (1 - south * 2);
  x1 = dm2deg(atod(strpart(*cols(4), 2:)));
  west = strpart(*cols(4), :1) == "w";
  x1 *= (1 - west * 2);

  y2 = dm2deg(atod(strpart(*cols(5), 2:)));
  south = strpart(*cols(5), :1) == "s";
  y2 *= (1 - south * 2);
  x2 = dm2deg(atod(strpart(*cols(6), 2:)));
  west = strpart(*cols(6), :1) == "w";
  x2 *= (1 - west * 2);

  south = west = [];

  if(utm) {
    u1 = ll2utm(y1, x1);
    u2 = ll2utm(y2, x2);
    // If they aren't all in the same zone, then force them to curzone if set.
    if(nallof(u1(3,) == u1(3,1)) || nallof(u2(3,) == u1(3,))) {
      if(curzone) {
        u1 = ll2utm(y1, x1, force_zone=curzone);
        u2 = ll2utm(y2, x2, force_zone=curzone);
      }
    }
    y1 = u1(1,);
    x1 = u1(2,);
    y2 = u2(1,);
    x2 = u2(2,);
  }

  fp.p = &[x1,y1,x2,y2];

  if(plot) {
    pl_fp, fp, win=win;
  }

  return fp;
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
    It must be of type FP.  If fp is not set, the user
    can select the polygon with a series of mouse clicks.
  ply=    If specified, then use an already defined polygon.
  win=  Default=6. Window you want to work in.
        mode=  set to 4 to use the pip feature. Use function sdist() for
              modes 1 through 3. see help, sdist()
        in_utm= set to 1 if input window is in utm coords
  out_utm= set to 1 if you want output in utm coords
  debug = set to 1 to work in debug mode.

  Output:  Variable of type FP.  Also writes out the flight plan lines
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
  fp_new = array(FP);

  if ( !fp.name  )
    fp.name = "noname";

  fp_new.name = fp.name;
  fp_new.block = fp.block;
  fp_new.aw = fp.aw;
  fp_new.sw = fp.sw;
  fp_new.msec = fp.msec;
  fp_new.ssturn = fp.ssturn;
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

func write_fp(fp, outfile=, plot=) {
/* DOCUMENT write_fp(fp, outfile=, plot=)
  Writes the data for a flight plan.

  Parameter:
    fp: An instance of FP data, containing the flight plan.
  Options:
    outfile= If specified, output will be written to this file. Otherwise, it
      will go to stdout (the console).
    plot= If plot=1, the data will be plotted as well.
*/
  f = [];
  if(outfile)
    f = open(outfile, "w");

  fpxy = *fp.p;
  fpxy = transpose(fpxy);

  counter = int(span(1,numberof(fpxy(1,)), numberof(fpxy(1,))));
  res = array(double, 4);
  res(1) = min(fpxy(1,));
  res(2) = min(fpxy(2,));
  res(3) = max(fpxy(3,));
  res(4) = max(fpxy(4,));

  write, f, format="# sw=%f aw=%f msec=%f ssturn=%f block=%d\n",
    fp.sw, fp.aw, fp.msec, fp.ssturn, fp.block;
  write, f, format="# %f %f %f %f \n", res(2),res(1), res(4), res(3);

  // now calculate the new total segment length and total time
  segdist = lldist(fpxy(2,), fpxy(1,), fpxy(4,), fpxy(3,));

  km = sum(segdist);
  segsecs = sum(segdist*1000./fp.msec);
  blocksecs = segsecs+(fp.ssturn*numberof(segdist));

  write, f,
    format="# Total Seglen=%5.3fkm Total segtime=%4.2f(min) Total time=%3.2f(hrs)\n",
    km, segsecs/60.0, blocksecs/3600.0;

  lat1d = abs(double(int(fpxy(2,))*100 + ((fpxy(2,) - int(fpxy(2,))) * 60.0) ));
  lon1d = abs(double(int(fpxy(1,))*100 + ((fpxy(1,) - int(fpxy(1,))) * 60.0) ));
  lat2d = abs(double(int(fpxy(4,))*100 + ((fpxy(4,) - int(fpxy(4,))) * 60.0) ));
  lon2d = abs(double(int(fpxy(3,))*100 + ((fpxy(3,) - int(fpxy(3,))) * 60.0) ));

  write, f, format="llseg %s-%d n%013.8f:w%12.8f n%13.8f:w%12.8f\n",
    fp.name, counter, lat1d, lon1d, lat2d, lon2d;

  if(!is_void(f))
    close, f;

  if(plot) {
    pl_fp, fp, win=win, color="blue";
  }
}

func write_globalmapper_fp(input, fp=, ifname=, ofname=, outfile=, out_utm=) {
/* DOCUMENT write_globalmapper_fp(fp, outfile=, out_utm=)
  This function writes out the flight plan to an ascii file formatted for
  Global Mapper.

  Parameters:
    input: The flight plan array (in FP struct) or the name of a flight
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

  lines = *input.p;
  count = dimsof(lines)(2);
  shp = array(pointer, count);
  meta = array(string, count);
  for(i = 1; i <= count; i++) {
    ply = lines(i,[[1,2],[3,4]]);
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
