
struct LFP_VEG {
 long north;
 long east;
 pointer rx;
 pointer npixels; // this is the number of 1ns returns  in each vertical bin
 pointer elevation;
 long npix; // this is the number of returns in the composite footprint
}

 


func energy_HOME(veg, rn, p=, bin=, plot=, thresh=, pse=) {
/*DOCUMENT energy_bin(rn,p,bin=).
  amar nayegandhi 02/24/04
  This function finds the height of median energy for each waveform 
*/

extern cenergy, tenergy, tpeak;
if (is_void(thresh)) thresh = 3;
if (is_void(pse)) pse = 0;

window, 7;
nveg = numberof(veg);
tome = array(float, 120, nveg);
home = array(float, 120, nveg);
cenergy = array(double, 120, nveg);
tenergy = array(long, 120, nveg);
tpeak = array(long, 120, nveg);

for (j=1;j<=nveg;j++) {
  rn = veg(j).rn(1) & 0xffffff;
  a = irg(rn,inc=0,usecentroid=1);

  //assuming irange can be no lesser than 100m (666 ns) and no greater than 600m (4000ns)
  idx = where(a.irange < 666 | a.irange > 4000);
  a.irange(idx) = 0;

  rr = decode_raster(get_erast(rn=rn));

  for (i=1;i<119;i++) {
   if (!is_array(*rr.rx(i,1))) continue;
   rp = max(*rr.rx(i,1))-int(*rr.rx(i,1));
   tp = max(*rr.tx(i,1))-int(*rr.tx(i,1));
   
   if (plot) {
   	fma;plmk, rp, marker=1, msize=0.3, color="black";
	plg, rp;
   }
   rq = where(abs(rp(dif)) > thresh);
   if (!is_array(rq)) continue 
   if (plot) {
	plmk, rp(rq(1)+1), rq(1)+1, marker=3, color="blue", msize=0.5;
	plmk, rp(rq(0)+1), rq(0)+1, marker=3, color="blue", msize=0.5;
   }
   cenergy(i,j) = sum(rp(rq(1)+1:rq(0)+1));
   tpeak(i,j) = max(tp);
   tenergy(i,j) = sum(tp);
   if (tpeak(i,j) != 0) cenergy(i,j) = cenergy(i,j)*1.0/tpeak(i,j);
   if (a.irange(i) != 0) tome(i, j) = a.irange(i)+(rq(0)+1)/2.;
   pause, pse;
  }

  elvdiff = veg(j).melevation - veg(j).elevation;
  ndiff = veg(j).mnorth - veg(j).north;
  ediff = veg(j).meast - veg(j).east;
 
  eindx = where(tome(,j) > 0)
  if (is_array(eindx)) {
   eratio = float(tome(,j)(eindx))/float(a.irange(eindx)+a.fs_rtn_centroid(eindx));
   home(eindx,j) = int(veg(j).melevation(eindx) - eratio*elvdiff(eindx));
  }

}

return home;
   
}
   
  
func find_be_from_grid(veg_all, img, ll, ur) {
   //amar nayegandhi 04/08/04

   veg_all = test_and_clean(veg_all);
   nox = float(numberof(img(,1)));
   cell = int((ur(1)-ll(1))/nox +0.5);
  
   idx = where(veg_all.least != 0);
   out = array(float, numberof(veg_all));
   
   for (i=1;i<=numberof(idx);i++) {
     en = [veg_all.least(idx(i))/100., veg_all.lnorth(idx(i))/100.];
     xidx = int((en(1)-ll(1))/cell);
     yidx = int((en(2)-ll(2))/cell);
     out(idx(i)) = img(xidx,yidx);
   }
 
   return out;
}


