// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_wf_centroid(wf, &position, &intensity, lim=) {
/* DOCUMENT position = wf_centroid(wf, lim=)
  -or- wf_centroid, wf, position, intensity, lim=

  Returns the centroid index for a waveform.

  Parameter:
    wf: Should be a vector of intensity values, with 0 representing "no power".

  Output parameters:
    position: The floating-point position into WF where the centroid is
      located. Note that the centroid's location may actually be outside the
      bounds of WF, particularly if WF contains negative values. If WF is [],
      then POSITION is set to 1e1000 (inf) to represet the invalid condition.
    intensity: The floating-point intensity value found at POSITION,
      interpolated. Points outside of range will receive the intensity of the
      first or last sample (whichever is closer).

  Options:
    lim= Limit number of points considered. If omitted, the whole waveform is
      considered. If provided, only the first LIM energy values are used.
      (In other words, wf(:lim) is used.) Must be a non-negative integer if
      provided.

  Returns:
    The same value as POSITION above.

  If wf=[], then will return inf.
*/
  // Values to return in case of an error situation
  position = 1e1000;
  intensity = 1e1000;

  if(!numberof(wf))
    return position;

  if(!is_void(lim) && lim < numberof(wf))
    wf = wf(:lim);

  sum_power = wf(sum);

  // If sum_power == 0, then we'll get a divide-by-zero situation below.
  if(!sum_power)
    return position;

  weighted_idx = double(wf) * indgen(numberof(wf));
  weighted_sum = weighted_idx(sum);

  position = weighted_sum / sum_power;
  intensity = interp(wf, indgen(numberof(wf)), position);

  return position;
}

if(!is_func(wf_centroid)) wf_centroid = nocalps_wf_centroid;
