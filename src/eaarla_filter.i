// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

// The functions in this file are used to filter EAARL-A wfobj objects, either
// by returning a subset of the object or by modifying the object's contents in
// some way.

func eaarla_wf_filter_channel(wf, lim=, max_intensity=, max_saturated=) {
/* DOCUMENT eaarla_wf_filter_channel(wf, lim=, max_intensity=, max_saturated=)
  The input for this must be a wfobj from the EAARL-A system. This function
  will go through each pulse's triplet of channels to select the best one in
  terms of saturation. A new wfobj with just these will be returned, sorted by
  raster_seconds, raster_fseconds, and pulse; the new wfobj will have 1/3 the
  size of the original.

  The waveforms should -not- be corrected for bias before running through this
  function.

  Options:
    lim= Limits how far into the waveform to look for saturated samples.
        lim=1e1000          Default, effectively means to look at all samples
        lim=12              Only consider the first 12 samples.
    max_intensity= The maximum intensity value. Samples with this intensity
      value or higher are considered saturated.
        max_intensity=255   Default, which is the max possible value
        max_intensity=251   Typical value used for FS
    max_saturated= Maximum number of saturated samples permitted. If more than
      this many samples are saturated, then the next channel will be
      considered.
        max_saturated=2     Default, allow up to 2 saturated samples
*/
  default, lim, 1e1000;
  default, max_intensity, 255;
  default, max_saturated, 2;

  // Make a copy so as to not modify the original if not in subroutine form
  if(!am_subroutine())
    wf = wf(index, 1:wf.count);

  if(wf.count % 3 != 0)
    error, "Invalid input to eaarla_wf_select_channel";

  // Reorder so that channel triplets are together
  wf, sort, ["raster_seconds", "raster_fseconds", "pulse", "channel"];

  keep = array(short(0), wf.count);

  for(i = 0; i < wf.count; i += 3) {
    j = 0;
    do {
      j++;
      rx = *wf(rx,i+j);
      np = min(lim, numberof(rx))
      saturated = numberof(where(rx(1:np) >= max_intensity));
      if(saturated <= max_saturated) {
        keep(i+j) = 1;
      }
    } while(!keep(i+j) && j < 2);

    if(noneof(keep(i+1:i+2)))
      keep(i+3) = 1;
  }

  wf, index, where(keep);
  return wf;
}

func eaarla_wf_filter_bias(wf, which=, method=, lim=) {
/* DOCUMENT wf = eaarla_wf_filter_bias(wf, which=, method=, lim=)
  Modifies the waveforms in the given wfobj object WF to remove bias. WF should
  be a waveform object with EAARL-A data.  WHICH specifies which waveform to
  modify and is usually "rx" but can also be "tx".  METHOD specifies the method
  to use for determining the bias. Methods available:

    method="first"
      The value of the first sample is used as the bias.

    method="min"
      The minimum value in the waveform is used as the bias.

    method="most"
      The most frequent value in the waveform is used as the bias. If multiple
      values are tied, then the first such value is used. Option LIM can be
      provided to limit the range of values considered. That is, if the minimum
      value in a waveform is 2 and lim=3, then only values 2 through 4 are
      considered when determining the bias. This method works best when the
      waveforms are integers; if they are floats, then samples will be
      temporarily rounded to the nearest integer for purposes of determining
      the bias.
*/
  default, which, "rx";
  default, method, "first";
  default, lim, 1e1000;
  if(!am_subroutine())
    wf = wf(index, 1:wf.count);

  // Use rx to store the waveforms, which are usually rx
  rx = wfobj(noop(which));

  if(method == "first") {
    // Bias is the first sample
    for(i = 1; i <= wf.count; i++)
      rx(i) = rx(i) - rx(i)(1);
  } else if(method == "min") {
    // Bias is the minimum value in waveform
    for(i = 1; i <= wf.count; i++)
      rx(i) = rx(i) - rx(i)(min);
  } else if(method == "most") {
    // Bias is the most popular value in waveform
    for(i = 1; i <= wf.count; i++) {
      rx(i) = rx(i) - rx(i)(min) + 1;
      hist = histogram(long(rx(i)+0.5));
      np = min(lim, numberof(hist));
      rx(i) = rx(i) - hist(:np)(mxx);
    }
  }

  save, wf, noop(which), rx;
  return wf;
}