func make_large_footprint_waveform(eaarl, binsize=, digitizer=, normalize=, mode=, pse=, plot=, bin=) {
/* DOCUMENT make_large_footprint_waveform(eaarl, binsize=, digitizer=, 
	normalize=, mode=, pse=, plot=, bin=)
   This function finds the return energy for a group of waveforms within a 
   certain bin size.
   INPUT:  
	eaarl		: initial processed data array
	binsize		: size of the box (synthesized footprint) in meters 
			  (default = 5m)
	digitizer	: if set, use the returns from only one of the two
			 digitizers (set 1 for odd rasters, 2 for even rasters)
			 (not yet supported).
	normalize	: if set, normalize the energy by the number of 
			 waveforms in bin
	mode		: currently works for only veg... when mode = 3 (default).
	pse		: pause interval when plot is selected (in milliseconds)
	plot		: set to 1 to plot the synthesized waveform
	bin		: vertical bin of resulting synthesized waveform (in cm)
*/

  tm1 = tm2 = array(double, 3);
  timer, tm1;
  eaarl = clean_veg(eaarl);
  if (is_void(pse)) pse = 1000;
  if (is_void(bin)) bin = 50;
  window, 5;

  if (is_void(mode)) mode = 3;
  // define a bounding box
  bbox = array(float, 4);
  bbox(1) = min(eaarl.least);
  bbox(2) = max(eaarl.least);
  bbox(3) = min(eaarl.lnorth);
  bbox(4) = max(eaarl.lnorth);

  if (!binsize) binsize = 5; //in meters
  binsize = binsize * 100;

  // transform bbox to a regular grid with "binsize" dimensions
  b1box = array(long,4);
  b1box(1) = int(bbox(1)/binsize)*binsize;
  b1box(2) = int(ceil(bbox(2)/binsize)*binsize);
  b1box(3) = int(bbox(3)/binsize)*binsize;
  b1box(4) = int(ceil(bbox(4)/binsize)*binsize);
  bbox = b1box;
  //now find the grid dimensions
  //ngridx = int(ceil((bbox(2)-bbox(1))/binsize));
  //ngridy = int(ceil((bbox(4)-bbox(3))/binsize));
  ngridx = (bbox(2)-bbox(1))/binsize;
  ngridy = (bbox(4)-bbox(3))/binsize;

  outveg = array(LFP_VEG, ngridx, ngridy);

  if (ngridx > 1)  {
    xgrid = bbox(1)+span(0, binsize*(ngridx-1), ngridx);
  } else {
    xgrid = [bbox(1)];
  }
  if (ngridy > 1)  {
    ygrid = bbox(3)+span(0, binsize*(ngridy-1), ngridy);
  } else {
    ygrid = [bbox(3)];
  }

 /*
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
 */
  //timer, t0
  count = 0;
  for (i = 1; i <= ngridy; i++) {
   //if (i!=19) continue;
   q = [];
   if (mode == 3) {
    q = where(eaarl.lnorth > ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.lnorth(q) <= ygrid(i)+binsize);
       if (is_array(qq)) {
          q = q(qq);
       } else q = []
    }
   } else {
    q = where (eaarl.north > ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.north(q) <= ygrid(i)+binsize);
       if (is_array(qq)){
	   q = q(qq);
       } else q = [];
    }
   }
   outveg(,i).north = long(ygrid(i));
   if (!(is_array(q))) continue;
      
    for (j = 1; j <= ngridx; j++) {
      outveg(j,i).east = long(xgrid(j));
      indx = [];
      if (is_array(q)) {
       if (mode == 3) {
        indx = where(eaarl.least(q) > xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.least(q)(indx) <= xgrid(j)+binsize);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       } else {
        indx = where(eaarl.east(q) > xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.east(q)(indx) <= xgrid(j)+binsize);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       }
      }
      if (is_array(indx)) {
	 outveg(j,i).npix = numberof(indx);
         yy = [ygrid(i), ygrid(i), ygrid(i)+binsize, ygrid(i)+binsize, ygrid(i)]/100.
	 xx = [xgrid(j), xgrid(j)+binsize, xgrid(j)+binsize, xgrid(j), xgrid(j)]/100.
	 window, 5; plg, yy, xx, color="red";
	 st = swrite(format="%d,%d",j,i);
	 //plt, st, (xgrid(j)+binsize/2.)/100., (ygrid(i)+binsize/2.)/100., tosys=1;
 	 rarr = array(char, 250, numberof(indx));
 	 erarr = array(float, 250, numberof(indx));
         aiarr = array(float, 3, numberof(indx));
	 rn_old = [];
	 rn = [];
	 //now loop through each pulse and find the returned waveform and irange
         for (k = 1; k<=numberof(indx); k++) {
 	     rn_old = rn;
	     v1 = eaarl(indx(k));
	     rn = v1.rn & 0xffffff;
	     p = v1.rn / 0xffffff;
             if (rn != rn_old) {
  	         rr = decode_raster(get_erast(rn=rn));
		 ai = irg(rn, inc=0, usecentroid=1);
	     }
	     if (v1.elevation < -300 || v1.elevation > 3500) continue;
  	     elvdiff = v1.melevation - v1.elevation;
	     rarr(1:numberof(*rr.rx(p,1)),k) = max(*rr.rx(p,1))-(*rr.rx(p,1));
 	     nrarr = span(1,numberof(*rr.rx(p,1)),numberof(*rr.rx(p,1)))+ai.irange(p);
             eratio = nrarr/float(ai.irange(p)+ai.fs_rtn_centroid(p));
             erarr(1:numberof(*rr.rx(p,1)),k) = int(v1.melevation - eratio*elvdiff);
	     //aiarr(,k) = [ai.irange(p), ai.fs_rtn_centroid(p), numberof(*rr.rx(p,1))];
	     aiarr(,k) = [eaarl(indx(k)).elevation/100., ai.fs_rtn_centroid(p), numberof(*rr.rx(p,1))];
         }
	 //if (j==11 && i==19) amar();
	 idx = where(erarr != 0);
	 if (!is_array(idx)) continue;
	 emin = min(erarr(idx));
	 emax = max(erarr(idx));
	 nbins = int(ceil((emax-emin)/bin));
	 rrarr = array(float, nbins);
	 errarr = array(float, nbins);
	 karr = array(long, nbins);
	 for (k=1; k<= nbins; k++) {
	   kemin = emin+(k-1)*bin;
	   kemax = emin+(k)*bin;
	   kidx = where((erarr(idx) >= kemin) & (erarr(idx) < kemax));
	   if (!is_array(kidx)) continue;
	   rrarr(k) = sum(int(rarr(idx(kidx))));
	   if (normalize) rrarr(k) = rrarr(k)/numberof(kidx);
	   errarr(k) = (kemin+kemax)/200.
	   karr(k) = numberof(kidx);
    	 }
	/*
	    
	 // now make an array that will hold all the returns from these waveforms within a certain bin
	 // the array height depends on erarr from all the returns
	 //aimin = aiarr(1,min);
	 //aimnx = aiarr(1,)(mnx);
         aiall = aiarr(1,)/NS2MAIR+aiarr(2,);
         aimin = aiall(min);
	 aimnx = aiall(mnx);
         //rmax = max(aiarr+aiarr(3,));
         rmax = max(aiall/NS2MAIR+aiarr(3,));
         //rmxx = (aiarr(1,)+aiarr(3,))(mxx);
         rmxx = (aiall(1,)/NS2MAIR+aiarr(3,))(mxx);
         nrrarr = int(ceil(rmax-aimin));
         rrarr = array(int, nrrarr);
         rrarr(1:int(aiarr(3,aimnx))) = rarr(1:int(aiarr(3,aimnx)),aimnx);
         rrarr(-int(aiarr(3,rmxx))+1:0) += rarr(1:int(aiarr(3,rmxx)),rmxx);
         // now loop through the remaining waveforms to add to rrarr
         for (k = 1; k<=numberof(indx); k++) {
            if (k == rmxx || k == aimnx) continue;
	    sidx = int(aiarr(1,k)+0.5-aimin);
	    rrarr(sidx+1:(sidx+int(aiarr(3,k)))) += rarr(1:int(aiarr(3,k)),k);
         }
	*/
         count++;
 	 if (plot) {
	   pidx = where(rrarr != 0);
           window, 7; fma; plmk, rrarr(pidx), errarr(pidx), msize=0.2, color="red", marker=1;
 	   plg, rrarr(pidx), errarr(pidx);
	   pause, pse;
	 }
	 outveg(j,i).rx = &rrarr;
	 outveg(j,i).elevation = &errarr;
	 outveg(j,i).npixels = &karr;
	 //if (count == 59) amar();
      }
    }
    if ((i%5) == 0) write, format="%d of %d complete...\r",i, ngridy;
  }
  write, format="Number of Composite Waveforms processed = %d\n", count;
  timer, tm2;
  time = tm2-tm1;
  write, "Time statistics:"
  write, format=" Total time taken = %f minutes\n",time(3)/60.;
  tm1;
  tm2;
  time;
  return outveg;
}
            
     
func make_single_lfpw(eaarl,bin=,normalize=, plot=, correct_chp=, min_elv=){
   // amar nayegandhi 04/23/04 
   if (!bin) bin = 50;
    
   outveg = array(LFP_VEG, 1);
   outveg.north = long(avg(eaarl.north));
   outveg.east = long(avg(eaarl.east));
   outveg.npix = numberof(eaarl);
   rarr = array(char, 250, numberof(eaarl));
   erarr = array(float, 250, numberof(eaarl));
   aiarr = array(float, 3, numberof(eaarl));
   rn_old = [];
   rn = [];
   //now loop through each pulse and find the returned waveform and irange
   for (k = 1; k<=numberof(eaarl); k++) {
      rn_old = rn;
      v1 = eaarl(k);
      rn = v1.rn & 0xffffff;
      p = v1.rn / 0xffffff;
      if (rn != rn_old) {
         rr = decode_raster(get_erast(rn=rn));
	 ai = irg(rn, inc=0, usecentroid=1);
      }
      if (v1.elevation < -300 || v1.elevation > 3500) continue;
      elvdiff = v1.melevation - v1.elevation;
      rarr(1:numberof(*rr.rx(p,1)),k) = max(*rr.rx(p,1))-(*rr.rx(p,1));
      nrarr = span(1,numberof(*rr.rx(p,1)),numberof(*rr.rx(p,1)))+ai.irange(p);
      eratio = nrarr/float(ai.irange(p)+ai.fs_rtn_centroid(p));
      erarr(1:numberof(*rr.rx(p,1)),k) = int(v1.melevation - eratio*elvdiff);
 
     if (correct_chp) {
      // code below tries to remove the noise below the ground
      pgnd = where(erarr(,k) <= 0)(1); // where the ground possibly is
      if (erarr(pgnd,k) != 0) {
	pgnd1 = where(rarr(pgnd:,k)(dif) > 0);// first instance when the pulse rises after 0
        if (is_array(pgnd1)) {
          lgnd = pgnd+pgnd1(1)-1;
        } else {
          lgnd = pgnd+1;
        }
      } else {
	lgnd = pgnd-1;
      }
      rarr((lgnd+1):,k) = 0
      erarr((lgnd+1):,k) = 0
     
      //aiarr(,k) = [ai.irange(p), ai.fs_rtn_centroid(p), numberof(*rr.rx(p,1))];
      aiarr(,k) = [eaarl(k).elevation/100., ai.fs_rtn_centroid(p), lgnd];
      ngr = int(aiarr(3,k)); // number of good rarrs.
      if (plot) {
        window, 2; fma; plmk, erarr(1:ngr,k)/100., rarr(1:ngr,k), color="black"; 
        plg, erarr(1:ngr,k)/100., rarr(1:ngr,k), color="black"; 
      }
      rarr(1:ngr,k) = correct_1_chp(rarr(1:ngr,k), erarr(1:ngr,k)/100.);
      //pause, 1000;
     }
     if (plot) {
	xidx = where(erarr(,k) != 0)
        window, 2; fma; plmk, erarr(xidx,k)/100., rarr(xidx,k), color="black"; 
        plg, erarr(xidx,k)/100., rarr(xidx,k), color="black"; 
	xytitles, "Backscatter (counts)", "Elevation (m)";
     }
      
   }
   idx = where(erarr != 0);
   emin = min(erarr(idx));
   emax = max(erarr(idx));
   nbins = int(ceil((emax-emin)/bin));
   rrarr = array(float, nbins);
   errarr = array(float, nbins);
   karr = array(long, nbins);
   for (k=1; k<= nbins; k++) {
      kemin = emin+(k-1)*bin;
      kemax = emin+(k)*bin;
      kidx = where((erarr(idx) >= kemin) & (erarr(idx) < kemax));
      if (!is_array(kidx)) continue;
      rrarr(k) = sum(int(rarr(idx(kidx))));
      if (normalize) rrarr(k) = rrarr(k)/numberof(kidx);
      errarr(k) = (kemin+kemax)/200.
      karr(k) = numberof(kidx);
   }
   if (plot) {
       pidx = where(rrarr != 0);
       window, 7; fma; plmk, rrarr(pidx), errarr(pidx), msize=0.2, color="red", marker=1;
       plg, rrarr(pidx), errarr(pidx);
       if (is_void(pse)) pse = 0;
       pause, pse;
   }
   outveg.rx = &rrarr;
   outveg.elevation = &errarr;
   outveg.npixels = &karr;
   return outveg;
}

