// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_interp_angles(ang, i, ip, rad=) {
/* DOCUMENT interp_angles(ang, i, ip, rad=)

  This performs linear interpolation on a sequence of angles. This is designed
  to accept arguments similar to interp. It circumvents problems at the
  boundaries of the cycle by breaking the angle into its component pieces
  (using trigonometric functions).
  
  Parameters:
    ang: The known angles around which to interpolate.
    i: The reference values corresponding to the known values. Must be
      strictly monotonic.
    ip: The reference values for which you want to interpolate values.

  Options:
    rad= Set to 1 if the angles are in radians. By default, this assumes
      degrees.
*/
// If you change this documentation, be sure to also change the documentation
// in calps.i.

  default, rad, 0;

  // Eliminates errors for scalars and simplifies handling of multi-dim arrays
  dims = dimsof(ip);
  ip = ip(*);

  angp = array(double, numberof(ip));

  // Trigonometric functions are expensive. Rather than converting ALL of
  // angles back and forth, we can save a lot of time by only converting the
  // range of values that we'll actually need for interpolation.
  minidx = max(1, digitize(ip(min), i) - 1);
  maxidx = min(numberof(i), digitize(ip(max), i) + 1);
  ang = ang(minidx:maxidx);
  i = i(minidx:maxidx);

  if(!rad) ang *= DEG2RAD;

  // Use C-ALPS helper if available
  if(is_func(_yinterp_angles)) {
    ib = digitize(ip, i);
    _yinterp_angles, i, ang, numberof(i),
      ip, angp, ib, numberof(ip);
  } else {
    x = cos(ang);
    y = sin(ang);

    xp = interp(x, i, ip);
    yp = interp(y, i, ip);

    angp = atan(yp, xp);
  }

  if(!rad) angp *= RAD2DEG;

  return dims(1) ? reform(angp, dims) : angp(1);
}

if(!is_func(interp_angles)) interp_angles = nocalps_interp_angles;
