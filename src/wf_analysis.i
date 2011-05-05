// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func wf_centroid(wf, lim=) {
/* DOCUMENT centroid = wf_centroid(wf, lim=)
   Returns the centroid of a waveform.

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
