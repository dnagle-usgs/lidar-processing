// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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