func plot_slfw(outveg, cmets=, ipath=, outwin=, indx=, dofma=, color=, interactive=, show=, inwin=, title=, noxytitles=,  normalize=, searchstr=) {
//amar nayegandhi 04/14/04
// plot synthesized large footprint waveform
// returns the waveforms selected
// normalize = 1 by default
// if outveg is [] search for the waveform in the files define by searchstr


w = window();
if (is_void(outwin)) outwin = 7;
if (is_void(inwin)) inwin = 5;
if (is_void(color)) color="black";
if (is_void(normalize)) normalize = 1;
if (is_void(searchstr)) searchstr="*merged.pbd";
out = [];

if (!is_void(dofma)) {
	window, outwin; fma;
}


if (!is_array(outveg)) {
  // find all the files in ipath using searchstr
  s = array(string,10000);
  if (searchstr) ss = searchstr;
  scmd = swrite(format = "find %s -name '%s'",ipath, ss);
  fp = 1; lp = 0;
  for (i=1; i<=numberof(scmd); i++) {
      f=popen(scmd(i), 0);
      n = read(f,format="%s", s );
      close, f;
      lp = lp + n;
      if (n) fn_all = s(fp:lp);
      fp = fp + n;
  }
}

if (!is_void(interactive)) {
  count = 0;
  if (is_array(outveg)) {
   idx = where(outveg.east != 0);
   outveg = outveg(idx);
   fp = max((outveg.east(2)-outveg.east(1)), (outveg.north(2)-outveg.north(1)));
  }
  window, inwin;
  while (1) {
   count++;
   if (count == 1) {
      m = mouse(1,0,"Left: Select waveform; Right:Quit");
   } else {
      m = mouse(1,0,"");
   }
   if (m(10) != 1) break;

   if ((count == 1) && (!is_array(outveg))) {
     // if outveg is not an array, search in ipath for the 
     // batch processed file
     tile = tile_location(m);
     tilen = tile(1);
     tilee = tile(2);
     itilee = tilee/10000 * 10000;
     itilen = tilen/10000 * 10000 + 10000;
     pattern = swrite(format="t_e%d_n%d",tilee, tilen+2000);
     fn_idx = where(strmatch(fn_all, pattern));
     //fname = swrite(format="%si_e%d_n%d_18s/t_e%d_n%d_18s/t_e%d_n%d_18s_n88_20020911_v_energy.pbd",ipath, itilee, itilen, tilee, tilen+2000, tilee, tilen+2000);
     fname = fn_all(fn_idx(1));
     write, format="Opening File %s\n",fname;
     f = openb(fname);
     restore, f;
     close, f;
     idx = where(outveg.east != 0);
     outveg = outveg(idx);
     fp = max((outveg.east(2)-outveg.east(1)), (outveg.north(2)-outveg.north(1)));
   }
   
  if ((count == 1) && (show)) 
      write, "CanopyHt BareEarth GRR CRR HOME "
   
   east = m(1);
   north = m(2);
   idx = data_box(outveg.east/100., outveg.north/100., m(1)-50, m(1)+50, m(2)-50, m(2)+50);
   if (is_array(idx)) {
     iidx = ((outveg.east(idx)/100.-m(1))^2+(outveg.north(idx)/100.-m(2))^2)(mnx);
     tveg = outveg(idx(iidx));
   }
   if ((count > 1) && (!is_array(idx))) {
     tile = tile_location(m);
     tilen = tile(1);
     tilee = tile(2);
     itilee = tilee/10000 * 10000;
     itilen = tilen/10000 * 10000 + 10000;
     fname = swrite(format="%si_e%d_n%d_18s/t_e%d_n%d_18s/t_e%d_n%d_18s_n88_20020911_v_energy.pbd",ipath, itilee, itilen, tilee, tilen+2000, tilee, tilen+2000);
     write, format="Opening File %s\n",fname;
     f = openb(fname);
     restore, f;
     close, f;
     idx = where(outveg.east != 0);
     outveg = outveg(idx);
     fp = max((outveg.east(2)-outveg.east(1)), (outveg.north(2)-outveg.north(1)));
     idx = data_box(outveg.east/100., outveg.north/100., m(1)-50, m(1)+50, m(2)-50, m(2)+50);
     iidx = ((outveg.east(idx)/100.-m(1))^2+(outveg.north(idx)/100.-m(2))^2)(mnx);
     tveg = outveg(idx(iidx));
   }
	
   if (show) {
	// plot the footprint box in inwin.
	plg, [(tveg.north-fp/2), (tveg.north-fp/2), (tveg.north+fp/2), (tveg.north+fp/2), (tveg.north-fp/2)]/100., [(tveg.east-fp/2), (tveg.east+fp/2), (tveg.east+fp/2), (tveg.east-fp/2), (tveg.east-fp/2)]/100., color="black";
        // write out indexing information
	write, format="1-D index = %d\n",idx(iidx);
	if (is_array(cmets)) {
          mets = cmets(,idx(iidx));
        } else {
	  mets = lfp_metrics([tveg], min_elv=-2.0);
        }
	write, format="%4.2f\t%3.2f\t%4.3f\t%4.3f\t%4.2f",mets(,1);
        if ((mets(1,1) > 5) & (mets(1,1) <= 22) & (mets(4,1) >= 0.59)) write, " FOREST ";
        if ((mets(1,1) > 5) & (mets(1,1) <= 22) & (mets(4,1) < 0.59) & (mets(4,1) >= 0.24)) write," WOODLAND ";
	if ((mets(1,1) > 5) & (mets(1,1) <= 22) & (mets(4,1) < 0.24) & (mets(4,1) >= 0.10)) write, " SPARSE WOODLAND ";
	if ((mets(1,1) <= 5) & (mets(1,1) > 1) & (mets(4,1) >= 0.2)) write, " SHRUBLAND ";
	if ((mets(1,1) <= 5) & (mets(1,1) > 1) & (mets(4,1) < 0.2)) write, " SPARSE SHRUBLAND ";
	if ((mets(1,1) <= 1) & (mets(1,1) > -2.0)) write, "OTHER"; // HERBACEOUS VEG, SAND, WATER etc.

	write, "\n";
   }
  
   if (is_void(*tveg.rx)) {
	write, "No waveform found...";
	continue;
   }
       
   window, outwin;
   yy = *tveg.rx;
   xx = *tveg.elevation;
   nn = *tveg.npixels

   if (!is_void(dofma)) {
	window, outwin; fma;
   }
   if (normalize == 1) {
    idx = where(nn != 0);
    plmk, xx(idx), yy(idx)/nn(idx), msize=0.2, color=color, marker=1;
    plg, xx(idx), yy(idx)/nn(idx), color=color;
   } else {
    plmk, xx, yy, msize=0.2, color=color, marker=1;
    plg, xx, yy, color=color;
   }
    
  pltitle, swrite(format="Number of samples = %d",tveg.npix);

   out = grow(out,tveg);

   window, inwin;
  }

}

window, outwin;


if (is_array(indx)) {
  dims = dimsof(indx);
  if (dims(1) == 1) tveg = outveg(indx(1), indx(2));
  if (dims(1) == 0) tveg = outveg(indx);
  yy = *tveg.rx;
  xx = *tveg.elevation;
  nn = *tveg.npixels

  idx = where(nn != 0);

  if (normalize == 1) {
    plmk, xx(idx), yy(idx)/nn(idx), msize=0.2, color=color, marker=1;
    plg, xx(idx), yy(idx)/nn(idx), color=color;
  } else {
    plmk, xx, yy*nn, msize=0.2, color=color, marker=1;
    plg, xx, yy*nn, color=color;
  }
  out = tveg;
  pltitle, swrite(format="Number of samples = %d",tveg.npix);
}

if (!noxytitles) xytitles, "Normalized Backscatter (counts)", "NAVD88 Elevation (m)"
if (is_array(title)) pltitle, title;

return out;
}


