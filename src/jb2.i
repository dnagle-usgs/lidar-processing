/*
   $Id$
*/

require, "plcm.i"

write, "jb2.i as of 11/25/2001"

func load {
/* DOCUMENT load

   This function loads the mth-7-14-01.pbd data file into memory.  The
  data are stored in an array of "R" structures.  
  
Useful commands:

  R		Show data structure
  info,rrr	show information about the actual data array
  load		Reload the data from the file
  display,i,j   display rasters between i and j.  Both numbers must 
                be between 1 and 21000. See help, display for more options.
  fma           Clear screen.  Use this before issuing new display commands
  help,load     Display this help.
  mdist		Measure a distance on the screen between mouse press and release.
  pan           A pan command for windows-95/98/nt/2000/XP users.

 You can see the digital camera images beginning at record 15331 using the sf.tcl
 command.

*/
f = openb("/data/0/7-14-01/mth-7-14-01.pbd");
write,"Loading........"
restore,f
show,f
 winkill,0
 window,0,dpi=100
 limits,square=1
 limits, [496672,497374,2.73529e+06,2.736e+06,576]
 pltitle,"Marathon Fla 7-14-01  EAARL Preliminary"
 xytitles,, "UTM Northing (M)"
 redraw;
 help, load
}

func display(i,j, cmin=, cmax=, size= ) {
/* DOCUMENT display, i, j, cmin=, cmax=, size= 

   Display EAARL laser samples.
   i		Starting point.
   j            Stopping point.
   cmin=        Deepest point in meters ( -35 default )
   cmax=        Highest point in meters ( -15 )
   size=        Screen size of each point. Fiddle with this
                to get the filling-in like you want.

*/

write,format="Please wait while drawing..........%s", "\r"
 if ( is_void( cmin )) cmin = -35.0;
 if ( is_void( cmax )) cmax = -15.0;
 if ( is_void( size )) size = 1.4;
for ( ; i<j; i++ ) {
  plcm, rrr(i).elevation, rrr(i).north, rrr(i).east,
      msize=size,cmin=cmin, cmax=cmax
  }
write,format="Draw complete                         %s", "\n"
}

func pan {
/* DOCUMENT pan
   A pan function for those using windows.
*/
    lims = limits();
   cc = mouse(,2,"Click and drag to pan:");
    dx = cc(3) - cc(1); 
    dy = cc(4) - cc(2); 
    lims(1) -= dx;
    lims(2) -= dx;
    lims(3) -= dy;
    lims(4) -= dy;
    limits( lims );
}

func mdist {
   cc = mouse(,2,"Click and dragout a distance to measure:");
    dx = cc(3) - cc(1); 
    dy = cc(4) - cc(2); 
  dist = sqrt( dx^2 + dy^2);
  if ( dist > 1000.0 ) 
    write,format="Distance is %5.3f kilometers\n", dist/1000.0;
  else
    write,format="Distance is %5.3f meters\n", dist;
}

//load
//display(1, 2000);


