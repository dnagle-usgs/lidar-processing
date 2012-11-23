
// These functions read and plot FMRI reefs in the FL Keys.

struct FMRI_REEFS {
  string code;	// Site Code
  string type;	// Type
  string name;	// Site Name	
  long segment;	// Segment
  double long;	// Longitude
  double lat;	// Latitude
  string station;	// Station
  string depth;	// Depth (ft)
  string date;	// Date Installed
  string ref;	// Reference
}
   
func read_fmri_reefs(fname) {
 /* DOCUMENT read_fmri_reefs(fname)
   amar nayegandhi 07/10/04
*/

  if (!fname) fname = "/home/amar/eaarl_stuff/04_jul_drto_eaarl/sitelist_update_2004.txt";
  f = open(fname, "r");

  reefs = array(FMRI_REEFS, 10000);

  i = 0;
  nc = 0; //null line counter
  gc = 0;
  loop = 1;

  while (loop) {
   i++;
   if (nc > 50) break;  // if 50 null lines are encountered
   a = rdline(f)(1);
   if (strlen(a) == 0)
 	nc++;  // null counter
   else
	nc = 0;

   w = array(string, 10);
   if ((a > "") && !(strmatch(a,"#"))) {
	a1 = a;
	s = pointer(a);
	tabs = where(*s == '\t');
	for (i=1; i<= numberof(tabs); i++) {
	   ww = (strtok(a1,"\t"));
	   w(i) = ww(1);
	   a1 = ww(2);
        }
	if (strlen(w(1)) == 0) continue;
	if (strlen(w(1)) == 3) {
	   gc++;
	   reefs(gc).code = w(1);
	   reefs(gc).type = w(2);
	   reefs(gc).name = w(3);
	   seg = 0;
	   sread, w(4), seg;
	   reefs(gc).segment = seg;
  	   degs = mins = 0.0;
	   sread, w(5), degs, mins;
	   reefs(gc).long = -1*(degs+mins/60.);
	   sread, w(6), degs, mins;
	   reefs(gc).lat = degs+mins/60.;
	   reefs(gc).station = w(7);
	   reefs(gc).depth = w(8);
	   reefs(gc).date = w(9);
	   reefs(gc).ref = w(10);
 	} else {
	   gc++;
	   seg = 0;
  	   degs = mins = 0.0;
	   sread, w(1), degs, mins;
	   reefs(gc).long = -1.*(degs+mins/60.);
	   sread, w(2), degs, mins;
	   reefs(gc).lat = degs+mins/60.;
	   reefs(gc).station = w(3);
	   reefs(gc).depth = w(4);
	   reefs(gc).date = w(5);
 	}
   }
  }
  reefs = reefs(1:gc);
  return reefs;
 }

func plot_fmri_reefs(reefs, win=, utm=, fma=, mode=, marker=, width=, msize=, color=) {
/* DOCUMENT plot_fmri_reefs(reefs, win=, utm=, fma=, mode=) 
   amar nayegandhi 07/11/04.
   mode = 0	Plots only reef location

   mode > 0 	Plots reef locations AND:
   mode = 1	Plot reef names
   mode = 2	Plot reef code
   mode = 3	Plot reef segment
   mode = 4 	Plot reef station
   mode = 5	Plot reef depth
   mode = 6	Plot reef date
   mode = 7 	Plot reef reference
*/

  if (is_void(marker)) marker=2;
  if (is_void(msize)) msize=0.5;
  if (is_void(color)) color="red";
  if (is_void(win)) win=6;
  if (is_void(mode)) mode = 0;
  window, win; 
  if (!is_void(fma)) fma = 1;
  // plot location of key marathon
  plmk, 24.72405378, -81.05439423, marker=5, color="yellow", msize=msize, width=width;

  plmk, reefs.lat, reefs.long, marker=marker, msize=msize, color=color, width=width;
  if (mode > 0) {
    plt, "Key Marathon", -81.05439423,  24.72405378, tosys=1, color="yellow";
    for (i=1;i<=numberof(reefs);i++) {
 	if (is_void(reefs.name)) continue;
	if (mode == 1) plt, reefs(i).name, reefs(i).long, reefs(i).lat, tosys=1, color=color;
	if (mode == 2) plt, reefs(i).code, reefs(i).long, reefs(i).lat, tosys=1, color=color;
	if (mode == 3) plt, reefs(i).segment, reefs(i).long, reefs(i).lat, tosys=1, color=color;
	if (mode == 4) plt, reefs(i).station, reefs(i).long, reefs(i).lat, tosys=1, color=color;
	if (mode == 5) plt, reefs(i).depth, reefs(i).long, reefs(i).lat, tosys=1, color=color;
	if (mode == 6) plt, reefs(i).date, reefs(i).long, reefs(i).lat, tosys=1, color=color;
	if (mode == 7) plt, reefs(i).ref, reefs(i).long, reefs(i).lat, tosys=1, color=color;
    }
  }

}

