// vim: set ts=2 sts=2 sw=2 ai sr et:

func eaarl_mp_extract_returns(data, low=, high=, idx=) {
/* DOCUMENT eaarl_mp_extract_returns(data, low=, high=, idx=)
  Returns the points from DATA where the return falls in the range defined by
  LOW and/or HIGH.

  LOW and HIGH each define a return number threshold. LOW defines the lowest
  return that passes and HIGH defines the lowest return the passes. The return
  number is treated in much the same way as Yorick index values: if it is
  positive, it's a direct return number; if it's zero or negative, then it's
  treated with respect to num_rets.

  Some examples to illustrate:

  Grab all first returns:
    fr = eaarl_mp_extract_returns(data, high=1)

  Grab all last returns:
    lr = eaarl_mp_extract_returns(data, low=0)

  Grab all mid returns (returns that are neither first nor last):
    mr = eaarl_mp_extract_returns(data, low=2, high=-1)

  Grab all points that are a 3rd return:
    mr = eaarl_mp_extract_returns(data, low=3, high=3)

  If you omit LOW or HIGH, then the returns are not restricted on the omitted
  field's basis. This is functionally equivalent to having a default of low=1
  and high=0.

  If you specify idx=1, then an index list will be returned instead of the
  relevant data.
*/
  keep = array(1, numberof(data));
  ret_num = short(data.ret_num);
  num_rets = short(data.num_rets);

  if(!is_void(low)) {
    if(low > 0) {
      w = where(ret_num < low);
    } else {
      w = where(ret_num - num_rets < low);
    }
    if(numberof(w)) keep(w) = 0;
  }

  if(!is_void(high)) {
    if(high > 0) {
      w = where(ret_num > high);
    } else {
      w = where(ret_num - num_rets > high);
    }
    if(numberof(w)) keep(w) = 0;
  }

  if(idx) return where(keep);
  return data(where(keep));
}
