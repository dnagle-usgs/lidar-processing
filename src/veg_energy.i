
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

   a = structof(veg_all(1));
   cell = int((ur(1)-ll(1))/numberof(img(,1)));
  
   idx = where(veg_all.least != 0);
   out = array(float, 120, numberof(veg_all));
   
   for (i=1;i<=numberof(idx);i++) {
     en = [veg_all.least(idx(i))/100., veg_all.lnorth(idx(i))/100.];
     xidx = int((en(1)-ll(1))/cell+0.5);
     yidx = int((en(2)-ll(2))/cell+0.5);
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
	     if (v1.elevation < -300 || v1.elevation > 2500) continue;
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
            
     

func plot_slfw(outveg, outwin=, indx=, dofma=, color=, interactive=, show=, inwin=) {
//amar nayegandhi 04/14/04
// plot synthesized large footprint waveform

w = window();
if (is_void(outwin)) outwin = 7;
if (is_void(inwin)) inwin = 5;
if (is_void(color)) color="black";

if (!is_void(dofma)) {
	window, outwin; fma;
}

if (!is_void(interactive)) {
  window, inwin;
  while (1) {
   m = mouse(1,0,"Left: Select waveform; Right:Quit");
   if (m(10) != 1) break;
   east = m(1);
   north = m(2);
   idx = where(outveg.east != 0);
   outveg = outveg(idx);
   idx = data_box(outveg.east/100., outveg.north/100., m(1)-50, m(1)+50, m(2)-50, m(2)+50);
   iidx = ((outveg.east(idx)/100.-m(1))^2+(outveg.north(idx)/100.-m(2))^2)(mnx);
   tveg = outveg(idx(iidx));

   window, outwin;
   yy = *tveg.rx;
   xx = *tveg.elevation;

   if (!is_void(dofma)) {
	window, outwin; fma;
   }
   plmk, yy, xx, msize=0.2, color=color, marker=1;
   plg, yy, xx, color=color;

   window, inwin;
  }

}

window, outwin;


if (is_array(indx)) {
  tveg = outveg(indx(1), indx(2))
  yy = *tveg.rx;
  xx = *tveg.elevation;

  plmk, yy, xx, msize=0.2, color=color, marker=1;
  plg, yy, xx, color=color;
}

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


func lfp_metrics(lfpveg, thresh=) {
/* DOCUMENT lfp_metrics(lfpveg, thresh=)
  This function calculates the composite large footprint metrics.
  amar nayegandhi 04/19/04.
  the output array will contain the following metrics:
   cht;	//canopy height in meters
   be;	// bare earth in meters
   grr;	// ground return ratio
   crr;	// canopy reflection ratio
   home;  // height of median energy
*/

 dims = dimsof(lfpveg);
 out = array(double, 5, dims(2), dims(3));
 if (is_void(thresh)) thresh = 10;
  
 for (i=1;i<=dims(2);i++) {
    for (j=1;j<=dims(3);j++) {
	lfprx = *lfpveg(i,j).rx;
	if (!is_array(lfprx)) continue;
	lfpelv = *lfpveg(i,j).elevation;
	lfpcum = (lfprx)(cum);
	menergy = lfpcum(0)/2;
	mindx = abs(lfpcum-menergy)(mnx);
	out(5,i,j) = (lfpelv)(mindx-1);
        lfpdif = where(lfprx(dif) >= thresh);
	if (!is_array(lfpdif)) continue;
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
	lfpgnd = lfprx(fgr:lgr);
	lfpcpy = lfprx(lgr+1:);
	lfpgsum = lfpgnd(sum);
	lfpcsum = lfpcpy(sum);
	out(3,i,j) = lfpgsum/(lfpgsum+lfpcsum);
	out(4,i,j) = lfpcsum/(lfpcsum+lfpgsum);
	
	out(1,i,j) = lfpelv(lfpdif(0)+1);
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

 idx = where(vmets(1,,) != 0);

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