func lfp_home(lfpveg) {
/* DOCUMENT lfp_home(lfpveg)
  This function finds the height of median energy for the large footprint 
waveform.
 amar nayegandhi 04/16/04.
*/

  dims = dimsof(lfpveg);

  if (dims(1) == 2) home = array(float, dims(2), dims(3));
  if (dims(1) == 1) home = array(float, dims(2));

  for (i=1;i<=dims(2);i++) {
    for (j=1;j<=dims(3);j++) {

      if (!is_array(*lfpveg(i,j).rx)) continue;
      lfpcum = (*lfpveg.rx(i,j))(cum);
      menergy = lfpcum(0)/2;
      mindx = abs(lfpcum-menergy)(mnx);
      home(i,j) = (*lfpveg(i,j).elevation)(mindx-1);
    }
  }
  
return home;
}


func lfp_metrics(lfpveg, thresh=, img=, fill=, min_elv=, normalize=) {
/* DOCUMENT lfp_metrics(lfpveg, thresh=)
  This function calculates the composite large footprint metrics.
  amar nayegandhi 04/19/04.
  INPUT:
      lfpveg: large-footprint waveform array
      thresh= amplitude threshold to consider significan return
      img = 2d array of bare-earth data at same resolution
      fill = ??
      min_elv = minimum elevation (in meters) to consider for bare earth
      normalize = set to 0 if you do not want to normalize (default = 1).
  the output array will contain the following metrics:
   cht;	//canopy height in meters
   be;	// bare earth in meters
   grr;	// ground return ratio
   crr;	// canopy reflection ratio
   home;  // height of median energy

   img = 2-D gridded images with true ground elevations
*/

 dims = dimsof(lfpveg);
 dimsimg = dimsof(img);
 if (dims(1) == 2) out = array(double, 5, dims(2), dims(3));
 if (dims(1) == 1) {
    out = array(double, 5, dims(2));
    dims = grow(dims,1);
 }
 if (is_void(thresh)) thresh = 5;
  
 for (i=1;i<=dims(2);i++) {
    for (j=1;j<=dims(3);j++) {
	lfprx = *lfpveg(i,j).rx;
	lfpnpix = *lfpveg(i,j).npixels;
	if (!is_array(lfprx)) {
	  out(1,i,j) = -1000;
	  continue;
        }
	//normalize for number of pixels in each rx
   	if (normalize) {
          nzidx = where(lfpnpix != 0);
          if (is_array(nzidx)) lfprx(nzidx) = lfprx(nzidx)/lfpnpix(nzidx);
        }
        nzidx = where(lfpnpix == 0);
        if (is_array(nzidx)) lfprx(nzidx) = 0;
	lfpelv = *lfpveg(i,j).elevation;
	if (is_array(min_elv)) {
	  idx = where(lfpelv > min_elv);
	  if (is_array(idx)) {
	     sidx = idx(1); // take this to be the starting pt.
	     lfprx = lfprx(sidx:);
	     lfpnpix = lfpnpix(sidx:);
	     lfpelv = lfpelv(sidx:);
	   }
	 }

	lfpcum = (lfprx)(cum);
	menergy = lfpcum(0)/2;
	mindx = abs(lfpcum-menergy)(mnx);
	out(5,i,j) = (lfpelv)(mindx); // this is HOME

      if (numberof(lfprx) < 2) continue;
      lfpdif = where(lfprx(dif) <= -thresh);
      if (!is_array(lfpdif)) continue;
      mnxcan = min(lfpdif(0)-3,numberof(lfprx));
      if (mnxcan <= 0) continue;
      //mxxcan = (lfprx(mnxcan:lfpdif(0)))(mxx) + mnxcan -1;
      mxidx = where(lfprx(mnxcan:lfpdif(0))(dif) < 0);
      if (is_array(mxidx)) {
	mxxcan = mxidx(0) + mnxcan - 1;
      } else {
        mxxcan = (lfprx(mnxcan:lfpdif(0)))(mxx) + mnxcan -1;
      }
      out(1,i,j) = lfpelv(mxxcan);
      if (!is_array(img)) {
        // no additional bare earth image available
	lfpdif = where(lfprx(dif) >= thresh);
        if (!is_array(lfpdif)) continue;
	// max(lfpdif(1):+5) should be the ground elevation 
	mnxgnd = min(lfpdif(1)+5, numberof(lfprx));
  	mxxgnd = (lfprx(lfpdif(1):mnxgnd))(mxx)+lfpdif(1)-1;
	out(2,i,j) = lfpelv(mxxgnd);
        // if out(2,i,j) is between -2 and 2m then this is bare earth
        // else try harder knowing that bare earth could be between -2 and 2m.
        if (((out(2,i,j) < -5.0) || (out(2,i,j) > 5.0)) || (out(2,i,j) == 0)) {
            //find all returns between -2 and 2
	    bidx = where((lfpelv >= -5.0) & (lfpelv <= 5.0))
	    if (numberof(bidx) >= 2) {
	      lfpdif = where(lfprx(bidx)(dif) >= 2);// thresh=2 is low enough to trip on any possible gnd return
		if (is_array(lfpdif)) {
                   lfpidx = where(lfprx(bidx(lfpdif)) < 0);
                   if (is_array(lfpidx)) {
		     mxxgnd = (lfprx(bidx(lfpdif)+1))(mxx);
		     out(2,i,j) = lfpelv(mxxgnd);
		   }
                }
            }
        }
	lastgnd = min(numberof(lfpelv), mxxgnd+5);
	if (lastgnd > mxxgnd) lgridx = where(lfprx(mxxgnd:lastgnd)(dif) > 0);
 	if (is_array(lgridx)) {
	  lgr = mxxgnd+lgridx(1)-1; // this is the last gnd return
	} else {
	  lgr = lastgnd-1;
	}
	if (mxxgnd > 1) fgridx = where(lfprx(1:mxxgnd)(dif) < 0);
	if (is_array(fgridx)) {
	    fgr = fgridx(0)+1;
	} else {
	    fgr = 1;
	}
	if (out(2,i,j) < 5.5) out(1,i,j) -= out(2,i,j); // assuming gnd is below 2.5 m
      } else {
	// correct the canopy height by subtracting the bare earth elevation
	out(1,i,j) = out(1,i,j) - img(i,j);
	out(2,i,j) = img(i,j);
	gidx = (abs(lfpelv - img(i,j)))(mnx);
	if (abs(lfpelv(gidx)-img(i,j)) > 2) {
	   // this waveform does not contain gnd info
	   continue;
        }
	mxxgnd = min(gidx+5, numberof(lfpelv));
        mxxgnd = long(mxxgnd(1));
        mnxgnd = max(gidx-5, 1);
        mnxgnd = long(mnxgnd(1));
        if (numberof(lfpelv(gidx:mxxgnd)) > 1)
 	  lgndidx = where(lfpelv(gidx:mxxgnd)(dif) > 1);// dont really need to do this
	if (is_array(lgndidx)) {
	   lgr = lgndidx(1)+gidx-1;
	} else {
	   lgr = mxxgnd;
	}
        if (numberof(lfpelv(mnxgnd:gidx)) > 1)
          fgndidx = where(lfpelv(mnxgnd:gidx)(dif) < -1); // dont really need to do this
	if (is_array(fgndidx)) {
	   fgr = fgndidx(0)+mnxgnd;
	} else {
	   fgr = mnxgnd;
	}
      }
      if (fgr > lgr) continue;
      if (lgr > numberof(lfprx)) lgr = numberof(lfprx);
      if (fgr > numberof(lfprx)) fgr = numberof(lfprx);
	lfpgnd = lfprx(fgr:lgr);
	lfpgnpix = lfpnpix(fgr:lgr);
	lfpcpy = lfprx(lgr:);
	lfpcnpix = lfpnpix(lgr:);
	lfpgsum = (lfpgnd)(sum);
	lfpcsum = (lfpcpy)(sum);
	if (abs(out(2,i,j)- out(1,i,j)) <= 0.5) { // return only from gnd
	    out(1,i,j) = 0;
	    out(3,i,j) = 1.0;
	    out(4,i,j) = 0.0;
        } else {
	 if ((out(2,i,j) > -1.5) && (out(2,i,j) < 5.0)) {
           out(3,i,j) = lfpgsum/(lfpgsum+lfpcsum);
	   out(4,i,j) = lfpcsum/(lfpcsum+lfpgsum);
         } else { // all returns are from the canopy
	   out(3,i,j) = 0.0;
           out(4,i,j) = 1.0;
         }
        }
	
    }
 }

 if (fill) {
   for (i=2;i<dims(2);i++) {
     for (j=2;j<dims(3);j++) {
	if (out(1,i,j) == -1000) continue;
	if (out(4,i,j) == 0) {
	  data = out(4,i-1:i+1,j-1:j+1);
	  idx = where(data != 0 & data != -1000);
          if (is_array(idx)) 
	  out(4,i,j) = avg(data(idx));
	}
	if (out(3,i,j) == 0) {
	  data = out(3,i-1:i+1,j-1:j+1);
	  idx = where(data != 0 & data != -1000);
          if (is_array(idx)) 
	  out(3,i,j) = avg(data(idx));
	}
	if (out(2,i,j) == 0) {
	  data = out(2,i-1:i+1,j-1:j+1);
	  idx = where(data != 0 & data != -1000);
          if (is_array(idx)) 
	  out(2,i,j) = avg(data(idx));
	}
	if (out(1,i,j) == 0) {
	  data = out(1,i-1:i+1,j-1:j+1);
	  idx = where(data != 0 & data != -1000);
          if (is_array(idx)) 
	  out(1,i,j) = avg(data(idx));
	}
	if (out(5,i,j) == 0) {
	  data = out(5,i-1:i+1,j-1:j+1);
	  idx = where(data != 0 & data != -1000);
          if (is_array(idx)) 
	  out(5,i,j) = avg(data(idx));
	}
     }
   }
 }
	     
return out;
}

  	

