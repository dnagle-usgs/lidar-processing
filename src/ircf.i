
require, "msort.i"

func rcf_triag_filter(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=) {
  /* DOCUMENT rcf_triag_filter(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=)
 this function splits data sets into manageable portions and calls new_rcfilter_eaarl_pts that 
uses the random consensus filter (rcf) and triangulation method to filter data.
 
 amar nayegandhi April 2004.

  INPUT:
  eaarl : data array to be filtered.  Can be of type VEG__ as of now.
  buf = buffer size in CENTIMETERS within which the rcf block minimum filter will be implemented (default is 500cm).
  w   = block minimum elevation width (vertical extent) in CENTIMETERS of the filter (default is 20cm)
  no_rcf = minimum number of 'winners' required in each buffer (default is 3).
  mode =
   mode = 1; //for first surface
   mode = 2; //for bathymetry
   mode = 3; // for bare earth vegetation
   (default mode = 3)
  fbuf = buffer size in METERS for the initial RCF to remove the "bad" outliers. Default = 100m
  fw = window size in METERS for the initial RCF to remove the "bad" outliers. Default = 15m
  tw = triangulation vertical range in centimeters Default = w
  tai = number of 'triangulation' iterations to be performed. Default = 3;
  interactive = set to 1 to allow interactive mode.  The user can deleted triangulated facets 
     		with mouse clicks in the triangulated mesh.
   OUTPUT:
    rcf'd data array of the same type as the 'eaarl' data array.

*/
 tmr1 = tmr2 = array(double, 3);
 timer, tmr1;
 extern boxmarker, tag_eaarl;
 //reset new_eaarl and data_out
 //t0 = t1 = double( [0,0,0] );
 MAXSIZE = 50000;
 new_eaarl = [];
 new_eaarl_all = [];
 data_out = [];
 if (!mode) mode = 3;
 ecount = 0;

 fsmode = mode;
 wfs = 15;

 // if data array is in raster format (R, GEOALL, VEGALL), then covert to 
 // non raster format (FS, GEO, VEG).
 a = structof(eaarl(1));
 if (a == R) {
     data_out = clean_fs(eaarl);
 }

 if (a == GEOALL) {
     data_out = clean_bathy(eaarl);
 }

 if (a == VEG_ALL) {
     data_out = clean_veg(eaarl);
 }

 if (a == VEG_ALL_) {
     data_out = clean_veg(eaarl);
 }

 if (is_array(data_out)) eaarl = data_out;
 data_out = [];

 neaarl = numberof(eaarl);

 //break the array into 4 regional blocks if greater than MAXN points
 MAXN = 100000;
 if (neaarl > MAXN) {
  eaarl_out = array(a, neaarl);
  min_mx = min(eaarl.east)/100.;
  max_mx = max(eaarl.east)/100.;
  min_my = min(eaarl.north)/100.;
  max_my = max(eaarl.north)/100.;
  nmx = nmy = 5;
  if (nmx > 1)  {
     spanx = span(min_mx, max_mx, nmx);
  } else {
     spanx = [min_mx, max_mx];
  }
  if (nmy > 1)  {
     spany = span(min_my, max_my, nmy);
  } else {
     spany = [min_my, max_my];
  }
 
  for (j=1;j<numberof(spany);j++) {
    for (k=1;k<numberof(spanx);k++) {
       isp1 = data_box(eaarl.east, eaarl.north,  spanx(k)*100, spanx(k+1)*100, spany(j)*100, spany(j+1)*100);
       window, 5; plg, [spany(j), spany(j), spany(j+1), spany(j+1), spany(j)], [spanx(k), spanx(k+1), spanx(k+1), spanx(k), spanx(k)], color="red";
       if (!is_array(isp1)) continue;
       eaarl1 = eaarl(isp1);
       xx = new_rcfilter_eaarl_pts(eaarl1, buf=buf, w=w, mode=mode, no_rcf=no_rcf, fbuf=fbuf, fw=fw, tw=tw, interactive=interactive, tai=tai);
       if (!is_array(xx)) continue;
       eaarl_out(ecount+1:ecount+numberof(xx)) = xx;
       ecount += numberof(xx);
     }
   }
 } else {
       eaarl_out = new_rcfilter_eaarl_pts(eaarl, buf=buf, w=w, mode=mode, no_rcf=no_rcf, fbuf=fbuf, fw=fw, tw=tw, interactive=interactive, tai=tai);
       ecount = numberof(eaarl_out);
 }
 eaarl_out = eaarl_out(1:ecount);
 
 write, format="Original points %d, Filtered points %d.  %2.2f%% data reduction\n", neaarl, ecount, (neaarl-ecount)*100./neaarl;
 timer, tmr2;
 tmr = tmr2-tmr1;
 write, format="Total time taken to filter: %4.2f minutes\n",tmr(3)/60.;
  
 return eaarl_out;    
}
   
