// width and height is in window pixels;
func write_gs ( width=, height=, xoff=, yoff=, box= ) {

  landscape=( width>height );

  default, xoff, .06;
  default, yoff, .06;
  default, box, 0;

  xmx  = width  * .00125;
  ymx  = height * .00125;

  gist_gpbox, xmx, ymx;

//if ( landscape ) {
//  n = set_gist_gpbox(1, 0, ymx, 0, xmx);
//  n = set_gist_gpbox(2, 0, xmx, 0, ymx);
//} else {
//  n = set_gist_gpbox(1, 0, xmx, 0, ymx);
//  n = set_gist_gpbox(2, 0, xmx, 0, ymx);
//}

  user = get_user();
  path=swrite(format="/tmp/gist/%s", user);
  if ( ! file_isdir(path) ) mkdir, path;

  sfname=swrite(format="%s/%04dx%04d.gs", path, width, height);

  f = open(sfname, "w");
  n = write(f, format="landscape=%d\n\n", landscape);
  n = write(f, format="%s", "default = {\n");
  n = write(f, format="%s", "  legend=0,\n");
  n = write(f, format="  viewport={ %lf, %lf, %lf, %lf},\n",xoff, xmx-xoff, yoff, ymx-yoff );

  n = write(f, format="%s", "  ticks= {\n");

  n = write(f, format="%s", "    horiz= {\n");
  n = write(f, format="%s", "      nMajor= 7.5,  nMinor= 50.0,  logAdjMajor= 1.2,  logAdjMinor= 1.2,\n");
  n = write(f, format="%s", "      nDigits= 12,  gridLevel= 1,  flags= 0x033,\n");
  n = write(f, format="%s", "      tickOff= 0.0007,  labelOff= 0.0182,\n");
  n = write(f, format="%s", "      tickLen= { 0.01, 0.0091, 0.0052, 0.0026, 0.0013 },\n");
  n = write(f, format="%s", "      tickStyle= { color= -2,  type= 1,  width= 1.0 },\n");
  n = write(f, format="%s", "      gridStyle= { color= -2,  type= 3,  width= 1.0 },\n");
  n = write(f, format="%s", "      textStyle= { color= -2,  font= 0x08,  height= 0.015,\n");
  n = write(f, format="%s", "        orient= 0,  alignH= 0,  alignV= 0,  opaque= 0 },\n");
  n = write(f, format="%s", "      xOver= 0.395,  yOver= 0.03 },\n");

  n = write(f, format="%s", "    vert= {\n");
  n = write(f, format="%s", "      nMajor= 7.5,  nMinor= 50.0,  logAdjMajor= 1.2,  logAdjMinor= 1.2,\n");
  n = write(f, format="%s", "      nDigits= 12,  gridLevel= 1,  flags= 0x033,\n");
  n = write(f, format="%s", "      tickOff= 0.0007,  labelOff= 0.0182,\n");
  n = write(f, format="%s", "      tickLen= { 0.0123, 0.0091, 0.0052, 0.0026, 0.0013 },\n");
  n = write(f, format="%s", "      tickStyle= { color= -2,  type= 1,  width= 1.0 },\n");
  n = write(f, format="%s", "      gridStyle= { color= -2,  type= 3,  width= 1.0 },\n");
  n = write(f, format="%s", "      textStyle= { color= -2,  font= 0x08,  height= 0.015,\n");
  n = write(f, format="%s", "        orient= 0,  alignH= 0,  alignV= 0,  opaque= 0 },\n");
  n = write(f, format="%s", "      xOver= 0.001,  yOver= 0.03 },\n");

  n = write(f, format="%s %d\n", "    frame= ", box);
  n = write(f, format="%s", "    frameStyle= { color= -2,  type= 1,  width= 1.0 }}}\n");

  n = write(f, format="%s", "\nsystem= { legend= \"System 0\" }\n");

  n = write(f, format="%s", "\nlegends= {\n");
  n = write(f, format="%s", "  x= 0.04698,  y= 0.360,  dx= 0.3758,  dy= 0.0,\n");
  n = write(f, format="%s", "  textStyle= { color= -2,  font= 0x00,  height= 0.0156,\n");
  n = write(f, format="%s", "    orient= 0,  alignH= 1,  alignV= 1,  opaque= 0 },\n");
  n = write(f, format="%s", "  nchars= 36,  nlines= 20,  nwrap= 2 }\n");

  n = write(f, format="%s", "\nclegends= {\n");
  n = write(f, format="%s", "  x= 0.6182,  y= 0.8643,  dx= 0.0,  dy= 0.0,\n");
  n = write(f, format="%s", "  textStyle= { color= -2,  font= 0x00,  height= 0.0156,\n");
  n = write(f, format="%s", "    orient= 0,  alignH= 1,  alignV= 1,  opaque= 0 },\n");
  n = write(f, format="%s", "  nchars= 14,  nlines= 28,  nwrap= 1 }\n");

  close,f;

  return  sfname;
}

func mkwin( win, width=, height=, xoff=, yoff=, dpi=, box= ) {

  default, dpi,     75;
  default, killme,   1;
  default, reset_me, 1;

  local wdata;

  if( window_exists(win)) {
    window, win;     // XYZZY - looks like save_plot only saves the current window, rwm
    wdata = save_plot(win);
  }

  gs = write_gs(width=width, height=height, xoff=xoff, yoff=yoff, box=box);
  if ( debug ) gist_gpbox(1);
  if ( killme ) winkill, win;

//ytk_window, win, dpi=dpi, width=width, height=height, keeptk=1, style=gs, mkwin=1;
  ytk_window, win,          width=width, height=height, keeptk=1, style=gs, mkwin=1;

  tkcmd, swrite(format=".yorwin%d configure -width  %d", win, width );
  tkcmd, swrite(format=".yorwin%d configure -height %d", win, height+23 );

  systems = (sys0 ? [0,1] : [1]);
  if(!is_void(wdata))
    load_plot, wdata, win, style=0, systems=systems;

  if ( reset_me )  reset_gist;
}

func reset_gist {
  gist_gpbox, 0.798584, 1.033461;
}
