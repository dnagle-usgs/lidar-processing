// vim: set ts=2 sts=2 sw=2 ai sr et:

func rcf_classify(data, class, select=, rcfmode=, buf=, w=, n=) {
/* DOCUMENT rcf_classify, data, class, select=, rcfmode=, buf=, w=, n=
  Classify data using an RCF filter.

  Parameters:
    data: A pcobj object.

    class: The classification string to apply to the found points.

  Options:
    select= A class query to use to only apply RCF filter to subset of
      points. Example:
        select="first_return"      Only filter first returns

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 500 cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 30 cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.
*/
  local x, y, z, keep;
  default, rcfmode, "grcf";
  default, buf, 500;
  default, w, 30;
  default, n, 3;
  default, idx, 0;

  consider = (is_void(select) ? indgen(data(count,)) :
    data(class, where, select));
  if(!numberof(consider))
    return;

  splitary, data(xyz,consider), 3, x, y, z;
  buf *= .01;
  w *= .01;

  if(rcfmode == "grcf")
    keep = gridded_rcf(unref(x), unref(y), unref(z), w, buf, n);
  else if(rcfmode == "rcf")
    keep = old_gridded_rcf(unref(x), unref(y), unref(z), w, buf, n);
  else
    error, "Please specify a valid rcfmode=.";

  if(numberof(keep))
    data, class, apply, class, consider(keep);
}
