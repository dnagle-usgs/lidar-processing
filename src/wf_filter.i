// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

// The functions in this file are used to filter waveforms or wfobj objects,
// either by returning a subset of the data or by modifying the data in some
// way.

func wfobj_filter_bias(wf, which=, method=, lim=) {
/* DOCUMENT wf = wfobj_filter_bias(wf, which=, method=, lim=)
  Modifies the waveforms in the given wfobj object WF to remove bias. WF should
  be a waveform object. WHICH specifies which waveform to modify and is usually
  "rx" but can also be "tx". METHOD specifies the method to use for determining
  the bias. See wf_filter_bias for details on METHOD.

  Note: This does not do any type conversions. If your wavesforms are of type
  CHAR, you should cast them to SHORT prior to passing it to this function.
*/
  default, which, "rx";
  default, method, "first";
  default, lim, 1e1000;
  if(!am_subroutine())
    wf = wf(index, 1:wf.count);

  // Use rx to store the waveforms, which are usually rx
  rx = wf(noop(which));

  for(i = 1; i <= wf.count; i++)
    rx(i) = &wf_filter_bias(*rx(i), method=method, lim=lim);

  save, wf, noop(which), rx;
  return wf;
}

func wf_filter_bias(wf, method=, lim=) {
/* DOCUMENT wf = wf_filter_bias(wf, which=, method=, lim=)
  Modifies the waveform WF to remove bias. WF should be an array of intensity
  values. METHOD specifies the method to use for determining the bias. Methods
  available:

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

  Note: This does not do any type conversions. If your wavesform is of type
  CHAR, you should cast it to SHORT prior to passing it to this function.
*/
  default, method, "first";
  default, lim, 1e1000;

  if(method == "first") {
    return wf_filter_bias_first(wf);
  } else if(method == "min") {
    return wf_filter_bias_min(wf);
  } else if(method == "most") {
    return wf_filter_bias_most(wf, lim=lim);
  } else {
    return wf;
  }
}

func wf_filter_bias_first(wf) {
/* DOCUMENT newwf = wf_filter_bias_first(wf)
  Returns a modified waveform with the bias removed. The bias is defined as the
  value of the first sample.

  Note: This does not do any type conversions. If your WF is type CHAR, you
  should cast it to SHORT prior to passing it to this function.
*/
  return numberof(wf) ? wf - wf(1) : [];
}

func wf_filter_bias_min(wf) {
/* DOCUMENT newwf = wf_filter_bias_min(wf)
  Returns a modified waveform with the bias removed. The bias is defined as the
  minimum sample value.

  Note: This does not do any type conversions. If your WF is type CHAR, you
  should cast it to SHORT prior to passing it to this function.
*/
  return numberof(wf) ? wf - wf(min) : [];
}

func wf_filter_bias_most(wf, lim=) {
/* DOCUMENT newwf = wf_filter_bias_most(wf, lim=)
  Returns a modified waveform with the bias removed. The most frequent value
  in the waveform is used as the bias. If multiple values are tied, then the
  first such value is used. Option LIM can be provided to limit the range of
  values considered. That is, if the minimum value in a waveform is 2 and
  lim=3, then only values 2 through 4 are considered when determining the bias.
  This method works best when the waveforms are integers; if they are floats,
  then samples will be temporarily rounded to the nearest integer for purposes
  of determining the bias.

  Note: This does not do any type conversions. If your WF is type CHAR, you
  should cast it to SHORT prior to passing it to this function.
*/
  if(!numberof(wf)) return [];
  wf = wf - wf(min) + 1;
  hist = histogram(long(wf+0.5));
  np = lim ? min(lim, numberof(hist)) : numberof(hist);
  return wf - hist(:np)(mxx);
}
