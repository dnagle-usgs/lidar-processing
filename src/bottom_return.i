
require, "bathy.i"

struct BOTRET {
   long  rn;	//raster-pulse number
   short idx;	//bottom index from ex_bath
   short sidx;	//starting index of bottom return
   short range;	//range of bottom return
   float ac;	//area under the bottom return
   float cent;	//centroid of bottom return
   float centidx;	//index of centroid
   float peak;	//peak power in the bottom return
   int peakidx;	//peak power indx in the bottom return
   double soe;	//seconds of the epoch
}
   
func bot_ret_stats(rn, i, graph=, win=) {
  /*DOCUMENT get_bottom_return(rn,i,graph=,win=)
    amar nayegandhi 10/28/03
     This function uses ex_bath to get the bottom return information and returns an array of type BOTRET
   */

 extern bath_ctl, db;
 bret = BOTRET();
 rv = ex_bath(rn, i, graph=graph, win=win);
 bret.rn = rv.rastpix;
 bret.idx = rv.idx;
  
 if (bret.idx != 0) {
  // now find all returns within the waveform above the threshold
  ridx = where(db > 2);
  //check to see if there is more than 1 peak
  mpp = where(ridx(dif) > 1);
  if (is_array(mpp)) {
    mpidx = grow(1,where(ridx(dif) > 1), numberof(ridx));
    //find the peak that was chosen as the bottom
    xidx = where((ridx-rv.idx)==0);
    if (is_array(xidx)) {
     lidx = where(xidx(1) < mpidx);
    } else {
     write, "no bottom return found.";
    }
    bret.sidx = ridx((mpidx(lidx(1)-1)+1));    
    end_idx = ridx((mpidx(lidx(1))));
  } else {
    bret.sidx = ridx(1);
    end_idx = ridx(0);
  }
  bret.range = end_idx - bret.sidx + 1;
  bret.ac = sum(db(bret.sidx:end_idx));
  bret.peak = db(bret.sidx:end_idx)(max);
  bret.peakidx = bret.sidx + db(bret.sidx:end_idx)(mxx);
  bret.centidx = bret.sidx +  float(  (db(bret.sidx:end_idx) * indgen(bret.range)) (sum) ) / bret.ac;
  bret.cent = float(  (db(bret.sidx:end_idx) * indgen(bret.range)) (sum) ) / (indgen(bret.range+1)(sum));
 } else {
  write, "No bottom return found."
 }

return bret
}
   
