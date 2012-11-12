// vim: set ts=2 sts=2 sw=2 ai sr et:

func poly2_fit_safe(y, x1, x2, m, w) {
/* DOCUMENT poly2_fit_safe(y, x1, x2, m)
  poly2_fit_safe(y, x1, x2, m, w)

  This is a simple wrapper around poly2_fit. If an interpreted error occurs
  during poly2_fit (as throw by the 'error' statement), a void result will be
  returned instead of stopping for the error. This is intended to address the
  scenario where an error arises when data points resolve into a singular
  matrix.
*/
  if(catch(0x10)) {
    return [];
  }
  return poly2_fit(y, x1, x2, m, w);
}

func polyfit_eaarl_pts(eaarl, wslide=, mode=, wbuf=, ndivide=) {
/* DOCUMENT polyfit_eaarl_pts(eaarl, wslide=, mode=, wbuf=, ndivide=)

  This function creates a 3rd order magnitude polynomial fit within the give
  data region and introduces random points within the selected region based on
  the polynomial surface. The points within the region are replaced by these
  random points. The entire input data is considered for smoothing. A window
  (size wslide x wslide) slides through the data array, and all points within
  the window + buffer (wbuf) are considered for deriving the surface.

  Parameter:
    eaarl: data array to be smoothed.

  Options:
    wslide = window size that slides through the data array.
    mode =
      mode = "fs"; //for first surface
      mode = "ba"; //for bathymetry (default)
      mode = "be"; //for bare earth vegetation
    wbuf = buffer distance (cm) around the selected region.  Default = 0
    ndivide= factor used to determine the number of random points to be added
      within each grid cell.  ( total area of the selected region is divided
      by ndivide). Default = 8;

  Output:
    Data array of the same type as the 'eaarl' data array.
*/
// Original 2005-08-05 Amar Nayegandhi
  t0 = array(double, 3);
  timer, t0;

  default, mode, "ba";
  default, wbuf, 0;
  default, ndivide, 8;

  if(is_integer(mode))
    mode = ["fs","ba","be"](mode);

  tmr1 = tmr2 = array(double, 3);
  timer, tmr1;

  eaarl = test_and_clean(eaarl);

  a = structof(eaarl(1));
  new_eaarl = array(a, numberof(eaarl) );
  count = 0;
  new_count = numberof(eaarl);

  if (!is_array(eaarl)) return;

  eaarl = sortdata(eaarl, mode=mode, method="x");
  local x, y, z;
  data2xyz, eaarl, x, y, z, mode=mode;

  indx = [];

  eaarl_orig = eaarl;

  // define a bounding box
  bbox = array(float, 4);
  bbox = [x(min), x(max), y(min), y(max)];

  if (!wslide) wslide = 1500; //in centimeters

  // Convert to meters
  wslide /= 100.;

  //now make a grid in the bbox
  ngridx = int(ceil((bbox(2)-bbox(1))/wslide));
  ngridy = int(ceil((bbox(4)-bbox(3))/wslide));

  if (ngridx > 1) {
    xgrid = bbox(1)+span(0, wslide*(ngridx-1), ngridx);
  } else {
    xgrid = [bbox(1)];
  }

  if (ngridy > 1) {
    ygrid = bbox(3)+span(0, wslide*(ngridy-1), ngridy);
  } else {
    ygrid = [bbox(3)];
  }

  origdata = [];
  status, start, msg="Polyfit smooth...";
  for (i = 1; i <= ngridy; i++) {
    q = where(y >= ygrid(i)-wbuf);
    if (is_array(q)) {
      qq = where(y(q) <= ygrid(i)+wslide+wbuf);
      if (is_array(qq)) {
        q = q(qq);
      } else q = []
    }
    if (!(is_array(q))) continue;

    for (j = 1; j <= ngridx; j++) {
      //define the extent of the strip to fit
      m = array(double, 4); // in meters
      m(1) = (xgrid(j)-wbuf);
      m(3) = (xgrid(j) + wslide+wbuf);
      m(2) = ygrid(i);
      m(4) = (ygrid(i) + wslide);
      indx = [];
      if (is_array(q)) {
        indx = where(x(q) >= m(1)*100.);
        if (is_array(indx)) {
          iindx = where(x(q)(indx) <= m(3)*100.);
          if (is_array(iindx)) {
            indx = indx(iindx);
            indx = q(indx);
          } else indx = [];
        }
      }
      if (numberof(indx) > 3) {
      // this is the data inside the box
      // tag these points in the original data array, so that we can remove
      // them later.
        eaarl(indx).rn = 0;
        //find min and max for be_elv
        mn_be_elv = z(indx)(min);
        mx_be_elv = z(indx)(max);
        // now find the 2-D polynomial fit for these points using order 3.
        c = poly2_fit_safe(z(indx), x(indx), y(indx), 3);
        if(is_void(c))
          continue;
        // define a random set of points in that area selected to apply
        // this fit

        // this is the area of the region in m^2.
        narea = abs((m(3)-m(1))*(m(4)-m(2)));
        narea = int(narea);
        a1 = [m(1),m(2)];
        a2 = [m(3), m(4)];
        ss = span(a1,a2,narea);

        nrand = int(narea/ndivide) + 1;
        rr1 = random(nrand);
        iidx1 = int(rr1*narea)+1;
        rr2 = random(nrand);
        iidx2 = int(rr2*narea)+1;
        elvall = array(double, nrand);
        for (k=1;k<=nrand;k++) {
          xp = ss(iidx1(k),1);
          yp = ss(iidx2(k),2);
          elvall(k) = poly2(xp, yp, c);
        }
        if (mode == "fs") {
          a = structof(eaarl(1));
          if (structeq(a, FS)) new_pts = array(R,nrand);
          if (structeq(a, VEG__)) new_pts = array(VEG__,nrand);
        }
        if (mode == "ba")
          new_pts = array(GEO,nrand);
        if (mode == "be")
          new_pts = array(VEG__,nrand);
        new_pts.east = int(ss(iidx1,1)*100);
        new_pts.north = int(ss(iidx2,2)*100);
        if (mode == "be") {
          new_pts.least = int(ss(iidx1,1)*100);
          new_pts.lnorth = int(ss(iidx2,2)*100);
        }
        if (mode == "ba") {
          new_pts.elevation = -10;
          new_pts.depth = int(elvall*100 + 10);
        }
        if (mode == "be") {
          new_pts.lelv = int(elvall*100);
        }
        if (mode == "fs") {
          new_pts.elevation = int(elvall*100);
        }
        new_pts.rn = span(count+1,count+nrand,nrand);
        new_pts.soe = span(count+1,count+nrand,nrand);

        // remove any points that are not within the elevation boundaries
        // of the original points
        if (mode=="fs")
          xidx = where(((new_pts.elevation) > mn_be_elv) & ((new_pts.elevation) < mx_be_elv));
        if (mode=="ba")
          xidx = where(((new_pts.elevation+new_pts.depth) > mn_be_elv) & ((new_pts.elevation+new_pts.depth) < mx_be_elv));
        if (mode=="be")
          xidx = where(((new_pts.lelv) > mn_be_elv) & ((new_pts.lelv) < mx_be_elv));
        if (is_array(xidx)) {
          new_pts = new_pts(xidx);
        } else {
          new_pts = []; nrand=0; continue;
        }
        xidx = [];
        nrand = numberof(new_pts);

        if ((count+nrand) > numberof(new_eaarl)) {
          new_eaarl1 = new_eaarl(1:count);
          new_count += numberof(new_eaarl);
          if (mode=="fs" || mode =="be")
            new_eaarl = array(VEG__, new_count);
          if (mode=="ba")
            new_eaarl = array(GEO, new_count);
          new_eaarl(1:count) = new_eaarl1;
          new_eaarl1 = [];
        }
        new_eaarl(count+1:count+nrand) = new_pts;
        count += nrand;
      }
      status, progress, i+(double(j)/ngridx), ngridy;
    }
    status, progress, i, ngridy;
  }
  status, finished;
  // remove points from eaarl_orig, that were tagged with rn = 0 in eaarl;
  rnidx = [];
  //if (!gridmode) {
  //  rnidx = grow(rnidx, where(eaarl.rn != 0));
  //  new_eaarl = grow(new_eaarl, eaarl(rnidx));
  //}

  new_eaarl = new_eaarl(1:count);

  // add fake mirror east,north, and elevation values (assume AGL to be 300m)
  new_eaarl.meast = new_eaarl.east;
  new_eaarl.mnorth = new_eaarl.north;
  new_eaarl.melevation = new_eaarl.elevation + 300*100;

  if (mode == "fs") {
    if (structeq(structof(new_eaarl), VEG__)) {
      // make last elevations the same as first return elevations
      new_eaarl.lnorth = new_eaarl.east;
      new_eaarl.least = new_eaarl.east;
      new_eaarl.lelv = new_eaarl.elevation;
    }
  }

  timer_finished, t0;
  return new_eaarl;
}
