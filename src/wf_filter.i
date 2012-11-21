// vim: set ts=2 sts=2 sw=2 ai sr et:

// The functions in this file are used to filter waveforms, either by returning
// a subset of the data or by modifying the data in some way.

func wf_filter_bias(wf, &bias, method=, lim=) {
/* DOCUMENT wf = wf_filter_bias(wf, &bias, which=, method=, lim=)
  Modifies the waveform WF to remove bias. WF should be an array of intensity
  values. METHOD specifies the method to use for determining the bias. BIAS is
  an output parameter that will be set to the bias removed. Methods
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
    return wf_filter_bias_first(wf, bias);
  } else if(method == "min") {
    return wf_filter_bias_min(wf, bias);
  } else if(method == "most") {
    return wf_filter_bias_most(wf, bias, lim=lim);
  } else {
    bias = 0;
    return wf;
  }
}

func wf_filter_bias_first(wf, &bias) {
/* DOCUMENT newwf = wf_filter_bias_first(wf, &bias)
  Returns a modified waveform with the bias removed. The bias is defined as the
  value of the first sample and is stored in BIAS.

  Note: This does not do any type conversions. If your WF is type CHAR, you
  should cast it to SHORT prior to passing it to this function.
*/
  if(numberof(wf)) {
    bias = wf(1);
    return wf - bias;
  } else {
    bias = 0;
    return [];
  }
}

func wf_filter_bias_min(wf, &bias) {
/* DOCUMENT newwf = wf_filter_bias_min(wf, &bias)
  Returns a modified waveform with the bias removed. The bias is defined as the
  minimum sample value and is stored in BIAS.

  Note: This does not do any type conversions. If your WF is type CHAR, you
  should cast it to SHORT prior to passing it to this function.
*/
  if(numberof(wf)) {
    bias = wf(min);
    return wf - bias;
  } else {
    bias = 0;
    return [];
  }
}

func wf_filter_bias_most(wf, &bias, lim=) {
/* DOCUMENT newwf = wf_filter_bias_most(wf, &bias, lim=)
  Returns a modified waveform with the bias removed. The most frequent value
  in the waveform is used as the bias and is stored in BIAS. If multiple values
  are tied, then the first such value is used. Option LIM can be provided to
  limit the range of values considered. That is, if the minimum value in a
  waveform is 2 and lim=3, then only values 2 through 4 are considered when
  determining the bias.  This method works best when the waveforms are
  integers; if they are floats, then samples will be temporarily rounded to the
  nearest integer for purposes of determining the bias.

  Note: This does not do any type conversions. If your WF is type CHAR, you
  should cast it to SHORT prior to passing it to this function.
*/
  bias = 0;
  if(!numberof(wf)) return [];
  wf = wf - wf(min) + 1;
  hist = histogram(long(wf+0.5));
  np = lim ? min(lim, numberof(hist)) : numberof(hist);
  bias = hist(:np)(mxx);
  return wf - bias;
}
