// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func wf_centroid(wf) {
/* DOCUMENT centroid = wf_centroid(wf)
   Returns the centroid of a waveform.

   Parameter:
      wf: Should be a vector of power values, with 0 representing "no power".

   Returns:
      Floating-point position in wf where the centroid is located.

   If wf=[], then will return inf.
*/
   if(!numberof(wf))
      return 1e1000;

   count = numberof(wf);

   sum_power = wf(sum);

   weighted_idx = double(wf) * indgen(count);
   weighted_sum = weighted_idx(sum);

   if(sum_power)
      centroid = weighted_sum / sum_power;
   else
      centroid = 1e1000;

   return centroid;
}


