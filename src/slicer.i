// vim: set ts=2 sts=2 sw=2 ai sr et:

/*
  Original: Richard Mitchell 2009-03
*/

func slicer(data, loop=, cmin=, cmax=, hgt=, mmin=) {
/* DOCUMENT slicer(data, loop=, cmin=, cmax=, hgt=, mmin=)
  Displays a movie plotting the data at successively lower elevations.

  data      : variable to plot
  loop=     : number of levels to display
  cmin=     :
  cmax=     :
  hgt=      : elevation amount to change between each loop.
  mmin=     : instead of loop, specify the minimum cmin to plot.

  Note:  The number of actual loops that gets completed seems to be dependent on the
       size of the data and amount of memory.
*/
  require, "movie.i";

  if ( is_void(data  ) ) {
    write,"Please supply a variable to plot\n";
    return(0);
  }
  if ( is_void(loop ) ) loop=16;
  if ( is_void(cmin ) ) cmin= 5.0;
  if ( is_void(cmax ) ) cmax=10.0;
  if ( is_void(hgt  ) ) hgt=2;

  limits;
  shrink;
  movie, slicer_d;

}

func slicer_d(i) {
  if ( i==1 ) {
    extern cn, cx;
    cx = cmax;
    cn = cmin;
  }
  write, format="%2d: cmin=%f  cmax=%f\n", i, cn, cx;
  display_data, data, win=5, cmin=cn, cmax=cx, mode="fs";
  cx = cx-hgt;
  cn = cn-hgt;
  // pause,40;
  if( !is_void(mmin) )
    ret = mmin <= cn;
  else
    ret = i<loop;
  return ret;
}

func shrink( void ) {
/* DOCUMENT shrink()
  shrinks the plot window just a little.  This helps to keep the
  entire image from blanking to adjust the coordinates when running
  slicer.
*/
  limits;
  l=limits();
  l;
  // these values were determined using sby with UTM.
  l(1) = l(1) * 0.9998;
  l(2) = l(2) * 1.00008;
  l(3) = l(3) * 0.99999;
  l(4) = l(4) * 1.00001;
  l(1:4);
  limits,l(1), l(2), l(3), l(4);
}

// Both getll() and getPolyll() should probably be in a different file

func getll( void, win= ) {
/* DOCUMENT getPolyll( win= )
  Displays the point selected using as lat/lon.
  This assumes the window is in UTM.
  The returned value can be pasted into Google Earth

  win=   specify window to get point
*/
  owin = window();

  if ( !is_void(win) )
    window,win;

  m=mouse(,,"Click point to display lat/lon value");
  ll = utm2ll(m(2), m(1), curzone);
  write, format="%f %f\n", ll(2), ll(1);

  if ( !is_void(win) )
    window,owin;
}

func getPolyll( void ) {
/* DOCUMENT getPolyll()
  Displays points selected using getPoly as lat/lon.
  This assumes the window is in UTM.
*/
  ply=getPoly();
  str="";
  for(i=1; i<=numberof(ply); i+=2) {
    ll = utm2ll(ply(i+1), ply(i+0), curzone );
    str=swrite(format="%s%f, %f\n", str, ll(2), ll(1));
  }
  write, format="%s", str;
  return(str);
}
