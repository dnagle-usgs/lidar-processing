// width and height is in window pixels;
func write_gs(width=, height=, xoff=, yoff=, box=, ticks=) {
/* DOCUMENT fn = write_gs(width=, height=, xoff=, yoff=, box=, ticks=)
   Createa a .gs file in /tmp/gist/USER with the name
   WIDTHxHEIGHT.gs.

   This is invoked by mkwin() and does not need to be called directly.

   You can modify the tick marks by setting "ticks" as described:

   Ticks flags (add together the ones you want):
     0x001  Draw ticks on bottom or left edge of viewport
     0x002  Draw ticks on top or right edge of viewport
     0x004  Draw ticks centered on origin in middle of viewport
     0x008  Ticks project inward into viewport
     0x010  Ticks project outward away from viewport (0x18 for both)
     0x020  Draw tick label numbers on bottom or left edge of viewport
     0x040  Draw tick label numbers on top or right edge of viewport
     0x080  Draw all grid lines down to gridLevel
     0x100  Draw single grid line at origin

   nMajor and nMinor can be set to control the tick spacing.
   default values are 4.0 and 40.0

  Return value is the name of the file created.

  SEE ALSO: mkwin, reset_gist
*/

  landscape=( width>height );

  default, xoff, .06;
  default, yoff, .06;
  default, box, 0;
  default, ticks, 0x033;
  default, nMajor,  4.0;
  default, nMinor, 40.0;

  nMajor = double(nMajor);
  nMinor = double(nMinor);
  xoff = double(xoff);
  yoff = double(yoff);

  /* The Yorick documentation claims .0013 is the correct value to convert to NDC
     units, but that value the causes x/yoff values to need to be scaled up as the
     window size increases.  This does not happen if .00125 is used.
  */
  xmx  = width  * .00125;
  ymx  = height * .00125;

  gist_gpbox, xmx, ymx;

  path = file_join(alpsrc.temp_dir, "gist", get_user());
  mkdirp, path;

  sfname=swrite(format="%s/%04dx%04d.gs", path, width, height);

  // This is a work-around to Yorick's broken write where format must specify at least
  // one % field.  To be consistent across all the lines, chose that to be the newline.
  local NL;
  NL="\n";

  f = open(sfname, "w");
  write, f, format="landscape=%d%s%s", landscape, NL, NL;
  write, f, format="default = {%s", NL;
  write, f, format="  legend=0,%s", NL;
  write, f, format="  viewport={ %lf, %lf, %lf, %lf },%s",xoff, xmx-xoff, yoff, ymx-yoff, NL ;

  write, f, format="  ticks= {%s", NL;

  write, f, format="    horiz= {%s", NL;
  write, f, format="      nMajor= %lf,  nMinor= %lf,  logAdjMajor= 1.2,  logAdjMinor= 1.2,%s", nMajor, nMinor, NL;
  write, f, format="      nDigits= 12,  gridLevel= 1,  flags= 0x%03x,%s", ticks, NL; // 0x06b to have inward pointing ticks.
  write, f, format="      tickOff= 0.0007,  labelOff= 0.0182,%s", NL;
  write, f, format="      tickLen= { 0.01, 0.0091, 0.0052, 0.0026, 0.0013 },%s", NL;
  write, f, format="      tickStyle= { color= -2,  type= 1,  width= 1.0 },%s", NL;
  write, f, format="      gridStyle= { color= -2,  type= 3,  width= 1.0 },%s", NL;
  write, f, format="      textStyle= { color= -2,  font= 0x08,  height= 0.015,%s", NL;
  write, f, format="        orient= 0,  alignH= 0,  alignV= 0,  opaque= 0 },%s", NL;
  write, f, format="        xOver= 0.395,  yOver= 0.03 },%s", NL;

  write, f, format="    vert= {%s", NL;
  write, f, format="      nMajor= %lf,  nMinor= %lf,  logAdjMajor= 1.2,  logAdjMinor= 1.2,%s", nMajor, nMinor, NL;
  write, f, format="      nDigits= 12,  gridLevel= 1,  flags= 0x%03x,%s", ticks, NL; // 0x06b to have inward pointing ticks.
  write, f, format="      tickOff= 0.0007,  labelOff= 0.0182,%s", NL;
  write, f, format="      tickLen= { 0.0123, 0.0091, 0.0052, 0.0026, 0.0013 },%s", NL;
  write, f, format="      tickStyle= { color= -2,  type= 1,  width= 1.0 },%s", NL;
  write, f, format="      gridStyle= { color= -2,  type= 3,  width= 1.0 },%s", NL;
  write, f, format="      textStyle= { color= -2,  font= 0x08,  height= 0.015,%s", NL;
  write, f, format="        orient= 0,  alignH= 0,  alignV= 0,  opaque= 0 },%s", NL;
  write, f, format="        xOver= 0.001,  yOver= 0.03 },%s", NL;

  write, f, format="    frame= %d,%s", box, NL;
  write, f, format="    frameStyle= { color= -2,  type= 1,  width= 1.0 }}}%s", NL;

  write, f, format="%ssystem= { legend= \"System 0\" }%s", NL, NL;

  write, f, format="%slegends= {%s", NL, NL;
  write, f, format="  x= 0.04698,  y= 0.360,  dx= 0.3758,  dy= 0.0,%s", NL;
  write, f, format="  textStyle= { color= -2,  font= 0x00,  height= 0.0156,%s", NL;
  write, f, format="    orient= 0,  alignH= 1,  alignV= 1,  opaque= 0 },%s", NL;
  write, f, format="  nchars= 36,  nlines= 20,  nwrap= 2 }%s", NL;

  write, f, format="%sclegends= {%s", NL, NL;
  write, f, format="  x= 0.6182,  y= 0.8643,  dx= 0.0,  dy= 0.0,%s", NL;
  write, f, format="  textStyle= { color= -2,  font= 0x00,  height= 0.0156,%s", NL;
  write, f, format="    orient= 0,  alignH= 1,  alignV= 1,  opaque= 0 },%s", NL;
  write, f, format="  nchars= 14,  nlines= 28,  nwrap= 1 }%s", NL;

  close, f;

  return  sfname;
}