func plot_metrics(vmets, lfpveg, vmetsidx=, cmin=, cmax=, msize=, marker= ,win=, dofma=, xbias=, ybias=) {
  // amar nayegandhi 04/20/04
 if (is_void(vmetsidx)) vmetsidx = 1;
 if (is_void(win)) win = 4;
 if (is_void(msize)) msize = 2.0;
 if (is_void(marker)) marker = 1;
 if (is_void(xbias)) xbias = 0;
 if (is_void(ybias)) ybias = 0;

 idx = where(vmets(vmetsidx,,) != 0);

 if (is_void(cmin)) cmin = min(vmets(vmetsidx,idx));
 if (is_void(cmax)) cmax = max(vmets(vmetsidx,idx));

 window, win;
 if (dofma) fma;
  
 //z = bytscl(vmets(vmetsidx,));
 z = vmets(vmetsidx,);
 pli, z, lfpveg(1,1).east/100., lfpveg(1,1).north/100., lfpveg(0,1).east/100., lfpveg(1,0).north/100., cmin=cmin, cmax=cmax;
 //plcm, vmets(vmetsidx,idx), lfpveg.north(idx)/100.+ybias, lfpveg.east(idx)/100.+xbias, cmin=cmin, cmax = cmax, msize=msize, marker=marker;

}


func plot_classes(vmets, lfpveg, vmetsidx=, nclasses=, classint=, win=) {
// amar nayegandhi 04/19/04

 if (is_void(vmetsidx)) vmetsidx = 1;
 if (is_void(win)) win = 4;
 
 if (!is_void(classint)) nclasses = numberof(classint);
 
 idx = where(vmets(1,,) != 0);
 if (is_void(classint)) {
   minclass = min(vmets(vmetsidx, idx));
   maxclass = max(vmets(vmetsidx, idx));
   classint = span(minclass, maxclass, nclasses);
 }

 colorbar = ["red", "blue", "green", "yellow", "magenta", "cyan", "black", "white"];

 window, win; fma;

 for (i=1;i<nclasses;i++) {
    iidx = where((vmets(vmetsidx, idx) >= classint(i)) & 
		(vmets(vmetsidx, idx) < classint(i+1)));
    plmk, lfpveg.north(idx(iidx))/100., lfpveg.east(idx(iidx))/100., marker=1,
		msize=0.5, width=10.0,  color=colorbar(i);
 }

}

