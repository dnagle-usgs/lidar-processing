/*
   $Id$

   Orginal by Amar Nayegandhi
   */

func sel_data_rgn(data, type, mode=,win=, exclude=) {
  /* DOCUMENT sel_data_rgn(data,type, mode=, win=)
  this function selects a region (limits(), rubberband, pip) and returns data within that region.
  // if mode = 1, limits() function is used to define the region.
  // if mode = 2, a rubberband box is used to define the region.
  // if mode = 3, the points-in-polygon technique is used to define the region.
  // type = type of data (R, FS, GEO, VEG_, etc.)
  // set exclude =1 if you want to exclude the selected region and return the rest of the data.
  //amar nayegandhi 11/26/02.
 */

  if (is_void(win)) win = 5;
  if (!mode) mode = 1;

  w = window();

  if (mode == 1) {
     window, win
     rgn = limits();
     //write, int(rgn*100);
  }

  if (mode == 2) {
     window, win;
     a = mouse(1,1,
     "Hold the left mouse button down, select a region:");
     rgn = array(float, 4);
     rgn(1) = min( [ a(1), a(3) ] );
     rgn(2) = max( [ a(1), a(3) ] );
     rgn(3) = min( [ a(2), a(4) ] );
     rgn(4) = max( [ a(2), a(4) ] );
     /* plot a window over selected region */
     a_x=[rgn(1), rgn(2), rgn(2), rgn(1), rgn(1)];
     a_y=[rgn(3), rgn(3), rgn(4), rgn(4), rgn(3)];
     plg, a_y, a_x;
     
     //write, int(rgn*100);
  }

  if ((mode==1) || (mode==2)) {
    q = where((data.east >= rgn(1)*100.)   & 
               (data.east <= rgn(2)*100.)) ;

    //write, numberof(q);
 
    indx = where(((data.north(q) >= rgn(3)*100) & 
               (data.north(q) <= rgn(4)*100)));

    //write, numberof(indx);

    indx = q(indx);
  }
     

  if (mode == 3) {
     window, win;
     ply = getPoly();
     box = boundBox(ply);
     box_pts = ptsInBox(box*100., data.east, data.north);
     poly_pts = testPoly(ply*100., data.east(box_pts), data.north(box_pts));
     indx = box_pts(poly_pts);
 }
 
 if (exclude) {
     iindx = array(int,numberof(data.rn));
     iindx(indx) = 1;
     indx = where(iindx == 0);
 }
    

 window, w;

 //a = [];
 //a = structof(data);
 a = type;
 if (a == R) {
   data_out = array(FS, numberof(indx));
   data_out.rn = data.rn(indx);
   data_out.mnorth = data.mnorth(indx);
   data_out.meast = data.meast(indx);
   data_out.melevation = data.melevation(indx);
   data_out.north = data.north(indx);
   data_out.east = data.east(indx);
   data_out.elevation = data.elevation(indx);
   data_out.intensity = data.intensity(indx);
 }
 if (a == FS)  data_out = data(indx);

 if (a == GEOALL) {
   data_out = array(GEO, numberof(indx));
   data_out.rn = data.rn(indx);
   data_out.north = data.north(indx);
   data_out.east = data.east(indx);
   data_out.sr2 = data.sr2(indx);
   data_out.elevation = data.elevation(indx);
   data_out.mnorth = data.mnorth(indx);
   data_out.meast = data.meast(indx);
   data_out.melevation = data.melevation(indx);
   data_out.bottom_peak = data.bottom_peak(indx);
   data_out.first_peak = data.first_peak(indx);
   data_out.depth = data.depth(indx);
 }
 if (a == GEO) data_out = data(indx);

 if (a == VEGALL) {
   data_out = array(VEG, numberof(indx));
   data_out.rn = data.rn(indx);
   data_out.north = data.north(indx);
   data_out.east = data.east(indx);
   data_out.elevation = data.elevation(indx);
   data_out.mnorth = data.mnorth(indx);
   data_out.meast = data.meast(indx);
   data_out.melevation = data.melevation(indx);
   data_out.felv = data.felv(indx);
   data_out.fint = data.fint(indx);
   data_out.lelv = data.lelv(indx);
   data_out.lint = data.lint(indx);
   data_out.nx = data.nx(indx);
 }
 if (a == VEG) data_out = data(indx);

 if (a == VEG_ALL) {
   data_out = array(VEG_, numberof(indx));
   data_out.rn = data.rn(indx);
   data_out.north = data.north(indx);
   data_out.east = data.east(indx);
   data_out.elevation = data.elevation(indx);
   data_out.mnorth = data.mnorth(indx);
   data_out.meast = data.meast(indx);
   data_out.melevation = data.melevation(indx);
   data_out.felv = data.felv(indx);
   data_out.fint = data.fint(indx);
   data_out.lelv = data.lelv(indx);
   data_out.lint = data.lint(indx);
   data_out.nx = data.nx(indx);
 }
 if (a == VEG_) data_out = data(indx);
 if (a == VEG__) data_out = data(indx);

 return data_out;

}

