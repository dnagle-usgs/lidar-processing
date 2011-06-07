// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func wfs_extract(method, wfs, lim=) {
/* DOCUMENT result = wfs_extract(method, wfs, lim=)
   Wrapper around various waveform target extraction algorithms.

   Parameters:
      method: Specifies which algorithm to use. Valid values:
            "centroid" - Uses wf_centroid
            "peak" - Uses wf_peak
            "peaks" - Uses wf_peaks
      wfs: An array of pointers to arrays of waveform data.

   Options:
      lim= Passed through to wf_centroid.

   Returns:
      Array of pointers to arrays of results.
*/
   result = array(pointer, dimsof(wfs));
   n = numberof(wfs);

   if(method == "centroid")
      for(i = 1; i <= n; i++)
         result(i) = &wf_centroid(*wfs(i), lim=lim);

   if(method == "peak")
      for(i = 1; i <= n; i++)
         result(i) = &wf_peak(*wfs(i));

   if(method == "peaks")
      for(i = 1; i <= n; i++)
         result(i) = &wf_peaks(*wfs(i));

   return result;
}

func wf_centroid(wf, lim=) {
/* DOCUMENT centroid = wf_centroid(wf, lim=)
   Returns the centroid index for a waveform.

   Parameter:
      wf: Should be a vector of power values, with 0 representing "no power".

   Options:
      lim= Limit number of points considered. If omitted, the whole waveform is
         considered. If provided, only the first LIM energy values are used.
         (In other words, wf(:lim) is used.) Must be a non-negative integer if
         provided.

   Returns:
      Floating-point position in wf where the centroid is located.

   If wf=[], then will return inf.
*/
   if(!numberof(wf))
      return 1e1000;

   if(!is_void(lim) && lim < numberof(wf))
      wf = wf(:lim);

   sum_power = wf(sum);

   if(!sum_power)
      return 1e1000;

   weighted_idx = double(wf) * indgen(numberof(wf));
   weighted_sum = weighted_idx(sum);

   return weighted_sum / sum_power;
}

func wf_peak(wf) {
/* DOCUMENT peak = wf_peak(wf)
   Returns the peak index of a waveform.

   Parameter:
      wf: Should be a vector of power values.

   Returns:
      Integer position in wf where peak is located.
*/
   if(!numberof(wf))
      return 1e1000;
   return wf(mxx);
}

func wf_peaks(wf) {
/* DOCUMENT peaks = wf_peaks(wf)
   Returns the peak indices of a waveform.

   Parameter:
      wf: Should be a vector of power values.

   Returns:
      Floating-point positions in wf where peaks are located.

   If a waveform has a flat peak, then the center point of that peak will be
   returned. For example:

      > wf_peaks([1,2,3,3,2,1])
      [3.5]
      > wf_peaks([1,2,1,2,2,2,1])
      [2,5]

   Thus, for a saturated return, the center spot on the saturated section will
   be returned.

   It's possible for no peaks to be found:

      > wf_peaks([2,1,2])
      []
*/
   n = numberof(wf);
   peaks = [];
   for(i = 2; i < n; i++) {
      if(wf(i-1) > wf(i)) {
         start = [];
         continue;
      }
      if(wf(i-1) < wf(i)) {
         start = i;
      }
      if(wf(i+1) < wf(i)) {
         stop = i;
         if(!is_void(start))
            grow, peaks, (start+stop)/2.;
      }
   }
   return peaks;
}

