
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
  window, win; 
  if (!is_void(fma)) fma = 1;
  // plot location of key marathon
  plmk, 24.72405378, -81.05439423, marker=5, color="blue", msize=msize, width=width;

  plmk, reefs.lat, reefs.long, marker=marker, msize=msize, color=color, width=width;
  if (mode > 0) {
    plt, "Key Marathon", -81.05439423,  24.72405378, tosys=1, color="blue";
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