func read_drto_polygon(fname) {
 // amar nayegandhi 07/11/04
 
 if (!fname) fname = "/home/amar/eaarl_stuff/04_jul_drto_eaarl/20m_bathy_DRTO.txt"

 f = open(fname, "r");
 drto = array(double, 2, 1684);
 // i know there are 1684 lines in the file.
 for (i=1;i<=1684;i++) {
   read, f, drto(1,i,), drto(2,i);
 }
 close, f;
 return drto
}


func plot_sambo_rgn(sambo) {
 // amar nayegandhi 07/12/04
 
 if (!sambo) {
   sambo = array(double, 2, 5);
   sambo(,1) = [-81.764,24.523]
   sambo(,2) = [-81.753,24.458]
   sambo(,3) = [-81.611,24.483]
   sambo(,4) = [-81.622,24.548]
   sambo(,5) = [-81.764,24.523]
 }

 plg, sambo(2,), sambo(1,), width=3.5, color="blue"
}


func plot_all_sites(win=) {
 // amar nayegandhi 07/12/04
 // this function plots all sites for the 04 DRTO mission

 extern reefs, drto, sambo, wdrcr, acropora
 f = openb("/home/amar/eaarl_stuff/04_jul_drto_eaarl/site_locations_all_071604.pbd");
 restore, f;
 close, f;
 
 //winkill, 6;
 //window, 6, dpi=100, style="landscape11x85.gs", width=1100, height=850;
 load_map, color="black", ffn="/home/amar/lidar-processing/maps/fla.pbd", utm=0; 
 limits, square=1;
 limits;
 plot_fmri_reefs, reefs, win=6, mode=1, width=10;
 plot_fmri_reefs, acropora, win=6, mode=1, color="cyan", width=10, marker=5;
 plmk, drto(2,), drto(1,), color="green", marker=1, msize=0.1;
 plmk, wdrcr(2,), wdrcr(1,), marker=3, width=10, msize=0.5, color="blue";
 plg, sambo(2,), sambo(1,), width=3.5, color="magenta";
 //pltitle, "DRTO Mission Planning -- All Site Locations";
 pltitle, "08-01-04 EAARL Flight Lines"
 xytitles, "Longitude (deg)", "Latitude (deg)";
 
 plt, "Legend:", 0.65, 0.22, tosys=0;
 plt, "Red Symbol: FMRI Reefs", 0.65,0.2, tosys=0, color="red";
 plt, "Blue: EAARL Flight Lines", 0.65, 0.18, tosys=0, color="blue";
 plt, "Green: DRTO Polygon", 0.65, 0.16, tosys=0, color="green";
 plt, "Magenta: Sambo Polygon", 0.65, 0.14, tosys=0, color="magenta";
 plt, "Cyan: Acropora Palmata", 0.65, 0.12, tosys=0, color="cyan";
 plt, "Yellow: Key Marathon", 0.65, 0.10, tosys=0, color="yellow";
}
 