func plot_veg_classes(mets, lfp, idx=, win=, dofma=, msize=, smooth=, write_imagefile=,opath=) {
// amar nayegandhi 051104
/*
 based on NPS Vegetation mapping program: Final Draft
 http://biology.usgs.gov/npsveg/classifcation/sect5.html

 FOREST: cht > 5m and 60-100% cover
 WOODLAND: cht > 5m and 25-60% cover
 SPARSE WOODLAND: cht > 5m and 10-25% cover
 SHRUBLAND: cht < 5m and cht > 0.5m & 100-25% cover
 SPARSE SHRUBLAND: cht < 5m and cht > 0.5m & 10-25% cover
 DWARF SHRUBLAND & HERBACEOUS: cht < 0.5m and cht > 0m 
*/

if (is_void(msize)) msize=0.5
/*
//idx1 = where((mets(1,) > 6) & (mets(1,) < 22) & (mets(4,) >= 0.5));
idx1 = where((mets(1,) > 5) & (mets(1,) <= 22) & (mets(4,) >= 0.59)); // FOREST 
idx2 = where((mets(1,) > 6) & (mets(4,) > 0.25) & (mets(4,) < 0.6));
idx2 = where((mets(1,) > 5) & (mets(1,) <= 22) & (mets(4,) < 0.59) & (mets(4,) >= 0.24)); // WOODLAND

idx3 = where((mets(1,) > 5) & (mets(1,) <= 22) & (mets(4,) < 0.24) & (mets(4,) >= 0.10)); // SPARSE WOODLAND

idx4 = where((mets(1,) <= 5) & (mets(1,) > 1) & (mets(4,) >= 0.2)); // SHRUBLAND

idx5 = where((mets(1,) <= 5) & (mets(1,) > 1) & (mets(4,) < 0.2)); // SPARSE SHRUBLAND

idx6 = where((mets(1,) <= 1) & (mets(1,) > -2.0)); // HERBACEOUS VEG, SAND, WATER etc.
*/

//modified 03/25/05 
idx1 = where((mets(1,) > 5) & (mets(1,) <= 29) & (mets(4,) >= 0.59) & (mets(2,) < 0.0)); // WETLAND FOREST 

idx2 = where((mets(1,) > 5) & (mets(1,) <= 29) & (mets(4,) >= 0.59) & (mets(2,) > 0.0)); // upLAND FOREST 

idx3 = where((mets(1,) > 5) & (mets(1,) <= 29) & (mets(4,) < 0.59)); // WOODLAND 

idx4 = where((mets(1,) > 1) & (mets(1,) <= 5) & (mets(4,) >= 0.19) & (mets(2,) < 0.0)); // wetLAND SHRUBLAND 

idx5 = where((mets(1,) > 1) & (mets(1,) <= 5) & (mets(4,) >= 0.19) & (mets(2,) > 0.0)); // upLAND SHRUBLAND 

idx6 = where((mets(1,) > 0.5) & (mets(1,) <= 1.5) & (mets(2,) > 0.5)); // HERBACEOUS VEGETATION

idx7 = where((mets(2,) < -0.5)); // WATER

z = mets(1,,);
z(*) = 0;

if (is_void(win)) win=4;
window, win;
if (dofma) fma;
if (!is_array(idx)) idx = [1,2,3,4,5,6,7];

if (is_array(idx1)) z(idx1) = 1;
if (is_array(idx2)) z(idx2) = 2;
if (is_array(idx3)) z(idx3) = 3;
if (is_array(idx4)) z(idx4) = 4;
if (is_array(idx5)) z(idx5) = 5;
if (is_array(idx6)) z(idx6) = 6;
if (is_array(idx7)) z(idx7) = 7;

 if (smooth) {
   // make 2d array with class numbers
   xx = dimsof(lfp);
   vclnew = array(long, xx(2), xx(3));
   for (i=2;i<xx(3);i++) {
     for (j=2;j<xx(2);j++) {
	//if (z(j,i)!= 0) {
	//   vclnew(j,i) = z(j,i);
	//   continue;
	//}
	i1 = where(z(j-1:j+1,i-1:i+1) == 1)
	i2 = where(z(j-1:j+1,i-1:i+1) == 2)
	i3 = where(z(j-1:j+1,i-1:i+1) == 3)
	i4 = where(z(j-1:j+1,i-1:i+1) == 4)
	i5 = where(z(j-1:j+1,i-1:i+1) == 5)
	i6 = where(z(j-1:j+1,i-1:i+1) == 6)
	i7 = where(z(j-1:j+1,i-1:i+1) == 7)
	imxx = [numberof(i1),numberof(i2),numberof(i3),numberof(i4),numberof(i5), numberof(i6)](mxx);
	imx = [numberof(i1),numberof(i2),numberof(i3),numberof(i4), numberof(i5), numberof(i6)](max);
	if (z(j,i)!= 0) {
           if (imx*100./8.0 > 70) { // smooth only if significant (>70%) of surrouding classes are same
	      if (imxx == 6) {
		vclnew(j,i) = imxx;// only for "other" class
	      } else {
	        vclnew(j,i) = z(j,i); 
	        continue;
	      }
           } else {
	      vclnew(j,i) = z(j,i); 
	      continue;
           }
	} else { // smooth irrespective of number of classes since otherwise it will be unclassified
	  if (imx != 0) vclnew(j,i) = imxx;
        }
     }
   }
   vclnew(,1) = long(z(,1));
   vclnew(,0) = long(z(,0));
   vclnew(1,) = long(z(1,));
   vclnew(0,) = long(z(0,));
   z = vclnew; vclnew=[];
 }

 if (write_imagefile) {
  snclasses = sbin= seast = snorth = "";
  seast = swrite(format="%d",int(lfp(1,1).east/100.));
  snorth = swrite(format="%d",int(lfp(0,1).north/100.));
  sbin = swrite(format="%d", int(lfp(2,1).east-lfp(1,1).east)/100);
  snclasses = "6";
  ofile = opath+"t_e"+seast+"_n"+snorth+"_bin"+sbin+"_vegclasses"+snclasses+".pnm";
  pnm_write, z, ofile;
  ofilearr = split_path(ofile, 1, ext=1);
  ofile_tif = ofilearr(1)+".tif";
  cmd = swrite(format="convert %s %s", ofile, ofile_tif); 
  f = popen( cmd, 0);
  close,f;

 }
 z = bytscl(z);
 pli, z, lfp(1,1).east/100., lfp(1,1).north/100., lfp(0,1).east/100., lfp(1,0).north/100.;
 colors = span(0,7,8);
 colors = bytscl(colors);
 window, 3; fma;
 for (i=1;i<=8;i++) {
   plmk, i,1, color=colors(i), marker=4, msize=1.0, width=10;
   txt1 = swrite(format="%d",i-1);
   plt, txt1, 2,i, tosys=1;
 }
 
	
return
}

func merge_veg_lfpw(outveg1, outveg2) {
 // this function merges 2 veg class outveg arrays usually within
 // the same data tile
 // amar nayegandhi 10/06/04. 


 while (outveg1(1,1).east == 0) {
   if (outveg1(0,1).east == 0) {
      outveg1 = outveg1(,2:);
   } else {
      outveg1 = outveg1(2:,);
   }
 }
      
 while (outveg2(1,1).east == 0) {
   if (outveg2(0,1).east == 0) {
      outveg2 = outveg2(,2:);
   } else {
      outveg2 = outveg2(2:,);
   }
 }

 bin1 = outveg1(2,1).east-outveg1(1,1).east;
 bin2 = outveg2(2,1).east-outveg2(1,1).east;

 if (bin1 != bin2) {
   write, "Input arrays do not have the same composite footprint size. Cannot merge.  Goodbye."
   return
 } else {
   bin = bin1;
 }

 outeast1 = min(outveg2(1,1).east,outveg1(1,1).east);
 outnorth1 = min(outveg2(1,1).north,outveg1(1,1).north);

 outeast2 = max(outveg2(0,0).east,outveg1(0,0).east);
 outnorth2 = max(outveg2(0,0).north,outveg1(0,0).north);

 xn = (outeast2-outeast1)/bin +1 ;
 yn = (outnorth2-outnorth1)/bin +1;
 
 ooutveg1 = array(LFP_VEG,xn,yn);
 ooutveg2 = array(LFP_VEG,xn,yn);
 outveg = array(LFP_VEG,xn,yn);

 outveg(1,1).east = outeast1;
 outveg(1,1).north = outnorth1;
 
 outveg(0,1).east = outeast1 + xn*bin;
 outveg(0,1).north = outnorth1;

 outveg(1,0).east = outeast1;
 outveg(1,0).north = outnorth1 + yn*bin;


 xstart1 = (outveg1(1,1).east-outeast1)/bin+1;
 xstart2 = (outveg2(1,1).east-outeast1)/bin+1;

 ystart1 = (outveg1(1,1).north-outnorth1)/bin+1;
 ystart2 = (outveg2(1,1).north-outnorth1)/bin+1;

 xstop1 = (outveg1(0,0).east-outeast1)/bin+1;
 xstop2 = (outveg2(0,0).east-outeast1)/bin +1;

 ystop1 = (outveg1(0,0).north-outnorth1)/bin+1;
 ystop2 = (outveg2(0,0).north-outnorth1)/bin+1;

 ooutveg1(xstart1:xstop1, ystart1:ystop1) = outveg1;
 ooutveg2(xstart2:xstop2, ystart2:ystop2) = outveg2;

 ooutveg1(1,1).east = outeast1;
 ooutveg1(1,1).north = outnorth1;
 
 ooutveg1(0,1).east = outeast1 + xn*bin;
 ooutveg1(0,1).north = outnorth1;

 ooutveg1(1,0).east = outeast1;
 ooutveg1(1,0).north = outnorth1 + yn*bin;

 ooutveg2(1,1).east = outeast1;
 ooutveg2(1,1).north = outnorth1;
 
 ooutveg2(0,1).east = outeast1 + xn*bin;
 ooutveg2(0,1).north = outnorth1;

 ooutveg2(1,0).east = outeast1;
 ooutveg2(1,0).north = outnorth1 + yn*bin;

 idx = [];
 idx = where((ooutveg2.npix >= ooutveg1.npix));
 if (is_array(idx)) outveg(idx) = ooutveg2(idx);

 idx = [];
 idx = where((ooutveg1.npix > ooutveg2.npix));
 if (is_array(idx)) outveg(idx) = ooutveg1(idx);

 // redefine north and east fields using bin and starting pt
 outveg(1,1).east = outeast1;
 outveg(1,1).north = outnorth1;
 outveg(,*).east = indgen(outeast1:outeast2:bin);
 o1 = transpose(outveg.north);
 o1(,*) = indgen(outnorth1:outnorth2:bin);
 o1 = transpose(o1);
 outveg.north = o1;
  
 return outveg;
}