func sel_data_ptRadius(data, point=, radius=, win=) {
  /*DOCUMENT sel_data_ptRadius(data, point, radius=) 
  	This function selects data given a point (in latlon or utm) and a radius.
 	amar nayegandhi 06/26/03.
  */

  extern utm
  if (!win) win = 5;
  if (!is_array(point)) {
     window, win;
     prompt = "Click to define center point in window";
     result = mouse(1, 0, prompt);
     point = [result(1), result(2)];
  }
    
  window, win;
  plmk, point(2), point(1), color="black", msize=0.5, marker=2
  if (!radius) radius = 1.0;

  radius = float(radius)
  write, format="Selected Point Coordinates: %8.2f, %9.2f\n",point(1), point(2);
  write, format="Radius: %5.2f m\n",radius;

  // first find the rectangular region of length radius and the point selected as center
  xmax = point(1)+radius;
  xmin = point(1)-radius;
  ymax = point(2)+radius;
  ymin = point(2)-radius;

  plg, [point(2), point(2)], [point(1), point(1)+radius], width=2.0, color="blue";
  //a_x=[xmin, xmax, xmax, xmin, xmin];
  //a_y=[ymin, ymin, ymax, ymax, ymin];
  //plg, a_y, a_x, color="blue", width=2.0;

  indx = data_box(data.east, data.north, xmin*100, xmax*100, ymin*100, ymax*100);

  if (!is_array(indx)) {
    write, "No data found within selected rectangular region. ";
    return
  }

  // now find all data within the given radius
  datadist = sqrt((data.east(indx)/100. - point(1))^2 + (data.north(indx)/100. - point(2))^2);
  iindx = where(datadist <= radius);

  if (!is_array(indx)) {
    write, "No data found within selected region. ";
    return
  }


  return data(indx)(iindx);
  
}

func write_sel_rgn_stats(data, type) {
  write, "****************************"
  write, format="Number of Points Selected	= %6d \n",numberof(data.elevation);
  write, format="Average First Surface Elevation = %8.3f m\n",avg(data.elevation)/100.0;
  write, format="Median First Surface Elevation  = %8.3f m\n",median(data.elevation)/100.;
  if (type == VEG__) {
    write, format="Avg. Bare Earth Elevation 	= %8.3f m\n", avg(data.lelv)/100.0;
    write, format="Median  Bare Earth Elevation	= %8.3f m\n", median(data.lelv)/100.0;
  }
  if (type == GEO) {
    write, format="Avg. SubAqueous Elevation 	= %8.3f m\n", avg(data.depth+data.elevation)/100.0;
    write, format="Median SubAqueous Elevation	= %8.3f m\n", avg(data.depth+data.elevation)/100.0;
  }
  write, "****************************"
  return
}

func data_box(x, y, xmin, xmax, ymin, ymax) {
/*DOCUMENT data_box(x, y, xmin, xmax, ymin, ymax)
	Program takes the arrays (of equal dimension) x and y and returns 
	the indicies of the arrays that fit inside the box defined by xmin, xmax, ymin, ymax
*/
indx = where(x >= xmin);
 if (is_array(indx)) {
    indx1 = where(x(indx) <= xmax);
    if (is_array(indx1)) {
       indx2 = where(y(indx(indx1)) >= ymin);
       if (is_array(indx2)) {
          indx3 = where(y(indx(indx1(indx2))) <= ymax);
          if (is_array(indx3)) return indx(indx1(indx2(indx3)));
       } else return;
    } else return;
 } else return;
}