func remove_noisy_tail(w1,thresh=,verbose=) {
/* DOCUMENT remove_noisy_tail(w1, thresh=)
   This function removes the "noise" in the tail of the waveform that is above a certain threshold from its minimum value
   Input:
      w1: waveform (1-d) array
      thresh: threshold value
   Ouput
      w1_out = output waveform
*/

   if (is_void(thresh)) thresh = 3;
   if (verbose) write, "*** Func remove_noisy_tail ***";
   if (verbose) write, format="Threshold value =%f\n",thresh;
   minw1 = min(w1);
   idx = where(w1 <= (minw1+thresh));
   if (numberof(idx) < 2) {
      if (verbose) write, "No data above threshold.  return."
      return w1;
   }
   iscontidx = where(idx(dif)> 1); // check to see if the indices are continuous or select only the last continuos set of indices
   if (is_array(iscontidx)) {
      idxstart = idx(iscontidx(0)+1);
   } else {
      idxstart = idx(1);
   }

   if (idxstart>=1) w1_out = w1(1:idxstart);

   return w1_out;
}

   
func extract_peaks_first_deriv(w1, thresh=, verbose=, graph=, newgraph=, win=) {
/* DOCUMENT extract_peaks_first_deriv(w1, thresh=, verbose=)
   This function extracts the peaks (or inflections) in the waveform using the maxima method by finding the first derivative (difference) of the waveform.
   Input:
      w1: waveform (1-d) array
      thresh: threshold value
      verbose: verbose
   Output:
      peaks_idx = returns index to the maxima locations of w1.
*/

   if (is_void(thresh)) thresh = 3;
   if (verbose) write, "*** Func extract_peaks_first_deriv ***";
   if (verbose) write, format="Threshold value = %d; Diff operator threshold = %d\n", thresh, diffthresh;

   if (newgraph) {
      if (is_void(win)) win = 25;
      window, win;fma;
      plg, w1, color="black";
      plmk, w1, color="black", msize=0.2, marker=4, width=10;
   }

   peaks_idx = [];
   minw1 = min(w1);
   w1_dif = w1(dif); // first derivative

   w1_dif_sign = sign(w1_dif);
   w1_dif_sign_dif = (w1_dif_sign)(dif);

   peaks_idx = where(w1_dif_sign_dif == -2);

   // index idx are the maxima points for each inflection

   if (!(is_array(peaks_idx))) {
      if (verbose) write, "No maxima points found.  return."
      return peaks_idx;
   }

   peaks_idx += 1; // add 1 to fix indexing issue caused by dif operator

   if (verbose) {
      if (graph || newgraph) plmk, w1(peaks_idx), peaks_idx, color="green", marker=5, width=10, msize=0.3;
   }

   // now check if w1(idx) are above thresh
   thresh_idx = where(w1(peaks_idx) >= thresh);

   if (!(is_array(thresh_idx))) {
      if (verbose) write, "Maxima points found are all below threshold.  return."
      return ;
   } else {
      peaks_idx = peaks_idx(thresh_idx);
   }

   if (verbose) {
      write, format="number of peaks=%d\n",numberof(peaks_idx); 
      write, format="peaks index =%d\n",peaks_idx;
   }

   if (graph || newgraph) plmk, w1(peaks_idx), peaks_idx, color="red", marker=2, msize=0.4, width=10;

   return peaks_idx
}

func txrx_wave_test_data(rn,i=,tx=,rx=,wait=) {
/* DOCUMENT txrx_wave_test_data(rn,i=,tx=,rx=,wait=)
   This function tests the peak finding algorithm: extract_peaks_first_deriv()
*/
   r = get_erast(rn= rn);
   rp = decode_raster(r);
   for (i=1;i<=120;i++) {
      write, format="***  i=%d  ***\n",i;
      if (tx) {
         txw = *rp.tx(i);
         if (is_void(txw)) continue; // no waveform recorded
         txw_inv = float((~txw+1) - (~txw(1)+1));
         txw_peaks = extract_peaks_first_deriv(txw_inv, thresh=3, verbose=1, graph=, newgraph=1, win=26); 
         if (wait) pause, wait;
      }
      if (rx) {
         rxw = *rp.rx(i,1);
         if (is_void(rxw)) continue; // no waveform recorded
         rxw_inv = float((~rxw+1) - (~rxw(1)+1));
         rxw_peaks = extract_peaks_first_deriv(rxw_inv, thresh=3, verbose=1, graph=, newgraph=1, win=26); 
         if (wait) pause, wait;
      }
   }
}
