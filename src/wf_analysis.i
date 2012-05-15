// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func wfs_extract(method, wfs, position, intensity, lim=) {
/* DOCUMENT result = wfs_extract(method, wfs, lim=)
  -or- wfs_extract, method, wfs, position, intensity, lim=

  Wrapper around various waveform target extraction algorithms.

  Parameters:
    method: Specifies which algorithm to use. Valid values:
        "centroid" - Uses wf_centroid
        "peak" - Uses wf_peak
        "peaks" - Uses wf_peaks
    wfs: An array of pointers to arrays of waveform data.

  Output parameters:
    position: Array of pointers to position values.
    intensity: Array of pointers to intensity values.

  Options:
    lim= Passed through to wf_centroid.

  Returns:
    The same value as POSITION above.
*/
  position = intensity = array(pointer, dimsof(wfs));
  n = numberof(wfs);

  if(method == "centroid")
    for(i = 1; i <= n; i++) {
      wf_centroid, wfs(i), pos, pow, lim=lim;
      position(i) = &pos;
      intensity(i) = &pow;
    }

  if(method == "peak")
    for(i = 1; i <= n; i++) {
      wf_peak, *wfs(i), pos, pow;
      position(i) = &pos;
      intensity(i) = &pow;
    }

  if(method == "peaks")
    for(i = 1; i <= n; i++) {
      wf_peaks, *wfs(i), pos, pow;
      position(i) = &pos;
      intensity(i) = &pow;
    }

  return position;
}

func wf_centroid(wf, &position, &intensity, lim=) {
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
  intensity = double(wf(0));

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

func wf_peak(wf, &position, &intensity) {
/* DOCUMENT position = wf_peak(wf)
  -or- wf_peak, wf, position, intensity

  Returns the peak index of a waveform.

  Parameter:
    wf: Should be a vector of intensity values.

  Output parameters:
    position: The integer position into WF where the peak is located. If there
      are multiple indices with the same maximal intensity, the first is
      returned. If WF is [], then POSITION is set to 1e1000 (inf) to represet
      the invalid condition.
    intensity: The intensity value found at POSITION. (If POSITION=inf, then
      the final intensity value is used.)

  Returns:
    The same value as POSITION above.
*/
  // Values to return in case of an error situation
  position = 1e1000;
  intensity = double(wf(0));

  if(!numberof(wf))
    return position;

  position = wf(mxx);
  intensity = wf(position);
  return position;
}

func wf_peaks(wf, &position, &intensity) {
/* DOCUMENT peaks = wf_peaks(wf)
  Returns the peak indices of a waveform.

  Parameter:
    wf: Should be a vector of intensity values.

  Output parameters:
    position: A vector containing the floating-point positions into WF where
      the peaks are located.
    intensity: A vector containing the floating-point intensity values
      corresponding to POSITION.

  Returns:
    The same value as POSITION above.

  This function defines a "peak" as any sample (or range of identical samples)
  that have lower values immediately before and after.

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
  position = intensity = [];
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
      if(!is_void(start)) {
        grow, position, (start+stop)/2.;
        grow, intensity, double(wf(long(position)));
      }
    }
  }
  return position;
}

func remove_noisy_tail(wf, thresh=, verbose=, idx=) {
/* DOCUMENT remove_noisy_tail(wf, thresh=, verbose=, idx=)
  This function removes the "noise" in the tail of the waveform that is above a
  certain threshold from its minimum value.
  Input:
    wf: waveform (1-d) array of intensity values
    thresh: intensity threshold value; default: 3
    verbose: 1 for verbose output, 0 for silent; default: 0
    idx: by default returns modified waveform; idx=1 returns index to last
      sample
  Output:
    1-d array of intensity values with noisy tail removed -or- scalar index

  If the mininum intensity value is 2 and thresh=3, then the tail will be
  trimmed back to one sample beyond the first value greater than or equal to 5.
*/
  default, thresh, 3.;
  default, verbose, 0;
  default, idx, 0;

  min_intensity = wf(min);

  if(verbose) {
    write, "*** Func remove_noisy_tail ***";
    write, format=" Threshold value = %f\n", double(thresh);
    write, format=" Minimum intensity = %f\n", double(min_intensity);
  }

  w = where(wf > min_intensity+thresh);
  if(!numberof(w)) {
    if(verbose) {
      write, "No data above threshold.";
    }
    return idx ? numberof(wf) : wf;
  }

  last = min(numberof(wf), w(0)+1);

  if(idx) return last;
  return wf(:last);
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
