// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_cent(wf, lim=) {
/* DOCUMENT cent(wf, lim=)
  Compute the centroid of "wf" using the first LIM points. If wf is an array
  of type char, it will first be inverted, converted to long, and have bias
  removed using the first point. Otherwise, the wf will be used as is.

  lim= Limit number of points considered. If omitted, only the first 12
     points are considered. Must be a non-negative integer if provided.

  Return result is array(double, 3):
    result(1) = centroid range
    result(2) = peak range
    result(3) = peak power

  If the waveform has fewer than 2 samples, the result will be [0,0,0].

  If a centroid cannot be calculated, then result(1) will be 10000 to indicate
  an error.
*/
  default, lim, 12;

  if(numberof(wf) < 2)
    return [0., 0., 0.];

  // convert to short and remove bias, if necessary
  if (typeof(wf) == "char")
    wf = short(~wf) - short(~(wf(1)));

  if (lim < numberof(wf))
    wf = wf(:lim);

  // Find maximum value & associated index
  max_index = wf(mxx);
  max_intensity = wf(max_index);

  centroid = min(wf_centroid(wf, lim=lim), 10000.);
  return [centroid, max_index, max_intensity];
}
if(!is_func(cent)) cent = nocalps_cent;
