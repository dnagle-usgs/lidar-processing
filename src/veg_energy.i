
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
   cell = int((ur(1)-ll(1))/numberof(img(,1)));
  
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

  //now make a grid in the bbox
  ngridx = int(ceil((bbox(2)-bbox(1))/binsize));
  ngridy = int(ceil((bbox(4)-bbox(3))/binsize));

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

  if ( __ytk ) {
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
  count = 0;
  for (i = 1; i <= ngridy; i++) {
   //if (i!=19) continue;
   q = [];
   if (mode == 3) {
    q = where(eaarl.lnorth >= ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.lnorth(q) <= ygrid(i)+binsize);
       if (is_array(qq)) {
          q = q(qq);
       } else q = []
    }
   } else {
    q = where (eaarl.north >= ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.north(q) <= ygrid(i)+binsize);
       if (is_array(qq)){
	   q = q(qq);
       } else q = [];
    }
   }
   outveg(,i).north = long((ygrid(i)+binsize/2.));
   if (!(is_array(q))) continue;
      
    for (j = 1; j <= ngridx; j++) {
      outveg(j,i).east = long((xgrid(j)+binsize/2.));
      indx = [];
      if (is_array(q)) {
       if (mode == 3) {
        indx = where(eaarl.least(q) >= xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.least(q)(indx) <= xgrid(j)+binsize);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       } else {
        indx = where(eaarl.east(q) >= xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.east(q)(indx) <= xgrid(j)+binsize);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       }
      }
	 // count++;
	 //if (count < 17) continue;
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
  return outveg;
}
            
     
func make_single_lfpw(eaarl,bin=,normalize=, plot=, correct_chp=){
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
	if (k==13) amar();
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

func plot_slfw(outveg, outwin=, indx=, dofma=, color=, interactive=, show=, inwin=, title=, noxytitles=,  normalize=) {
//amar nayegandhi 04/14/04
// plot synthesized large footprint waveform
// returns the waveforms selected
// normalize = 1 by default


w = window();
if (is_void(outwin)) outwin = 7;
if (is_void(inwin)) inwin = 5;
if (is_void(color)) color="black";
if (is_void(normalize)) normalize = 1;
out = [];

if (!is_void(dofma)) {
	window, outwin; fma;
}

if (!is_void(interactive)) {
  count = 0;
  idx = where(outveg.east != 0);
  outveg = outveg(idx);
  fp = max((outveg.east(2)-outveg.east(1)), (outveg.north(2)-outveg.north(1)));
  window, inwin;
  while (1) {
   count++;
   if (count == 1) {
      m = mouse(1,0,"Left: Select waveform; Right:Quit");
   } else {
      m = mouse(1,0,"");
   }
   if (m(10) != 1) break;
   east = m(1);
   north = m(2);
   idx = data_box(outveg.east/100., outveg.north/100., m(1)-50, m(1)+50, m(2)-50, m(2)+50);
   iidx = ((outveg.east(idx)/100.-m(1))^2+(outveg.north(idx)/100.-m(2))^2)(mnx);
   tveg = outveg(idx(iidx));
   if (show) {
	// plot the footprint box in inwin.
	plg, [(tveg.north-fp/2), (tveg.north-fp/2), (tveg.north+fp/2), (tveg.north+fp/2), (tveg.north-fp/2)]/100., [(tveg.east-fp/2), (tveg.east+fp/2), (tveg.east+fp/2), (tveg.east-fp/2), (tveg.east-fp/2)]/100., color="black";
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
    plmk, xx, yy, msize=0.2, color=color, marker=1;
    plg, xx, yy, color=color;
   } else {
    plmk, xx, yy*nn, msize=0.2, color=color, marker=1;
    plg, xx, yy*nn, color=color;
   }
    

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

  if (normalize == 1) {
    plmk, xx, yy, msize=0.2, color=color, marker=1;
    plg, xx, yy, color=color;
  } else {
    plmk, xx, yy*nn, msize=0.2, color=color, marker=1;
    plg, xx, yy*nn, color=color;
  }
  out = tveg;
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


func lfp_metrics(lfpveg, thresh=, img=, fill=) {
/* DOCUMENT lfp_metrics(lfpveg, thresh=)
  This function calculates the composite large footprint metrics.
  amar nayegandhi 04/19/04.
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
 if (is_void(thresh)) thresh = 10;
  
 for (i=1;i<=dims(2);i++) {
    for (j=1;j<=dims(3);j++) {
	lfprx = *lfpveg(i,j).rx;
	lfpnpix = *lfpveg(i,j).npixels;
	if (!is_array(lfprx)) {
	  out(1,i,j) = -1000;
	  continue;
        }
	lfpelv = *lfpveg(i,j).elevation;
	lfpcum = (lfprx)(cum);
	menergy = lfpcum(0)/2;
	mindx = abs(lfpcum-menergy)(mnx);
	out(5,i,j) = (lfpelv)(mindx-1); // this is HOME

      lfpdif = where(lfprx(dif) >= thresh);
      if (!is_array(lfpdif)) continue;
      out(1,i,j) = lfpelv(lfpdif(0)+1);
      if (!is_array(img)) {
	// max(lfpdif(1):+5) should be the ground elevation 
	mnxgnd = min(lfpdif(1)+5, numberof(lfprx));
  	mxxgnd = (lfprx(lfpdif(1):mnxgnd))(mxx)+lfpdif(1)-1;
	out(2,i,j) = lfpelv(mxxgnd);
	lastgnd = min(numberof(lfpelv), mxxgnd+5);
	lgridx = where(lfprx(mxxgnd:lastgnd)(dif) > 0);
 	if (is_array(lgridx)) {
	  lgr = mxxgnd+lgridx(1)-1; // this is the last gnd return
	} else {
	  lgr = lastgnd-1;
	}
	fgridx = where(lfprx(1:mxxgnd)(dif) < 0);
	if (is_array(fgridx)) {
	    fgr = fgridx(0)+1;
	} else {
	    fgr = 1;
	}
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
 	  lgndidx = where(lfpelv(gidx:mxxgnd)(dif) > 0);
	if (is_array(lgndidx)) {
	   lgr = lgndidx(1)+gidx-1;
	} else {
	   lgr = mxxgnd;
	}
        if (numberof(lfpelv(mnxgnd:gidx)) > 1)
          fgndidx = where(lfpelv(mnxgnd:gidx)(dif) < 0);
	if (is_array(fgndidx)) {
	   fgr = fgndidx(0)+mnxgnd;
	} else {
	   fgr = mnxgnd;
	}
      }
      if (fgr > lgr) continue;
	lfpgnd = lfprx(fgr:lgr);
	lfpgnpix = lfpnpix(fgr:lgr);
	lfpcpy = lfprx(lgr:);
	lfpcnpix = lfpnpix(lgr:);
	lfpgsum = (lfpgnd*lfpgnpix)(sum);
	lfpcsum = (lfpcpy+lfpcnpix)(sum);
	out(3,i,j) = lfpgsum/(lfpgsum+lfpcsum);
	out(4,i,j) = lfpcsum/(lfpcsum+lfpgsum);
	
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
  
 plcm, vmets(vmetsidx,idx), lfpveg.north(idx)/100.+ybias, lfpveg.east(idx)/100.+xbias, cmin=cmin,
	cmax = cmax, msize=msize, marker=marker;

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

func plot_veg_classes(mets, lfp, idx=, win=, dofma=, msize=, smooth=) {
// amar nayegandhi 051104
/*
 FOREST: cht > 8m and 60-100% cover
 WOODLAND: cht > 8m and 25-60% cover
 SHRUBLAND: cht < 8m and cht > 1m & > 25% cover
 DWARF SHRUBLAND & HERBACEOUS: cht < 1m and cht > 0m 
*/

if (is_void(msize)) msize=0.5
idx1 = where((mets(1,) > 8) & (mets(4,) >= 0.5));

idx2 = where((mets(1,) > 8) & (mets(4,) > 0.25) & (mets(4,) < 0.5));

idx3 = where((mets(1,) < 8) & (mets(1,) > 1) & (mets(4,) > 0.25));

idx4 = where((mets(1,) < 1) & (mets(1,) > -1)); 


if (is_void(win)) win=4;
window, win;
if (dofma) fma;
if (!is_array(idx)) idx = [1,2,3,4,5];
 for (i=1;i<=numberof(idx);i++) {
    if (idx(i) == 1) {
	plmk, lfp.north(idx1)/100., lfp.east(idx1)/100., marker=1, msize=msize, width=10, color="yellow";
    }
    if (idx(i) == 2) {
	plmk, lfp.north(idx2)/100., lfp.east(idx2)/100., marker=1, msize=msize, width=10, color="green";
    }
    if (idx(i) == 3) {
	plmk, lfp.north(idx3)/100., lfp.east(idx3)/100., marker=1, msize=msize, width=10, color="blue";
    }
    if (idx(i) == 4) {
	plmk, lfp.north(idx4)/100., lfp.east(idx4)/100., marker=1, msize=msize, width=10, color="red";
    }
 }

if (smooth) {
   // make 2d array with class numbers
   xx = dimsof(lfp);
   vcl = array(long, xx(2), xx(3));
   vclnew = array(long, xx(2), xx(3));
   vcl(idx1)=1;
   vcl(idx2)=2;
   vcl(idx3)=3;
   vcl(idx4)=4;
   for (i=2;i<xx(3);i++) {
     for (j=2;j<xx(2);j++) {
	i1 = where(vcl(j-1:j+1,i-1:i+1) == 1)
	i2 = where(vcl(j-1:j+1,i-1:i+1) == 2)
	i3 = where(vcl(j-1:j+1,i-1:i+1) == 3)
	i4 = where(vcl(j-1:j+1,i-1:i+1) == 4)
	imxx = [numberof(i1),numberof(i2),numberof(i3),numberof(i4)](mxx);
	imx = [numberof(i1),numberof(i2),numberof(i3),numberof(i4)](max);
	if (imx != 0) vclnew(j,i) = imxx;
     }
   }
   window, win+1; fma;
   idx1 = where(vclnew == 1);
   idx2 = where(vclnew == 2);
   idx3 = where(vclnew == 3);
   idx4 = where(vclnew == 4);
   plmk, lfp.north(idx1)/100., lfp.east(idx1)/100., marker=1, msize=msize, width=10, color="yellow";
   plmk, lfp.north(idx2)/100., lfp.east(idx2)/100., marker=1, msize=msize, width=10, color="green";
   plmk, lfp.north(idx3)/100., lfp.east(idx3)/100., marker=1, msize=msize, width=10, color="blue";
   plmk, lfp.north(idx4)/100., lfp.east(idx4)/100., marker=1, msize=msize, width=10, color="red";
}
	
return
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