func plot_fcht_histograms(fcht, binsize=, scale=, win=, color=, width=, dofma=, noxytitles=) {
 // amar nayegandhi 04/26/04
 
 if (!binsize) binsize = 2;
 if (is_void(win)) win = window();
 if (is_void(color)) color = "blue";
 if (is_void(width)) width = 1.0;
 if (is_void(scale)) scale = 1.0;

 minn = fcht(min);
 maxx = fcht(max)+1;
   
 nbins = int(ceil((maxx-minn)/float(binsize)));
 hist = array(float, nbins, 2);

 for (i=1; i<=nbins; i++) {
      minc = minn + (i-1)*binsize;  
      maxc = minn + (i)*binsize;
      indx = where((fcht>= minc) & (fcht< maxc));
      if (is_array(indx)) {
         hist(i,1) = numberof(indx);
         hist(i,2) = avg(fcht(indx));
      } else {
  	 hist(i,1) = 0;
	 hist(i,2) = minc+binsize/2;
      }
 }
 //hist = hist(where(hist(,1) != 0));
 w = window();
 window, win;
 if (dofma) fma;
 minz = min(fcht);
 maxz = max(fcht);
  
 nbins = int(ceil((maxz-minz)/float(binsize))+1);
 xsc = span(minz, maxz, nbins);
 color=-3;
 for (i=1; i< numberof(hist(,1));i++) {
      y = hist(,1);
      //plg, [0,y(i),y(i),0], [xsc(i),xsc(i),xsc(i+1),xsc(i+1)], width=5, color=color;
      plg, [xsc(i),xsc(i),xsc(i+1),xsc(i+1)], [0,y(i)*scale,y(i)*scale,0], width=width, color="blue";
     
      //plmk, hist(i,1), hist(i,2), marker=4, msize=0.4, width=10, color=color;
      //plmk, hist(i,2), hist(i,1), marker=4, msize=0.4, width=10, color=color;
      //xytitles,"Mean Elevation (meters)", "# of measurements (normalized n/n_max)";
      if (!noxytitles) xytitles,"# of measurements", "Canopy Height (meters)" 
      //pltitle, swrite(format="Elevation Histogram Site PT-%d", number);

    color--;
 }
 //plg, hist(,2), hist(,1)*scale, color=color, width=width;
 //plmk, hist(,2), hist(,1)*scale, marker=4, msize=0.2, width=10, color=color;
 return
}

func derive_chp(out1) {

 rx = *out1.rx(1);
 re = *out1.elevation(1);
 rn = *out1.npixels(1);

 nrx = numberof(rx);
 irx = indgen(nrx:1:-1);
 cumrx = (rx(irx))(cum)
 plmk, re(irx), (rx(irx))(cum)(2:), color="red";
 plg, re(irx), (rx(irx))(cum)(2:), color="red";

 cumrxn = cumrx(2:)/cumrx(0);
 cumnew = (cumrxn(1:-2)-log(1-cumrxn(1:-2)))(dif);
 cumnew = cumnew*cumrx(0);
 cumnew = grow(cumnew, rx(0));
 
 plmk, re(irx(3:0)), cumnew, color="blue";
 plg, re(irx(3:0)), cumnew, color="blue";

 return cumnew;
 
}

func correct_1_chp(rarr,erarr) {

 rx = double(rarr);
 re = erarr;

 nrx = numberof(rx);
 //irx = indgen(nrx:1:-1);
 //cumrx = (rx(irx))(cum)
 cumrx = (rx)(cum)
 plmk, re, cumrx(2:), color="red";
 plg, re, (cumrx)(2:), color="red";

 cumrxn = cumrx(2:)/cumrx(0);
 idx = where(cumrxn != 1)
 cumnew = (cumrxn(idx)-log(1-cumrxn(idx)))(dif);
 cumnew = cumnew*cumrx(0);
 cumnew = grow(rx(1), cumnew, rx(numberof(idx)+1:0));
 
 plmk, re, cumnew, color="blue";
 plg, re, cumnew, color="blue";

 return cumnew;
 
}

func make_begrid_from_bexyz(bexyz, binsize=, intdist=, lfpveg=) {
/* DOCUMENT make_begrid_from_bexyz(bexyz, binsize=)
  amar nayegandhi 02/16/05.
  This function makes a Bare Earth grid using the processed/filtered bare earth 
  data (bexyz) at a grid resolution of binsize.  
  intdist = interpolation distance to average missing values (default=2)
  lfpveg = array that describes the composite waveforms.  This is used to make the
  	   begrid conform to the size of the lfpveg array.
  OUTPUT:  array img containing the Bare Earth grid
*/

  extern bbox
  if (is_void(intdist)) intdist=2;
  if (!binsize) binsize = 5; //in meters
  binsize = binsize * 100;

  // define a bounding box
  bbox = array(long, 4);
  if (is_array(lfpveg)) {
    bbox(1) = lfpveg(1,1).east;
    bbox(3) = lfpveg(1,1).north;
    bbox(2) = lfpveg(0,0).east+binsize;
    bbox(4) = lfpveg(0,0).north+binsize;
  } else {
    bbox(1) = min(bexyz.least);
    bbox(2) = max(bexyz.least);
    bbox(3) = min(bexyz.lnorth);
    bbox(4) = max(bexyz.lnorth);
  }


  // transform bbox to a regular grid with "binsize" dimensions, if required
  if (!is_array(lfpveg)) {
    b1box = array(long,4);
    bbox = float(bbox);
    b1box(1) = int(bbox(1)/binsize)*binsize;
    b1box(2) = int(ceil(bbox(2)/binsize)*binsize);
    b1box(3) = int(bbox(3)/binsize)*binsize;
    b1box(4) = int(ceil(bbox(4)/binsize)*binsize);
    bbox = b1box;
    bbox = long(bbox);
  }
  ll = [bbox(1), bbox(3)]/100; // lower left location
  //now find the grid dimensions
  ngridx = (bbox(2)-bbox(1))/binsize;
  ngridy = (bbox(4)-bbox(3))/binsize;

  img = array(float, ngridx, ngridy); img(*) = -1000; // initialize with missing value
  imgcount = array(int, ngridx,ngridy); // counter 
  if ((dimsof(lfpveg)(2) != dimsof(img)(2)) || (dimsof(lfpveg)(3) != dimsof(img)(3))) {
    write, "dimensions not the same ... halt!"
    amar();
  }

 // now use delaunay triangulation to find the vertices
  verts = triangulate_xyz(data=bexyz, mode=3, distthresh=100);

  // find the centroid for each triangle
  
  da = sqrt(((bexyz.least(verts(2,))-bexyz.lnorth(verts(3,)))/100.)^2+((bexyz.lnorth(verts(2,))-bexyz.lnorth(verts(3,)))/100.)^2);
  db = sqrt(((bexyz.least(verts(3,))-bexyz.lnorth(verts(1,)))/100.)^2+((bexyz.lnorth(verts(3,))-bexyz.lnorth(verts(1,)))/100.)^2);
  dc = sqrt(((bexyz.least(verts(1,))-bexyz.lnorth(verts(2,)))/100.)^2+((bexyz.lnorth(verts(1,))-bexyz.lnorth(verts(2,)))/100.)^2);


  centx = (da*bexyz.least(verts(1,))/100.+db*bexyz.least(verts(2,))/100.+dc*bexyz.least(verts(3,))/100.)/(da+db+dc);
  centy = (da*bexyz.lnorth(verts(1,))/100.+db*bexyz.lnorth(verts(2,))/100.+dc*bexyz.lnorth(verts(3,))/100.)/(da+db+dc);
  centz = (bexyz.lelv(verts(1,))+bexyz.lelv(verts(2,))+bexyz.lelv(verts(3,)))/300.0;

  // now loop through the centroids and place the centz values in the img array
  // if there is more than 1 centz value for the same bincell, then take an avg.

  // we are now working in meters
  binsize = binsize/100;
  for (i=1;i<=numberof(centz);i++) {
     imgx = int(ceil((centx(i)-ll(1))/binsize));
     imgy = int(ceil((centy(i)-ll(2))/binsize));
     if (img(imgx,imgy) == -1000) {
        img(imgx,imgy) = centz(i);
     } else {
        img(imgx,imgy) = sum([img(imgx,imgy),centz(i)]);
	imgcount(imgx,imgy)++;
     }
     if (i%10000 == 0) write, format="%d of %d complete \r",i,numberof(centz);
  }

  idx = where(imgcount != 0);
  img(idx) = img(idx)/imgcount(idx);

  // now find those img locations that have not yet been assigned
  // check to see if the neighbors have any significant value else
  // assign them a missing value of -1000

  // define intdist i.e. how many neigbors to look at for assigning value
  // to the unassigned img locations

  idx = where(img == -1000);
  dimg = dimsof(img);
  img1 = img;
  for (i=1;i<=numberof(idx);i++) {
     imgx = idx(i) % dimg(2);
     imgy = idx(i) / dimg(2) +1;
     mindistx = min(intdist,imgx-1);
     maxdistx = min(intdist,dimg(2)-imgx-1);
     mindisty = min(intdist,imgy-1);
     maxdisty = min(intdist,dimg(3)-imgy-1);
     zcount = z = 0.0;
     for (j=-mindisty;j<=maxdisty;j++) {
       for (k=-mindistx;k<=maxdistx;k++) {
         if (img(imgx+k,imgy+j) != -1000) {
           z = sum([z,img(imgx+k,imgy+j)])
           zcount++
         }
        }
      }
      if (zcount != 0) {
         img1(imgx,imgy) = z/zcount;
      }
  }
  
  bbox /= 100;
  return img1;
}


