// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

// The functions in this file are used to filter EAARL-A wfobj objects, either
// by returning a subset of the object or by modifying the object's contents in
// some way.

func eaarla_wf_filter_channel(wf, lim=, max_intensity=, max_saturated=) {
/* DOCUMENT eaarla_wf_filter_channel(wf, lim=, max_intensity=, max_saturated=)
  The input for this must be a wfobj from the EAARL-A system. This function
  will go through each pulse's triplet of channels to select the best one in
  terms of saturation. A new wfobj with just these will be returned; the new
  wfobj will have 1/3 the size of the original.

  Note: The input WF -must- already be sorted so that each pulse's channels are
  together as a triplet in 1-2-3 order!

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

  keep = array(short(0), wf.count);

  for(i = 0; i < wf.count; i += 3) {
    j = 0;
    do {
      j++;
      rx = *wf(rx,i+j);
      np = long(min(lim, numberof(rx)));
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
