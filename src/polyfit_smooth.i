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

func polyfit_eaarl_pts(eaarl, wslide=, mode=, boxlist=, wbuf=, gridmode=,
ndivide=) {
/* DOCUMENT polyfit_eaarl_pts(eaarl, wslide=, mode=, boxlist=, wbuf=,
  gridmode=, ndivide=)

  This function creates a 3rd order magnitude polynomial fit within the give
  data region and introduces random points within the selected region based on
  the polynomial surface. The points within the region are replaced by these
  random points.  The region can be defined in an array (boxlist=), or if
  gridmode is set to 1, the entire input data is considered for smoothing.  A
  window (size wslide x wslide) slides through the data array, and all points
  within the window + buffer (wbuf) are considered for deriving the surface.

  Parameter:
    eaarl: data array to be smoothed.

  Options:
    wslide = window size that slides through the data array.
    mode =
      mode = "fs"; //for first surface
      mode = "ba"; //for bathymetry (default)
      mode = "be"; //for bare earth vegetation
    gridmode= set to 1 to work in a grid mode. All data will be fitted to a
      polynomial within the defined wslide range and buffer distance (wbuf).
    boxlist = list of regions (x,y bounding box) where the poly fit function
      is to be applied.  All data within that region will be removed, and
      fitted with data within some wbuf buffer distance.
    wbuf = buffer distance (cm) around the selected region.  Default = 0
    ndivide= factor used to determine the number of random points to be added
      within each grid cell.  ( total area of the selected region is divided
      by ndivide). Default = 8;

  Output:
    Data array of the same type as the 'eaarl' data array.
*/
// Original 2005-08-05 Amar Nayegandhi
  default, mode, "ba";
  default, gridmode, 1;
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
  if (gridmode) {
    ngridx = int(ceil((bbox(2)-bbox(1))/wslide));
  } else {
    // number of regions where poly fit will be needed.
    ngridx = numberof(boxlist(,1));
  }
  ngridy = int(ceil((bbox(4)-bbox(3))/wslide));

  if (gridmode) {
    if (ngridx > 1) {
      xgrid = bbox(1)+span(0, wslide*(ngridx-1), ngridx);
    } else {
      xgrid = [bbox(1)];
    }
  }

  if (ngridy > 1) {
    ygrid = bbox(3)+span(0, wslide*(ngridy-1), ngridy);
  } else {
    ygrid = [bbox(3)];
  }

  origdata = [];
  if (!gridmode) {
    maxblistall = max(max(boxlist(*,2),boxlist(*,4)));
    minblistall = min(min(boxlist(,2),boxlist(,4)));
  }
  status, start, msg="Polyfit smooth...";
  for (i = 1; i <= ngridy; i++) {
    if (!gridmode) {
      // check to see if ygrid is within the boxlist region
      yi = ygrid(i);
      yib = (ygrid(i) + wslide);
      if ((yi > maxblistall) || (yi < minblistall) || (yib > maxblistall) || (yib < minblistall)) continue;
    }
    q = where(y >= ygrid(i)-wbuf);
    if (is_array(q)) {
      qq = where(y(q) <= ygrid(i)+wslide+wbuf);
      if (is_array(qq)) {
        q = q(qq);
      } else q = []
    }
    if (!(is_array(q))) continue;

    for (j = 1; j <= ngridx; j++) {
      if (!gridmode) {
        // check to see if ygrid is within the boxlist region
        maxblist = max(boxlist(j,2),boxlist(j,4));
        minblist = min(boxlist(j,2),boxlist(j,4));
        if ((yi > maxblist) || (yi < minblist) || (yib > maxblist) || (yib < minblist)) continue;
      }
      //define the extent of the strip to fit
      m = array(double, 4); // in meters
      if (!gridmode) {
        m(1) = min(boxlist(j,1),boxlist(j,3))-wbuf;
        m(3) = max(boxlist(j,1),boxlist(j,3))+wbuf;
      } else {
        m(1) = (xgrid(j)-wbuf);
        m(3) = (xgrid(j) + wslide+wbuf);
      }
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
  if (!gridmode) {
    rnidx = grow(rnidx, where(eaarl.rn != 0));
    new_eaarl = grow(new_eaarl, eaarl(rnidx));
  }

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

  return new_eaarl;
}

func make_boxlist(win) {
// Original 2005-08-08 Amar Nayegandhi
  window, win;

  boxlist = array(double, 10, 4);
  count = 1;
  contadd = 1;
  icount = 1;
  ans = 'n';
  while (contadd) {
    m = mouse(1,1,"select region: ");
    plg, [m(2),m(2),m(4),m(4),m(2)], [m(1),m(3),m(3),m(1),m(1)], color="red", width=1.5;
    if ((count % 10) == 0) {
      icount++;
      boxlist1 = boxlist;
      boxlist = array(double, 10*icount,4);
      boxlist(1:count,) = boxlist1;
    }
    boxlist(count++,) = m(1:4);
    n = read(prompt="Continue? (y/n):", format="%c",ans);
    if (ans != 'y' ) contadd = 0;
  }

  boxlist = boxlist(1:count-1,);
  return boxlist;
}

func batch_polyfit_smooth(bdata, iwin=, wslide=, mode=, boxlist=, wbuf=,
gridmode=, ndivide=) {
/* DOCUMENT batch_polyfit_smooth(idata, iwin=, wslide=, mode=, boxlist=, wbuf=,
  gridmode=, ndivide=)
  See polyfit_eaarl_pts for explanation of input parameters
*/
// Original 2005-08-12 Amar Nayegandhi
  default, iwin, 5;
  default, mode, 2;

  window, iwin;
  // ensure there are no 0 east or north values in bdata
  idx = where(bdata.east != 0);
  bdata = bdata(idx);
  idx = where(bdata.north != 0);
  bdata = bdata(idx);

  n_bdata = numberof(bdata);
  if (mode == 1)
    outdata = array(FS, n_bdata);
  if (mode == 2)
    outdata = array(GEO, n_bdata);
  if (mode == 3)
    outdata = array(VEG__, n_bdata);

  ncount = 0;
  nt_bdata = 1;

  // find boundaries of bdata
  mineast = min(bdata.east)/100.;
  maxeast = max(bdata.east)/100.;
  minnorth = min(bdata.north)/100.;
  maxnorth = max(bdata.north)/100.;

  ind_e_min = 2000 * (int((mineast/2000)));
  ind_e_max = 2000 * (1+int((maxeast/2000)));
  if ((maxeast % 2000) == 0) ind_e_max = maxeast;
  ind_n_min = 2000 * (int((minnorth/2000)));
  ind_n_max = 2000 * (1+int((maxnorth/2000)));
  if ((maxnorth % 2000) == 0) ind_n_max = maxnorth;

  n_east = (ind_e_max - ind_e_min)/2000;
  n_north = (ind_n_max - ind_n_min)/2000;
  n = n_east * n_north;

  min_e = array(float, n);
  max_e = array(float, n);
  min_n = array(float, n);
  max_n = array(float, n);

  i = 1;
  for (e=ind_e_min; e<=(ind_e_max-2000); e=e+2000) {
    for(north=(ind_n_min+2000); north<=ind_n_max; north=north+2000) {
      min_e(i) = e;
      max_e(i) = e+2000;
      min_n(i) = north-2000;
      max_n(i) = north;
      i++;
    }
  }

  pldj, min_e, min_n, min_e, max_n, color="green";
  pldj, min_e, min_n, max_e, min_n, color="green";
  pldj, max_e, min_n, max_e, max_n, color="green";
  pldj, max_e, max_n, min_e, max_n, color="green";

  for (i=1;i<=n;i++) {
    write, format="Processing Region %d of %d\r",i,n;
    dt_idx  = data_box(bdata.east/100., bdata.north/100., min_e(i)-100, max_e(i)+100, min_n(i)-100, max_n(i)+100);

    if (!is_array(dt_idx)) continue;
    dtdata = bdata(dt_idx);

    dtdp = polyfit_eaarl_pts(dtdata, wslide=wslide, mode=mode, wbuf=wbuf, gridmode=gridmode,ndivide=ndivide);

    if (!is_array(dtdp)) continue;

    didx  = data_box(dtdp.east/100., dtdp.north/100., min_e(i), max_e(i), min_n(i), max_n(i));

    if (!is_array(didx)) continue;
    dtdp = dtdp(didx);

    n_dtdp = numberof(dtdp);
    if ((ncount+n_dtdp) > n_bdata) {
      // increase the output data array
      nt_bdata++;
      if (nt_bdata==1)
        write, format="Warning... Output data array is bigger than input data array...\n";
      outdata1 = outdata(1:ncount);
      outdata = array(GEO,ncount+n_dtdp);
      outdata(1:ncount) = outdata1;
      outdata1 = [];
    }

    outdata(ncount+1:ncount+n_dtdp) = dtdp;
    ncount += n_dtdp;
    pldj, min_e(i), min_n(i), min_e(i), max_n(i), color="black";
    pldj, min_e, min_n(i), max_e, min_n(i), color="black";
    pldj, max_e, min_n(i), max_e, max_n(i), color="black";
    pldj, max_e(i), max_n(i), min_e(i), max_n(i), color="black";
  }

  outdata = outdata(1:ncount);

  // change the rn and soe values of outdata so that they are unique
  outdata.rn = span(1,ncount,ncount);
  outdata.soe = span(1,ncount,ncount);
  return outdata;

}
