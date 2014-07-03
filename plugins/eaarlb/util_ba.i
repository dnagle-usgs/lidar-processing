// vim: set ts=2 sts=2 sw=2 ai sr et:

func eaarl_ba_bback_ratio(data, ubound=) {
/* DOCUMENT eaarl_ba_bback_ratio(data, ubound=)
  DATA must be an array with fields east, north, bback1, and bback2. Returns
  [east, north, ratio] where east and north are in meters and ratio is
  bback1/bback2. Points where bback2 == 0 are excluded. Points where ratio >
  ubound are excluded. By default, ubound = 50.
*/
  default, ubound, 50;
  local x, y;

  w = where(data.bback2 > 0);
  data = data(w);

  ratio = data.bback1 / data.bback2;

  w = where(ratio <= ubound);
  ratio = ratio(w);
  data = data(w);

  data2xyz, data, x, y;
  return [x, y, ratio];
}