func mkwin(win, width, height, xoff=, yoff=, dpi=, box=, tk=, ticks=) {
/* DOCUMENT mkwin, win, width=, height=, xoff=, yoff=, dpi=, box=, tk=, ticks=

   Make a plot window of arbitrary size.  If the window already exists,
   it will be recreated at the specified size.

   box=[0|1]  : draw a box around the inside of the x/y axis ticks.

   xoff=      : modify the offset from the x axis.

   yoff=      : modify the offset from the y axis.
                The initial offset values for both x/y is .06.

   tk=        : Added when called by tk to adjust the window size
                for the toolbar

   Set the variable "BOX=1" to add a box around the plot when
   invoked from the GUI.

   Other Variables to enable/disable [0/1] test functionality:

   dpi        : default=75.  why would you want anything else?

   killme     : winkill the window before resizing. default=1

   reset_gs   : call reset_gists after resizing plot.  this allows
                the original GUI options to still work. default=1

   keep_gsfile: Keep the freshly created gs file.  It will be
                stored in /tmp/gist/USERNAME/WIDTHxHEIGHT.gs
                Enable this if issues with zooming/panning are
                discovered.  default=0.

   safe_resize: Don't allow window sizes to exceed 1646 pixels.
                this appears to be some magic value where if this
                value is exceeded, the right y-axis tick marks
                don't appear.  default=1

  SEE ALSO: write_gs, reset_gist
*/

  default, dpi,        75;
  default, killme,      1;  // 2014-07-14: these settings are to allow easy
  default, reset_gs,    1;  // toggling of functions if issues are discovered.
  default, keep_gsfile, 0;
  default, safe_resize, 1;  // don't allow unreasonable window sizes
  default, box,       BOX;

  local wdata;

  if( window_exists(win))
    wdata = save_plot(win);

  if ( tk ) height -= 23;

  if ( safe_resize ) {
    width = max(width,  100);   // don't want to be too small
    width = min(width, 1646);   // yorick quits plotting the right side beyond this

    height = max(height,  100);
    height = min(height, 1646);
  }
  if ( debug ) write, format="Window: %d  %04x%04x\n", win, width, height;

  gs = write_gs(width=width, height=height, xoff=xoff, yoff=yoff, box=box, ticks=ticks);

  if ( debug  ) gist_gpbox(1);
  if ( killme ) winkill, win;

//ytk_window, win, dpi=dpi, width=width, height=height, keeptk=1, style=gs, mkwin=1;
  ytk_window, win,          width=width, height=height, keeptk=1, style=gs, mkwin=1;

  tkcmd, swrite(format=".yorwin%d configure -width  %d -height %d", win, width, height+23 );

  systems = (sys0 ? [0,1] : [1]);
  if(!is_void(wdata))
    load_plot, wdata, win, style=0, systems=systems;

  if ( reset_gs    ) reset_gist;
  if ( !keep_gsfile ) remove, gs; // 2014-07-14: if this file isn't needed, change to use a standard tmpfile.
}

func reset_gist {
/* DOCUMENT reset_gist
  Resets the gist_gpbox values to their original default values.
  The gist_gpbox values may be changed from their original
  values by using mkwin.

  SEE ALSO: write_gs, mkwin
*/
  gist_gpbox, 0.798584, 1.033461;
}