func clean_lfpw (lfpw, beimg=, thresh=, min_elv=, max_elv=) {
 /* DOCUMENT clean_lfpw (lfpw, beimg=) 
    lfpw = large footprint waveform array
    beimg = bare earth image (grid)
    thresh= threshold limit
    min_elv = elevation below which will be filtered out
    max_elv = elevation above which will be filtered out

    this function cleans the large footprint waveform 
    -- removes false returns coming from the atmosphere
    -- removes "noise" returns below bare earth.
  */

 dims = dimsof(lfpw);
 if (is_void(thresh)) thresh = 5;

 if (is_void(min_elv)) min_elv = -1.0
 if (is_void(max_elv)) max_elv = 25.0;

 lfpw_new = array(LFP_VEG,dims(2),dims(3));

 for (i=1;i<=dims(3);i++) {
   for (j=1;j<=dims(2);j++) {
     lfp = lfpw(j,i);
     lfpw_new(j,i).north = lfp.north;
     lfpw_new(j,i).east = lfp.east;
     if (lfp.npix <= 0) continue;
     lfprx = *lfp.rx;
     if (!is_array(lfprx)) continue;
     npixels = *lfp.npixels;
     elvs = *lfp.elevation;
     nzidx = where(npixels != 0);
     if (is_array(nzidx)) lfprx(nzidx) = lfprx(nzidx)/npixels(nzidx);
     if (numberof(lfprx) < 2) {
        continue;
      }

     // filter points above max_elv and below min_elv
     // add 1 m for trailing/leading edge of waveform
     elidx = where((elvs > (min_elv-1)) & (elvs < (max_elv+1)));
     if (is_array(elidx)) {
        elvs = elvs(elidx);
        lfprx = lfprx(elidx);
        npixels = npixels(elidx);
     } else {
        continue;
     }
     //find peaks in the waveform above a specific threshold
     lfpdif = where(lfprx(dif) <= -thresh);
     if (!is_array(lfpdif)) {
        continue;
     }
     // now find the start and stop waveform points to remove noise
     // the trailing edge near lfpdif(1) will be the last return
     // the leading edge near lfpdif(0) will be the first return
     start_idx = max(1,lfpdif(1)-10);
     stop_idx = min(numberof(lfprx),lfpdif(0)+5);

     lfprx = lfprx(start_idx:stop_idx);
     elvs = elvs(start_idx:stop_idx);
     npixels = npixels(start_idx:stop_idx);
     zidx = where(lfprx != 0);
     lfprx = lfprx(zidx);
     elvs = elvs(zidx);
     npixels = npixels(zidx);

     // test to see where elvs(dif) > 1.5m
     ezidx = where(elvs(dif) > 1.5);
     if (is_array(ezidx)) {
       elvs = elvs(1:ezidx(1));
       lfprx = lfprx(1:ezidx(1));
       npixels = lfprx(1:ezidx(1));
     }
     zidx = where(npixels != 0);
     lfprx(zidx) *= npixels(zidx);
     lfp.elevation = &elvs;
     lfp.rx = &lfprx;
     lfp.npixels = &npixels;
     lfp.npix = numberof(elvs);
     lfpw_new(j,i) = lfp;
   }
  }
  return lfpw_new
 }

func compare_mets(outveg1, mets1, outveg2, mets2, idx=, win=) {
/* DOCUMENT compare_mets(outveg1, mets1, outveg2, mets2, idx=, win=)
   This function compares the vegetation metrics from 2 diff surveys.
	amar nayegandhi 03/25/05.
   INPUT:
	outveg1 = lfpw array for mission 1
	mets1 = vegetation metrics for mission 1
	outveg2 = lfpw array for mission 2
	mets2 = vegetation metrics for mission 2
	idx = metric index to compare
	win = window number to plot the difference
*/

  if (is_void(idx)) idx = 1;
  if (is_void(win)) win = 1;
  
  // make sure the grid cells are the same size
  xbin1 = outveg1(2,1).east - outveg1(1,1).east;
  ybin1 = outveg1(1,2).north - outveg1(1,1).north;

  xbin2= outveg2(2,1).east - outveg2(1,1).east;
  ybin2 = outveg2(1,2).north - outveg2(1,1).north;

  if (xbin1 != xbin2) {
    write, "X Grid cell size not same... cannot compare... goodbye!"
    return
  }
  if (ybin1 != ybin2) {
    write, "Y Grid cell size not same... cannot compare... goodbye!"
    return
  }
  xbin = xbin1; ybin = ybin1;
  if (xbin == ybin) bin = xbin;

  // now find the common area for both missions
  mineast1 = min(outveg1.east);
  minnorth1 = min(outveg1.north);
  maxeast1 = max(outveg1.east);
  maxnorth1 = max(outveg1.north);
  
  mineast2 = min(outveg2.east);
  minnorth2 = min(outveg2.north);
  maxeast2 = max(outveg2.east);
  maxnorth2 = max(outveg2.north);

  mineast = max(mineast1,mineast2);
  maxeast = min(maxeast1,maxeast2);
  minnorth = max(minnorth1,minnorth2);
  maxnorth = min(maxnorth1, maxnorth2);

  idx1 = where((outveg1.east > mineast) & (outveg1.east < maxeast) & (outveg1.north > minnorth) & (outveg1.north < maxnorth));
  idx2 = where((outveg2.east > mineast) & (outveg2.east < maxeast) & (outveg2.north > minnorth) & (outveg2.north < maxnorth));
  ngridx = (maxeast-mineast)/xbin;
  ngridy = (maxnorth-minnorth)/ybin;

  amar();
  outmets = array(5,ngridx,ngridy);
  omets1 = array(5,ngridx,ngridy);
  omets2 = array(5,ngridx,ngridy);
  
  if (mineast != mineast1) {
    sxidx1 = (mineast-mineast1)/xbin;
    sxidx2 = 1;
  } else {
    sxidx2 = (mineast-mineast2)/xbin;
    sxidx1 = 1;
  }
  if (maxeast != maxeast1) {
    exidx1 = (maxeast2-maxeast)/xbin;
    exidx2 = maxeast;
  } else {
    exidx2 = 0;
    exidx1 = maxeast;
  }
    
  if (minnorth != minnorth1) {
    eyidx1 = (minnorth-minnorth1);
    exidx2 = maxeast;
  } else {
    exidx2 = 0;
    exidx1 = maxeast;
  }
  
  if (maxnorth != maxnorth1) {
    exidx1 = 0;
    exidx2 = maxeast;
  } else {
    exidx2 = 0;
    exidx1 = maxeast;
  }
  amar();
  mets1 = mets1(sxidx1:exidx1,syidx1:eyidx1); 
  mets2 = mets2(sxidx2:exidx2,syidx2:eyidx2); 

  outmets = mets1-mets2;

  return outmets;
}
