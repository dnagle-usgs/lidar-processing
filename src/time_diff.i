/*

 $Id$

time_diff.i

********************************************************************************

The purpose of this routine is to determine the number of seconds between
two points on a plot of .alt vs .sod, as in:
	plmk, pnav.alt, pnav.sod, msize=.1, marker=4

********************************************************************************

*/

write, "$Id$"

extern data_path;

func time_plot( foo ) {
/* DOCUMENT time_plot( foo )
   Plots alt vs sod
*/
  window,4; fma
  plmk, pnav.alt, pnav.sod, msize=.1, marker=4
  limits
}

func time_diff( foo ) {
/* DOCUMENT  time_diff( foo )
   Computes time and cost for a flight
*/

  t = array(double, 2)
  t(1) = mouse()(1);
  t(2) = mouse()(1);
  dec_hr = ( (t(2)-t(1)) / 3600.0 )
  cost = dec_hr * 2000.0
  write,    format="Mission:  %s\n", data_path
  write,    format="Hours:    %9.4f\nCost:     %8.3f\n",   dec_hr, cost
  f = open("/tmp/ALPS_FlightTime.txt", "a")
  write, f, format="Mission:  %s\n", data_path
  write, f, format="Hours:    %9.4f\nCost:     %8.3f\n\n", dec_hr, cost
  close,f
}
