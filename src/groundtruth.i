/*
  $Id$
  Convert a PNAV to FS.  Used when reading a ground truth
  gtpnav file and then displaying it with lidar data
  A check should probably be done to make sure curzone is set.
  The "Process EAARL Data" window must also be open or FS isn't
  available.
*/
func pnav2fs(pn) {

  retarr = 1;
  x   = ll2utm( pn.lat, pn.lon, force_zone=curzone );
  xyz = [ x(,1), x(,2), pn.alt ];
  gd  = transpose(xyz);

  N   = numberof(gd(1,));
  fs  = array(FS,N);
  fs.east      = long(gd(1,) * 100. );
  fs.north     = long(gd(2,) * 100. );
  fs.elevation = long(gd(3,) * 100. );

  return(fs);

}
