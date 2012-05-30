// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

// The functions in this file are used to filter wfobj objects, either by
// returning a subset of the object or by modifying the object's contents in
// some way.

func wf_filter_bias(wf, which=, method=, lim=) {
/* DOCUMENT wf = wf_filter_bias(wf, which=, method=, lim=)
  Modifies the waveforms in the given wfobj object WF to remove bias. WF should
  be a waveform object. WHICH specifies which waveform to modify and is usually
  "rx" but can also be "tx". METHOD specifies the method to use for determining
  the bias. Methods available:

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
  rx = wf(noop(which));

  if(method == "first") {
    // Bias is the first sample
    for(i = 1; i <= wf.count; i++)
      rx(i) = &(*rx(i) - (*rx(i))(1));
  } else if(method == "min") {
    // Bias is the minimum value in waveform
    for(i = 1; i <= wf.count; i++)
      rx(i) = &(*rx(i) - (*rx(i))(min));
  } else if(method == "most") {
    // Bias is the most popular value in waveform
    for(i = 1; i <= wf.count; i++) {
      rx(i) = &(*rx(i) - (*rx(i))(min) + 1);
      hist = histogram(long(*rx(i)+0.5));
      np = min(lim, numberof(hist));
      rx(i) = &(*rx(i) - hist(:np)(mxx));
    }
  }

  save, wf, noop(which), rx;
  return wf;
}