func new_rcfilter_eaarl_pts(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=) {
  /* DOCUMENT new_rcfilter_eaarl_pts(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=)
 this function uses the random consensus filter (rcf) and triangulation method to filter data.
 
 amar nayegandhi Jan/Feb 2004.

  INPUT:
  eaarl : data array to be filtered.  Can be of type VEG__ as of now.
  buf = buffer size in CENTIMETERS within which the rcf block minimum filter will be implemented (default is 500cm).
  w   = block minimum elevation width (vertical extent) in CENTIMETERS of the filter (default is 20cm)
  no_rcf = minimum number of 'winners' required in each buffer (default is 3).
  mode =
   mode = 1; //for first surface
   mode = 2; //for bathymetry
   mode = 3; // for bare earth vegetation
   (default mode = 3)
  fbuf = buffer size in METERS for the initial RCF to remove the "bad" outliers. Default = 100m
  fw = window size in METERS for the initial RCF to remove the "bad" outliers. Default = 15m
  tw = triangulation vertical range in centimeters Default = w
  tai = number of 'triangulation' iterations to be performed. Default = 3;
  interactive = set to 1 to allow interactive mode.  The user can deleted triangulated facets 
     		with mouse clicks in the triangulated mesh.
   OUTPUT:
    rcf'd data array of the same type as the 'eaarl' data array.

*/
 tmr1 = tmr2 = array(double, 3);
 timer, tmr1;
 extern boxmarker, tag_eaarl;
 //reset new_eaarl and data_out
 //t0 = t1 = double( [0,0,0] );
 MAXSIZE = 50000;
 new_eaarl = [];
 new_eaarl_all = [];
 data_out = [];
 if (!mode) mode = 3;

 fsmode = mode;
 wfs = 15;

 // if data array is in raster format (R, GEOALL, VEGALL), then covert to 
 // non raster format (FS, GEO, VEG).
 a = structof(eaarl(1));
 if (a == R) {
     data_out = clean_fs(eaarl);
 }

 if (a == GEOALL) {
     data_out = clean_bathy(eaarl);
 }

 if (a == VEG_ALL) {
     data_out = clean_veg(eaarl);
 }

 if (a == VEG_ALL_) {
     data_out = clean_veg(eaarl);
 }

 if (is_array(data_out)) eaarl = data_out;
 data_out = [];


 a = structof(eaarl(1));
 new_eaarl = array(a, MAXSIZE);
 selcount = 0;

 if (is_void(fw)) fw = 15; //15m
 if (is_void(fbuf)) fbuf = 100; // 100m
 write, format="RCF'ing data set with window size = %d, and elevation width = %d meters...\n",fbuf,fw
 eaarl = rcfilter_eaarl_pts(eaarl, buf=fbuf*100, w=fw*100, mode=mode)

 tag_eaarl = array(int, numberof(eaarl));
 tag_eaarl++;
 indx = [];
 if (mode == 3) {
     eaarl = eaarl(sort(eaarl.least)); // for bare_earth
 } else {
     eaarl = eaarl(sort(eaarl.east)); // for first surface and bathy
 }
     
 eaarl_orig = eaarl;
    
 // define a bounding box
  bbox = array(float, 4);
  bbox(1) = min(eaarl.east);
  bbox(2) = max(eaarl.east);
  bbox(3) = min(eaarl.north);
  bbox(4) = max(eaarl.north);

  if (!buf) buf = 500; //in centimeters
  if (!w) w = 20; //in centimeters
  // no_rcf is the minimum number of points required to be returned from rcf
  if (!no_rcf) no_rcf = 3;

  //now make a grid in the bbox
  ngridx = int(ceil((bbox(2)-bbox(1))/buf));
  ngridy = int(ceil((bbox(4)-bbox(3))/buf));
  xgrid = bbox(1)+span(0, buf*(ngridx-1), ngridx);
  ygrid = bbox(3)+span(0, buf*(ngridy-1), ngridy);

  if ( _ytk ) {
    tkcmd,"destroy .rcf1; toplevel .rcf1; set progress 0;"
    tkcmd,swrite(format="ProgressBar .rcf1.pb \
	-fg green \
	-troughcolor blue \
	-relief raised \
	-maximum %d \
	-variable progress \
	-height 30 \
	-width 400", int(ngridy) );
    tkcmd,"pack .rcf1.pb; update; center_win .rcf1;"
  }


  //timer, t0
  origdata = [];
  for (i = 1; i <= ngridy; i++) {
   q = [];
   if (mode == 3) {
    q = where(eaarl.lnorth >= ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.lnorth(q) <= ygrid(i)+buf);
       if (is_array(qq)) {
          q = q(qq);
       } else q = []
    }
   } else {
    q = where (eaarl.north >= ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.north(q) <= ygrid(i)+buf);
       if (is_array(qq)){
	   q = q(qq);
       } else q = [];
    }
   }
   if (!(is_array(q))) continue;
      
    for (j = 1; j <= ngridx; j++) {
      indx = [];
      if (is_array(q)) {
       if (mode == 3) {
        indx = where(eaarl.least(q) >= xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.least(q)(indx) <= xgrid(j)+buf);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       } else {
        indx = where(eaarl.east(q) >= xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.east(q)(indx) <= xgrid(j)+buf);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       }
      }
      if (is_array(indx)) {
       // this is the data inside the box
       if (mode==3) {
         //be_elv = eaarl.elevation(indx)-(eaarl.lelv(indx)-eaarl.felv(indx));
         be_elv = eaarl.lelv(indx);
       }
       if (mode==2) {
         be_elv = eaarl.elevation(indx)+eaarl.depth(indx);
       }
       if (mode==1) {
         be_elv = eaarl.elevation(indx);
       }
       // find the minimum inside the box
       min_be_elv = min(be_elv);

       sel_ptr = rcf(be_elv, w, mode=2);

       if ((min(be_elv(*sel_ptr(1))) < (min_be_elv+w)) && (*sel_ptr(2) >= no_rcf)) {
	    tmp_eaarl = eaarl(indx(*sel_ptr(1)));
            tag_eaarl(indx(*sel_ptr(1)))++;
            if (fsmode == 4 && mode == 3) {
	      fsidx = where(tmp_eaarl.elevation < (avg(tmp_eaarl.lelv)+wfs*100));
	      if (is_array(fsidx)) {
	         tmp_eaarl = tmp_eaarl(fsidx);
		 *sel_ptr(2) = numberof(fsidx);
	      } else {
	         continue;
	      }
	    }
	    if (selcount+(*sel_ptr(2)) > MAXSIZE) {
	      grow, new_eaarl_all, new_eaarl(1:selcount);
	      new_eaarl = array(a, MAXSIZE);
	      selcount = 0;
	    }
	    new_eaarl(selcount+1:selcount+(*sel_ptr(2))) = tmp_eaarl;
	    selcount = selcount + (*sel_ptr(2));
	    //write, numberof(indx), *sel_ptr(2);
       } 
      }
    }
    if (_ytk) 
       tkcmd, swrite(format="set progress %d", i)
  }
  if (selcount > 0) 
	grow, new_eaarl_all, new_eaarl(1:selcount);
  //timer,t1
  //t1 - t0;
  if (_ytk) {
   tkcmd, "destroy .rcf1"
  } 

 // now find all points that have been rejected in the above step
 // i.e. where tag_eaarl == 1
 tidx = where(tag_eaarl == 1);
 if (is_array(tidx)) {
      maybe_eaarl = eaarl_orig(tidx);
 } else {
      maybe_eaarl = [];
 }

 // **** initial RCF complete ****

 if (is_void(tai)) tai = 3;
 for (ai=1;ai<=tai;ai++) {
  selcount = 0;
  write, format="Iteration number %d...\n", ai;
  if (ai > 1) {
    // now find all points that have been rejected in the above step
    // i.e. where tag_eaarl == 1
    tidx = where(tag_eaarl == 1);
    if (is_array(tidx)) {
       maybe_eaarl = maybe_eaarl(tidx);
    } else {
      maybe_eaarl = [];
    }
  }
  tag_eaarl = array(int,numberof(maybe_eaarl));
  tag_eaarl++;

  // now triangulate all the selected bare earth points
  nea_idx = msort(new_eaarl_all.least, new_eaarl_all.lnorth);
  new_eaarl_all = new_eaarl_all(nea_idx);

  // initial check for duplicates
  dupidx = [];
  dupidx = where((new_eaarl_all.least(dif) != 0) | (new_eaarl_all.lnorth(dif) != 0));
  new_eaarl_all = grow(new_eaarl_all(dupidx),new_eaarl_all(0));
  //write, format="number of new_eaarl_all = %d when ai = %d\n",numberof(new_eaarl_all), ai;

  verts = triangulate_xyz(data=new_eaarl_all, plot=1);

  if (interactive == 1) {
    // allow interactive mode to remove any outliers
    ques = "";
    n = read(prompt="Interactive Mode? ",ques);
    icount=0;
    while(ques == "y" || ques == "yes") {
 	tr = locate_triag_surface(pxyz, verts);
          if (is_array(tr)) {
 	    for (tri = 1; tri<= 3; tri++) {
	     tridx = where((new_eaarl_all.least/100. == tr(1,tri)) & (new_eaarl_all.lnorth/100.== tr(2,tri)));
	     new_eaarl_all(tridx).rn = 0;
             icount++;
            }
          } else {
             write, "No points selected..."
          }
	n = read(prompt="Continue Interactive Mode? ",ques);
    }

    if (icount) {
        tridx = where(new_eaarl_all.rn != 0);
	new_eaarl_all = new_eaarl_all(tridx);
        write, "Retriangulating..."
  	nea_idx = msort(new_eaarl_all.least, new_eaarl_all.lnorth);
  	new_eaarl_all = new_eaarl_all(nea_idx);
  	verts = triangulate_xyz(data=new_eaarl_all, plot=1);
     }
  }

  n_eaarl = numberof(new_eaarl_all);
  n_maybe = numberof(maybe_eaarl);
  new_eaarl_all1 = array(VEG__, n_eaarl+n_maybe);
  new_eaarl_all1(1:n_eaarl) = new_eaarl_all;
  new_eaarl_all = new_eaarl_all1;
  new_eaarl_all1 = [];
  
  // now loop through the 'maybe' points and see if they fit within the TIN
  ncount = n_eaarl;
  maybe_xyz = [maybe_eaarl.least/100., maybe_eaarl.lnorth/100., maybe_eaarl.lelv/100.];
  neweaarl_xyz = [new_eaarl_all.least/100., new_eaarl_all.lnorth/100., new_eaarl_all.lelv/100.];
  verts_idx = array(int, numberof(verts(1,)));

  // if maybe_xyz is greater than 100, split the array in regional blocks of 100 m
  min_mx = min(maybe_xyz(,1));
  max_mx = max(maybe_xyz(,1));
  min_my = min(maybe_xyz(,2));
  max_my = max(maybe_xyz(,2));
  nmx = int(ceil((max_mx - min_mx)/100.));
  nmy = int(ceil((max_my - min_my)/100.));
  if (nmx > 1)  {
     spanx = span(min_mx, max_mx, nmx);
  } else {
     spanx = [min_mx, max_mx];
  }
  if (nmy > 1)  {
     spany = span(min_my, max_my, nmy);
  } else {
     spany = [min_my, max_my];
  }
      
  for (j=1;j<numberof(spany);j++) {
    for (k=1;k<numberof(spanx);k++) {
       isp1 = data_box(maybe_xyz(,1), maybe_xyz(,2),  spanx(k), spanx(k+1), spany(j), spany(j+1));
       plg, [spany(j), spany(j), spany(j+1), spany(j+1), spany(j)], [spanx(k), spanx(k+1), spanx(k+1), spanx(k), spanx(k)], color="red";
       if (!is_array(isp1)) continue;
       maybe_sp = maybe_xyz(isp1,);
       //plmk, maybe_sp(,2), maybe_sp(,1), color="green", msize=0.1, marker=1;
       // find the points in each triangulated facet
       itpts=ibpts=bpts=tpts=ichpts=[];
       for (i=1;i<=numberof(verts(1,));i++) {
        //if ((i-1)%1000 == 0) write, format="%d of %d facets complete\r",i-1,numberof(verts(1,));
        if ((neweaarl_xyz(verts(1,i),1) < spanx(k)) || (neweaarl_xyz(verts(1,i),1) > spanx(k+1)) || (neweaarl_xyz(verts(1,i),2) < spany(j)) || (neweaarl_xyz(verts(1,i),2) > spany(j+1))) continue;
        if ((neweaarl_xyz(verts(2,i),1) < spanx(k)) || (neweaarl_xyz(verts(2,i),1) > spanx(k+1)) || (neweaarl_xyz(verts(2,i),2) < spany(j)) || (neweaarl_xyz(verts(2,i),2) > spany(j+1))) continue;
        if ((neweaarl_xyz(verts(3,i),1) < spanx(k)) || (neweaarl_xyz(verts(3,i),1) > spanx(k+1)) || (neweaarl_xyz(verts(3,i),2) < spany(j)) || (neweaarl_xyz(verts(3,i),2) >= spany(j+1))) continue;
        verts_idx(i) = 1;
        vpp = pxyz(,verts(,i));
        vp = grow(vpp(1:2,),vpp(1:2,1));
        box = boundBox(vp, noplot=1);
        //ibpts = ptsInBox(box, maybe_xyz(,1), maybe_xyz(,2));
        ibpts = data_box(maybe_sp(,1), maybe_sp(,2), box(1,min), box(1,max), box(2,min), box(2,max));
        if (is_array(ibpts)) {
         bpts = maybe_sp(ibpts,);
        } else {
         continue;
        }
        itpts = testPoly(vp, bpts(,1), bpts(,2));
        if (is_array(itpts)) {
         tpts = bpts(itpts,);
        } else {
         continue;
        }
        //elvavg = avg(vpp(3,));
        //ichpts = where((tpts(,3) < elvavg+w/100.) & (tpts(,3) > elvavg-w/100.)); 
        plconst = derive_plane_constants(vpp(,1), vpp(,2), vpp(,3));
 	if (plconst(3) == 0) continue;
        z_hope = -(tpts(,1)*plconst(1)+tpts(,2)*plconst(2)+plconst(4))/plconst(3);
        ichpts = where(abs(z_hope-tpts(,3)) <= tw/100.);
        if (is_array(ichpts)) {
         chidx = ibpts(itpts(ichpts));
        } else {
         chidx = [];
         continue;
        }
        nstart = ncount+1;
        ncount += numberof(chidx);
        new_eaarl_all(nstart:ncount) = maybe_eaarl(isp1(chidx));
        tag_eaarl(isp1(chidx))++;
       }
       //write, format="%d of %d facets complete\n",numberof(verts(1,ito)),numberof(verts(1,ito));
     
  /*   
  for (i=1;i<=numberof(maybe_eaarl);i++) {
    m = [maybe_xyz(i,1), maybe_xyz(i,2)];
    tr = locate_triag_surface(pxyz, verts, m=m);
    if (is_array(tr)) {
       elvavg = avg(tr(3,,));
       if ((maybe_xyz(i,3) < elvavg+w/100.) && (maybe_xyz(i,3) > elvavg-w/100.)) {
	   new_eaarl_all(++ncount) = maybe_eaarl(i);
	   tag_eaarl(i)++;
       }
    }
    if (i%1000 == 0) write, format="%d of %d complete\r",i,numberof(maybe_eaarl)
  }
  */
  }
  write, format="%d of %d iterations complete\n",j,numberof(spany);
 }
  write, format="%d of %d facets complete\n",numberof(verts(1,ito)),numberof(verts(1,ito));
  write, format="%d new points added in this iteration.\n",(ncount-n_eaarl);

  vidx = where(verts_idx == 0);
  if (!is_array(vidx)) continue;
  write, format="numberof of verts == 0 is %d\n",numberof(vidx);
  rverts = verts(,vidx);
  itpts=ibpts=bpts=tpts=ichpts=[];
  for (i=1;i<=numberof(rverts(1,));i++) {
    if ((i-1)%1000 == 0) write, format="%d of %d remaining facets complete\r",i-1,numberof(rverts(1,));
        vpp = pxyz(,rverts(,i));
        vp = grow(vpp(1:2,),vpp(1:2,1));
        box = boundBox(vp, noplot=1);
        ibpts = data_box(maybe_xyz(,1), maybe_xyz(,2), box(1,min), box(1,max), box(2,min), box(2,max));
        if (is_array(ibpts)) {
         bpts = maybe_xyz(ibpts,);
        } else {
         continue;
        }
        itpts = testPoly(vp, bpts(,1), bpts(,2));
        if (is_array(itpts)) {
         tpts = bpts(itpts,);
        } else {
         continue;
        }
        //elvavg = avg(vpp(3,));
        //ichpts = where((tpts(,3) < elvavg+w/100.) & (tpts(,3) > elvavg-w/100.)); 
        plconst = derive_plane_constants(vpp(,1), vpp(,2), vpp(,3));
 	if (plconst(3) == 0) continue;
        z_hope = -(tpts(,1)*plconst(1)+tpts(,2)*plconst(2)+plconst(4))/plconst(3);
        ichpts = where(abs(z_hope-tpts(,3)) <= tw/100.);
        if (is_array(ichpts)) {
         chidx = ibpts(itpts(ichpts));
        } else {
         chidx = [];
         continue;
        }
        nstart = ncount+1;
        ncount += numberof(chidx);
        new_eaarl_all(nstart:ncount) = maybe_eaarl(chidx);
        tag_eaarl(chidx)++;
   }
   write, format="\n %d iterations completed.\n", numberof(rverts(1,));
  new_eaarl_all = new_eaarl_all(1:ncount);
 }
 timer, tmr2;
 tmr = tmr2-tmr1;
 write, format="Total time taken to filter this section: %4.2f minutes\n",tmr(3)/60.;
 return new_eaarl_all;
	 
}


func derive_plane_constants(p,q,r) {
/*DOCUMENT derive_plane_constants(p,q,r)
  amar nayegandhi 02/04/04.
*/
 
  A = p(2)*(q(3)-r(3))+q(2)*(r(3)-p(3))+r(2)*(p(3)-q(3));
  B = p(3)*(q(1)-r(1))+q(3)*(r(1)-p(1))+r(3)*(p(1)-q(1));
  C = p(1)*(q(2)-r(2))+q(1)*(r(2)-p(2))+r(1)*(p(2)-q(2));
  D = p(1)*(q(2)*r(3) - r(2)*q(3))+q(1)*(r(2)*p(3)-p(2)*r(3))+r(1)*(p(2)*q(3)-q(2)*p(3));
  D = -1.0*D;

return [A,B,C,D];
}
