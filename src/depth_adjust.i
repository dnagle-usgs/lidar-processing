
func depth_adjust(&data, m, b) {
/* DOCUMENT depth_adjust, data, m, b
  -or- result = depth_adjust(data, m, b)

  Applies a linear adjustment to the depth in the given data array. The depth
  will be adjusted as such:

    znew = m * z + b

  where m and b are provided and z is the original depth in meters. Depth
  values are negative: 1 meter below the surface is -1.
*/
  local x, y, z;
  data2xyz, data, x, y, z, mode="depth";

  z = m * z + b;

  // avoid having depths go above the surface
  w = where(z > 0);
  if(numberof(w)) z(w) = 0;

  result = data;
  xyz2data, x, y, z, result, mode="depth";
  if(am_subroutine()) data = result;
  else return result;
}
